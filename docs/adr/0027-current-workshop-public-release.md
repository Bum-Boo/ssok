# 0027 — Publish the current learning workshop with explicit research limits

- Status: accepted
- Date: 2026-09-30
- Implements: the owner's explicit instruction to merge, deploy, upload final GitHub assets and make the repository public.
- Extends: 0013, 0023 and 0026. Supersedes only 0013's historical full research-product acceptance scope for this versioned learning-workshop publication. Engine, graph, physics, learning proofs and original rights remain unchanged.

## Decision

Merge reviewed implementation PR40/41, freeze a clean v0.2.0 source and rebuild all four platforms from that source. Verify the complete native suite, real browser assembly/storage/learning/settings and existing physics regression before publishing application bytes. Keep every failed attempt separate.

The owner's current product direction is micro:bit-first education and three observable learning stages. Kit/biped/RL work is paused and retained as an exhibit, not a promise of universal sustained locomotion. Publish these known limits rather than silently relaxing research metrics or claiming they are met. The older research release checklist remains historical; this version's actual delivery checks are recorded separately.

Audit tracked files and Git history before changing visibility. Retain original all-rights-reserved licensing and third-party notices; public visibility does not grant a new license.

GitHub artifact storage quota currently prevents Actions artifact upload. Publish the exact verified Web payload to a dedicated gh-pages branch with .nojekyll, and configure Pages to use its root. Attach verified versioned desktop/Web archives, Windows setup, manifest and SHA256 to the GitHub release directly. Do not delete existing artifacts or change billing to work around the quota. Application source stays on main; payload identity and anonymous deployed checks accompany release evidence.

A public repository or uploaded ZIP alone is not a completed deployment. Confirm anonymous repository, release downloads and real public Web interaction. Windows is unsigned; macOS is ad-hoc signed, without Developer ID/notarization or physical-Mac verification. Disclose these platform limits in downloads and release notes.

## Consequences

Normal contributor review rules resume after this owner-authorized publication. Rebuild for application changes; later documentation-only evidence commits identify the source already deployed. No paid provider, secret transfer or shared-lab Mac is required.
