# Contributing

Dotty is a small bash project. The main bar for changes is clarity and portability, not cleverness.

## Local setup

Initialize the test submodule first:

```bash
git submodule update --init
```

Run the full test suite with:

```bash
./test/bats/bin/bats test/
```

While iterating, run the smallest relevant bats file first, then rerun the full suite before you send or merge a change.

## Bash expectations

- Keep `set -euo pipefail`.
- Preserve bash `3.2` compatibility.
- Keep GNU/BSD portability in mind for small utilities like `sed` and `stat`.
- Add comments only when they explain non-obvious behavior.

## Keep behavior and docs aligned

If dotty behavior changes, update the same change set:

- `README.md`
- `dotty` help text in `cmd_help()`
- `completions/_dotty`
- relevant bats coverage in `test/*.bats`

If the change affects repo conventions, hook behavior, or other durable contributor-facing behavior, update `AGENTS.md` too.

## CI

GitHub Actions runs the bats suite and a clean-home install smoke test on macOS and Linux. Treat local green tests as the minimum bar before relying on CI.

## Releases

Release mechanics live in `RELEASING.md`.
