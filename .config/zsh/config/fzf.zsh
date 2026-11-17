# Requires fzf >= 0.48 (`fzf --zsh`).
# Must be sourced AFTER plugins.zsh: fzf's init is queued with zsh-defer, and
# the queue runs in order, so fzf-tab is already loaded when fzf initializes.
# ──────────────────────────────────────────────────────────────────────────────


# ── Options ───────────────────────────────────────────────────────────────────
# Unified preview: directories -> tree, files -> bat
FZF_PREVIEW="--preview '$XDG_CONFIG_HOME/fzf/preview.sh {}'"
export FZF_DEFAULT_OPTS_FILE="$XDG_CONFIG_HOME/fzf/config"

# Ctrl+T: multi-select, Ctrl+O opens the selection in $EDITOR (default nvim)
export FZF_CTRL_T_OPTS="$FZF_PREVIEW \
--multi \
--bind 'ctrl-o:execute(${EDITOR:-nvim} {+})+abort'"

# Alt+C: directory preview
export FZF_ALT_C_OPTS="$FZF_PREVIEW"

# Ctrl+R: reverse history search with inline info
export FZF_CTRL_R_OPTS="\
--height ${FZF_TMUX_HEIGHT:-50%} \
--reverse \
--scheme=history \
--exact \
--inline-info"

# ── Initialization ────────────────────────────────────────────────────────────
# Run a command deferred if zsh-defer exists, otherwise immediately.
_fzf_defer() {
	if (( $+functions[zsh-defer] )); then
		zsh-defer "$@"
	else
		"$@"
	fi
}

# Load fzf's key bindings and completion, then give Tab back to fzf-tab
# (`fzf --zsh` rebinds Tab to its own completion, which would sit on top of it).
_fzf_init() {
	emulate -L zsh
	(( $+commands[fzf] )) || return 1

	source <(fzf --zsh) || return 1

	if (( $+widgets[fzf-tab-complete] )); then
		local keymap
		for keymap in emacs viins; do
			bindkey -M $keymap '^I' fzf-tab-complete
		done
	fi
}
_fzf_defer _fzf_init

# fzf-git key bindings (Ctrl-G Ctrl-B, etc.); deferred so they exist right away
_fzf_git_script="$XDG_CONFIG_HOME/fzf-git/fzf-git.sh"
[[ -r $_fzf_git_script ]] && _fzf_defer source "$_fzf_git_script"
unset _fzf_git_script

# ── Helpers ───────────────────────────────────────────────────────────────────
# fzf_ssh: pick a host from ~/.ssh/config and connect
# (handles several aliases per Host line, skips wildcards, any letter case)
fzf_ssh() {
	emulate -L zsh
	local config="$HOME/.ssh/config" host

	[[ -r $config ]] || {
		print -u2 "fzf_ssh: cannot read $config"
		return 1
	}

	host=$(
		awk 'tolower($1) == "host" {
			for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i
		}' "$config" |
		sort -u |
		fzf --prompt='ssh> ' \
			--preview 'ssh -G {} | grep -iE "^(hostname|user|port|identityfile) "'
	) || return

	[[ -n $host ]] && ssh -- "$host"
}

# fkill [signal]: pick processes and kill them (default signal: TERM)
fkill() {
	emulate -L zsh
	local pids

	if (( UID )); then
		pids=$(ps -U "$UID" -o pid=,comm= | fzf -m --prompt='kill> ' | awk '{print $1}')
	else
		pids=$(ps -A -o pid=,comm= | fzf -m --prompt='kill> ' | awk '{print $1}')
	fi

	[[ -n $pids ]] || return 0
	kill -"${1:-TERM}" ${(f)pids}
}
