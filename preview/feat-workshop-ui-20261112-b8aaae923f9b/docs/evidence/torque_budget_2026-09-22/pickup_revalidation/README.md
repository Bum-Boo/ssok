# Pickup after the whole-step torque correction

The default lift duration changes from 2.5 to 4.0 seconds within the existing 2–4 second policy
range. It changes the commanded trajectory duration, not elapsed-time measurement, motor caps,
collision geometry, gravity or acceptance thresholds. Existing explicit saved policies retain
their values. Godot program/policy defaults and the Python proposal service remain synchronized.

The original complete kit regression reproduces the 2.5-second failure: 275 checks, two failures
in the x=-5 mm / z=-10 mm offset episode. A 4.0-second lift passes all 277 checks, including
bilateral physical contact, at least 25 cm lift / one-second hold, uprightness, release under
gravity, simultaneous isolated worlds and reversed graph ordering. Base lift is 0.477 m;
minimum uprightness 0.994. The additional checks come from the longer evaluated trajectory.

Independent fresh-process diagnostics test three durations across five positions. All five
4.0-second cases pass (0.475–0.478 m lift; minimum uprightness at least 0.9847). The 3.25-second
offset case falls despite that duration passing the original complete regression. Conversely,
all five fresh 2.5-second cases pass even though the original allocation/execution sequence
fails. These differences expose sensitivity to initial solver conditions; one successful
fresh episode is not a replacement for the failing original regression. All outcomes and
15-frame motor/pose traces are retained.

After applying the synchronized default, 12 integration suites pass, recorded under `integration/`:
kit physics, legacy and modular pickup, reversed links, main-app pickup for both morphologies,
parallel trials, both lab/bridge UIs, scenario storage, trial metrics and the Python service.
The kit topology helper still includes separately recorded fourteen-axis WIP; final clean
release verification remains required. No new user-facing text needs a language-pack entry.

This is specific corrected-runtime pickup evidence, not sustained kit walking or hardware
calibration. `manifest.json` identifies source hashes and the two completed Himmel jobs.
