# Clone a plugin on first use (if missing)
plugin-path() {
    emulate -L zsh
    setopt localoptions nullglob

    # Validate arguments
    (($# >= 2)) || {
        print -u2 -P "%F{red}usage: plugin-path <owner> <repo> %f"
        return 1
    }

    local owner=$1
    local repo=$2
    local dir="$ZSH_PLUGIN_DIR/$repo"

    # Clone the plugins
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$ZSH_PLUGIN_DIR" || return 1
        print -u2 -P "→ ${(r:29:)repo} %F{cyan}installing...%f"

        if ! git clone --depth=1 --quiet \
            "https://github.com/$owner/$repo" "$dir"; then
            rm -rf "$dir"
            print -u2 -P "→ ${(r:29:)repo} %F{red}✗ clone failed%f"
            print -u2
            return 1
        fi

        print -u2 -P "→ ${(r:29:)repo} %F{green}✓ installed%f"
        print -u2
    fi

    # Prefer the conventional entry points
    local entry
    for entry in \
        "$dir/$repo.plugin.zsh" \
        "$dir"/*.plugin.zsh \
        "$dir/$repo.zsh"
    do
        [[ -r $entry ]] && {
            print -r -- "$entry"
            return 0
        }
    done

    # Last resort: only if there is exactly one *.zsh in the root
    local -a candidates=("$dir"/*.zsh)

    if (( $#candidates == 1 )) && [[ -r $candidates[1] ]]; then
        print -r -- "$candidates[1]"
        return 0
    fi

    print -u2 -P "→ ${(r:29:)repo} %F{red}✗ missing plugin entry%f"
    print -u2
    return 1
}

# Install (and build if needed) + activate zsh-patina
# A fast syntax highlighter written in Rust
load-zsh-patina() {
    emulate -L zsh

    local dir="$ZSH_PLUGIN_DIR/zsh-patina"
    local name="zsh-patina"

    # Clone on first use
    if [[ ! -d "$dir" ]]; then
        print -u2 -P "→ ${(r:29:)name} %F{cyan}installing...%f"

        if ! git clone --depth=1 --quiet \
            https://github.com/michel-kraemer/zsh-patina.git "$dir"; then
            rm -rf "$dir"
            print -u2 -P "→ ${(r:29:)name} %F{red}✗ clone failed%f"
            print -u2
            return 1
        fi

        print -u2 -P "→ ${(r:29:)name} %F{green}✓ installed%f"
        print -u2

    fi

    # Build the binary if it is missing
    if [[ ! -x $ZSH_PATINA_PATH ]]; then
        if ! (( $+commands[cargo] )); then
            print -u2 -P "→ ${(r:29:)name} %F{yellow}⚠ cargo is missing%f"
            print -u2 -P "  Install Rust from https://rustup.rs and then run:"
            print -u2 -P "  Then run: (cd $dir && cargo build --release)"
            print -u2
            return 1
        fi

        print -u2 -P "→ ${(r:29:)name} %F{cyan}building...%f"

        if ! (cd "$dir" && cargo build --release --quiet); then
            print -u2 -P "→ ${(r:29:)name} %F{red}✗ build failed%f"
            print -u2
            return 1
        fi

        print -u2 -P "→ ${(r:29:)name} %F{green}✓ built%f"
        print -u2
    fi

    # Final sanity check
    if [[ ! -x $ZSH_PATINA_PATH ]]; then
        print -u2 -P "→ ${(r:29:)name} %F{red}✗ binary not found%f"
        print -u2
        return 1
    fi

    # Activate only once (safe to call multiple times)
    if ! typeset -f _zsh_patina_activate >/dev/null 2>&1; then
        _zsh_patina_activate() {
            unfunction _zsh_patina_activate
            add-zsh-hook -d precmd _zsh_patina_activate
            eval "$("$ZSH_PATINA_PATH" activate)"
        }

        add-zsh-hook precmd _zsh_patina_activate
    fi
}

update-plugin() {
    emulate -L zsh
    setopt localoptions nullglob nomonitor

    local -a plugins=("$ZSH_PLUGIN_DIR"/*(/))
    (( $#plugins )) || {
        print -P "%F{yellow}No plugins found in $ZSH_PLUGIN_DIR%f"
        return 0
    }

    local dir name
    local -a pids=()

    print -P "%F{cyan}Updating ${#plugins} plugins...%f"

    for dir in $plugins; do
        [[ -d "$dir/.git" ]] || continue
        name=${dir:t}

        (
            local old new

            old=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || {
                print -P "⎔ ${(r:29:)name} %F{red}✗ not a valid git repo%f"
                return
            }

            if ! git -C "$dir" fetch --depth=1 --quiet origin 2>/dev/null; then
                print -P "⎔ ${(r:29:)name} %F{red}✗ fetch failed%f"
                return
            fi

            if git -C "$dir" merge --ff-only --quiet FETCH_HEAD 2>/dev/null ||
                git -C "$dir" reset --hard --quiet FETCH_HEAD 2>/dev/null; then

                new=$(git -C "$dir" rev-parse HEAD)

                if [[ $old == $new ]]; then
                    print -P "⎔ ${(r:29:)name} %F{8}○ already up to date%f"

                elif [[ $name == zsh-patina ]]; then
                    if ! (( $+commands[cargo] )); then
                        print -P "⎔ ${(r:29:)name} %F{yellow}⚠ updated, but cargo missing%f"
                    elif (cd "$dir" && cargo build --release --quiet); then
                        print -P "⎔ ${(r:29:)name} %F{green}✓ updated & rebuilt%f"
                    else
                        print -P "⎔ ${(r:29:)name} %F{yellow}⚠ updated, rebuild failed%f"
                    fi
                else
                    print -P "⎔ ${(r:29:)name} %F{green}✓ updated%f"
                fi
            else
                print -P "⎔ ${(r:29:)name} %F{red}✗ update failed%f"
            fi
        ) &

        pids+=($!)
    done

    for pid in $pids; do
        wait $pid
    done

    print -P "%F{green}Done.%f"
}

# Helper to avoid repeating the success / rebuild logic
_update_plugin_success() {
    local dir=$1

    case ${dir:t} in
        zsh-patina)
            if ! (( $+commands[cargo] )); then
                print -P "%F{yellow}⚠ Updated, but cargo is missing%f"
            elif (cd "$dir" && cargo build --release --quiet); then
                print -P "%F{green}✓ Updated & rebuilt%f"
            else
                print -P "%F{yellow}⚠ Updated, but rebuild failed%f"
            fi
            ;;

        *)
            print -P "%F{green}✓ Updated%f"
            ;;
    esac
}

# Critical plugins, loaded immediately
source "$(plugin-path romkatv gitstatus)"
source "$(plugin-path romkatv zsh-defer)"

# Install the rest (hide the path, keep the status messages)
plugin-path mattmc3 ez-compinit                    >/dev/null
plugin-path zsh-users zsh-completions              >/dev/null
plugin-path aloxaf fzf-tab                         >/dev/null
plugin-path zsh-users zsh-autosuggestions          >/dev/null
plugin-path zsh-users zsh-history-substring-search >/dev/null
plugin-path houssamouhra colored-man-pages         >/dev/null
load-zsh-patina                                    >/dev/null

# Defer only the sourcing
zsh-defer -c '
    source "$(plugin-path mattmc3 ez-compinit)"
    source "$(plugin-path zsh-users zsh-completions)"
    source "$(plugin-path aloxaf fzf-tab)"
    source "$(plugin-path zsh-users zsh-autosuggestions)"
    source "$(plugin-path zsh-users zsh-history-substring-search)"
    source "$(plugin-path houssamouhra colored-man-pages)"
    load-zsh-patina
'
