# Clone a plugin on first use (if missing)
plugin-path() {
    emulate -L zsh

    # Validate arguments
    (($# >= 2)) || {
        print -u2 -P "%F{red}usage: plugin-path <owner> <repo>%f"
        return 1
    }

    local owner=$1
    local repo=$2
    local dir="$ZSH_PLUGIN_DIR/$repo"
    local entry

    # Clone the plugin if it's not installed
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$ZSH_PLUGIN_DIR" || return

        print -u2 -P "==> Installing $repo..."

        if ! git clone --depth=1 \
            "https://github.com/$owner/$repo" "$dir" >/dev/null 2>&1; then
            rm -rf "$dir"
            print -u2 -P "%F{red}✗ Failed to install $repo%f"
            return 1
        fi

        print -u2 -P "%F{green}✓ Installed $repo%f"
    fi

    for entry in \
        "$dir/$repo.plugin.zsh" \
        "$dir"/*.plugin.zsh(N) \
        "$dir/$repo.zsh" \
        "$dir"/*.zsh(N);
    do
        [[ -r $entry ]] && {
            print -r -- "$entry"
            return
        }
    done

    print -u2 -P "%F{red}Missing plugin entry:%f $dir"
    return 1
}

# Install and initialize zsh-patina
# A Fast syntax highlighter
load-zsh-patina() {
    emulate -L zsh

    local dir="$ZSH_PLUGIN_DIR/zsh-patina"

    # Clone on first use
    if [[ ! -d "$dir" ]]; then
        print -u2 -P "==> Installing zsh-patina..."

        if ! git clone --depth=1 \
            https://github.com/michel-kraemer/zsh-patina.git "$dir" >/dev/null 2>&1; then
            print -u2 -P "%F{red}✗ Failed to clone zsh-patina%f"
            return 1
        fi
    fi

    # Build if the binary doesn't exist
    if [[ ! -x "$ZSH_PATINA_PATH" ]]; then
        print -u2 -P "==> Building zsh-patina..."

        if ! command -v cargo >/dev/null; then
            print -u2 -P "%F{red}cargo is not installed%f"
            return 1
        fi

        (
            cd "$dir" &&
                cargo build --release --quiet
        ) || {
            print -u2 -P "%F{red}✗ Failed to build zsh-patina%f"
            return 1
        }

        print -u2 -P "%F{green}✓ Built zsh-patina%f"
    fi

    _syntax_highlight() {
        unfunction _syntax_highlight
        eval "$("$ZSH_PATINA_PATH" activate)"
    }
    add-zsh-hook -d precmd _syntax_highlight 2>/dev/null
    add-zsh-hook precmd _syntax_highlight
}

# Update all installed plugin repositories
update-plugin() {
    emulate -L zsh

    local dir old new

    # Iterate over plugin directories only
    for dir in "$ZSH_PLUGIN_DIR"/*(/); do
        [[ -d "$dir/.git" ]] || continue

        old=$(git -C "$dir" rev-parse HEAD)

        printf "%-32s" "${dir:t}"

        if git -C "$dir" fetch --depth=1 origin >/dev/null 2>&1 &&
            git -C "$dir" reset --hard "@{u}" >/dev/null 2>&1; then

            new=$(git -C "$dir" rev-parse HEAD)

            if [[ $old == $new ]]; then
                print -P "%F{8}○ Already up to date%f"
            else
                case ${dir:t} in
                zsh-patina)
                    if ((! $+commands[cargo])); then
                        print -u2 -P "%F{yellow}⚠ cargo is not installed%f"
                    elif (cd "$dir" && cargo build --release >/dev/null 2>&1); then
                        print -P "%F{green}✓ Updated & rebuilt%f"
                    else
                        print -u2 -P "%F{yellow}⚠ Updated, but rebuild failed%f"
                    fi
                    ;;
                *)
                    print -P "%F{green}✓ Updated%f"
                    ;;
                esac
            fi
        else
            print -u2 -P "%F{red}✗ Failed to update%f"
        fi
    done
}

# Load plugins
source "$(plugin-path romkatv gitstatus)"
source "$(plugin-path romkatv zsh-defer)"
zsh-defer source "$(plugin-path mattmc3 ez-compinit)"
zsh-defer source "$(plugin-path zsh-users zsh-completions)"
zsh-defer source "$(plugin-path aloxaf fzf-tab)"
zsh-defer source "$(plugin-path zsh-users zsh-autosuggestions)"
zsh-defer source "$(plugin-path zsh-users zsh-history-substring-search)"
zsh-defer source "$(plugin-path houssamouhra colored-man-pages)"
load-zsh-patina
