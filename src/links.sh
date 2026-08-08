#!/bin/bash

# The link store: "*.md" files under a configured folder. A file's name is the
# link title, its "url:" and "tags:" lines hold the rest, and the parent
# subfolder is the category. All files are aggregated into a cached JSON index,
# rebuilt whenever anything under the folder changes.

. src/cache.sh

# Path to the file that stores the links folder (a single line).
folder_config() {
  printf '%s/folder' "${alfred_workflow_data:-.}"
  return 0
}

# The links folder: the configured path, or "~/.jump" by default so the workflow
# works with no setup. JUMP_DEFAULT_FOLDER overrides the default (used by tests).
links_folder() {
  local file path=""
  file="$(folder_config)"
  [[ -f "$file" ]] && path="$(grep -vE '^[[:space:]]*$' "$file" 2>/dev/null | head -1)"
  [[ -n "$path" ]] || path="${JUMP_DEFAULT_FOLDER:-$HOME/.jump}"
  printf '%s' "$path"
  return 0
}

# Path to the cached index.
links_index() {
  printf '%s/links.json' "${alfred_workflow_cache:-.}"
  return 0
}

# Build the index from every "*.md" under the folder.
build_index() {
  local folder index
  folder="$(links_folder)"
  index="$(links_index)"
  mkdir -p "$(dirname "$index")"
  # create the links folder if it does not exist yet
  [[ -n "$folder" ]] && mkdir -p "$folder" 2>/dev/null
  if [[ -z "$folder" || ! -d "$folder" ]]; then
    printf '[]' > "$index"
    return 0
  fi
  find "$folder" -type f -name '*.md' -exec awk -v root="$folder" -f src/parse-links.awk {} + 2>/dev/null \
    | jq -R -s -f src/links-to-json.jq > "$index.tmp" 2>/dev/null
  mv "$index.tmp" "$index" 2>/dev/null || printf '[]' > "$index"
  return 0
}

# Succeed when the index exists and nothing under the folder is newer than it.
# A delete bumps the parent directory's mtime, so this catches adds and removals.
index_fresh() {
  local folder index
  folder="$(links_folder)"
  index="$(links_index)"
  [[ -f "$index" ]] || return 1
  [[ -n "$folder" && -d "$folder" ]] || return 0
  [[ -z "$(find "$folder" -newer "$index" -print -quit 2>/dev/null)" ]]
}

# Print the index JSON, rebuilding it when stale.
read_index() {
  index_fresh || build_index
  cat "$(links_index)" 2>/dev/null || printf '[]'
  return 0
}

# Frecency stats: a JSON object mapping url -> {n: opens, t: last open epoch}.
frecency_file() {
  printf '%s/frecency.json' "${alfred_workflow_data:-.}"
  return 0
}

frecency_json() {
  local file
  file="$(frecency_file)"
  if [[ -f "$file" ]]; then cat "$file"; else printf '{}'; fi
  return 0
}

# Record an open of a url: bump its count and last-open time.
record_open() {
  local url="$1" file now stats
  [[ -n "$url" ]] || return 0
  file="$(frecency_file)"
  now="$(date +%s)"
  mkdir -p "${alfred_workflow_data:-.}"
  stats="$(frecency_json)"
  printf '%s' "$stats" \
    | jq -c --arg u "$url" --argjson t "$now" '.[$u] = {n: (((.[$u].n) // 0) + 1), t: $t}' \
      > "$file.tmp" 2>/dev/null && mv "$file.tmp" "$file"
  return 0
}

# Pinned links: one link file path per line.
pinned_file() {
  printf '%s/pinned' "${alfred_workflow_data:-.}"
  return 0
}

pinned_json() {
  local file
  file="$(pinned_file)"
  if [[ -f "$file" ]]; then jq -Rn '[inputs | select(length > 0)]' < "$file"; else printf '[]'; fi
  return 0
}

pin_link() {
  local path="$1" file
  file="$(pinned_file)"
  mkdir -p "${alfred_workflow_data:-.}"
  grep -qxF "$path" "$file" 2>/dev/null || printf '%s\n' "$path" >> "$file"
  return 0
}

unpin_link() {
  local path="$1" file kept
  file="$(pinned_file)"
  [[ -f "$file" ]] || return 0
  kept="$(grep -vxF "$path" "$file" || true)"
  printf '%s' "$kept" > "$file"
  return 0
}

# Trim surrounding whitespace and collapse runs of spaces.
trim() {
  local text="$1"
  printf '%s' "$text" | awk '{ $1 = $1; print }'
  return 0
}

# Create a link file from "url | title @category #tags". Category defaults to
# "General", the title to the url's host. The folder is created as needed.
add_link() {
  local spec="$1" folder url meta category tags title word dir safe file
  folder="$(links_folder)"
  [[ -n "$folder" ]] || return 1
  url="$(trim "${spec%%|*}")"
  [[ -n "$url" ]] || return 1
  meta=""
  [[ "$spec" == *"|"* ]] && meta="${spec#*|}"
  category="General"
  tags=""
  title=""
  local -a metawords=()
  read -ra metawords <<< "$meta"
  for word in "${metawords[@]}"; do
    case "$word" in
      @?*)  category="${word#@}" ;;
      \#?*) tags="$tags ${word#\#}" ;;
      *)    title="$title $word" ;;
    esac
  done
  title="$(trim "$title")"
  tags="$(trim "$tags")"
  [[ -n "$title" ]] || title="$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#/.*##')"
  dir="$folder/$category"
  mkdir -p "$dir"
  safe="$(printf '%s' "$title" | tr '/' '-')"
  file="$dir/$safe.md"
  {
    printf 'url: %s\n' "$url"
    [[ -n "$tags" ]] && printf 'tags: %s\n' "$tags"
  } > "$file"
  return 0
}
