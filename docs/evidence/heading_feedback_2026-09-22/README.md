# Selected heading feedback under the corrected motor budget

The frozen candidate passes **255/256 new native conditions with one fall**, compared with
**251/256 and five falls** for the previously bundled policy on the same conditions. The same
candidate passes twelve actual native-app flows and six Chromium WebAssembly flows. This is
an observed improvement in this cohort; it does not establish universal stability.

The integrated asset is `assets/policies/yaw_biped_heading_v2.json`. Its unchanged
[frozen policy](frozen-policy.json) has file SHA-256
`4a48d9c3616293559662181bd6c7bdc558e5a921ff2347f38d0e7894c0100a2d`.
The application canonical policy fingerprint is
`d16287993d2e93cb49a9ec7beaf9a443273164ed36c3e2df74afe6a1bfb4d72d`;
canonical policy fingerprinting and file hashing are distinct operations.

## Selection before new evaluation

The [preceding CEM run](../bounded_feedback_2026-09-22/README.md) learned three opposite-ankle
feedback weights with a frozen periodic carrier. Four reproduced baseline episodes and a
[24-episode counterfactual comparison](counterfactuals/results.json) motivated replacing one feedback component at a time.
Its [predeclared inputs and raw results](counterfactuals/raw.zip) are development evidence.
The three variants were then compared on **128 already observed development conditions**:

| Component restored from the earlier learned policy | Passes | Falls |
|---|---:|---:|
| Lateral position | 123/128 | 4 |
| Lateral velocity | 124/128 | 4 |
| Heading | 128/128 | 0 |

These are selection results, not held-out results. Only the heading variant was selected.
It changes the tied ankle heading coefficient from 0.02755020573071411 to 0.06710958619117571
(and its opposite sign), retaining the new position and velocity coefficients. This is
**post-training coefficient selection/recombination, not a new CEM training run**. The original
training provenance and the later selection are separate fields in the policy. No paid API was used.
[The complete development outcomes](selection/results.json), [plan](selection/plan.json) and
[unaltered raw inputs, logs and runner](selection/raw.zip) retain the rejected variants.

Graph `c1920876e4044891aef8a9db6dafc91f665711f0070e3ed590066762a2b024d7` and runtime
`0a269bde27b83ce81d78c5fa745237ab960316f4660e6714b624b0a85c6361ae` are unchanged. This is the same
v2 observation/inference contract, 60 Hz physics, 30 Hz inference and corrected whole-step
0.25 N·m motor model. No body force, gravity/collision change or success-gate relaxation is used.

## Frozen paired comparison

The candidate was fixed before generating 128 fresh and 128 restart conditions using Python
Random seed 202609221638 and disjoint episode ranges 990100000–990100127 and 990200000–990200127.
Settling spans 0–300 nominal frames, restart warmup/pause 1–300, and initial velocity noise is
±0.004 m/s. Each episode starts a fresh exact Godot 4.7.2 process. Four retained baseline
episodes match every original numerical output before the comparison begins.

| Policy | Fresh | Restart | Total | Falls |
|---|---:|---:|---:|---:|
| Previously bundled corrected-model policy | 127/128 | 124/128 | 251/256 | 5 |
| Selected heading candidate | 127/128 | 128/128 | 255/256 | 1 |

Five reference failures improve, one reference success regresses and 250 cases pass under both.
This is 256 paired conditions / 512 episodes, not 512 independent conditions. All passes satisfy
the unchanged 12-second, command-relative 0.30 m forward / 0.10 m lateral / 30-degree gate,
plus minimum uprightness 0.85, minimum height 0.09 m, both soles clearing 0.5 mm and no fall.

**The remaining candidate failure is fresh seed 990100126**, after a 1.6-second settle. It falls
after 6.8 seconds (minimum uprightness 0.446221, height 0.080450 m); the reference passes this case.
It is neither removed nor rerun to obtain a favourable result. No tuning follows this evaluation.
Any later tuning using these cases must relabel them as development data.

