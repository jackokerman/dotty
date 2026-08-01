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

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) so release history stays scannable and version decisions remain mechanical.

- `feat:` introduces user-visible behavior and normally warrants a minor release.
- `fix:` corrects user-visible behavior and normally warrants a patch release.
- `feat!:` or another type with `!` marks a breaking change and warrants a major release.
- `docs:`, `refactor:`, `perf:`, `test:`, and `chore:` describe changes that do not determine a release on their own.

Keep the subject concise and imperative, for example `fix: preserve registry order when updating entries`.

## Keep behavior and docs aligned

If dotty behavior changes, update the same change set:

- `README.md`
- `dotty` help text in `cmd_help()`
- `completions/_dotty`
- relevant bats coverage in `test/*.bats`

If the change affects repo conventions, hook behavior, or other durable contributor-facing behavior, update `AGENTS.md` too.

## CI

GitHub Actions runs the bats suite and a clean-home install smoke test on macOS and Linux. Treat local green tests as the minimum bar before relying on CI.

## Reporting bugs and feature requests

Use the GitHub issue forms. Bug reports should include `dotty version`, the OS and shell, the repo chain shape, the exact command you ran, and the relevant output from `dotty doctor` plus whichever of `dotty status`, `dotty trace <path>`, or `dotty files` explains the failure.

If you need a concrete minimal layout, start from `examples/personal-dotfiles/` and `examples/work-dotfiles/` and then trim the repro down from there.

## Releases

Release mechanics live in `RELEASING.md`. Releases are currently cut manually from the conventional commits since the previous tag.
