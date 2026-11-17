# tiny plugin manager (clone on first use, load deferred)

typeset -gi _PLUGIN_LABEL_WIDTH=29

# plugin-path <owner> <repo>
# Clones the repo on first use, then sets REPLY to the plugin's entry file.
# Uses REPLY instead of printing, so callers don't need a $(...) subshell:
#   plugin-path romkatv gitstatus && source $REPLY
plugin-path() {
    emulate -L zsh
    setopt nullglob

    REPLY=

    (( $# >= 2 )) || {
        print -u2 -P "%F{red}usage: plugin-path <owner> <repo>%f"
        return 1
    }

    local owner=$1 repo=$2
    local dir="$ZSH_PLUGIN_DIR/$repo"
    local label="${(r:$_PLUGIN_LABEL_WIDTH:)repo}"

    # Clone on first use
    if [[ ! -d $dir ]]; then
        mkdir -p "$ZSH_PLUGIN_DIR" || return 1
        print -u2 -P "→ $label %F{cyan}installing...%f"

        # GIT_TERMINAL_PROMPT=0: a typo'd repo fails instead of asking for credentials
        if ! GIT_TERMINAL_PROMPT=0 git clone --depth=1 --quiet \
            "https://github.com/$owner/$repo" "$dir"; then
            rm -rf "$dir"
            print -u2 -P "→ $label %F{red}✗ clone failed%f"
            return 1
        fi

        print -u2 -P "→ $label %F{green}✓ installed%f"
    fi

    # Prefer the conventional entry points
    local entry
    for entry in \
        "$dir/$repo.plugin.zsh" \
        "$dir"/*.plugin.zsh \
        "$dir/$repo.zsh"
    do
        if [[ -r $entry ]]; then
            REPLY=$entry
            return 0
        fi
    done

    # Last resort: exactly one *.zsh in the root
    local -a candidates=("$dir"/*.zsh)
    if (( $#candidates == 1 )) && [[ -r $candidates[1] ]]; then
        REPLY=$candidates[1]
        return 0
    fi

    print -u2 -P "→ $label %F{red}✗ missing plugin entry%f"
    return 1
}

# update-plugins: update every cloned plugin in parallel
update-plugins() {
    emulate -L zsh
    setopt nullglob nomonitor

    local -a plugins=("$ZSH_PLUGIN_DIR"/*(/N))
    (( $#plugins )) || {
        print -P "%F{yellow}No plugins found in $ZSH_PLUGIN_DIR%f"
        return 0
    }

    print -P "%F{cyan}Updating $#plugins plugins...%f"

    local dir pid
    local -a pids=()

    for dir in $plugins; do
        [[ -d $dir/.git ]] || continue

        (
            local name=${dir:t}
            local label="${(r:$_PLUGIN_LABEL_WIDTH:)name}"
            local old new
            export GIT_TERMINAL_PROMPT=0

            old=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || {
                print -P "→ $label %F{red}✗ not a valid git repo%f"
                return
            }

            git -C "$dir" fetch --depth=1 --quiet origin 2>/dev/null || {
                print -P "→ $label %F{red}✗ fetch failed%f"
                return
            }

            # Plugins are read-only clones, so a hard reset is fine
            git -C "$dir" reset --hard --quiet FETCH_HEAD 2>/dev/null || {
                print -P "→ $label %F{red}✗ update failed%f"
                return
            }

            new=$(git -C "$dir" rev-parse HEAD)

            if [[ $old == $new ]]; then
                print -P "→ $label %F{8}○ already up to date%f"
            else
                print -P "→ $label %F{green}✓ updated%f %F{8}${old[1,7]} → ${new[1,7]}%f"
            fi
        ) &
        pids+=($!)
    done

    for pid in $pids; do
        wait $pid
    done

    print -P "%F{green}Done.%f"
}

# Critical plugins: loaded immediately (prompt.zsh depends on both)
plugin-path romkatv gitstatus && source $REPLY
plugin-path romkatv zsh-defer && source $REPLY

# Autosuggestions settings
typeset -g ZSH_AUTOSUGGEST_MANUAL_REBIND=1
typeset -g ZSH_AUTOSUGGEST_USE_ASYNC=1
typeset -g ZSH_AUTOSUGGEST_STRATEGY=(history)

# Deferred plugins
# Order matters:
#   1. zsh-completions   adds to fpath, so it must come BEFORE compinit
#   2. ez-compinit       runs compinit
#   3. fzf-tab           must come after compinit
#   4. the rest

typeset -a _deferred_plugins=(
    zsh-users/zsh-completions
    mattmc3/ez-compinit
    Aloxaf/fzf-tab
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-history-substring-search
    houssamouhra/colored-man-pages
)

# Clone anything missing now (status messages show on first run) and queue
# each plugin for deferred sourcing. zsh-defer keeps queue order.
typeset _spec
for _spec in $_deferred_plugins; do
    plugin-path ${_spec%%/*} ${_spec#*/} && zsh-defer source $REPLY
done
unset _spec _deferred_plugins

# Autosuggestions normally binds its widgets from a one-shot precmd hook, which
# would only fire after the *first* command. Bind right away instead.
zsh-defer -c '(( $+functions[_zsh_autosuggest_start] )) && _zsh_autosuggest_start'

# zsh-patina: activate directly (no precmd hook needed)
# If this misbehaves, go back to the one-shot precmd hook version.
zsh-defer -c '(( $+commands[zsh-patina] )) && eval "$(zsh-patina activate)"'
