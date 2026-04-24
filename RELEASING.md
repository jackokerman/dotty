# Releasing

This repo does not have a heavy release pipeline. Keep releases small and mechanical.

## Checklist

1. Make sure user-visible behavior is documented in `README.md`, `cmd_help()`, `completions/_dotty`, and the relevant bats files.
2. Run `./test/bats/bin/bats test/`.
3. Bump `DOTTY_VERSION` in `dotty`.
4. Commit the release change.
5. Create an annotated tag like `v0.4.0`.
6. Push `main` and the tag.
7. Draft GitHub release notes that summarize the user-visible changes and any migration or install notes.

## Notes

- Prefer a minor bump for new commands or user-facing behavior changes.
- Prefer a patch bump for fixes and docs-only cleanup that still merits a release.
- If a change lands on `main` without a release, leave `DOTTY_VERSION` alone until the release commit.
