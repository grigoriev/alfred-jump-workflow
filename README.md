# <img src="https://raw.githubusercontent.com/grigoriev/alfred-jump-workflow/main/icon.png" alt="jump" width="32"> Alfred Jump Workflow

![CI](https://github.com/grigoriev/alfred-jump-workflow/actions/workflows/ci.yml/badge.svg)
[![Release](https://img.shields.io/github/v/release/grigoriev/alfred-jump-workflow)](https://github.com/grigoriev/alfred-jump-workflow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-jump-workflow&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-jump-workflow)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-jump-workflow&metric=coverage)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-jump-workflow)

Store many links with tags and categories in plain files, and open them fast
from Alfred.

## Requirements

- [Alfred](https://www.alfredapp.com/) with the Powerpack.
- `jq` (preinstalled on macOS 12+, or `brew install jq`).

## Install

1. Open the [latest release](https://github.com/grigoriev/alfred-jump-workflow/releases/latest).
2. Under **Assets**, download `Jump.alfredworkflow`.
3. Double click the file to add it to Alfred.

## Usage

```
jump <query>            search links by title, category, tags or url
jump aws #work          every word must match, so this narrows by both
jump >                  settings: sort, add a link, folder, rebuild, update
jump > add <url> | <title> @category #tag1 #tag2
```

Enter opens the link. On a link, <kbd>⌘</kbd> deletes it and <kbd>⌥</kbd> pins it
to the top (marked with a star).

Press <kbd>⌥</kbd><kbd>Space</kbd> (configurable in the workflow editor) to open
the list from anywhere, without typing the keyword.

## Storage

Links live in plain files under a folder, `~/.jump` by default (created on first
use; change it in `jump >`). The layout is:

- **category = subfolder**, **link = one `.md` file**;
- the **file name is the title**;
- the file holds `url:` and an optional `tags:` line.

```
~/.jump/
  work/
    Jira.md            # url: https://jira.example.com
    CI Dashboard.md    # url: ...  /  tags: ci build
  personal/
    Bank.md
  Inbox item.md        # a file at the root is category "General"
```

Add and remove from Alfred, or manage the files directly in Finder. All files are
aggregated into a cached index, rebuilt whenever the folder changes.

## Sorting

Choose the order in `jump >`:

- **Frecency** (default) - the links you open most float to the top.
- **Alphabetical** - by title.

Pinned links (<kbd>⌥</kbd>) always sort to the top, in either mode.

## Development

```sh
make lint     # ShellCheck the action scripts
make test     # run the bats tests
make build    # build the workflow bundle
make icons    # regenerate PNG icons from Octicons (macOS, needs librsvg)
```

Icons come from [Octicons](https://github.com/primer/octicons) (MIT).
