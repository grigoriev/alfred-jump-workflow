# Filter the link index by a query and format the matches as Alfred items. Every
# whitespace-separated word of the query must appear (case-insensitive) somewhere
# in "title category tags url". Pinned links are marked with a star and sorted to
# the top; the rest are ordered by the chosen sort. Enter opens the url, cmd
# deletes the file, alt pins or unpins it.
# --arg q query  --arg icon link icon  --argjson pinned a list of pinned paths
# --argjson frecency a map url -> {n, t}  --arg sort "frecency" | "alphabet".
def words($s): ($s | ascii_downcase | [splits("[[:space:]]+")] | map(select(length > 0)));
[ .[]
  | ((.title + " " + .category + " " + (.tags | join(" ")) + " " + .url) | ascii_downcase) as $hay
  | select(words($q) | all(. as $w | $hay | contains($w)))
  | . + {
      _pinned: ((.path as $p | ($pinned | index($p))) != null),
      _n: (($frecency[.url].n) // 0),
      _t: (($frecency[.url].t) // 0)
    }
]
| (if $sort == "alphabet"
   then sort_by(.title | ascii_downcase)
   else sort_by([- ._n, - ._t, (.title | ascii_downcase)])
   end)
| (map(select(._pinned)) + map(select(._pinned | not)))
| map({
    title: (if ._pinned then "★ " + .title else .title end),
    subtitle: (.category + "  ·  " + .url
               + (if (.tags | length) > 0 then "  ·  " + (.tags | map("#" + .) | join(" ")) else "" end)),
    arg: ("open " + .url),
    icon: { path: $icon },
    mods: {
      cmd: { valid: true, arg: ("delete " + .path), subtitle: "Delete this link" },
      alt: (if ._pinned
            then { valid: true, arg: ("unpin " + .path), subtitle: "Unpin from the top" }
            else { valid: true, arg: ("pin " + .path), subtitle: "Pin to the top" }
            end)
    }
  })
