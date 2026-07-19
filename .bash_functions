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

# Execute a saved Claude plan in a fresh conversation.
# Usage: runplan [path-to-plan.md] [-m|--model MODEL] [-e|--effort LEVEL]
# Defaults to the newest plan in ~/.claude/plans/ and Claude's default model/effort.
runplan() {
    local plan="" model="" effort=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -m|--model)  model="$2";  shift 2 ;;
            -e|--effort) effort="$2"; shift 2 ;;
            -h|--help)   echo "Usage: runplan [path-to-plan.md] [-m MODEL] [-e EFFORT]"; return 0 ;;
            *)           plan="$1";   shift ;;
        esac
    done

    plan="${plan:-$(ls -t "$HOME/.claude/plans/"*.md 2>/dev/null | head -n1)}"
    if [ -z "$plan" ] || [ ! -f "$plan" ]; then
        echo "Usage: runplan [path-to-plan.md] [-m MODEL] [-e EFFORT]  (no plan found)" >&2
        return 1
    fi

    # Title = first line, stripped of its leading markdown '#' markers.
    local title
    title=$(sed -n '1s/^#\+[[:space:]]*//p' "$plan")

    # Only pass --model/--effort when overridden; otherwise Claude uses its defaults.
    local -a args=()
    [ -n "$model" ]  && args+=(--model "$model")
    [ -n "$effort" ] && args+=(--effort "$effort")

    printf 'Plan:   %s\n' "${title:-(untitled)}"
    printf 'File:   %s\n' "$plan"
    printf 'Model:  %s\n' "${model:-(default)}"
    printf 'Effort: %s\n' "${effort:-(default)}"

    local confirm
    printf 'Execute this plan? (y/n): '
    read -r confirm </dev/tty
    case "$confirm" in
        [Yy]*) ;;
        *) echo "Cancelled."; return 0 ;;
    esac

    claude "${args[@]}" "Read the plan titled \"$title\" at $plan and implement it step by step, treating it as the source of truth. Verify changes as you go, and check with me before anything destructive or ambiguous."
}

# Llama.cpp Build Pipeline
llmb() {
    cd ~/repo/llama.cpp || return
    echo "🔄 Pulling latest changes..."
    git pull

    echo "⚙️ Configuring Llama.cpp..."
    cmake -B build -S . -DGGML_CUDA=ON -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA_ALLREDUCE=ON -DGGML_CUDA_NCCL=OFF

    echo "🔨 Building binaries..."
    cmake --build build --config Release -j $(nproc) --clean-first --target llama-cli llama-server

    echo "✅ Build complete."
}

# Serve local coding models via llama-server router mode (see ~/.config/llama.cpp/preset.ini)
llama-router() {
    cd ~/repo/llama.cpp/build/bin || return
    ./llama-server --models-preset ~/.config/llama.cpp/preset.ini "$@"
}
