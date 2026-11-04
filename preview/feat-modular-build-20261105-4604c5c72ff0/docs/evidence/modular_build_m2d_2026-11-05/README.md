# M2d evidence ? Windows native, Godot 4.7.2

Source starts at b7f417620624befc34b93168661786441111969f. Current changed source hashes
are recorded in source.json; the final commit is reported by the task handoff.

- [A5](A5.json), [B15](B15.json), [B20](B20.json): same compact geometry, separate caster,
  same original code/physics/stage limits; actual solver clusters, geometry, COM and60Hz samples.
- [A5 runtime](a-shape-final-runtime.log), [B15 runtime](b15-final-runtime.log),
  [B20 runtime](b20-runtime.log): actual3stage outcomes, including A failures.
- [Oblique](kit-oblique.png), [side](kit-side.png): actual GL Compatibility assembly views.
  [Render log](capture.log), [independent review](review.md).
- source.json records commands, environment and relevant source SHA256; evidence hashes in hashes.json.

Neither mass is adopted:15g target camera-rest drift2.681mm FAIL;20g retained-resource
camera-rest probe drift2.721mm FAIL. See [rejected candidate patch](rejected-b15.patch),
[B15 target](b15-target-console.log), [B15 results](b15-target-results.json),
[20g probe](camera20-probe.gd.txt), [20g output](camera20-held.log).
B15 full was cooperatively interrupted after rejection; [partial console](b15-full-interrupted-console.log)
and [partial results](b15-full-interrupted-results.json) are not a completed full verification.

Final production preserves original kit geometry/caster5g. Only wall author graph uses legacy car,
with exact exception regression checks; flags/finish keep kit answers and tray remains unchanged.
Images, A/B JSON and compact geometry test patch document rejected morphology, not final production.
20g also passes3stages but is not the shipped mass. Chassis220.12g, not174g;
COM differs. Sensor mesh foremost is verified; original sensing face remains1.3mm inside mesh.
Full/target console and results are retained here after verification. No publishing or push.

- [Final target console](final-target-console.log), [JSON](final-target-results.json),
  [summary](final-target-summary.md):30/0, exit0.
- [Final kit/legacy answers](final-kit-runtime.log), [Stage UI flow](final-stage-own-build.log),
  [legacy car](final-legacy-car.log), [camera rest](final-legacy-camera-rest.log).
- [Candidate15g source hashes](b15-source.json); [interrupted scope-correction attempt](fallback-before-scene-fix-console.log).

- [Final full console](final-full-console.log), [JSON](final-full-results.json),
  [summary](final-full-summary.md):121 checks,119 PASS/2 missing-module FAIL, exit1.
- [mcp failure](final-tests-motion_mcp_check.py.log),
  [mujoco failure](final-tools-rl_lab-test_rl_lab.py.log): original output, not suppressed.
- Documentation write/check PASS; documentation tool tests10 PASS. No Web/export run.

Text artifacts use UTF-8/LF; console wording and failure output are preserved.
