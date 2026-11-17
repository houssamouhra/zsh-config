# The prompt answers four questions:
#   1. Where am I?                           → PATH_INFO
#   2. What Git context am I in?             → GIT_INFO (branch/tag/HEAD)
#   3. Is the repo in a notable state?       → status icons (+!?✘=$⇡⇣)
#   4. Did my last command fail / take long? → CMD_STATUS + CMD_DURATION
#
# Architecture: everything is driven by async gitstatus.
# On every precmd we fire a non-blocking gitstatus_query (-t 0). While the
# query is in flight, VCS_STATUS_RESULT is "tout" and we deliberately ignore
# it, keeping the last known worktree. PATH_INFO is only recalculated when the
# directory changes or a real result (ok-* / norepo-*) changes the worktree.
# The async callback updates GIT_INFO (and PATH_INFO if needed) and issues a
# single `zle reset-prompt` if anything visible changed. This avoids the
# classic "~/repo" ↔ "repo" flicker while keeping the prompt fully non-blocking.
#
# Requires (from plugins.zsh): gitstatus, zsh-defer
#
# Conventions: helper functions return their value in $REPLY instead of
# printing, so callers avoid a $(...) subshell (a fork) on every prompt.
# ──────────────────────────────────────────────────────────────────────────────

autoload -Uz add-zsh-hook
setopt PROMPT_SUBST

typeset -g  PATH_INFO GIT_INFO CMD_STATUS CMD_DURATION
typeset -g  _LAST_PWD _LAST_WORKTREE _REPO_NAME
typeset -g  _PROMPT_START_TIME
typeset -gi _GITSTATUS_READY=0

# Show the duration of a command only if it took at least this many seconds
typeset -gi PROMPT_DURATION_THRESHOLD=2

