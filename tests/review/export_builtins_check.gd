extends SceneTree


func _initialize() -> void:
	var out: Array = []
	for stage: Dictionary in StageCatalog.builtins():
		out.append(stage)
	var file: FileAccess = FileAccess.open(OS.get_environment("REVIEW_OUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "", true, true))
	file.close()
	print("exported ", out.size())
	quit(0)
