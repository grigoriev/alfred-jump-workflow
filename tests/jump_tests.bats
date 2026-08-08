#!/usr/bin/env bats

# Integration tests for src/jump.sh. open and osascript are mocked.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
  # keep the default fallback inside the sandbox, never the real ~/.jump
  export JUMP_DEFAULT_FOLDER="$BATS_TEST_TMPDIR/default"
  export LINKS="$BATS_TEST_TMPDIR/links"
  mkdir -p "$LINKS/work"
  printf 'url: https://jira.example.com\ntags: work tracker\n' > "$LINKS/work/Jira.md"
  printf 'url: https://news.example.com\ntags: read\n' > "$LINKS/Inbox.md"
  printf '%s\n' "$LINKS" > "$alfred_workflow_data/folder"
}

@test "jump.sh: lists all links sorted by title" {
  run bash -c '. src/jump.sh list ""'
  echo "$output" | jq -e '[.items[].title] == ["Inbox", "Jira"]' >/dev/null
}

@test "jump.sh: filters by a word across title, category and tags" {
  run bash -c '. src/jump.sh list "work"'
  echo "$output" | jq -e '[.items[].title] == ["Jira"]' >/dev/null
  run bash -c '. src/jump.sh list "read"'
  echo "$output" | jq -e '[.items[].title] == ["Inbox"]' >/dev/null
}

@test "jump.sh: a link opens its url and offers a delete modifier" {
  run bash -c '. src/jump.sh list "jira"'
  echo "$output" | jq -e '.items[0].arg == "open https://jira.example.com"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.cmd.arg | startswith("delete ") and endswith("/work/Jira.md")' >/dev/null
}

@test "jump.sh: > lists the global commands" {
  run bash -c '. src/jump.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Add a link") != null and index("Set links folder") != null and index("Rebuild index") != null and index("Check for updates") != null' >/dev/null
}

@test "jump.sh: > add previews the link to create" {
  run bash -c '. src/jump.sh list "> add https://x.com | My @c #t"'
  echo "$output" | jq -e '.items[0].title == "Add this link"' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "add-link https://x.com | My @c #t"' >/dev/null
}

@test "jump.sh: run add-link creates the file" {
  run bash -c '. src/jump.sh run "add-link https://x.com | My Site @tools #dev"'
  [ -f "$LINKS/tools/My Site.md" ]
}

@test "jump.sh: frecency floats an opened link to the top" {
  bash -c '. src/jump.sh run "open https://jira.example.com"'
  bash -c '. src/jump.sh run "open https://jira.example.com"'
  run bash -c '. src/jump.sh list ""'
  echo "$output" | jq -e '.items[0].title == "Jira"' >/dev/null
}

@test "jump.sh: a pinned link sorts to the top with a star" {
  bash -c ". src/jump.sh run \"pin $LINKS/Inbox.md\""
  run bash -c '. src/jump.sh list ""'
  echo "$output" | jq -e '.items[0].title == "★ Inbox"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.alt.arg | startswith("unpin ")' >/dev/null
}

@test "jump.sh: a link offers a pin modifier" {
  run bash -c '. src/jump.sh list "jira"'
  echo "$output" | jq -e '.items[0].mods.alt.arg | startswith("pin ") and endswith("/work/Jira.md")' >/dev/null
}

@test "jump.sh: > shows the frecency sort toggle, and it switches" {
  run bash -c '. src/jump.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Sort: Frecency") != null' >/dev/null
  bash -c '. src/jump.sh run "sort alphabet"'
  run bash -c '. src/jump.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Sort: Alphabetical") != null' >/dev/null
}

@test "jump.sh: run delete removes the file" {
  run bash -c ". src/jump.sh run \"delete $LINKS/work/Jira.md\""
  [ ! -f "$LINKS/work/Jira.md" ]
}

@test "jump.sh: run open dispatches to open" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "open https://jira.example.com"'
  grep -q "https://jira.example.com" "$OPEN_LOG"
}

@test "jump.sh: run edit-folder opens the config in an editor" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "edit-folder"'
  grep -q "folder" "$OPEN_LOG"
}

@test "jump.sh: with no config it falls back to the default folder" {
  rm -f "$alfred_workflow_data/folder"
  run bash -c '. src/jump.sh list ""'
  echo "$output" | jq -e '.items[0].title == "No links found"' >/dev/null
}

@test "jump.sh: an empty folder shows a no-links hint" {
  rm -rf "$LINKS"/*
  run bash -c '. src/jump.sh list ""'
  echo "$output" | jq -e '.items[0].title == "No links found"' >/dev/null
}
