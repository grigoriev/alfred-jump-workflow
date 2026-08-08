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

@test "jump.sh: a run link becomes an iTerm action with a terminal icon" {
  printf 'url: ~/proj\nrun: claude\n' > "$LINKS/work/Claude.md"
  run bash -c '. src/jump.sh list "claude"'
  echo "$output" | jq -e '.items[0].arg | startswith("iterm ") and endswith("/work/Claude.md")' >/dev/null
  echo "$output" | jq -e '.items[0].icon.path == "icons/terminal.png"' >/dev/null
  echo "$output" | jq -e '.items[0].subtitle | contains("$ claude")' >/dev/null
}

@test "jump.sh: run iterm reads the file and invokes osascript" {
  printf 'url: ~/proj\nrun: claude\n' > "$LINKS/work/Claude.md"
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  run bash -c ". src/jump.sh run \"iterm $LINKS/work/Claude.md\""
  grep -q "claude" "$OSASCRIPT_LOG"
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

@test "jump.sh: run open dispatches to open, leaving a url unchanged" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "open https://jira.example.com/path"'
  grep -qxF "https://jira.example.com/path" "$OPEN_LOG"
}

@test "jump.sh: run open expands a leading tilde" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "open ~/project"'
  grep -qxF "$HOME/project" "$OPEN_LOG"
  run bash -c '. src/jump.sh run "open ~"'
  grep -qxF "$HOME" "$OPEN_LOG"
}

@test "jump.sh: run open keeps literal dollars that are not variables" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "open https://x.com/a\$/b\$1c"'
  grep -qxF 'https://x.com/a$/b$1c' "$OPEN_LOG"
}

@test "jump.sh: run open expands environment variables" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  export MYVAR=/tmp/xyz
  run bash -c '. src/jump.sh run "open \$MYVAR/a"'
  grep -qxF "/tmp/xyz/a" "$OPEN_LOG"
  run bash -c '. src/jump.sh run "open \${MYVAR}/b"'
  grep -qxF "/tmp/xyz/b" "$OPEN_LOG"
}

@test "jump.sh: run edit-folder opens the config in an editor" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "edit-folder"'
  grep -q "folder" "$OPEN_LOG"
}

@test "jump.sh: run unpin removes the pin" {
  bash -c ". src/jump.sh run \"pin $LINKS/work/Jira.md\""
  run bash -c ". src/jump.sh run \"unpin $LINKS/work/Jira.md\""
  run bash -c '. src/jump.sh list ""'
  echo "$output" | jq -e '[.items[].title] | index("★ Jira") == null' >/dev/null
}

@test "jump.sh: run open-folder reveals the folder" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "open-folder"'
  grep -qF "$LINKS" "$OPEN_LOG"
}

@test "jump.sh: run rebuild drops the index" {
  bash -c '. src/jump.sh list "" >/dev/null'
  [ -f "$alfred_workflow_cache/links.json" ]
  run bash -c '. src/jump.sh run "rebuild"'
  [ ! -f "$alfred_workflow_cache/links.json" ]
}

@test "jump.sh: run autoupdate toggles the flag" {
  run bash -c '. src/jump.sh run "autoupdate on"'
  [ -f "$alfred_workflow_data/autoupdate" ]
}

@test "jump.sh: run edit-folder seeds the config when missing" {
  rm -f "$alfred_workflow_data/folder"
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/jump.sh run "edit-folder"'
  [ -f "$alfred_workflow_data/folder" ]
  grep -q "folder" "$OPEN_LOG"
}

@test "jump.sh: run ignores an unknown action" {
  run bash -c '. src/jump.sh run "bogus payload"'
  [ "$status" -eq 0 ]
}

@test "jump.sh: > add with no spec shows the format hint" {
  run bash -c '. src/jump.sh list "> add"'
  echo "$output" | jq -e '.items[0].title == "Add a link"' >/dev/null
}

@test "jump.sh: > update delegates to the updater when present" {
  cat > src/update.sh <<'STUB'
#!/bin/bash
printf '{"items":[{"title":"updater ran"}]}'
STUB
  run bash -c '. src/jump.sh list "> update"'
  rm -f src/update.sh
  echo "$output" | jq -e '.items[0].title == "updater ran"' >/dev/null
}

@test "jump.sh: > update shows a hint when the updater is missing" {
  rm -f src/update.sh
  run bash -c '. src/jump.sh list "> update"'
  echo "$output" | jq -e '.items[0].title == "Updater unavailable"' >/dev/null
}

@test "jump.sh: run installs an update from a url" {
  export INSTALL_LOG="$BATS_TEST_TMPDIR/install.log"
  cat > src/update.sh <<'STUB'
#!/bin/bash
echo "install [$1]" >> "$INSTALL_LOG"
STUB
  run bash -c '. src/jump.sh run "https://example.com/Jump.alfredworkflow"'
  rm -f src/update.sh
  grep -q 'install \[https://example.com/Jump.alfredworkflow\]' "$INSTALL_LOG"
}

@test "jump.sh: shows an update banner when one is pending" {
  : > "$alfred_workflow_data/autoupdate"
  cat > src/update.sh <<'STUB'
#!/bin/bash
printf '{"items":[{"title":"Update to v9","arg":"https://example.com/Jump.alfredworkflow"}]}'
STUB
  run bash -c '. src/jump.sh list ""'
  rm -f src/update.sh
  echo "$output" | jq -e '[.items[].title] | index("Update available") != null' >/dev/null
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
