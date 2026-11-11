class_name BundledBipedMotion
extends LearnedBipedMotion

## The bundled example uses the same frozen policy and inference class as offline evaluation.
const POLICY_PATH: String = "res://assets/policies/yaw_biped_v2.json"
const HELP: String = "Learned forward gait: hold W or push the stick forward; release to stop. Reverse and turning are not supported."
const MISMATCH: String = "This learned gait needs its original assembly and physics settings. Reload the learned-biped example to restore them."


func _init() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
	if data is Dictionary:
		load_policy(data)
	_set_status(HELP)


func configure(hardware: RunMode, graph: ConnectionGraph) -> bool:
	var configured: bool = super.configure(hardware, graph)
	_set_status(HELP if configured else MISMATCH)
	return configured
