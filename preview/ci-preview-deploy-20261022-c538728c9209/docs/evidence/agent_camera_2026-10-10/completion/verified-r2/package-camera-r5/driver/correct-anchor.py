from pathlib import Path
import hashlib,json
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/package-camera-r5'
review=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/package-camera-r5/astra-initial.json')
evidence=json.loads(review.read_text());correction=evidence['import_confirmation_anchor_correction']
assert evidence['actual_model']=='gpt-6-astra' and correction['OK_button_center']==[588,498]
layout=json.loads((out/'layout.json').read_text());assert layout['points']['project_confirm']==[810.0,484.0]
layout['points']['project_confirm']=correction['OK_button_center']
layout['correction']={'actual_image':str(out/'import-confirm.png'),'actual_image_sha256':hashlib.sha256((out/'import-confirm.png').read_bytes()).hexdigest(),'astra_result_sha256':hashlib.sha256(review.read_bytes()).hexdigest(),'old_anchor':correction['supplied_prior_anchor'],'new_anchor':correction['OK_button_center'],'scope':'Driver anchor only. Unchanged application.'}
assert not (out/'layout-native-corrected.json').exists()
(out/'layout-native-corrected.json').write_text(json.dumps(layout,indent=2)+'\n')
print(json.dumps(layout['correction']))
