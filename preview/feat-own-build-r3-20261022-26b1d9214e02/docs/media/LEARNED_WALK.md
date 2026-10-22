# Recorded learned walking in the workshop

`learned-walk.mp4` shows the actual Godot 4.7.2 GL Compatibility application at **1152 × 648**,
30 frames/s and 14.566667 seconds, at normal playback speed. `learned-walk.gif` is a 960 × 540,
10 frames/s preview lasting 14.6 seconds because GIF delays are quantized. The separate
`learned-walk.png` still is 1600 × 900; it is not the movie's resolution.

The capture script opens `main.tscn`, selects the learned-biped starter, enables Run mode and
sends the same W input events as the keyboard. It settles for 60 physics intervals, holds W
for 720 intervals (12 seconds), then releases it for 90 intervals (1.5 seconds). Physics stays
at 60 Hz while rendering runs at 30 Hz. The normal workshop camera follows horizontal body
travel; the robot remains visible at the beginning, middle and end of the recording.

The recorded trajectory travels 0.420723 m forward with 0.025667 m lateral displacement and
10.386839° yaw. Minimum uprightness is 0.965398 and minimum height above the floor is 0.128831 m;
uprightness after stopping is 0.999788. The selected version 2 heading-feedback policy and the corrected
whole-step 0.25 N·m actuator budget run in the application. [Measurements, script identity and media hashes](../evidence/heading_recording_2026-09-22/README.md)
bind this episode to committed source `d986f6a`. Native recording and [candidate browser physics evidence](../evidence/heading_feedback_2026-09-22/README.md)
are distinct checks; neither replaces held-out or restart evaluation or final clean export verification.

## Reproduce

Run from the repository root with the pinned engine and a working GL display:

```sh
mkdir -p build
touch build/.gdignore
godot --headless --path . --editor --import --quit
godot --path . --resolution 1600x940 --rendering-method gl_compatibility \
  --write-movie build/learned-app.avi --fixed-fps 30 \
  --script tools/godot/capture_learned_app.gd
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate -show_entries format=duration \
  -of json build/learned-app.avi
ffmpeg -i build/learned-app.avi -an -c:v libx264 -crf 20 -pix_fmt yuv420p \
  -movflags +faststart build/learned-walk.mp4
```

MovieWriter uses the project's 1152 × 648 viewport. The capture script subsequently requests a
1600 × 900 live window. In the retained WSLg run, adding `--resolution 1600x940` at startup yields
a 1600 × 900 final still with complete footer text; omitting it yielded a 1600 × 940 still and a
cropped footer. This command-line request is not the movie resolution. Inspect the actual output
with ffprobe and review beginning/middle/end frames in your display environment.

The retained corrected framing and first attempt have exactly equal physical metrics. The script
passes policy version 2 to the runtime fingerprint and measures heading/displacement in a
horizontal command frame. The full source snapshot, both capture commands and the original
incorrect output-size expectation remain in the recording evidence.

The script writes `user://release_media/learned-app.metrics.json`, prints `LEARNED_RECORDING` with
the measurements and exits unsuccessfully if the walking/standing gates fail. Raw AVI files are
local intermediates; compressed public media and hashes are preserved in this repository.

The preceding corrected-budget movie remains in Git history at `d986f6a`, with unchanged
metrics in [the earlier recording report](../evidence/corrected_recordings_2026-09-22/README.md).
The still earlier old-actuator recording remains in Git history at `6470757` and
`docs/evidence/learned-app-recording.json`.
