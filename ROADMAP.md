# Roadmap

Dotty is aiming for a polished v1 for power users who want layered personal,
work, and machine-specific dotfiles without moving to a template-heavy tool.

Active roadmap work now lives as repo-local Jackie Plan artifacts under
`.jackie-plan/`. Use `jp list --status inbox,active,ready-to-implement` from
this repo to choose the next item.

## Ready to implement

- `2026-06-25-cut-first-public-ready-dotty-release` — Cut first public-ready
  dotty release.
- `2026-06-25-run-outside-user-onboarding-pass-for-dotty` — Run outside-user
  onboarding pass for dotty.

## Captured for later

- `2026-06-25-decide-whether-dotty-needs-init-or-starter-profiles` — Decide
  whether dotty needs `init` or starter profiles after onboarding produces
  evidence.
- `2026-06-25-polish-dotty-status-and-trace-output-from-feedback` — Polish
  `dotty status` and `dotty trace` from concrete user feedback.

## Product boundaries

These are intentionally out of scope unless repeated user evidence changes the
direction:

- Template DSL.
- Built-in secrets management or encryption.
- Built-in JSON merge abstractions or package-manager integrations.

If a behavior change lands, keep `README.md`, `cmd_help()`,
`completions/_dotty`, and the relevant tests in sync in the same change set.
