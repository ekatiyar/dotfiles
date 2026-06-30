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
