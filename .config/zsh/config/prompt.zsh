# The prompt answers four questions:
#   1. Where am I?                           → PATH_INFO
#   2. What Git context am I in?             → GIT_INFO (branch/tag/HEAD)
#   3. Is the repo in a notable state?       → status icons (+!?✘=$⇡⇣)
#   4. Did my last command fail / take long? → CMD_STATUS + CMD_DURATION
#
#
# Prompt state
typeset -g PATH_INFO GIT_INFO CMD_STATUS CMD_DURATION
typeset -g _LAST_PWD _LAST_WORKTREE _REPO_NAME
typeset -g _GITSTATUS_READY=0
typeset -g _PROMPT_START_TIME

setopt PROMPT_SUBST
gitstatus_stop 'MY_PROMPT' 2>/dev/null

# Start gitstatus after shell init
zsh-defer -c '
  gitstatus_start -s -1 -u -1 -c -1 -d -1 -e "MY_PROMPT"
  _GITSTATUS_READY=1
  if gitstatus_query -t 0.3 -c _gitstatus_async_update "MY_PROMPT"; then
    if [[ $VCS_STATUS_RESULT == ok-sync ]]; then
      GIT_INFO=$(git_prompt)
    else
      GIT_INFO=
    fi
  fi
  _refresh_path_info
  zle && zle reset-prompt
'
# Git prompt
git_prompt() {
  [[ $VCS_STATUS_RESULT == ok-* ]] || return

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
  if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
    ref=$VCS_STATUS_LOCAL_BRANCH
  elif [[ -n $VCS_STATUS_TAG ]]; then
    ref="#$VCS_STATUS_TAG"
  else
    ref="HEAD (${VCS_STATUS_COMMIT[1,7]})"
  fi

  print -rn -- "%F{green}󰘬 ${ref}%f"
  (($#segments)) && print -rn -- " %B%F{red}[${(j::)segments}]%f%b"
}

_refresh_path_info() {
  local new_worktree=${VCS_STATUS_WORKDIR:-}

  if [[ $PWD != ${_LAST_PWD-} || $new_worktree != ${_LAST_WORKTREE-} ]]; then
      _REPO_NAME=${new_worktree:t}
      _LAST_WORKTREE=$new_worktree
    PATH_INFO=$(path_prompt)
    _LAST_PWD=$PWD
  fi
}

# Path: repo-relative when in git, otherwise last 1–2 dirs
path_prompt() {
  if [[ $VCS_STATUS_RESULT == ok-* ]]; then
    if [[ $PWD == $VCS_STATUS_WORKDIR ]]; then
      print -rn -- "${_REPO_NAME}"
      return
    fi

    local relative=${PWD#$VCS_STATUS_WORKDIR/}

    if [[ $relative == */* ]]; then
      print -rn -- "󰇘/${relative:h:t}/${relative:t}"
    else
      print -rn -- "󰇘/${relative}"
    fi
  else

    local p=${(%):-%~}

    if [[ $p == */*/* ]]; then
      print -rn -- "󰇘/${p:h:t}/${p:t}"
    elif [[ $p == */* ]]; then
      print -rn -- "󰇘/${p:t}"
    else
      print -rn -- "$p"
    fi
  fi
}

# Async gitstatus callback
_gitstatus_async_update() {
  GIT_INFO=$(git_prompt)
  _refresh_path_info
  zle && zle reset-prompt
}

# Command duration
preexec() {
  _PROMPT_START_TIME=$SECONDS
}

precmd() {
  local st=$?

  # Exit-status arrow
  CMD_STATUS=${${st:#0}:+%F{red}➜%f}
  CMD_STATUS=${CMD_STATUS:-%F{magenta}➜%f}

  # Duration (shown only if command took ≥ 2s)
  CMD_DURATION=
  if (( ${+_PROMPT_START_TIME} )); then
    local -i sec=$(( SECONDS - _PROMPT_START_TIME ))
    unset _PROMPT_START_TIME

    if (( sec >= 2 )); then
      if (( sec >= 60 )); then
        local -i m=$(( sec / 60 ))
        local -i s=$(( sec % 60 ))
        CMD_DURATION="%F{yellow}${m}m${s}s%f"
      else
        CMD_DURATION="%F{yellow}${sec}s%f"
      fi
    fi
  fi

  # Intentionally do nothing on timeout — keep previous GIT_INFO to avoid flicker
  if (( _GITSTATUS_READY )); then
    if gitstatus_query -t 0.05 -c _gitstatus_async_update 'MY_PROMPT'; then
      if [[ $VCS_STATUS_RESULT == ok-sync ]]; then
        GIT_INFO=$(git_prompt)
      else
        GIT_INFO=
      fi
    fi
  fi

  # path updates on PWD or worktree change
  _refresh_path_info
}

PROMPT=$'\n%B%F{blue}${PATH_INFO}%f%b ${GIT_INFO}\n${CMD_STATUS} '
RPROMPT='${CMD_DURATION}'
