# FZF default options & preview
# Unified preview: directories -> tree, files -> bat
FZF_PREVIEW="--preview '$XDG_CONFIG_HOME/fzf/preview.sh {}'"
export FZF_DEFAULT_OPTS_FILE="$XDG_CONFIG_HOME/fzf/config"

# Ctrl+T options: multi-select + open selected files in nvim
export FZF_CTRL_T_OPTS="$FZF_PREVIEW \
--multi \
--bind 'ctrl-o:execute(nvim {+})+abort'"

# Alt+C options: directory preview
export FZF_ALT_C_OPTS="$FZF_PREVIEW"

# Ctrl+R options: reverse history search with inline info
export FZF_CTRL_R_OPTS="\
--height ${FZF_TMUX_HEIGHT:-50%} \
--reverse \
--scheme=history \
--exact \
--ansi \
--inline-info"

# FZF initialization
_fzf_init() {
    emulate -L zsh
    (( $+commands[fzf] )) || return
    local init
    init="$(fzf --zsh)" || return
    eval "$init" || return
    unfunction _fzf_init
}

# Lazy load Ctrl+R history search
_fzf_history_lazy() {
    _fzf_init
    fzf-history-widget() {
        local selected ret=0
        emulate -L zsh
        setopt pipefail no_aliases

        selected=$(
            fc -lnr 1 |
            awk '!seen[$0]++' |
            FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} ${FZF_CTRL_R_OPTS}" \
                fzf +m --query "$LBUFFER"
        )

        ret=$?
        [[ -z "$selected" ]] && { zle redisplay; return $ret; }

        LBUFFER="$selected"
        zle reset-prompt
    }

    zle -N fzf-history-widget
    zle fzf-history-widget
}
zle -N _fzf_history_lazy
bindkey '^R' _fzf_history_lazy

# Lazy load Ctrl+T file finder
_fzf_file_widget_lazy() {
    _fzf_init
    zle fzf-file-widget
}
zle -N _fzf_file_widget_lazy
bindkey '^T' _fzf_file_widget_lazy

# Lazy load Alt+C directory finder
_fzf_cd_widget_lazy() {
    _fzf_init
    zle fzf-cd-widget
}
zle -N _fzf_cd_widget_lazy
bindkey '^[c' _fzf_cd_widget_lazy

# Lazy git-fzf integration
# Override git command to source fzf-git only when git is used
git() {
    unfunction git
    local fzf_git="${XDG_CONFIG_HOME}/fzf-git/fzf-git.sh"
    [[ -f "$fzf_git" ]] && source "$fzf_git" 2>/dev/null
    command git "$@"
}

# FZF SSH quick connect
fzf_ssh() {
    emulate -L zsh
    local host
    [[ -r ~/.ssh/config ]] || return
    host=$(awk '/^Host / && $2 != "*" {print $2}' ~/.ssh/config | fzf --preview 'dig {} +short; ping -c1 {} 2>/dev/null | head -1')
    [[ -n $host ]] && ssh "$host"
}

# FZF process killer
fkill() {
    emulate -L zsh
    local pid
    if [[ $UID -ne 0 ]]; then
        pid=$(ps -u "$UID" -o pid,comm --no-headers | fzf -m | awk '{print $1}')
    else
        pid=$(ps -ef | awk 'NR>1 {print $2, $8}' | fzf -m | awk '{print $1}')
    fi

    [[ -n $pid ]] && kill -"${1:-9}" ${(f)pid}
}
