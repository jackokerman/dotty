# Releasing

This repo does not have a heavy release pipeline. Keep releases small and mechanical.

Dotty is a Bash script, not a compiled binary or package artifact. A release is a git commit with `DOTTY_VERSION` set in `dotty`, an annotated tag, and GitHub release notes. The installer clones this repository into `~/.dotty` and symlinks `~/.dotty/bin/dotty` to the tracked `dotty` script, so there is no build, upload, or install artifact to produce.

## Checklist

1. Make sure user-visible behavior is documented in `README.md`, `cmd_help()`, `completions/_dotty`, and the relevant bats files.
2. Run `./test/bats/bin/bats test/`.
3. Bump `DOTTY_VERSION` in `dotty`.
4. Commit the release change.
5. Create an annotated tag like `v0.4.0`.
6. Decide whether the public install path should keep tracking `main` or point at the release, and document that choice in the release notes.
7. Push `main` and the tag.
8. Draft GitHub release notes that summarize the user-visible changes and any migration or install notes.

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

Create the GitHub release as a draft. Generated notes are fine as a starting point, but review them before publishing when the release needs migration notes or an explicit install-path decision.

```bash
release_args=(--draft --verify-tag --generate-notes)
if [[ -n "$previous_tag" ]]; then
    release_args+=(--notes-start-tag "$previous_tag")
fi

gh release create "$version" "${release_args[@]}"
```

After reviewing the draft notes, publish the release:

```bash
gh release edit "$version" --draft=false
```

## Notes

- If a change lands on `main` without a release, leave `DOTTY_VERSION` alone until the release commit.
- The first public-ready release kept the curl installer on `main`. Future releases can keep that model or switch to a tagged installer path as long as the release notes make the choice explicit.
