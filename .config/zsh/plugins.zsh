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

    # Clone the plugin if it's not installed
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$ZSH_PLUGIN_DIR" || return 1
        print -u2 -P "==> Installing $repo..."

        if ! git clone --depth=1 --quiet \
            "https://github.com/$owner/$repo" "$dir"; then
            rm -rf "$dir"
            print -u2 -P "%F{red}✗ Failed to install $repo%f"
            return 1
        fi

        print -u2 -P "%F{green}✓ Installed $repo%f"
    fi

    local entry
    for entry in \
        "$dir/$repo.plugin.zsh" \
        "$dir"/*.plugin.zsh(N) \
        "$dir/$repo.zsh"; do
        [[ -r $entry ]] && { print -r -- $entry; return 0 }
    done

    # Last resort: only if there is exactly one *.zsh in the root
    local -a candidates=("$dir"/*.zsh(N))
    if (( $#candidates == 1 )) && [[ -r $candidates[1] ]]; then
        print -r -- $candidates[1]
        return 0
    fi

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
        if ! git clone --depth=1 --quiet \
            https://github.com/michel-kraemer/zsh-patina.git "$dir"; then
            rm -rf "$dir"
            print -u2 -P "%F{red}✗ Failed to clone zsh-patina%f"
            return 1
        fi
    fi

    # Prefer a pre-built binary. Never build at shell startup.
    if [[ ! -x $ZSH_PATINA_PATH ]]; then
        print -u2 -P "%F{red}zsh-patina binary not found at $ZSH_PATINA_PATH%f"
        print -u2 -P "Build it once with: (cd $dir && cargo build --release)"
        return 1
    fi

    # Activate zsh-patina
    _zsh_patina_activate() {
        unfunction _zsh_patina_activate
        add-zsh-hook -d precmd _zsh_patina_activate
        eval "$("$ZSH_PATINA_PATH" activate)"
    }
    add-zsh-hook precmd _zsh_patina_activate
}

# Update all installed plugin repositories
update-plugin() {
    emulate -L zsh
    local dir old new

    # Iterate over plugin directories only
    for dir in "$ZSH_PLUGIN_DIR"/*(/); do
        [[ -d "$dir/.git" ]] || continue

        old=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || continue

        printf "%-32s" "${dir:t}"

        # Fetch once
        if ! git -C "$dir" fetch --depth=1 --quiet origin; then
            print -u2 -P "%F{red}✗ Failed to update%f"
            continue
        fi

        # Prefer clean fast-forward, fall back to hard reset
        if git -C "$dir" merge --ff-only --quiet FETCH_HEAD 2>/dev/null ||
            git -C "$dir" reset --hard --quiet FETCH_HEAD; then
            new=$(git -C "$dir" rev-parse HEAD)
            if [[ $old == $new ]]; then
                print -P "%F{8}○ Already up to date%f"
            else
                _update_plugin_success "$dir"
            fi
        else
            print -u2 -P "%F{red}✗ Failed to update%f"
        fi
    done
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

# Load plugins
source "$(plugin-path romkatv gitstatus)"
source "$(plugin-path romkatv zsh-defer)"
zsh-defer -c '
  source "$(plugin-path mattmc3 ez-compinit)"
  source "$(plugin-path zsh-users zsh-completions)"
  source "$(plugin-path aloxaf fzf-tab)"
  source "$(plugin-path zsh-users zsh-autosuggestions)"
  source "$(plugin-path zsh-users zsh-history-substring-search)"
  source "$(plugin-path houssamouhra colored-man-pages)"
  load-zsh-patina
'
