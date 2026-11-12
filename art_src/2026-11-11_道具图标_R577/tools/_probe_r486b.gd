extends SceneTree
## R577 隔离探针：验证 R486b 逻辑本身；用独立存档路径，避开并行会话的 user:// 抢档。
func _initialize() -> void:
	RunSave.SAVE_PATH = "user://run_save_r577_probe.sav"
	RunSave.TRACE_FILE = "user://save_trace_r577_probe.log"
	var snap := RunSave.snapshot()
	snap["data_ver"] = RunSave.CONTENT_VERSION + 1
	RunSave.clear_save()
	print("A clear: exists=", FileAccess.file_exists(RunSave.SAVE_PATH))
	RunSave.probe_newer_save()
	print("B no-file probe: err=[", RunSave.last_error, "]")
	var w := RunSave.save_snapshot(snap)
	print("C save=", w, " exists=", FileAccess.file_exists(RunSave.SAVE_PATH))
	RunSave.probe_newer_save()
	print("D probe: kind=", RunSave.last_error_kind, " exists=", FileAccess.file_exists(RunSave.SAVE_PATH))
	print("E protects=", RunSave.protects_save(), " has_save=", RunSave.has_save(),
			" exists=", FileAccess.file_exists(RunSave.SAVE_PATH))
	RunSave.clear_save()
	quit()
