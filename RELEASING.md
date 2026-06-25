# Releasing

This repo does not have a heavy release pipeline. Keep releases small and mechanical.

## Checklist

1. Make sure user-visible behavior is documented in `README.md`, `cmd_help()`, `completions/_dotty`, and the relevant bats files.
2. Run `./test/bats/bin/bats test/`.
3. Bump `DOTTY_VERSION` in `dotty`.
4. Commit the release change.
5. Create an annotated tag like `v0.4.0`.
6. Decide whether the public install path should keep tracking `main` or point at the release, and document that choice in the release notes.
7. Push `main` and the tag.
8. Draft GitHub release notes that summarize the user-visible changes and any migration or install notes.

## Notes

- Prefer a minor bump for new commands or user-facing behavior changes.
- Prefer a patch bump for fixes and docs-only cleanup that still merits a release.
- If a change lands on `main` without a release, leave `DOTTY_VERSION` alone until the release commit.
- For the first public-ready release, it is acceptable to keep the curl installer on `main` if the release notes call that out explicitly.
