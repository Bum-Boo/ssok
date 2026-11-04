# 0038 — Count only free environment objects in cups

- Status: accepted
- Date: 2026-10-22
- Implements: owner's work D-3 correction after a GitHub cup test counted the chassis.
- Partially supersedes: [0037](0037-functional-transmissions-and-devices.md), only the eligibility of any movable body as a cup-count candidate.
- Extends: 0002, 0003, 0025 and 0036. Graph authority, physics, board APIs and Stage selectors remain unchanged.

## Decision

A cup candidate must have `environment_role="object"`, be movable, and have no mechanical
connection to any non-object graph part. This excludes robot chassis, boards, motors,
structural parts and cups, including objects attached through joints or merged bodies.
Electrical wiring does not change mechanical membership.

Count each eligible solver RID once across all cups. Every member of a merged object body
must fit inside the cup's local interior using the existing analytic sphere extents,
conservative mesh bounds and solver penetration tolerance. Do not change physics parameters
or write observations back into the graph. Stage v2 `cup_count` keeps its whole-environment
selector, min/max/hold and unavailable-physics behavior.

## Verification

Use direct-placement regression checks independently of a short, slow physical pushing
fixture with a ball close to the cup mouth. A chassis overlapping the cup must not affect
the count. Source-specific results and platform limits belong in [work D-3](../WORK_SUMMARY_D3.md).
