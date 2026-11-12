extends SceneTree
## R640：验证「通关删档」这条链在这个引擎 / 这台机器上到底成不成立。
## 只写 `run_save_test.sav`（走 RunSave.set_test_mode），**不碰玩家真档**。
## 用法：godot --headless --path . --script res://tools/probe_r640_clear.gd

const RunSave = preload("res://scripts/run_save.gd")
const RunState = preload("res://scripts/run_state.gd")


func _init() -> void:
	RunSave.set_test_mode()
	RunSave.clear_save("probe-start")

	# ---- ① 造一份最小可读档并落盘 ----
	RunState.run_active = true
	RunState.run_finished = false
	RunState.deck_ids = [8002, 8002, 8003]
	RunState.map_cells = [{"id": 1, "type": "battle"}]
	RunState.current_layer = 3
	RunState.current_node_id = 19
	var ok1 := RunSave.save_run()
	print("[1] save_run=%s  exists=%s  has_save=%s"
			% [str(ok1), str(FileAccess.file_exists(RunSave.SAVE_PATH)), str(RunSave.has_save())])

	# ---- ② 通关：mark_run_won 删档 ----
	RunState.mark_run_won()
	var exists_after := FileAccess.file_exists(RunSave.SAVE_PATH)
	print("[2] mark_run_won → run_finished=%s  file_exists=%s  has_save=%s"
			% [str(RunState.run_finished), str(exists_after), str(RunSave.has_save())])

	# ---- ③ 残档体检：.tmp / .prev / .bad 有没有留下能被 _recover_tmp 捡回来的东西 ----
	for suf: String in [".tmp", ".prev", ".bad"]:
		var p: String = String(RunSave.SAVE_PATH) + suf
		print("    residual %s = %s" % [suf, str(FileAccess.file_exists(p))])

	# ---- ④ 关键漏洞：已收尾（run_finished=true）但 run_active 仍为真时还能不能写档 ----
	# 这正是 battle_scene 通关后到结算页之间那段窗口的真实状态。
	var ok2 := RunSave.save_run()
	var exists2 := FileAccess.file_exists(RunSave.SAVE_PATH)
	print("[3] 已收尾但仍 run_active → save_run=%s  file_exists=%s  has_save=%s"
			% [str(ok2), str(exists2), str(RunSave.has_save())])
	if exists2:
		var txt := FileAccess.get_file_as_string(RunSave.SAVE_PATH)
		var root: Variant = str_to_var(txt)
		var d: Dictionary = (root as Dictionary).get("d", {})
		print("    ↑ 这份档 run_finished=%s layer=%d node=%d"
				% [str(d.get("run_finished")), int(d.get("current_layer")), int(d.get("current_node_id"))])
		print("    标题页 has_save()=%s → 「继续游戏」按钮会亮" % str(RunSave.has_save()))
		print("    load_run() = %s（last_error=%s）"
				% [str(RunSave.load_run()), RunSave.last_error])

	# ---- ⑤ end_run（真收尾）之后必须彻底没有档 ----
	RunState.end_run()
	print("[4] end_run → file_exists=%s  has_save=%s"
			% [str(FileAccess.file_exists(RunSave.SAVE_PATH)), str(RunSave.has_save())])

	RunSave.clear_save("probe-end")
	print("PROBE DONE")
	quit()
