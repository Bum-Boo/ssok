# M2e B20 measurements and rollback — 2026-11-05

**NOT ADOPTED.** Application, presets, generator/resource, wall exception and contract documents
are restored to `1a86a5355221a1a66d7261920c8492dc6a891776`. Only measurements/documentation remain.
Windows native Godot 4.7.2 / GL Compatibility / GodotPhysics3D / 60 Hz; Python 3.13.
See the M2e section of [work M2](../../WORK_SUMMARY_M2.md).

- [Candidate hashes/commands](source.json), [restored source hashes](restored-source.json), [unadopted patch](not-adopted-b20.patch), [generator output](generator.log).
- Candidate target: **29 PASS / 1 FAIL**, exit 1. [Console](target-console.log), [JSON](target-results.json), [summary](target-summary.md), [runtime](target-kit-runtime.log), [camera rest](target-camera-rest.log).
- Candidate full: **117 PASS / 4 FAIL**, exit 1, inherited `PYTHONUTF8=1`. [Console](full-console.log), [JSON](full-results.json), [summary](full-summary.md), [runtime](full-kit_robot_runtime_check.log), [camera rest](full-agent_camera_rest_check.log).
- New failure: [release documentation UTF8 decoding](full-tests-test_release_documents.py.log). The target SUMMARY was archived as CP949, not UTF8: byte 0xa1 at offset 63. [Original bytes](target-summary-original-cp949.zip) are retained; the Markdown copy is now UTF8/LF. This evidence-archiving mistake does not establish a B20 physics defect. The brief's stop condition was nevertheless applied.
- Existing dependency failures: [mcp](full-tests-motion_mcp_check.py.log), [mujoco](full-tools-rl_lab-test_rl_lab.py.log).
- Candidate [import](full-import.log) and [scene load](full-scene-load.log) pass.

All three candidate kit answers succeed. Camera drift is 0.00272093876265 m against unchanged
0.002 m; Linux baseline 0.00277 m is supplied by the brief, not re-run here.
The exact candidate kit-car blob matches M2d `0220dbe0053dfd655cb1fbd138bcf922426d6e55`;
independent gpt-6.1-sol static review found no code/explicit scope violation before verification.
Candidate results are not current restored-source passing claims. No restored full run, Web,
user assembly reproduction, integration, push or deployment. A later authorized adoption can
reuse the recorded patch and fix evidence encoding before running the gates again.

After rollback and evidence UTF8 correction, `python -m unittest tests.test_release_documents -v` passes 1 test, exit0 ([raw output](restored-document-check.log)). This does not replace the failed candidate full result. Documentation write/check and10 documentation tool tests pass. Final independent review confirms rollback and factual measurements.
