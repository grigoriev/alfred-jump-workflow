# CLAUDE.md

Alfred workflow that stores links with tags and categories in plain files and opens them fast.
A link can open a URL, a file, an app, a deep link, or run a command in iTerm2.
Keyword: `jump`. Artifact: `Jump.alfredworkflow`.

## Layout

- `src/jump.sh` - the entry point. It takes `mode` (`list` for the Script Filter, `run` for the Run Script) and `query`.
- `src/links.sh` - the links folder, the cached index, add and delete, frecency stats, pins, iTerm2 session ids.
- `src/cache.sh` - the cache under `$alfred_workflow_cache`.
- `src/globals.sh` - the `jump >` settings menu (`globals_menu`): sort, add, folder, rebuild, updates.
- `src/parse-links.awk`, `src/links-to-json.jq`, `src/filter-links.jq` - extracted awk and jq programs.
- `src/workflow_handler.sh` - shared JSON feedback helpers, identical in all sibling workflows.
- `src/media.sh` - icon paths. `icons/` holds the PNGs, built from Octicons.
- `src/update.sh`, `src/autoupdate.sh` - fetched at build time from `alfred-workflow-updater`. Gitignored, never committed.
- `info.plist` - Alfred objects, the hotkey trigger and the workflow `version`.
- `tests/jump_tests.bats`, `tests/links_tests.bats`, `tests/workflow_handler_tests.bats`, `tests/perf_tests.bats`.
- `tests/mocks/bin/` - fake `open` and `osascript`.

Link storage: one `.md` file per link, subfolder = category, file name = title. Lines: `url:`, optional `tags:`, optional `run:`. Default folder `~/.jump`.

## Commands

```sh
make lint       # ShellCheck jump, links, cache, globals in Docker
make test       # fetch the updater, then run bats tests (macOS)
make coverage   # bats under kcov in Docker, writes sonar-coverage.xml
make build      # fetch the updater, smoke-test it, zip Jump.alfredworkflow
make icons      # regenerate PNG icons from Octicons (macOS, needs librsvg)
make clean      # remove the artifact, fetched updater and coverage
```

1. Install tools with `brew install bats-core jq`.
2. `make lint SHELLCHECK=shellcheck` uses a local ShellCheck instead of Docker.
3. `make test` needs network access, because it fetches the updater bundle first.
4. `JUMP_DEFAULT_FOLDER` points the links folder at a fixture in tests.

## Constraints and conventions

- Scripts run under stock macOS `/bin/bash` 3.2.
- No bash 4+ features: no `mapfile`, `readarray`, `declare -A`, `${var,,}` or `${var^^}`.
- Check a construct with `/bin/bash -c '...'`. zsh and Homebrew bash 5 hide 3.2 gaps.
- No perl. Use `awk`, `sed`, `jq` or bash.
- The index is rebuilt with one `find ... -exec awk` pass piped into one `jq` pass.
- The index counts as stale when the folder changes or when `parse-links.awk` or `links-to-json.jq` is newer than it. Keep that check.
- Build Script Filter JSON with `add_result` and `get_json_results`, never by hand.
- Put multi-line jq or awk programs in `src/*.jq` or `src/*.awk` and call them with `-f`.
- `run:` links reuse an iTerm2 session by its stored `id`. Compile-check AppleScript with `osacompile -o /dev/null -`.
- Alfred clears an imported hotkey. Keep the hotkey object wired and document the manual setup.
- Settings and updates live behind the `jump >` menu. `globals_menu` calls the shared `autoupdate_menu`.
- Update logic lives only in `alfred-workflow-updater`. Never reimplement it here.
- SonarCloud shell rules: `[[ ]]` not `[ ]`, positional params into named lowercase `local`s, snake_case functions, explicit `return` at function end, a `*)` default in every `case`, HTTPS for `curl`.

## Review focus

Flag these in a pull request:

- Any bash 4+ feature, or any perl call.
- A new or changed function without a bats test. A bug fix without a test that fails before the fix.
- Unquoted variable expansions, especially file names, titles with spaces, URLs and folder paths.
- `url:` or `run:` values passed to `eval`, or interpolated into `osascript` without escaping.
- A change to the link file format without a matching change in `parse-links.awk` and the README.
- A parser change that bypasses the index staleness check, so users keep a stale index.
- `jq`, `awk` or a subshell spawned inside a per-link loop.
- A multi-line jq or awk program embedded in `$(...)` instead of a `src/*.jq` or `src/*.awk` file.
- Hand-built JSON strings instead of `add_result` and `json_encode`.
- A test that reads or writes the real `~/.jump` or opens real apps instead of the fixture and mocks.
- A violation of the Sonar shell rules listed above.
- A new `src/*.sh` script that the `SCRIPTS` list in the Makefile does not lint.
- Update or autoupdate logic added here, or a committed `src/update.sh` or `src/autoupdate.sh`.
- A change to `.github/workflows/ci.yml`, `release.yml` or `bump-version.yml` in this repo only. These are byte-identical across all 8 Alfred repos.
- A user-facing change without an entry under `## [Unreleased]` in `CHANGELOG.md`.
- A behavior or storage change without a README update.

Commit, branch and pull request rules are in `CONTRIBUTING.md`.

## CI and release

- `ci.yml`: ShellCheck, actionlint and zizmor on Ubuntu, bats on `macos-latest`, the build, and a SonarCloud scan with kcov coverage.
- The version lives in `info.plist`. `make print-version` and `make set-version VERSION=x.y.z` read and write it.
- A maintainer runs **Bump Version & Release**. It cuts the `CHANGELOG.md` section and tags `v*`.
- `release.yml` builds with `CHECK_PROVENANCE=1`, attests the artifact, and publishes an immutable release.
