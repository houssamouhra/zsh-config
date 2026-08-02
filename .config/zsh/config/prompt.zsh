typeset -g GIT_INFO PATH_INFO CMD_STATUS
typeset -g _LAST_PWD _LAST_WORKTREE _REPO_NAME
typeset -g _GITSTATUS_READY=0

setopt PROMPT_SUBST

gitstatus_stop 'MY_PROMPT' 2>/dev/null

# Defer the heavy start. Always update the prompt variables + force redraw
# no matter whether the query finished sync or async.
zsh-defer -c '
  gitstatus_start -s -1 -u -1 -c -1 -d -1 -e "MY_PROMPT"
  _GITSTATUS_READY=1

  # Do a query. Use a callback for the slow case, but also handle the fast case.
  if gitstatus_query -t 0.3 -c _gitstatus_async_update "MY_PROMPT"; then
    # Finished synchronously → update right now
    if [[ $VCS_STATUS_RESULT == ok-sync ]]; then
      GIT_INFO=$(git_prompt)
    else
      GIT_INFO=
    fi
    PATH_INFO=$(path_prompt)
    _LAST_PWD=$PWD
  fi

  # Always redraw so the first prompt becomes correct
  zle && zle reset-prompt
'

git_prompt() {
  [[ $VCS_STATUS_RESULT == ok-* ]] || return

  local -a segments
  local deleted=$((VCS_STATUS_NUM_STAGED_DELETED + VCS_STATUS_NUM_UNSTAGED_DELETED))
  (( VCS_STATUS_NUM_STAGED ))      && segments+=("%F{green}+${VCS_STATUS_NUM_STAGED}%f")
  (( VCS_STATUS_NUM_UNSTAGED ))    && segments+=("%F{yellow}!${VCS_STATUS_NUM_UNSTAGED}%f")
  (( VCS_STATUS_NUM_UNTRACKED ))   && segments+=("%F{cyan}?${VCS_STATUS_NUM_UNTRACKED}%f")
  (( deleted ))                    && segments+=("%F{red}✘${deleted}%f")
  (( VCS_STATUS_NUM_CONFLICTED ))  && segments+=("%B%F{red}=${VCS_STATUS_NUM_CONFLICTED}%f%b")
  (( VCS_STATUS_STASHES ))         && segments+=("%F{magenta}\$${VCS_STATUS_STASHES}%f")
  (( VCS_STATUS_COMMITS_AHEAD ))   && segments+=("%F{green}⇡${VCS_STATUS_COMMITS_AHEAD}%f")
  (( VCS_STATUS_COMMITS_BEHIND ))  && segments+=("%F{yellow}⇣${VCS_STATUS_COMMITS_BEHIND}%f")

  local ref=$VCS_STATUS_LOCAL_BRANCH
  [[ -z $ref && -n $VCS_STATUS_TAG ]] && ref="#$VCS_STATUS_TAG"
  [[ -z $ref ]] && ref="@${VCS_STATUS_COMMIT[1,8]}"

  print -rn -- "%F{green}󰘬 ${ref}%f"
  (($#segments)) && print -rn -- " %F{8}[${(j: :)segments}%F{8}]%f"
}

path_prompt() {
  if [[ $VCS_STATUS_RESULT == ok-* ]]; then
    if [[ $VCS_STATUS_WORKDIR != ${_LAST_WORKTREE-} ]]; then
      _REPO_NAME=${VCS_STATUS_WORKDIR:t}
      _LAST_WORKTREE=$VCS_STATUS_WORKDIR
    fi
    if [[ $PWD == $VCS_STATUS_WORKDIR ]]; then
      print -rn -- "󰇘/${_REPO_NAME}"
      return
    fi
    local relative=${PWD#$VCS_STATUS_WORKDIR/}
    if [[ $relative == */* ]]; then
      print -rn -- "󰇘/${relative:h:t}/${relative:t}"
    else
      print -rn -- "󰇘/${relative}"
    fi
  else

    # Smarter fallback: try to show last 1–2 components with the same icon
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

_gitstatus_async_update() {
  # Only reached when the query timed out and results arrived later
  GIT_INFO=$(git_prompt)
  PATH_INFO=$(path_prompt)
  _LAST_PWD=$PWD
  zle && zle reset-prompt
}

precmd() {
  local st=$?
  CMD_STATUS=${${st:#0}:+%F{red}➜%f}
  CMD_STATUS=${CMD_STATUS:-%F{magenta}➜%f}

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

  # Keep PATH_INFO fresh
  if [[ ${_LAST_PWD-} != $PWD || $VCS_STATUS_RESULT == ok-* ]]; then
    PATH_INFO=$(path_prompt)
    _LAST_PWD=$PWD
  fi
}

PROMPT=$'\n%F{blue}${PATH_INFO}%f ${GIT_INFO}\n${CMD_STATUS} '

