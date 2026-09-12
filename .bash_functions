# watch + bell on output change (without exiting)
ping_diff() {
    while iwatch -g "$@"; do
        printf '\a'
    done
}

iwatch() {
    local cmd="${@: -1}"
    if [ -n "$ZSH_VERSION" ]; then
        watch --color "${@[1,-2]}" "bash -ic \"$cmd\""
    else
        watch --color "${@:1:$#-1}" "bash -ic \"$cmd\""
    fi
}

# git branch -v with worktree paths
gbv() {
    local -A worktree_map
    local worktree_path=""
    while IFS= read -r line; do
        if [[ $line == worktree\ * ]]; then
            worktree_path="${line#worktree }"
        elif [[ $line == branch\ * ]]; then
            local branch="${line#branch refs/heads/}"
            worktree_map[$branch]="$worktree_path"
        fi
    done < <(git worktree list --porcelain)

    local max_len=0
    local -a branch_lines
    while IFS= read -r line; do
        branch_lines+=("$line")
        (( ${#line} > max_len )) && max_len=${#line}
    done < <(git branch --no-color)

    for line in "${branch_lines[@]}"; do
        local branch="${line:2}"
        if [[ -n "${worktree_map[$branch]}" ]]; then
            printf "%-*s  %s\n" "$max_len" "$line" "${worktree_map[$branch]}"
        else
            echo "$line"
        fi
    done
}
