# XDG base directories
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_BIN_HOME="$HOME/.local/bin"
export XDG_CACHE_HOME="$HOME/.cache"

# Zsh configuration and plugins directories
export ZSH_CONFIG_DIR="$ZDOTDIR/config"
export ZSH_PLUGIN_DIR="$ZDOTDIR/plugins"
export ZSH_PATINA_PATH="$ZSH_PLUGIN_DIR/zsh-patina/target/release/zsh-patina"

# Tools configuration directories
export CARGO_BIN_HOME="$HOME/.cargo/bin"
export PNPM_HOME="$XDG_DATA_HOME/pnpm/bin/bin/bin"

# ATAC configuration
export ATAC_CONFIG_DIR="$XDG_CONFIG_HOME/atac"
export ATAC_THEME="$ATAC_CONFIG_DIR/themes/postman_theme.toml"
export ATAC_KEY_BINDINGS="$ATAC_CONFIG_DIR/key_binds/vim_key_bindings.toml"

# Disable docker hints
export DOCKER_CLI_HINTS=false

# Default editor and pager
export EDITOR=nvim
export VISUAL=$EDITOR
export PAGER=less
export MANPAGER=$PAGER
export GPG_TTY=$(tty)

# Cursor theme and size
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=22
export GTK_CURSOR_THEME=$XCURSOR_THEME

# path setup
typeset -gU path
path=(
	$XDG_BIN_HOME
	$CARGO_BIN_HOME
	$PNPM_HOME
	$path
)
