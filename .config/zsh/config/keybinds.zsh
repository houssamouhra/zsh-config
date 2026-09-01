bindkey -e

# Cursor movement
bindkey '^a' beginning-of-line
bindkey '^e' end-of-line

# Editing
bindkey '^w' backward-kill-word
bindkey '^u' backward-kill-line
bindkey '^_' undo

# History search
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward

# Character movement
bindkey '^b' backward-char
bindkey '^f' forward-char

# History substring search
bindkey '^p' history-substring-search-up
bindkey '^n' history-substring-search-down

# Open the current command line in your $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Shortcuts
bindkey -s '^G' 'tmux-sessionizer'
