extends SceneTree
## 只读探针：整局统计口径实测（R630）
## 用户报障：「3 层胜利后只统计了三层的战斗和精英战斗」。
## 本探针回答四件事（不改任何数据文件，只读内存 + 打印）：
##   ① 换层（advance_layer）会不会把「整局累计」清掉；
##   ② 三级打完时 total_* 与「本层」battle_wins/elite_wins 各是多少；
##   ③ 记录页读的那份快照（RunRecord.snapshot）取的是哪一个；
##   ④ 存档（RunSave.snapshot/apply）有没有把整局累计带上。
## 跑法：Godot --headless --path . --script res://tools/probe_r630_stats.gd

func _p(tag: String) -> void:
	print("[%s] 本层 battle=%d elite=%d | 整局 battle=%d elite=%d | 伤害=%d"
		% [tag, RunState.battle_wins, RunState.elite_wins,
		RunState.total_battle_wins, RunState.total_elite_wins, RunState.total_damage])


func _step(layer_tag: String, battles: int, elites: int) -> void:
	for i in battles:
		RunState.on_battle_won("battle")
	for i in elites:
		RunState.on_battle_won("elite")
	_p(layer_tag)


func _init() -> void:
	print("==== R630 统计口径探针 ====")
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.default_id(), 20261112, "")
	RunState.run_active = true
	_step("L1 打 3 普通 + 1 精英", 3, 1)

	print("-- RunRecord.snapshot()（记录页显示的就是这份）--")
	var rec: Dictionary = RunRecord.snapshot()
	print("   snap.layer=%d snap.battles=%d snap.elites=%d"
		% [int(rec.get("layer", -1)), int(rec.get("battles", -1)), int(rec.get("elites", -1))])

	print("-- 换层到第 2 层 --")
	RunState.advance_layer(GameLayers.LAYER_TWO)
	_p("L2 刚进层")
	_step("L2 打 2 普通 + 1 精英", 2, 1)

	print("-- 换层到第 3 层 --")
	RunState.advance_layer(GameLayers.LAYER_THREE)
	_p("L3 刚进层")
	_step("L3 打 2 普通 + 1 精英", 2, 1)

	print("-- 通关那一刻应当写进结算快照的两个数 --")
	print("   期望：整局 battle=7 elite=3（3+2+2 / 1+1+1）")

	var rec2: Dictionary = RunRecord.snapshot()
	print("-- RunRecord.snapshot() 三级通关时 --")
	print("   snap.layer=%d snap.battles=%d snap.elites=%d  ← 记录页「战斗胜场」读这里"
		% [int(rec2.get("layer", -1)), int(rec2.get("battles", -1)), int(rec2.get("elites", -1))])

	var save: Dictionary = RunSave.snapshot()
	print("-- RunSave.snapshot() 字段体检 --")
	for k: String in ["total_battle_wins", "total_elite_wins", "total_damage"]:
		print("   %s in save: %s" % [k, save.has(k)])

	print("-- 模拟「关掉游戏再继续」：内存统计清空后 apply(存档) --")
	var keep_b: int = RunState.total_battle_wins
	var keep_e: int = RunState.total_elite_wins
	RunState.total_battle_wins = 0
	RunState.total_elite_wins = 0
	RunState.total_damage = 0
	RunSave.apply(save)
	print("   读档前整局 battle=%d elite=%d → 读档后 battle=%d elite=%d"
		% [keep_b, keep_e, RunState.total_battle_wins, RunState.total_elite_wins])

	print("==== 探针结束 ====")
	quit()
