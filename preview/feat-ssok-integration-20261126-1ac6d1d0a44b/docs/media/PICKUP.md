# Recorded construction-kit pickup

`pickup.webm` is an actual Godot 4.7.2 GL Compatibility render: 1152 × 648,
30 frames/s, 11.366 seconds, normal playback speed. `pickup.gif` is a smaller
720 × 405 preview with 171 frames over 11.4 seconds (GIF delays are quantized
to centiseconds). `pickup.png` is a separate 1280 × 720 final viewport capture.
No robot or cargo transforms are animated for the recording.

The controller uses the default seven-parameter pickup policy, 60 Hz
GodotPhysics3D, unchanged graph geometry and the corrected whole-step actuator torque budget. In this
recorded episode the box rose 47.7 cm, remained stably held for 1.0 second,
and torso uprightness stayed above 0.993. Both hands contacted the box before
the transient grasp constraints were created. See
[the recorded episode's measurements](../evidence/corrected_recordings_2026-09-22/pickup.json)
and [source/media hashes](../evidence/corrected_recordings_2026-09-22/provenance.json).

The four-second lift uses the current default policy. The evaluated episode ends at 10.2667
simulated seconds. The successful final
result is then retained for one second, as in the app's pickup lab; that last
still interval is not counted as an additional physical hold. Capture-only
sky reflections, fill lighting and camera framing make the original metal
parts visible; the graph, controller, policy and physics are unchanged.

## Reproduce the native recording

Godot's MovieWriter fixes its output size from the project viewport before
scripts start. Use the unmodified project viewport for the 1152 × 648 video:

```bash
mkdir -p build
touch build/.gdignore
godot --headless --path . --editor --import --quit
godot --path . --fixed-fps 30 --write-movie build/pickup.avi --script tools/godot/capture_pickup.gd
ffmpeg -i build/pickup.avi -an -c:v libvpx-vp9 -crf 28 -b:v 0 -deadline good -cpu-used 4 -row-mt 1 -threads 2 build/pickup.webm
```

The capture script exits unsuccessfully if the actual trial does not succeed.
It writes a PNG and the measured episode to `user://release_media/` and prints
the JSON result. The raw AVI and temporary frames are not repository assets.
The result is example-specific, not evidence of arbitrary robot control,
finger-friction grasping, stable running or real hardware transfer.

The previous recording and its earlier actuator model remain in Git history at `6470757`;
historical measurements remain unchanged in `docs/evidence/pickup-video.json`.
