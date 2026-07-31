setopt PROMPT_SUBST

gitstatus_stop 'MY_PROMPT' 2>/dev/null
zsh-defer gitstatus_start -s -1 -u -1 -c -1 -d -1 -e 'MY_PROMPT'

git_prompt() {
    [[ $VCS_STATUS_RESULT == ok-sync ]] || return

    local -a segments
    local deleted=$((VCS_STATUS_NUM_STAGED_DELETED + VCS_STATUS_NUM_UNSTAGED_DELETED))
    local ref=$VCS_STATUS_LOCAL_BRANCH

    ((VCS_STATUS_NUM_STAGED)) && segments+=("%F{green}+${VCS_STATUS_NUM_STAGED}%f")
    ((VCS_STATUS_NUM_UNSTAGED)) && segments+=("%F{yellow}!${VCS_STATUS_NUM_UNSTAGED}%f")
    ((VCS_STATUS_NUM_UNTRACKED)) && segments+=("%F{cyan}?${VCS_STATUS_NUM_UNTRACKED}%f")
    ((deleted)) && segments+=("%F{red}✘${deleted}%f")
    ((VCS_STATUS_NUM_CONFLICTED)) && segments+=("%B%F{red}=${VCS_STATUS_NUM_CONFLICTED}%f%b")
    ((VCS_STATUS_STASHES)) && segments+=("%F{magenta}\$${VCS_STATUS_STASHES}%f")
    ((VCS_STATUS_COMMITS_AHEAD)) && segments+=("%F{green}⇡${VCS_STATUS_COMMITS_AHEAD}%f")
    ((VCS_STATUS_COMMITS_BEHIND)) && segments+=("%F{yellow}⇣${VCS_STATUS_COMMITS_BEHIND}%f")

    [[ -z $ref && -n $VCS_STATUS_TAG ]] && ref="#$VCS_STATUS_TAG"
    [[ -z $ref ]] && ref="@${VCS_STATUS_COMMIT[1,8]}"

    printf "%%F{green}󰘬 %s%%f" "$ref"

    (($#segments)) && printf " %%F{8}[%s%%F{8}]%%f" "${(j: :)segments}"
}

path_prompt() {
    local path

    if [[ $VCS_STATUS_RESULT == ok-sync ]]; then
        if [[ $VCS_STATUS_WORKDIR != $_LAST_WORKTREE ]]; then
            _REPO_NAME=${VCS_STATUS_WORKDIR:t}
            _LAST_WORKTREE=$VCS_STATUS_WORKDIR
        fi

        if [[ $PWD == $VCS_STATUS_WORKDIR ]]; then
            print -r -- "󰇘/$_REPO_NAME"
            return
        fi

        path="$_REPO_NAME/${PWD#$VCS_STATUS_WORKDIR/}"
    else
        path="${(%):-%~}"
    fi

    if [[ $path != */*/* ]]; then
        print -r -- "$path"
    else
        print -r -- "󰇘/${path:h:t}/${path:t}"
    fi
}

precmd() {
    local cmd_status=$?

    if (( cmd_status )); then
        CMD_STATUS='%F{red}➜%f'
    else
        CMD_STATUS='%F{magenta}➜%f'
    fi

    if gitstatus_query 'MY_PROMPT'; then
        GIT_INFO=$(git_prompt)
    else
        GIT_INFO=
    fi

    if [[ ${_LAST_PWD-} != $PWD ]]; then
        PATH_INFO=$(path_prompt)
        _LAST_PWD=$PWD
    fi
}

PROMPT='
%F{blue}${PATH_INFO}%f ${GIT_INFO}
${CMD_STATUS} '

