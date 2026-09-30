# 0013 — Reviewed product publication and retained original rights

- Status: accepted
- Date: 2026-09-22
- Supersedes: 0006's private-only incubation policy for the reviewed release.

## Context

The owner requested completion and GitHub deployment as a product that prospective employers
can inspect and use. The earlier private repository was an incubation choice, not a permanent
product requirement. Publication must represent working software and preserve existing work.
The prior commercial intent does not imply permission to grant a blanket MIT license.

## Decision

- Integrate and verify in a separate release worktree, preserving both existing dirty worktrees.
- Publish an audited source revision, a usable static browser application and a desktop build
  with retained evidence, checksums, architecture and measured limitations.
- Publication follows the full release gate in `docs/RELEASE_PLAN.md`; a branch push or attractive
  README alone is not a finished product release. Failing gates stay visible and block release.
- Original project rights remain reserved. Bundled Godot, Noto and Lucide notices accompany the
  corresponding components. An open-source licensing change is a separate owner decision.
- This delivery is authorized by the current owner instruction, including necessary GitHub
  integration and deployment; the earlier human-only merge workflow does not prevent this
  requested release. Routine future contributions retain the ordinary review workflow.

## Consequences

The public evidence must distinguish scripted control, bounded parameter search and learned
policies. Private data, credentials, developer environments and personal saved projects are
excluded from publication. A local test or successful export is not proof of public usability.
