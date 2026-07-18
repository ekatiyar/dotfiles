# Shared test scaffolding, sourced by the .test.sh files.
pass=0 fail=0

strip() { sed $'s/\x1b\\[[0-9;]*m//g'; }

# Print the pass/fail footer; return non-zero if any test failed.
summary() {
  echo "---"
  echo "pass=$pass fail=$fail"
  [[ $fail -eq 0 ]]
}
