# Enable zsh hook management
autoload -U add-zsh-hook

# Source plugins
source "$ZDOTDIR/plugins.zsh"

# Load modular configs
local -a configs=(prompt history keybinds aliases fzf myfuncs)
for f in $configs; do
	[[ -r "$ZSH_CONFIG_DIR/$f.zsh" ]] && source "$ZSH_CONFIG_DIR/$f.zsh"
done

# SSH Agent / Keychain
_ssh_agent_lazy() {
	if [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" ]] &&
		ssh-add -l >/dev/null 2>&1; then
		echo "SSH agent already active"
		return 0
	fi

	[[ -f ~/.keychain/"$HOST"-sh ]] && source ~/.keychain/"$HOST"-sh
	eval "$(keychain --eval --quiet --nogui --timeout 480 ~/.ssh/id_ed25519)" &&
		echo "SSH agent started"
}

# zoxide integration
z() {
	unset -f z
	eval "$(zoxide init zsh)"
	z "$@"
}

# open yazi either at the given directory
# or at the one zoxide suggests
y() {
	if [[ -n $1 ]]; then
		if [ -d "$1" ]; then
			yazi "$1"
		else
			yazi "$(zoxide query $1)"
		fi
	else
		yazi
	fi
}

# fnm lazy load
_fnm_lazy_load() {
	if [[ -f package.json ]]; then
		eval "$(fnm env)" 2>/dev/null || return
		add-zsh-hook -d chpwd _fnm_lazy_load
	fi
}
_fnm_lazy_load
add-zsh-hook -d chpwd _fnm_lazy_load 2>/dev/null
add-zsh-hook chpwd _fnm_lazy_load

# fnm manual activation
fnm-on() {
	eval "$(fnm env)" 2>/dev/null
	echo "Node activated"
}
