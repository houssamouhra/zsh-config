typeset -g GIT_INFO PATH_INFO CMD_STATUS
typeset -g _LAST_PWD _LAST_WORKTREE _REPO_NAME

setopt PROMPT_SUBST

gitstatus_stop 'MY_PROMPT' 2>/dev/null
zsh-defer gitstatus_start -s -1 -u -1 -c -1 -d -1 -e 'MY_PROMPT'

git_prompt() {
    [[ $VCS_STATUS_RESULT == ok-sync ]] || return

    local -a segments
    local deleted=$((VCS_STATUS_NUM_STAGED_DELETED + VCS_STATUS_NUM_UNSTAGED_DELETED))

    (( VCS_STATUS_NUM_STAGED ))     && segments+=("%F{green}+${VCS_STATUS_NUM_STAGED}%f")
    (( VCS_STATUS_NUM_UNSTAGED ))   && segments+=("%F{yellow}!${VCS_STATUS_NUM_UNSTAGED}%f")
    (( VCS_STATUS_NUM_UNTRACKED ))  && segments+=("%F{cyan}?${VCS_STATUS_NUM_UNTRACKED}%f")
    (( deleted ))                   && segments+=("%F{red}✘${deleted}%f")
    (( VCS_STATUS_NUM_CONFLICTED )) && segments+=("%B%F{red}=${VCS_STATUS_NUM_CONFLICTED}%f%b")
    (( VCS_STATUS_STASHES ))        && segments+=("%F{magenta}\$${VCS_STATUS_STASHES}%f")
    (( VCS_STATUS_COMMITS_AHEAD ))  && segments+=("%F{green}⇡${VCS_STATUS_COMMITS_AHEAD}%f")
    (( VCS_STATUS_COMMITS_BEHIND )) && segments+=("%F{yellow}⇣${VCS_STATUS_COMMITS_BEHIND}%f")

    local ref=$VCS_STATUS_LOCAL_BRANCH
    [[ -z $ref && -n $VCS_STATUS_TAG ]] && ref="#$VCS_STATUS_TAG"
    [[ -z $ref ]] && ref="@${VCS_STATUS_COMMIT[1,8]}"

    print -rn -- "%F{green}󰘬 ${ref}%f"

    (($#segments)) && print -rn -- " %F{8}[${(j: :)segments}%F{8}]%f"
}

path_prompt() {
  if [[ $VCS_STATUS_RESULT == ok-sync ]]; then
    if [[ $VCS_STATUS_WORKDIR != ${_LAST_WORKTREE-} ]]; then
      _REPO_NAME=${VCS_STATUS_WORKDIR:t}
      _LAST_WORKTREE=$VCS_STATUS_WORKDIR
    fi

    if [[ $PWD == $VCS_STATUS_WORKDIR ]]; then
      print -r -- "󰇘/${_REPO_NAME}"
      return
    fi

    local relative=${PWD#$VCS_STATUS_WORKDIR/}

    # Show last two components when possible, otherwise just the last one
    if [[ $relative == */* ]]; then
      print -r -- "󰇘/${relative:h:t}/${relative:t}"
    else
      print -r -- "󰇘/${relative}"
    fi
  else
    # Fall back to %~ but truncate similarly
    local p=${(%):-%~}
    if [[ $p == */*/* ]]; then
      print -r -- "󰇘/${p:h:t}/${p:t}"
    else
      print -r -- "$p"
    fi
  fi
}

precmd() {
    local st=$?
    CMD_STATUS=${${st:#0}:+%F{red}➜%f}
    CMD_STATUS=${CMD_STATUS:-%F{magenta}➜%f}

    if gitstatus_query -t 20 'MY_PROMPT'; then
        GIT_INFO=$(git_prompt)
    else
        GIT_INFO=
    fi

    if [[ ${_LAST_PWD-} != $PWD ]]; then
        PATH_INFO=$(path_prompt)
        _LAST_PWD=$PWD
    fi
}

PROMPT=$'\n%F{blue}${PATH_INFO}%f ${GIT_INFO}\n${CMD_STATUS} '
