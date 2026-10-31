# Cloud review evidence, 2026-10-31

Source: main `4eb059f`, r3 `578ca79` (`feat/own-build-r3-20261022`). Linux x86_64 cloud VM,
4 vCPU, Godot `4.7.2.stable.official.ed1daf0bf` (SHA-256 checked by `install_godot.py`),
Python 3.13.18 (3.14.7 unavailable here), Xvfb + Mesa llvmpipe. Review report:
[cloud-20261031-ssok-review](../../cloud-20261031-ssok-review.md).

- `verify-main-SUMMARY.md`: full `verify.py` on main, 72 checks / 1 failure (`motion_lab_ui_check`).
- `verify-r3-SUMMARY.md`: full `verify.py` on r3, 115 checks / 5 failures. Both full runs ran
  concurrently with each other and with review scripts, so timing-sensitive checks were loaded.
- `rerun-r3-SUMMARY.md`: serial rerun of r3's failures plus `motion_lab_ui_check`, 6 / 4.
- `motion_lab_ui_check` serial repeats (`--match '^motion_lab_ui_check$'`):
  main PASS, PASS, FAIL(125.0 s); r3 PASS, PASS, PASS. Earlier: main full FAIL / serial PASS,
  r3 full PASS / serial FAIL. Intermittent on both branches, therefore not an r3 regression.
- `review-*.log`: output of each `tests/review/*.gd` script on r3, backtrace lines removed.
- `web-*.log`: r3 Web export(`build.py --platforms Web`, exit 0) 후 Chromium `/opt/pw-browsers/chromium` 게이트 끝부분.
  smoke/authoring/physics PASS, learning FAIL. `web-browser_learning-relaxed.log`는 두 단언만 출력으로 바꾼
  임시 사본(커밋 안 함)의 결과로, 세 답지가 Web에서 클리어된 값을 보여요.
