#!/usr/bin/env bats

# Performance guard for the Script Filter. Times the search render over a large
# link store and fails only on an order-of-magnitude regression. The measured
# time is printed. Times with jq's `now` (BSD `date` has no %N).

BUDGET_MS=2000
LINKS_N=300

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
  export LINKS="$BATS_TEST_TMPDIR/links"
  mkdir -p "$LINKS/work" "$LINKS/personal"
  local i dir
  for i in $(seq 1 "$LINKS_N"); do
    dir=$([ $(( i % 2 )) -eq 0 ] && echo work || echo personal)
    printf 'url: https://example.com/%d\ntags: t%d shared\n' "$i" "$i" > "$LINKS/$dir/Link $i.md"
  done
  printf '%s\n' "$LINKS" > "$alfred_workflow_data/folder"
}

now_ms() { jq -n 'now * 1000 | floor'; }

@test "perf: jump search over many links stays fast" {
  # warm the index first, so this times the render, not the one-off build
  bash -c '. src/jump.sh list "shared"' >/dev/null
  local start end ms
  start="$(now_ms)"
  run bash -c '. src/jump.sh list "shared"'
  end="$(now_ms)"
  ms=$(( end - start ))
  [ "$status" -eq 0 ]
  echo "# jump search ($LINKS_N links): ${ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$ms" -lt "$BUDGET_MS" ]
}
