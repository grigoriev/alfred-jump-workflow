#!/bin/bash

. src/workflow_handler.sh
. src/media.sh
. src/links.sh
. src/globals.sh

# Single entry point behind the "jump" keyword. Called two ways from Alfred:
#   list mode (Script Filter): . src/jump.sh list "{query}"
#   run mode  (Run Script):    . src/jump.sh run  "{query}"
#
# Query grammar:
#   jump <query>          -> fuzzy search links by title, category, tags, url
#   jump >                -> global commands (add, folder, rebuild, update)
#   jump > add <spec>     -> add a link: url | title @category #tags
#
# A link item opens its url; the cmd modifier deletes the file.

mode="$1"
query="$2"

# Reopen Alfred on a query so the list refreshes in place after an action.
alfred_search() {
  local query="$1"
  osascript - "$query" <<'APPLESCRIPT'
on run argv
  tell application id "com.runningwithcrayons.Alfred" to search (item 1 of argv)
end run
APPLESCRIPT
  return 0
}

# Run mode: dispatch the item action.
if [[ "$mode" == "run" ]]; then
  action="${query%% *}"
  payload="${query#"$action"}"
  payload="${payload# }"
  case "$action" in
    open)        open "$payload"; record_open "$payload" ;;
    delete)      rm -f "$payload"; alfred_search "jump " ;;
    pin)         pin_link "$payload"; alfred_search "jump " ;;
    unpin)       unpin_link "$payload"; alfred_search "jump " ;;
    sort)        set_pref sort "$payload" 0; alfred_search "jump >" ;;
    add-link)    add_link "$payload"; alfred_search "jump " ;;
    edit-folder) edit_folder ;;
    open-folder) open_folder ;;
    rebuild)     rm -f "$(links_index)"; alfred_search "jump " ;;
    autoupdate)  set_autoupdate "$payload" ;;
    http://*|https://*) autoupdate_clear; [[ -f src/update.sh ]] && . src/update.sh "$query" ;;
    *) : ;;
  esac
  exit
fi

# List mode
if [[ "$query" == ">"* ]]; then
  sub="${query#>}"
  sub="${sub# }"
  if [[ "$sub" == update* ]]; then
    if [[ -f src/update.sh ]]; then
      . src/update.sh ""
    else
      add_result "" "" "Updater unavailable" "Rebuild the workflow bundle" "$ICON_UPDATE" "no"
      get_json_results
    fi
  elif [[ "$sub" == "add" || "$sub" == add\ * ]]; then
    spec="${sub#add}"
    spec="${spec# }"
    if [[ -z "$spec" ]]; then
      add_result "" "" "Add a link" "Type: url | title @category #tags" "$ICON_ADD" "no"
    else
      add_result "" "add-link $spec" "Add this link" "$spec" "$ICON_ADD" "yes"
    fi
    get_json_results
  else
    globals_menu "$sub"
  fi
  exit
fi

if [[ -z "$query" ]]; then
  autoupdate_refresh
  autoupdate_banner
fi

index="$(read_index)"
pinned="$(pinned_json)"
frecency="$(frecency_json)"
sort="$(get_pref sort 0)"
[[ -n "$sort" ]] || sort="frecency"
items="$(jq -c -f src/filter-links.jq --arg q "$query" --arg icon "$ICON_LINK" \
  --argjson pinned "$pinned" --argjson frecency "$frecency" --arg sort "$sort" <<< "$index" 2>/dev/null)"
if [[ -z "$items" || "$items" == "[]" ]]; then
  add_result "" "" "No links found" "Add one with jump > add" "$ICON_LINK" "no"
  get_json_results
  exit
fi

# Prepend any update banner queued on the home view, then the links.
printf '{"items":%s}\n' "$(jq -c --argjson extra "$(get_json_results)" '$extra.items + .' <<< "$items")"
