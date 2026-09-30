# 0017 — Read-only evidence from actual browser physics

- Status: accepted
- Date: 2026-09-22
- Extends: 0001, 0003, 0012 and 0014; simulation and command ownership remain unchanged.

## Context

Native engine results cannot certify the exported WebAssembly application. Canvas screenshots also
cannot establish displacement or stability. Browser verification needs measurements from the same
application and frozen policy that a learner uses, driven through actual browser keyboard input.

## Decision

- Enable a small `BrowserEvidence` observer only on the Web target with `?ssok_verify=1`.
- Expose numeric observations and graph/runtime/policy fingerprints through `window.__ssokPhysics`.
  Expose no setters, robot commands, evaluation callbacks or source-code execution interface.
- Observe the actual main scene, graph-derived run bodies and manual W command. Record exactly
  720 physics-frame intervals beginning with the active command, then freeze that measurement.
  Browser polling delays must not extend the measured horizon. Never pause or alter physics.
- Separately record the pose after 90 physics-frame intervals with the command released. Preserve
  early-release failures and bind both snapshots to the same unchanged graph and runtime.
- Verify the app's existing gate: 0.30 m forward, at most 0.10 m lateral and 30 degrees yaw, minimum
  uprightness 0.85, height above the floor greater than 0.09 m, finite trajectory, then uprightness
  at least 0.90 after stopping. A readout without passing these gates is not successful walking.
- Measure the lowest transformed corner of each actual foot collision box on every walking frame.
  Record per-foot maximum sole clearance and frames above 0.5 mm, requiring both feet to lift.

## Consequences

Ordinary application URLs do not publish diagnostic data. The observer neither owns commands nor
changes any body, joint, timing or policy parameter. Tests retain the exact build identity and
browser results; native and Web evidence remain separate. This adds no user-facing text and needs
no language-pack changes.
