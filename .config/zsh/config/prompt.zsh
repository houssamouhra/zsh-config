# Prompt state
typeset -g GIT_INFO PATH_INFO CMD_STATUS
typeset -g _LAST_PWD _LAST_WORKTREE _REPO_NAME
typeset -g _GITSTATUS_READY=0
typeset -g CMD_DURATION
typeset -gF SECONDS

setopt PROMPT_SUBST
gitstatus_stop 'MY_PROMPT' 2>/dev/null

# Start gitstatus after shell init (keeps startup fast)
zsh-defer -c '
  gitstatus_start -s -1 -u -1 -c -1 -d -1 -e "MY_PROMPT"
  _GITSTATUS_READY=1
  if gitstatus_query -t 0.3 -c _gitstatus_async_update "MY_PROMPT"; then
    if [[ $VCS_STATUS_RESULT == ok-sync ]]; then
      GIT_INFO=$(git_prompt)
    else
      GIT_INFO=
    fi
    PATH_INFO=$(path_prompt)
    _LAST_PWD=$PWD
  fi
  zle && zle reset-prompt
'
# Git: branch / tag / HEAD + icon-only status
git_prompt() {
  [[ $VCS_STATUS_RESULT == ok-* ]] || return

  local -a segments
  (( VCS_STATUS_NUM_STAGED ))          && segments+=("+")
  (( VCS_STATUS_NUM_UNSTAGED ))        && segments+=("!")
  (( VCS_STATUS_NUM_UNTRACKED ))       && segments+=("?")
  (( VCS_STATUS_NUM_STAGED_DELETED + VCS_STATUS_NUM_UNSTAGED_DELETED )) && segments+=("✘")
  (( VCS_STATUS_NUM_CONFLICTED ))      && segments+=("=")
  (( VCS_STATUS_STASHES ))             && segments+=("$")
  (( VCS_STATUS_COMMITS_AHEAD && VCS_STATUS_COMMITS_BEHIND )) && segments+=("⇕${VCS_STATUS_COMMITS_AHEAD}⇣${VCS_STATUS_COMMITS_BEHIND}")
  (( VCS_STATUS_COMMITS_AHEAD && ! VCS_STATUS_COMMITS_BEHIND )) && segments+=("⇡${VCS_STATUS_COMMITS_AHEAD}")
  (( VCS_STATUS_COMMITS_BEHIND && ! VCS_STATUS_COMMITS_AHEAD )) && segments+=("⇣${VCS_STATUS_COMMITS_BEHIND}")

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

# Path: repo-relative when in git, otherwise last 1–2 dirs
path_prompt() {
  if [[ $VCS_STATUS_RESULT == ok-* ]]; then
    if [[ $VCS_STATUS_WORKDIR != ${_LAST_WORKTREE-} ]]; then
      _REPO_NAME=${VCS_STATUS_WORKDIR:t}
      _LAST_WORKTREE=$VCS_STATUS_WORKDIR
    fi
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
  PATH_INFO=$(path_prompt)
  _LAST_PWD=$PWD
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
      local plain styled
      if (( sec >= 60 )); then
        local -i m=$(( sec / 60 )) s=$(( sec % 60 ))
        plain="took ${m}m${s}s"
        styled="%F{8}took%f %F{yellow}${m}m${s}s%f"
      else
        sec=$(( sec ))
        plain="took ${sec}s"
        styled="%F{8}took%f %F{yellow}${sec}s%f"
      fi
        local back=$(( ${#plain} + 1 ))
        CMD_DURATION=$'%{\e[999C\e['"${back}"$'D%}'"${styled}"$'%{\e[0m%}'
    fi
  fi

  # Refresh git info
  if (( _GITSTATUS_READY )); then
    if gitstatus_query -t 0.05 -c _gitstatus_async_update 'MY_PROMPT'; then
      if [[ $VCS_STATUS_RESULT == ok-sync ]]; then
        GIT_INFO=$(git_prompt)
      else
        GIT_INFO=
      fi
    else
      GIT_INFO=
    fi
  else
    GIT_INFO=
  fi

  # Refresh path when cwd changes
  if [[ ${_LAST_PWD-} != $PWD || $VCS_STATUS_RESULT == ok-* ]]; then
    PATH_INFO=$(path_prompt)
    _LAST_PWD=$PWD
  fi
}

PROMPT=$'\n%B%F{blue}${PATH_INFO}%f%b ${GIT_INFO}${CMD_DURATION}\n${CMD_STATUS} '
RPROMPT=

