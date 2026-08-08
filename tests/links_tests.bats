#!/usr/bin/env bats

# Unit tests for src/links.sh.

setup() {
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
  export JUMP_DEFAULT_FOLDER="$BATS_TEST_TMPDIR/default"
  export LINKS="$BATS_TEST_TMPDIR/links"
  mkdir -p "$LINKS/work"
  printf 'url: https://jira.example.com\ntags: work tracker\n' > "$LINKS/work/Jira.md"
  printf 'url: https://news.example.com\ntags: read\n' > "$LINKS/Inbox.md"
  printf '%s\n' "$LINKS" > "$alfred_workflow_data/folder"
}

@test "links.sh: build_index indexes files with title, category, tags and url" {
  run bash -c '. src/links.sh; read_index'
  echo "$output" | jq -e 'length == 2' >/dev/null
  echo "$output" | jq -e '.[] | select(.title=="Jira") | .category=="work" and .url=="https://jira.example.com" and (.tags==["work","tracker"])' >/dev/null
  echo "$output" | jq -e '.[] | select(.title=="Inbox") | .category=="General"' >/dev/null
}

@test "links.sh: a parser newer than the index makes it stale" {
  bash -c '. src/links.sh; read_index >/dev/null'
  touch -t 200001010000 "$(bash -c '. src/links.sh; links_index')"
  run bash -c '. src/links.sh; index_fresh; echo "rc=$?"'
  [[ "$output" == *"rc=1"* ]]
}

@test "links.sh: the index rebuilds when a file is added" {
  bash -c '. src/links.sh; read_index >/dev/null'
  sleep 1
  printf 'url: https://new.example.com\n' > "$LINKS/work/New.md"
  run bash -c '. src/links.sh; read_index'
  echo "$output" | jq -e '[.[].title] | index("New") != null' >/dev/null
}

@test "links.sh: add_link writes a file with url and tags in the category" {
  bash -c '. src/links.sh; add_link "https://x.com | My Site @tools #dev #ref"'
  [ -f "$LINKS/tools/My Site.md" ]
  grep -q '^url: https://x.com$' "$LINKS/tools/My Site.md"
  grep -q '^tags: dev ref$' "$LINKS/tools/My Site.md"
}

@test "links.sh: add_link defaults the title to the host and category to General" {
  bash -c '. src/links.sh; add_link "https://example.org/path"'
  [ -f "$LINKS/General/example.org.md" ]
}

@test "links.sh: add_link titles a bare path by its last component" {
  bash -c '. src/links.sh; add_link "~/Projects/intechcore/intranet"'
  [ -f "$LINKS/General/intranet.md" ]
  grep -qxF 'url: ~/Projects/intechcore/intranet' "$LINKS/General/intranet.md"
}

@test "links.sh: add_link writes a run line from a trailing ! command" {
  bash -c '. src/links.sh; add_link "~/Projects/intechcore/intranet | Intranet @claude ! claude --resume"'
  [ -f "$LINKS/claude/Intranet.md" ]
  grep -qxF 'url: ~/Projects/intechcore/intranet' "$LINKS/claude/Intranet.md"
  grep -qxF 'run: claude --resume' "$LINKS/claude/Intranet.md"
}

@test "links.sh: a run field is indexed" {
  printf 'url: ~/proj\nrun: claude\n' > "$LINKS/work/Claude.md"
  run bash -c '. src/links.sh; read_index'
  echo "$output" | jq -e '.[] | select(.title=="Claude") | .run == "claude" and .url == "~/proj"' >/dev/null
}

@test "links.sh: iterm session id round-trips by marker" {
  bash -c '. src/links.sh; iterm_set_session_id "/tmp :: claude" "ABC-123"'
  run bash -c '. src/links.sh; iterm_session_id "/tmp :: claude"'
  [ "$output" == "ABC-123" ]
  run bash -c '. src/links.sh; iterm_session_id "unknown"'
  [ -z "$output" ]
}

@test "links.sh: record_open bumps the frecency count" {
  bash -c '. src/links.sh; record_open "https://x.com"; record_open "https://x.com"'
  run cat "$alfred_workflow_data/frecency.json"
  echo "$output" | jq -e '.["https://x.com"].n == 2' >/dev/null
}

@test "links.sh: pin_link and unpin_link toggle the pinned list" {
  bash -c '. src/links.sh; pin_link "/a/b.md"'
  run bash -c '. src/links.sh; pinned_json'
  echo "$output" | jq -e '. == ["/a/b.md"]' >/dev/null
  bash -c '. src/links.sh; unpin_link "/a/b.md"'
  run bash -c '. src/links.sh; pinned_json'
  echo "$output" | jq -e '. == []' >/dev/null
}

@test "links.sh: build_index creates the folder when missing" {
  rm -rf "$LINKS"
  bash -c '. src/links.sh; build_index'
  [ -d "$LINKS" ]
}
