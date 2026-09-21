# Recorded construction-kit pickup

`pickup.webm` is an actual Godot 4.7.2 GL Compatibility render: 1280 × 720,
30 frames/s, 10.00 seconds, normal playback speed. `pickup.gif` is a smaller
720 × 405 preview with 150 frames over the same 10 seconds (GIF delays are
quantized to centiseconds). `pickup.png` is its final
frame. No robot or cargo transforms are animated for the recording.

The controller uses the default seven-parameter pickup policy, 60 Hz
GodotPhysics3D, unchanged graph geometry and actuator torque limits. In this
recorded episode the box rose 47.7 cm, remained stably held for 1.0 second,
and torso uprightness stayed above 0.995. Both hands contacted the box before
the transient grasp constraints were created. See
[the recorded episode's measurements](../evidence/pickup-video.json).

The evaluated episode ends at 8.9 simulated seconds. The successful final
result is then retained for one second, as in the app's pickup lab; that last
still interval is not counted as an additional physical hold. Capture-only
sky reflections, fill lighting and camera framing make the original metal
parts visible; the graph, controller, policy and physics are unchanged.

## Reproduce the native recording

Godot's MovieWriter fixes its output size from the project viewport before
scripts start. Make a temporary project copy for the 1280 × 720 viewport:

```bash
recording_dir=$(mktemp -d)
rsync -a --exclude=.git --exclude=.godot --exclude=build --exclude=assets/blender ./ "$recording_dir/"
cat >> "$recording_dir/project.godot" <<'EOF'

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
EOF
godot --headless --path "$recording_dir" --editor --import --quit
godot --path "$recording_dir" --fixed-fps 30 --write-movie "$recording_dir/pickup.avi" --script tools/godot/capture_pickup.gd
ffmpeg -i "$recording_dir/pickup.avi" -an -c:v libvpx-vp9 -crf 28 -b:v 0 -deadline good -cpu-used 4 -row-mt 1 -threads 2 pickup.webm
```

The capture script exits unsuccessfully if the actual trial does not succeed.
It writes a PNG and the measured episode to `user://release_media/` and prints
the JSON result. The raw AVI and temporary frames are not repository assets.
The result is example-specific, not evidence of arbitrary robot control,
finger-friction grasping, stable running or real hardware transfer.
