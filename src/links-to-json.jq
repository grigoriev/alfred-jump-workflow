# Turn the TSV rows from parse-links.awk into the link index. Rows without a url
# are dropped. Tags are split on spaces and commas.
split("\n")
| map(select(length > 0))
| map(split("\t"))
| map(select((.[2] // "") != ""))
| map({
    title: .[0],
    category: .[1],
    url: .[2],
    tags: ((.[3] // "") | gsub(","; " ") | split(" ") | map(select(length > 0))),
    path: .[4]
  })
