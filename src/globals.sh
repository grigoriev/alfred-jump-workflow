#!/bin/bash

# Global commands behind "jump >": add a link, set or open the links folder,
# rebuild the index, and updates. The autoupdate helpers come from the shared,
# fetched src/autoupdate.sh.

. src/media.sh
. src/autoupdate.sh
. src/links.sh

# Lowercase a string.
jump_lower() {
  local text="$1"
  printf '%s' "$text" | tr '[:upper:]' '[:lower:]'
  return 0
}

# Queue a global command when its token contains the filter (case-insensitive).
# $1 token  $2 filter  $3 title  $4 subtitle  $5 arg  $6 valid  $7 icon  $8 autocomplete
global_item() {
  local token="$1" filter="$2" title="$3" subtitle="$4" arg="$5" valid="$6" icon="$7" auto="$8"
  case "$(jump_lower "$token")" in
    *"$(jump_lower "$filter")"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "$valid" "$auto" ;;
    *) : ;;
  esac
  return 0
}

# The global command menu, filtered by a substring.
globals_menu() {
  local filter="$1" sort
  sort="$(get_pref sort 0)"
  [[ -n "$sort" ]] || sort="frecency"
  if [[ "$sort" == "alphabet" ]]; then
    global_item "sort order" "$filter" "Sort: Alphabetical" "Switch to most-used first (frecency)" "sort frecency" "yes" "$ICON_GEAR" ""
  else
    global_item "sort order" "$filter" "Sort: Frecency" "Switch to alphabetical" "sort alphabet" "yes" "$ICON_GEAR" ""
  fi
  global_item "add link"      "$filter" "Add a link"        "Continue: url | title @category #tags ! command" ""  "no"  "$ICON_ADD"    "> add "
  global_item "set folder"    "$filter" "Set links folder"  "Edit the folder path that holds links"  "edit-folder" "yes" "$ICON_FOLDER" ""
  global_item "open folder"   "$filter" "Open links folder" "Reveal it in Finder"                    "open-folder" "yes" "$ICON_FOLDER" ""
  global_item "rebuild index" "$filter" "Rebuild index"     "Re-scan the links folder"               "rebuild"     "yes" "$ICON_GEAR"   ""
  autoupdate_menu "$filter" "$ICON_UPDATE"
  get_json_results
  return 0
}

# Open the folder-config file in a text editor, seeding a suggested path.
edit_folder() {
  local file
  file="$(folder_config)"
  mkdir -p "${alfred_workflow_data:-.}"
  [[ -f "$file" ]] || printf '%s\n' "${JUMP_DEFAULT_FOLDER:-$HOME/.jump}" > "$file"
  open -e "$file"
  return 0
}

# Reveal the configured links folder in Finder, creating it if missing.
open_folder() {
  local folder
  folder="$(links_folder)"
  [[ -n "$folder" ]] || return 0
  mkdir -p "$folder" 2>/dev/null
  open "$folder"
  return 0
}