The original plan stores integer draws as seconds; the existing evaluator uses
`int(seconds * 60)`. Nine case/field entries truncate by one frame through floating point:
seven settling values and two restart pauses. Both policies receive identical encoded timings.
The exact entries are retained in [the independent plan audit](frozen/independent-plan-review.json);
the timings were not changed retrospectively. [All outcomes](frozen/results.json),
[paired comparison](frozen/paired-comparison.json), [original plan](frozen/plan.json) and
[raw episode inputs, outputs, logs and runner](frozen/raw.zip) preserve the complete evidence.

## Actual application and Web

The actual native `main.tscn` application passes all twelve original checks: delays of
0, 1, 60, 121, 180 and 257 frames, each fresh and after a 180-frame walk / 60-frame pause.
Each case passes 737 assertions for real W input, walking, visibility, upright release,
graph preservation, edit framing and incompatible-assembly rejection. The original camera and
viewport suites pass separately, including 62,660 viewport assertions. Native-app forward travel
is 0.40961–0.43800 m; maximum absolute lateral travel is 0.05779 m. The 12 walking checks do not
themselves certify ray picking or foot air time. [Native summary](native/summary.json) and
[all native logs and source audits](native/raw.zip) retain that distinction.

The isolated Web export uses committed base `389f817` plus this candidate and the previously
retained read-only multi-episode observer. Observer off/on pairs give identical full-precision
native trajectories for both fresh and restart flows. Six browser cases pass **123 assertions**,
with exactly 720 walking intervals and 90 released-command intervals. Both collision soles clear
0.5 mm in every case; startup and console logs contain no engine/browser errors.

| Browser case | Forward (m) | Lateral (m) | Yaw (degrees) |
|---|---:|---:|---:|
| fresh-60 | 0.415939 | 0.018503 | -2.6441 |
| fresh-90 | 0.427689 | 0.019440 | -2.3430 |
| fresh-150 | 0.428792 | 0.023028 | 5.8793 |
| restart-21-18 | 0.431642 | 0.015770 | 4.5166 |
| restart-120-60 | 0.418622 | 0.008092 | 8.4129 |
| restart-222-180 | 0.424627 | 0.030166 | -6.6769 |

Names identify polling thresholds; the actual observed frames are retained in
[browser results](web/browser/results.json). Minimum walking uprightness is 0.961239 and minimum
stopped uprightness is 0.999811. All six final screenshots were inspected: the upright robot and
its board remain visible between the panels. [Web export hashes](web/web-payload.json),
[source identities](web/source-sha256.json), [observer parity](web/native-parity.json),
[independent recomputation](web/independent-audit.json) and [complete raw artifacts](web/raw.zip)
bind these results to the candidate. This is an isolated candidate export, not a clean release.

## Reproduction and integration boundary

Use the pinned engine and import the project before reproducing the encoded cohort:

```sh
godot --headless --path . --editor --import --quit
python3 -m tools.rl_lab.evaluate_feedback --godot godot \
  --policy docs/evidence/heading_feedback_2026-09-22/frozen-policy.json \
  --cases docs/evidence/heading_feedback_2026-09-22/cases.json \
  --reference assets/policies/yaw_biped_bounded_v2.json \
  --workers 4 --out build/heading-feedback-reproduction.json
```

`cases.json` copies the original encoded conditions without resampling. The existing helper's
summary uses its deployment gate; recompute the stricter sole-clearance gate above from its
per-episode results when comparing this report. Exact historical reproduction uses commit
`389f817` and the source manifest; the archived original runner additionally checks source and
four-episode parity and retains every subprocess log. Its machine-specific paths describe that
run and are not required by the portable command above.

[The manifest](manifest.json) records all source jobs, file identities and retained artifact hashes.
Each managed job completed with exit 0, was fetched and reviewed, and released its resources.
The previous policy and all of its failures remain preserved. Clean integrated CI/export verification,
current-policy media and final public delivery remain separate gates after this integration.
No UI wording or locale files change: the existing forward-only scope remains explicit.
