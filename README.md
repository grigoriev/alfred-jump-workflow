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
jump > add <url> | <title> @category #tag1 #tag2 ! command
```

Enter opens the link. On a link, <kbd>⌘</kbd> deletes it and <kbd>⌥</kbd> pins it
to the top (marked with a star).

The workflow ships a hotkey trigger wired to the list, suggesting
<kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>Space</kbd>. Alfred clears an imported
workflow's hotkey on install, on purpose, so it cannot clash with your existing
hotkeys. So assign a combo once: double-click the Hotkey object in the workflow
editor and press your keys. Pick a combo with a modifier, not a bare
<kbd>⌥</kbd><kbd>Space</kbd> (that types a non-breaking space, not a hotkey).

## What you can open

The `url:` line is handed to macOS `open`, so a link is not limited to the web:

- **Web pages** - `https://...`, routed by your default browser.
- **Files and folders** - `~/project`, `$HOME/notes.md`, `/Applications` (a
  leading `~` and `$VAR` / `${VAR}` are expanded, so store paths naturally).
- **Applications** - a full bundle path, `/Applications/Xcode.app`.
- **Deep links and url schemes** - jump inside an app:
  - `slack://channel?team=...&id=...`
  - `obsidian://open?vault=...&file=...`
  - `vscode://file/Users/you/project`
  - `x-apple.systempreferences:com.apple.preference.network`
  - `things:///`, `raycast://`, `spotify:`, `mailto:`, `tel:`, and any custom
    scheme an installed app registers.
- **Commands in iTerm2** - add a `run:` line to launch a command in a folder,
  see [Running commands in iTerm2](#running-commands-in-iterm2).

## Running commands in iTerm2

A link can launch a command in [iTerm2](https://iterm2.com), in a folder, instead
of opening a url. Add a `run:` line: `url:` is the working directory and `run:` is
the command to run there.

```
url: ~/projects/myapp
run: claude
tags: dev claude
```

Selecting it opens a new iTerm2 window, `cd`s into the folder, and runs the
command (here [Claude Code](https://www.anthropic.com/claude-code)). A leading `~`
and `$VAR` in the folder are expanded. The session is tagged with the folder and
command, so if you pick the same link again while it is still open, jump **switches
to that window** instead of starting a second one.

This is the way to keep per-project "Claude Code here" aliases - one file per
repository:

```
~/.jump/claude/
  myapp.md       # url: ~/projects/myapp    run: claude
  api.md         # url: ~/work/api          run: claude
```

Then `jump myapp` (or the hotkey) drops you into Claude Code in that repo, and
reuses the window on the next jump. Any command works, not only `claude`, so you
can also run `lazygit`, `htop`, a dev server, and so on. A link with a `run:` line
shows a terminal icon and its command in the subtitle.

You can create one from Alfred with a trailing `! command`:

```
jump > add ~/projects/myapp | Claude myapp @claude ! claude
```

or just add a `run:` line to any existing link file.

## Storage

Links live in plain files under a folder, `~/.jump` by default (created on first
use; change it in `jump >`). The layout is:

- **category = subfolder**, **link = one `.md` file**;
- the **file name is the title**;
- the file holds `url:`, an optional `tags:` line, and an optional `run:` line
  (a command to run in iTerm2, see
  [Running commands in iTerm2](#running-commands-in-iterm2)).

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
