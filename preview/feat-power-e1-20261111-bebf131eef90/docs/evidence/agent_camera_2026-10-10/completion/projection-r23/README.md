# Archived camera projection diagnosis r23

Source **afbc89968e1f11037dee10b12020baf5bf61b436**, issue32, 2026-10-11.
One pinned Godot4.7.2 headless numerical replay completed in1.026s/exit0.
This is a diagnosis of already captured images/poses, not a new physical,
rendered, AI or immutable packaged-app trial. No controller or target changed.

The wall/floor boundary is explained by camera geometry: nine archived640×480
PNGs agree with projection within0.968px. Independent Python pinhole arithmetic
agrees with Godot projection within0.0001px. The replay checks actual graph
chassis/body identity offset, wall mesh front0.340m, floor top0.050m, mount,
FOV60 and viewport640×480. Four r22 poses were actually assigned to the camera;
five r21 poses are inferred from same-tick frame_ready bodies and unchanged
source/mount (not a fresh assigned-pose measurement). SHA/tick matches verified.

| Camera target | Gap at nine observed poses, fixed orientation |
|---|---|
|24px|13.9919–14.2278cm|
|31px|14.4799–14.7269cm|
|38px|15.0005–15.2599cm|

At the latest r21 stock AI pose,31px corresponds to camera-time14.6625cm;
the actual image classified31px had camera-time14.7204cm and separately
measured stopped gap14.5838cm. At that pose14cm projects to21.56px.
Seven of nine observed poses put the smallest original image goal24px beyond
camera-time14cm. Two poses have a tiny geometric overlap. **This does not prove
the joint goal impossible** or predict final gap after Stop. Projection uses
continuous pixel coordinates; the classifier quantizes and has±1px uncertainty.

Making only the replay body orientation identity at the same body origin changes
the projected strip by6.19–11.02px. This counterfactual includes rotation of the
mount and camera height; it is not a physical pose correction, successful
controller, isolated pitch effect or fresh causal experiment. It supports
accounting for pose when calibrating the demonstration.

Ranked predictions were written in the existing project plan before replay.
The observed-pose calibration hypothesis is supported; a large measurement
discrepancy was not found. Next distinguish a user-approved calibrated goal
from further control work. Existing12–20px proposal remains unadopted/unrun;
even plausible geometry would require separate actual AI/physics verification.

[Numerical summary](summary.json), [independent arithmetic](arithmetic-audit.json),
[engine projection](projection.json), [input identities](input.json),
[command/receipt](receipt.json), [nine copied raw artifacts](copy-manifest.json).
Original images remain in [r21](../adaptive-ai-r21/README.md) and
[r22](../brake-integral-r22/README.md), whose existing Astra views are dated evidence.
No new visual judgment or Opus design work was required for this numerical audit.

Source426+operator7 unchanged; frozen24–38px AND stopped4–14cm unchanged.
Historical3layouts×3AI image9/9 physical0/9 and separate r21 jointFAIL are retained.
No UI/localization/provider/auth/request-limit change, model inference0.
Docs maintenance/tests only; app import/fullnative/Web/export/installer unrun.
Fable functional review/integration is recorded separately in the coordinator handoff.
Original precision, fresh account, native Mac, Arch raw/task16 CLI release, human
merge and exact-version publication remain open.
External helpers require the original checkout/private contract and original
artifacts; they are archived diagnostic tools, not product launchers.