# ── Git segment ───────────────────────────────────────────────────────────────
# Sets REPLY to the branch/tag + status icons.
_prompt_git() {
	case $VCS_STATUS_RESULT in
		ok-*)     ;;
		norepo-*) REPLY=; return ;;
		*)        REPLY=$GIT_INFO; return ;;  # in flight: keep what we have
	esac

	local -a segments
	(( VCS_STATUS_NUM_STAGED ))     && segments+=('+')
	(( VCS_STATUS_NUM_UNSTAGED ))   && segments+=('!')
	(( VCS_STATUS_NUM_UNTRACKED ))  && segments+=('?')
	(( VCS_STATUS_NUM_STAGED_DELETED + VCS_STATUS_NUM_UNSTAGED_DELETED )) && segments+=('✘')
	(( VCS_STATUS_NUM_CONFLICTED )) && segments+=('=')
	(( VCS_STATUS_STASHES ))        && segments+=('$')
	(( VCS_STATUS_COMMITS_AHEAD ))  && segments+=("⇡${VCS_STATUS_COMMITS_AHEAD}")
	(( VCS_STATUS_COMMITS_BEHIND )) && segments+=("⇣${VCS_STATUS_COMMITS_BEHIND}")

	local ref
	if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
		ref=$VCS_STATUS_LOCAL_BRANCH
	elif [[ -n $VCS_STATUS_TAG ]]; then
		ref="#$VCS_STATUS_TAG"
	else
		ref="HEAD (${VCS_STATUS_COMMIT[1,7]})"
	fi

	# A literal % in a branch name must not be read as a prompt escape
	REPLY="%F{green}󰘬 ${ref//\%/%%}%f"
	(( $#segments )) && REPLY+=" %B%F{red}[${(j::)segments}]%f%b"
}

# ── Path segment ──────────────────────────────────────────────────────────────
# Sets REPLY to a truncated path: repo-relative inside git, otherwise the
# last 1-2 directories.
_prompt_path() {
	local worktree=${_LAST_WORKTREE-} out relative
	local -a parts

	if [[ -n $worktree && ( $PWD == "$worktree" || $PWD == "$worktree"/* ) ]]; then
		# Inside a known git worktree
		if [[ $PWD == "$worktree" ]]; then
			out=$_REPO_NAME
		else
			relative=${PWD#"$worktree"/}
			if [[ $relative == */* ]]; then
				out="…/${relative:h:t}/${relative:t}"
			else
				out="…/$relative"
			fi
		fi
	elif [[ $PWD == "$HOME" ]]; then
		out='~'
	elif [[ $PWD == "$HOME"/* ]]; then
		relative=${PWD#"$HOME"/}
		parts=(${(s:/:)relative})
		if (( $#parts <= 3 )); then
			out="~/$relative"
		else
			out="…/${parts[-2]}/${parts[-1]}"
		fi
	else
		parts=(${(s:/:)PWD})
		if (( $#parts <= 2 )); then
			out=$PWD
		else
			out="…/${parts[-2]}/${parts[-1]}"
		fi
	fi

	# Escape % so odd directory names can't inject prompt escapes
	REPLY=${out//\%/%%}
}

# Recompute PATH_INFO only if the directory or worktree really changed.
_prompt_refresh_path() {
	local worktree
	case $VCS_STATUS_RESULT in
		ok-*)     worktree=$VCS_STATUS_WORKDIR ;;
		norepo-*) worktree= ;;                    # really left the repo
		*)        worktree=${_LAST_WORKTREE-} ;;  # in flight: keep previous
	esac

	if [[ $PWD != ${_LAST_PWD-} || $worktree != ${_LAST_WORKTREE-} ]]; then
		_LAST_WORKTREE=$worktree
		_REPO_NAME=${worktree:t}
		_prompt_path
		PATH_INFO=$REPLY
		_LAST_PWD=$PWD
	fi
}

# ── gitstatus ─────────────────────────────────────────────────────────────────
# Async callback: update git info and redraw only if something changed.
_prompt_gitstatus_cb() {
	local old_git=$GIT_INFO old_path=$PATH_INFO

	_prompt_git
	GIT_INFO=$REPLY
	_prompt_refresh_path

	if [[ $GIT_INFO != $old_git || $PATH_INFO != $old_path ]]; then
		zle && zle reset-prompt
	fi
}

# Start the daemon once the shell is interactive, then fire the first query
_prompt_gitstatus_init() {
	(( $+functions[gitstatus_start] )) || return 1
	gitstatus_start -s -1 -u -1 -c -1 -d -1 -e "MY_PROMPT"
	_GITSTATUS_READY=1
	gitstatus_query -t 0 -c _prompt_gitstatus_cb "MY_PROMPT"
}

if (( $+functions[zsh-defer] )); then
	zsh-defer _prompt_gitstatus_init
else
	_prompt_gitstatus_init
fi

# ── Hooks ─────────────────────────────────────────────────────────────────────
_prompt_preexec() {
	_PROMPT_START_TIME=$SECONDS
}

_prompt_precmd() {
	local st=$?   # must stay the first statement: captures the last exit status

	if (( st )); then
		CMD_STATUS='%F{red}➜%f'
	else
		CMD_STATUS='%F{magenta}➜%f'
	fi

	# Command duration
	CMD_DURATION=
	if [[ -n $_PROMPT_START_TIME ]]; then
		local -i sec=$(( SECONDS - _PROMPT_START_TIME ))
		_PROMPT_START_TIME=

		if (( sec >= 60 )); then
			CMD_DURATION="%F{yellow}$(( sec / 60 ))m$(( sec % 60 ))s%f"
		elif (( sec >= PROMPT_DURATION_THRESHOLD )); then
			CMD_DURATION="%F{yellow}${sec}s%f"
		fi
	fi

	# Fire the async gitstatus query
	if (( _GITSTATUS_READY )); then
		gitstatus_query -t 0 -c _prompt_gitstatus_cb "MY_PROMPT"
	fi

	# Refresh path (only does work on real changes)
	_prompt_refresh_path
}

# Registered at config time, so this runs before hooks added later by plugins,
# which keeps $? intact for _prompt_precmd.
add-zsh-hook preexec _prompt_preexec
add-zsh-hook precmd  _prompt_precmd

# ── Prompt ────────────────────────────────────────────────────────────────────
# One-line prompt
PROMPT='%B%F{blue}${PATH_INFO}%f%b ${GIT_INFO:+${GIT_INFO} }${CMD_STATUS} '

# Two-line prompt option
# PROMPT=$'\n%B%F{blue}${PATH_INFO}%f%b ${GIT_INFO}\n${CMD_STATUS} '

RPROMPT='${CMD_DURATION}'
PROMPT_EOL_MARK='↩'
