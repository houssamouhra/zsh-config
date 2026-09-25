# The prompt answers four questions:
#   1. Where am I?                           → PATH_INFO
#   2. What Git context am I in?             → GIT_INFO (branch/tag/HEAD)
#   3. Is the repo in a notable state?       → status icons (+!?✘=$⇡⇣)
#   4. Did my last command fail / take long? → CMD_STATUS + CMD_DURATION
#
# Architecture: everything is driven by pure async gitstatus.
# On every precmd we fire a non-blocking gitstatus_query (-t 0). While the
# query is in flight the plugin temporarily clears VCS_STATUS_* variables
# (RESULT becomes "tout"). We deliberately ignore that transient state and
# keep the last known good worktree (_LAST_WORKTREE / _REPO_NAME). Consequently
# PATH_INFO is only recalculated when the directory actually changes or when
# a real "ok-*" result arrives with a different worktree. The async callback
# then updates GIT_INFO (and PATH_INFO only if needed) and issues a single
# zle reset-prompt if anything visible changed. This eliminates the classic
# "~/repo" ↔ "repo" flicker while keeping the entire prompt non-blocking.
#
#
typeset -g PATH_INFO GIT_INFO CMD_STATUS CMD_DURATION
typeset -g _LAST_PWD _LAST_WORKTREE _REPO_NAME
typeset -g _GITSTATUS_READY=0
typeset -g _PROMPT_START_TIME
setopt PROMPT_SUBST

# Start gitstatus daemon once the shell is interactive
zsh-defer -c '
gitstatus_start -s -1 -u -1 -c -1 -d -1 -e "MY_PROMPT"
_GITSTATUS_READY=1
# Fire the first query asynchronously (no blocking)
gitstatus_query -t 0 -c _gitstatus_async_update "MY_PROMPT"
'

# Git segment (branch/tag + status icons)
git_prompt() {
	[[ "$VCS_STATUS_RESULT" == ok-* ]] || return

	local -a segments
	(( VCS_STATUS_NUM_STAGED ))          && segments+=("+")
	(( VCS_STATUS_NUM_UNSTAGED ))        && segments+=("!")
	(( VCS_STATUS_NUM_UNTRACKED ))       && segments+=("?")
	(( VCS_STATUS_NUM_STAGED_DELETED + VCS_STATUS_NUM_UNSTAGED_DELETED )) && segments+=("✘")
	(( VCS_STATUS_NUM_CONFLICTED ))      && segments+=("=")
	(( VCS_STATUS_STASHES ))             && segments+=("$")
	(( VCS_STATUS_COMMITS_AHEAD  ))      && segments+=("⇡${VCS_STATUS_COMMITS_AHEAD}")
	(( VCS_STATUS_COMMITS_BEHIND  ))     && segments+=("⇣${VCS_STATUS_COMMITS_BEHIND}")

	local ref
	if [[ -n "$VCS_STATUS_LOCAL_BRANCH" ]]; then
		ref="$VCS_STATUS_LOCAL_BRANCH"
	elif [[ -n "$VCS_STATUS_TAG" ]]; then
		ref="#$VCS_STATUS_TAG"
	else
		ref="HEAD ("${VCS_STATUS_COMMIT[1,7]}")"
	fi

	print -rn -- "%F{green}󰘬 ${ref}%f"
	(("$#segments")) && print -rn -- " %B%F{red}["${(j::)segments}"]%f%b"
}

# Update PATH_INFO only when directory or worktree really changed
_refresh_path_info() {
	local new_worktree=
	if [[ "$VCS_STATUS_RESULT" == ok-* ]]; then
		new_worktree="${VCS_STATUS_WORKDIR:-}"
	else
		# Keep previous worktree while query is in flight
		new_worktree="${_LAST_WORKTREE-}"
	fi

	if [[ "$PWD" != "${_LAST_PWD-}" || "$new_worktree" != "${_LAST_WORKTREE-}" ]]; then
		_REPO_NAME="${new_worktree:t}"
		_LAST_WORKTREE="$new_worktree"
		PATH_INFO=$(path_prompt)
		_LAST_PWD=$PWD
	fi
}

# Truncated path: repo-relative when inside git, otherwise last 1–2 dirs
path_prompt() {
	local worktree="${_LAST_WORKTREE-}"

	# Inside a known git worktree
	if [[ -n "$worktree" && "$PWD" == "$worktree"* ]]; then
		if [[ "$PWD" == "$worktree" ]]; then
			print -rn -- "${_REPO_NAME}"
			return
		fi

		local relative=${PWD#"$worktree"/}

		if [[ "$relative" == */* ]]; then
			print -rn -- "…/${relative:h:t}/${relative:t}"
		else
			print -rn -- "…/${relative}"
		fi
		return
	fi

	# Outside git
	if [[ "$PWD" == "$HOME" ]]; then
		print -rn -- "~"
		return
	fi

	local relative parts

	if [[ "$PWD" == "$HOME"/* ]]; then
		relative="${PWD#"$HOME"/}"
		parts=("${(@s:/:)relative}")

		if (( "${#parts}" <= 3 )); then
			print -rn -- "~/${relative}"
		else
			print -rn -- "…/${parts[-2]}/${parts[-1]}"
		fi
		return
	fi

	parts=("${(@s:/:)PWD}")

	if (( ${#parts} <= 2 )); then
		print -rn -- "${(%):-%~}"
	else
		print -rn -- "…/${parts[-2]}/${parts[-1]}"
	fi
}

# Async callback – update git info and redraw only if something changed
_gitstatus_async_update() {
	local old_git="$GIT_INFO"
	local old_path="$PATH_INFO"

	GIT_INFO=$(git_prompt)
	_refresh_path_info

	if [[ "$GIT_INFO" != "$old_git" || "$PATH_INFO" != "$old_path" ]]; then
		zle && zle reset-prompt
	fi
}

preexec() {
	_PROMPT_START_TIME="$SECONDS"
}

precmd() {
	local st=$?
	CMD_STATUS=${${st:#0}:+%F{red}➜%f}
	CMD_STATUS=${CMD_STATUS:-%F{magenta}➜%f}

	# Command duration (shown only if ≥ 2 s)
	CMD_DURATION=
	if (( "${+_PROMPT_START_TIME}" )); then
		local -i sec="$(( SECONDS - _PROMPT_START_TIME ))"
		unset _PROMPT_START_TIME

		if (( sec >= 2 )); then
			if (( sec >= 60 )); then
				local -i m="$(( sec / 60 ))"
				local -i s="$(( sec % 60 ))"
				CMD_DURATION="%F{yellow}${m}m${s}s%f"
			else
				CMD_DURATION="%F{yellow}${sec}s%f"
			fi
		fi
	fi

	# Fire async gitstatus query
	if (( _GITSTATUS_READY )); then
		gitstatus_query -t 0 -c _gitstatus_async_update 'MY_PROMPT'
	fi

	# Refresh path (only does work on real changes)
	_refresh_path_info
}

# One-line prompt Option
PROMPT='%B%F{blue}${PATH_INFO}%f%b ${GIT_INFO} ${CMD_STATUS} '

# Two-lines prompt Option
# PROMPT=$'\n%B%F{blue}${PATH_INFO}%f%b ${GIT_INFO}\n${CMD_STATUS} '

RPROMPT='${CMD_DURATION}'
PROMPT_EOL_MARK='↩'
