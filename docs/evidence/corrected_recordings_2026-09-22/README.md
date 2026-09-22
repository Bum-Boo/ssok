# Native recordings under the corrected motor budget

> The learned movie records the preceding corrected-budget policy; the selected
> [heading-feedback policy](../heading_feedback_2026-09-22/README.md) has separate evidence.
> Pickup remains the current recorded pickup behavior. The original metrics and hashes below are retained.

Both movies use the unchanged application runtime from clean commit `6470757`, native Godot
4.7.2 GL Compatibility, 60 Hz physics and 30 Hz movie capture. They play at normal speed.
No policy, actuator limit, graph transform, collision or gravity setting is changed for capture.
Pickup's existing capture lighting/camera only affect appearance. Current media are in `docs/media/`;
the replaced old-model videos remain available in Git history at `6470757`.

- **Learned:** frozen policy SHA `d0b91edcee2bf2729ac1392ee3bc19547c9a38d48b96d1a54ea965f614fcf46b`,
  12 seconds of actual W input, 0.418373 m forward, -0.008129 m lateral, -10.413 degrees yaw,
  minimum uprightness 0.963639, then uprightness 0.999846 after releasing W for 1.5 seconds.
  The 1152 × 648 MP4 contains 437 frames / 14.566667 seconds. Its preview has 146 frames at
  10 fps; the separate final PNG is 1600 × 900. Frames at 1, 7 and 13.5 seconds were reviewed:
  the robot remains fully visible and the normal workshop camera follows its motion.
- **Pickup:** the current four-second lift reaches 0.477346 m, holds for 1 second and stays
  above uprightness 0.993473. Actual bilateral contact precedes the grasp. The evaluated episode
  lasts 10.2667 seconds; the retained final result lasts a further second without adding hold
  credit. Startup rendering makes the 341-frame movie 11.3667 seconds. Its GIF has 171 frames
  over 11.4 seconds, and the separate PNG is 1280 × 720. The robot, box, floor contact and final
  held pose are visible in the reviewed rendered frames.

`learned.json` and `pickup.json` are unedited capture outputs. `provenance.json` stores runtime,
policy, script, raw-movie and compressed-media SHA-256 values plus actual ffprobe dimensions.
The corresponding logs and exact capture scripts are retained here. Both scripts exited 0 and
passed their existing physical success gates. The recording scripts introduce no product text.

## Capture instrumentation correction

The first attempt used the old recording script's default version-1 runtime fingerprint for a
version-2 policy. It also projected yaw/displacement through the full body basis. Its raw JSON
and log are retained as `initial-stale-fingerprint.*`; that fingerprint is not a policy match.
The script now passes the actual policy version and projects onto the horizontal command frame.
The replacement capture reports runtime fingerprint
`0a269bde27b83ce81d78c5fa745237ab960316f4660e6714b624b0a85c6361ae`, matching the frozen policy.
Only measurement code changes. Minimum height, minimum uprightness and stopped uprightness
match at full printed precision across both captures; reported projection-dependent values differ.

These are two recorded episodes. They do not replace the [held-out/restart evaluation](../bounded_feedback_2026-09-22/README.md)
or [clean exported-browser gates](../browser_clean_6470757_2026-09-22/README.md), and do not remove
the two known native falls or the unfinished construction-kit locomotion requirement.
