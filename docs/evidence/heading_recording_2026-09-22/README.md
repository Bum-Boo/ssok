# Current learned-policy recording

The actual workshop at committed source `d986f6aa20e0adccd78413b5d107d41fd711bb2e` walks
**0.420723 m forward in 12 seconds**, with 0.025667 m lateral displacement and 10.386839 degrees
yaw. Minimum uprightness is 0.965398 and minimum height is 0.128831 m. After releasing W for
90 physics intervals, uprightness is 0.999788. [The unedited metrics](learned.json) identify
policy file SHA `4a48d9c3616293559662181bd6c7bdc558e5a921ff2347f38d0e7894c0100a2d` and the
unchanged graph/runtime fingerprints.

All 483 supplied application source files match their committed Git blobs, including the
unchanged capture script. The script opens the real main scene, selects the bundled robot,
waits 60 physics intervals, sends W for 720 intervals and releases it for 90. Physics is 60 Hz,
movie rendering 30 Hz and playback speed 1.0. No policy, physics, collision or trajectory changes
are made for the recording. The CPU-rendered Mesa llvmpipe capture completed under pinned Godot
4.7.2; its unsupported-VSync warning is retained with zero engine/script errors.

The MP4 is **1152 × 648**, 437 frames / 14.566667 seconds. The GIF is **960 × 540**, 146 frames /
14.6 seconds (GIF delay quantization). The separate still is **1600 × 900**. Beginning, middle
and ending frames at 1, 7 and 13.5 seconds were visually inspected: the complete robot, board
and bottom status text remain visible. [Media hashes, actual ffprobe output, source identities
and raw-AVI hashes](provenance.json) bind these files to the capture. Raw AVI intermediates stay
outside Git; compressed media are in `docs/media/`.

## Preserved framing correction

The first capture produced a 1600 × 940 live still and clipped the bottom status text in its
1152 × 648 movie. Its [metrics](first-window-crop/learned.json), [sample frame](first-window-crop/sample-1.png),
plan, source hashes, runner and logs remain preserved. The second command adds the window-size
request `--resolution 1600x940` and forces software GL; the application and capture script are
unchanged. The final live still measures 1600 × 900 and the footer is complete.

The original second plan expected a 1600 × 940 movie. **That expectation was incorrect:** the
MovieWriter retains the project's 1152 × 648 output. The measured dimensions above are authoritative;
the preserved plan is not rewritten to disguise its expectation. Every physical metric is exactly
equal between the two captures. Selection of the second recording fixes observed framing, not a
failed physical outcome. Both managed jobs completed with exit 0 and released their resources.

[Reproduction commands](../../media/LEARNED_WALK.md) reproduce the capture and encoding. This is one
recorded episode, separate from the [256-condition and actual-browser validation](../heading_feedback_2026-09-22/README.md).
The one remaining frozen-cohort fall is still a limitation. Clean integrated browser/export checks
and public delivery are separate gates. No user-facing application text or language pack changed.
