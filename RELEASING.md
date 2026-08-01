# Releasing

This repo does not have an automated release pipeline. Keep releases small and mechanical.

Dotty is a Bash script, not a compiled binary or package artifact. A release is a git commit with `DOTTY_VERSION` set in `dotty`, checked-in notes under `docs/releases/`, an annotated tag, and a GitHub release. The installer clones this repository into `~/.dotty` and symlinks `~/.dotty/bin/dotty` to the tracked `dotty` script, so there is no build, upload, or install artifact to produce.

## Checklist

1. Make sure user-visible behavior is documented in `README.md`, `cmd_help()`, `completions/_dotty`, and the relevant bats files.
2. Run `./test/bats/bin/bats test/`.
3. Review the conventional commits since the previous tag and choose the next semantic version.
4. Bump `DOTTY_VERSION` in `dotty` and add `docs/releases/<version>.md`.
5. Commit the release change with `chore: release <version>`.
6. Create an annotated tag like `v0.4.0`.
7. Decide whether the public install path should keep tracking `main` or point at the release, and document that choice in the release notes.
8. Push `main` and the tag, then publish the checked-in notes as the GitHub release body.

## Manual flow

Pick the next version from the commits since the previous tag. Prefer a minor bump for new commands or user-facing behavior changes, and a patch bump for fixes or docs-only cleanup that still merits a release.

```bash
previous_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
version="v0.4.0"

git status --short --branch
git log --oneline "${previous_tag:+$previous_tag..}HEAD"
./test/bats/bin/bats test/
```

If the version needs to change, update `DOTTY_VERSION` in `dotty`, then commit it:

```bash
git add dotty
git commit -m "chore: release ${version#v}"
```

Create and push the annotated tag:

```bash
git tag -a "$version" -m "dotty $version"
git push origin main "$version"
```

Create the GitHub release as a draft from the checked-in notes:

```bash
gh release create "$version" \
    --draft \
    --verify-tag \
    --title "dotty $version" \
    --notes-file "docs/releases/$version.md"
```

After reviewing the draft notes, publish the release:

```bash
gh release edit "$version" --draft=false
```

## Notes

- If a change lands on `main` without a release, leave `DOTTY_VERSION` alone until the release commit.
- The first public-ready release kept the curl installer on `main`. Future releases can keep that model or switch to a tagged installer path as long as the release notes make the choice explicit.
- Keep release automation demand-driven. The manual flow is the source of truth until repeated release friction justifies another maintained workflow and its GitHub write permissions.
