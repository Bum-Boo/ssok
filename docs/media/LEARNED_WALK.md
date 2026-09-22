# Recorded learned walking in the workshop

> This movie depicts the preceding `yaw_biped_bounded_v2.json` policy at `6470757`. The current
> selected heading policy has [separate validation](../evidence/heading_feedback_2026-09-22/README.md);
> a new current-policy capture is pending. The measurements below remain historical and unchanged.

`learned-walk.mp4` shows the actual Godot 4.7.2 GL Compatibility application at **1152 × 648**,
30 frames/s and 14.566667 seconds, at normal playback speed. `learned-walk.gif` is a 960 × 540,
10 frames/s preview lasting 14.6 seconds because GIF delays are quantized. The separate
`learned-walk.png` still is 1600 × 900; it is not the movie's resolution.

The capture script opens `main.tscn`, selects the learned-biped starter, enables Run mode and
sends the same W input events as the keyboard. It settles for 60 physics intervals, holds W
for 720 intervals (12 seconds), then releases it for 90 intervals (1.5 seconds). Physics stays
at 60 Hz while rendering runs at 30 Hz. The normal workshop camera follows horizontal body
travel; the robot remains visible at the beginning, middle and end of the recording.

The recorded trajectory travels 0.418373 m forward with -0.008129 m lateral displacement and
-10.413° yaw. Minimum uprightness is 0.963639 and minimum height above the floor is 0.129155 m;
uprightness after stopping is 0.999846. The preceding corrected-budget version 2 feedback policy and the corrected
whole-step 0.25 N·m actuator budget run in the application. [Measurements, script identity and media hashes](../evidence/corrected_recordings_2026-09-22/README.md)
bind this episode to source `6470757`. Native recording and [clean browser physics evidence](../evidence/browser_clean_6470757_2026-09-22/README.md)
are distinct checks; neither replaces held-out or restart evaluation.

## Reproduce

Run from the repository root with the pinned engine and a working GL display:

```sh
mkdir -p build
touch build/.gdignore
godot --headless --path . --editor --import --quit
godot --path . --rendering-method gl_compatibility \
  --write-movie build/learned-app.avi --fixed-fps 30 \
  --script tools/godot/capture_learned_app.gd
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate -show_entries format=duration \
  -of json build/learned-app.avi
ffmpeg -i build/learned-app.avi -an -c:v libx264 -crf 20 -pix_fmt yuv420p \
  -movflags +faststart build/learned-walk.mp4
```

MovieWriter fixes the movie output to the project's 1152 × 648 viewport before the script starts.
The unchanged capture script subsequently sets the live window to 1600 × 900, so its separate
`user://release_media/learned-app.png` screenshot has that larger size. The MP4/GIF were encoded
from the corrected `learned-app-v2.avi` recording. The script explicitly passes policy version 2
to the runtime fingerprint and measures heading/displacement in a horizontal command frame.
Verify dimensions with ffprobe rather than inferring them from a filename.

The script writes `user://release_media/learned-app.metrics.json`, prints `LEARNED_RECORDING` with
the measurements and exits unsuccessfully if the walking/standing gates fail. Raw AVI files are
local intermediates; compressed public media and hashes are preserved in this repository.

The earlier policy/actuator recording remains in Git history at `6470757`; its unchanged
historical metrics remain in `docs/evidence/learned-app-recording.json`.
