# Parse link files into TSV rows: title <TAB> category <TAB> url <TAB> tags <TAB> path
# Run over many "*.md" files. Title is the filename without ".md"; category is the
# immediate subfolder under root, or "General" for files at the root. Portable
# awk (no gawk ENDFILE): emit the previous record when the filename changes.
# Pass -v root=<links folder>.
FNR == 1 {
  if (path != "") emit()
  path = FILENAME
  n = split(path, parts, "/")
  title = parts[n]; sub(/\.md$/, "", title)
  dir = path; sub(/\/[^\/]*$/, "", dir)
  if (dir == root) {
    category = "General"
  } else {
    m = split(dir, dparts, "/"); category = dparts[m]
  }
  url = ""; tags = ""
}
/^[ \t]*url:/  { line = $0; sub(/^[ \t]*url:[ \t]*/, "", line);  url = line }
/^[ \t]*tags:/ { line = $0; sub(/^[ \t]*tags:[ \t]*/, "", line); tags = line }
END { if (path != "") emit() }
function emit() { printf "%s\t%s\t%s\t%s\t%s\n", title, category, url, tags, path }
