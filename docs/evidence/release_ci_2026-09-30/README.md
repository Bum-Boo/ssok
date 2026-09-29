# CI evidence for the selected heading policy

The original [push run 35706168449](https://github.com/Bum-Boo/ssok/actions/runs/35706168449) and [PR run 35706172447](https://github.com/Bum-Boo/ssok/actions/runs/35706172447) completed successfully on 2026-09-22. Both used branch head `170417be0b3d1d44e46429dea950c84cf4580a71`; the PR checks used GitHub's synthetic merge `9fa296f86bf60b24cd5b5ed70b3ed6fd3edaa017`. This 2026-09-30 audit fetched their original verification, browser and release artifacts without rerunning CI.

Each run passed 59 native checks in Godot `4.7.2.stable.official.ed1daf0bf`, with zero recorded failures and zero `engine_error` results. Independent scans of the downloaded native, import, export and Linux startup logs found no `ERROR:` or `SCRIPT ERROR:` lines. Each produced clean Web and Linux archives and passed actual Chromium startup, project persistence/import/block editing and learned walking browser gates. Browser result error arrays and console error entries were empty. The four downloaded archive hashes matched their CI manifests. Pages and release asset publication jobs were skipped.

The bundled learned policy fingerprint was `d16287993d2e93cb49a9ec7beaf9a443273164ed36c3e2df74afe6a1bfb4d72d` in both browser runs. Its graph fingerprint was `c1920876e4044891aef8a9db6dafc91f665711f0070e3ed590066762a2b024d7` and runtime fingerprint was `0a269bde27b83ce81d78c5fa745237ab960316f4660e6714b624b0a85c6361ae`, matching the frozen expected values recorded before those runs. The committed frozen policy file SHA-256 is `4a48d9c3616293559662181bd6c7bdc558e5a921ff2347f38d0e7894c0100a2d`.

| Actual Web run | W duration | Forward | Lateral | Yaw | Foot-air frames | Stop upright |
|---|---:|---:|---:|---:|---|---:|
| Push | 720 frames / 12 s | 0.423212 m | 0.010663 m | +5.040° | 155 / 254 | 0.999961 |
| PR merge | 720 frames / 12 s | 0.432316 m | 0.019335 m | −1.927° | 165 / 272 | 0.999990 |

Both runs retained finite state, real sole clearance and upright posture through walking and the following 90-frame stop. Three representative push screenshots were inspected visually on 2026-09-30; a full four-language visual review remains open. The local original artifact audit and all six downloaded artifact trees are in `build/release-review/integrated-ci-audit-170417b/`. These results cover the committed branch and synthetic merge, excluding the preserved uncommitted Kit experiment.
