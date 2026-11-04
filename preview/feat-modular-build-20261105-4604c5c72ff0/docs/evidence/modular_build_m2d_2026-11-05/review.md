# Independent Astra review (2026-11-05)

Source: b7f417620624 + M2d preset/resource/generator/test/diagnostic working tree.
Read-only gpt-6-astra reviewed the diff and actual GL kit-oblique.png / kit-side.png.
DONE_WITH_CONCERNS: no confirmed blocking issue in reviewed scope; parent owns target/full results.

- Caster lead67.5mm and height-21mm meet legacy ?3mm; track164mm matches. Separate caster retained.
- Plate/driver/board graph links and wheel65 retained. Final bracket base_4_back has1.5mm minimum
  overlap with board (below existing2mm placement threshold); driver touches board at its x face.
- Retracted caster beam keeps sonar mesh foremost. Captures show assembly pose, not running pose.
- A5 wall FAIL; B15 diagnostic legacy+kit wall/finish PASS; runtime101/0 all3 PASS; B20 runtime94/0.
- Chassis220.12g is26.5% heavier than174g. Chassis COM relative axle: kit(32.23,16.69,-10.26)mm,
  legacy(19.62,-5.70,0)mm. Do not claim identical mass/COM.
- Sensor mesh maxX54.1mm equals robot maxX; original sensing faceX52.8mm remains1.3mm inside.
  Do not claim exactly equal sensing distance and physical separation.
- Full regression, learner placement reproduction and Web were not independently run.
- An initial4mm board-overlap warning based on historical probe.log was retracted after current
  base_4_back source and capture timestamps were checked. Only final source applies above.

No edits, engine processes or persistent resources were created by this reviewer.

## Final fallback review

Astra independently reviewed the explicit fallback after B15/B20 camera-rest rejection.
It found that changing StageDefinition.create's graph would also change scene, outside the brief.
Parent corrected this: construct original kit scene, replace only wall.author_solution,
then assert both scene-kit and answer-legacy fingerprints in parts_tray_check.
No other concrete blocker was reported. Final target/full evidence is the parent's observed output;
Astra did not execute engines or claim those checks passed. Final kit geometry/resources are restored.
