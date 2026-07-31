# Enable zsh hook management
autoload -U add-zsh-hook

# Source plugins
source "$ZDOTDIR/plugins.zsh"

# Load modular configs
local -a configs=(prompt history keybinds aliases fzf functions)
for f in $configs; do
	[[ -r "$ZSH_CONFIG_DIR/$f.zsh" ]] && source "$ZSH_CONFIG_DIR/$f.zsh"
done
