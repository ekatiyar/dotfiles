#!/usr/bin/env bash
# Local checks: every *.test.sh, shell syntax, config validity.
set -u
cd "$(dirname "$0")" || exit 1
pass=0 fail=0

run() { # label command...
  local label=$1 out rc=0; shift
  out=$("$@" 2>&1) || rc=$?
  case $rc in
    0)  printf 'PASS  %s\n' "$label"; pass=$((pass+1)) ;;
    77) printf 'SKIP  %s (%s)\n' "$label" "$(tail -n1 <<<"$out")" ;;
    *)  printf 'FAIL  %s\n%s\n' "$label" "$out" | sed '2,$s/^/      /'; fail=$((fail+1)) ;;
  esac
}
files() { git ls-files --cached --others --exclude-standard "$@" | sort; } # includes not-yet-added files

# Any *.test.sh is picked up.
for t in $(files '*.test.sh'); do
  run "bash $t" bash "$t"
done

for f in $(files '*.sh' | grep -v '^\.oh-my-zsh/'); do
  run "bash -n $f" bash -n "$f"
done
for f in $(files '.bash*' | grep -v '\.sh$'); do
  run "bash -n $f" bash -n "$f"
  run "zsh -n $f" zsh -n "$f"
done
run "zsh -n .zshrc" zsh -n .zshrc

run "json .claude/settings.json" jq empty .claude/settings.json
run "json .claude/.mcp.json" jq empty .claude/.mcp.json
for f in .codex/config.toml .config/herdr/config.toml; do
  run "toml $f" python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$f"
done
if command -v codex >/dev/null; then
  run "codex rules parse" codex execpolicy check --rules .codex/rules/default.rules true
fi

echo "---"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
