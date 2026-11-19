# -*- coding: utf-8 -*-
"""R819：往 test_engine.gd（CRLF）里补 _test_r819 并注册。"""
import io

PATH = "scripts/test_engine.gd"
raw = io.open(PATH, "rb").read()

# ① 注册
anchor = b"\t_test_r817()\r\n"
assert raw.count(anchor) == 1, "注册锚点不唯一"
if b"_test_r819()\r\n" not in raw:
    raw = raw.replace(anchor, anchor + b"\t_test_r819()\r\n", 1)

# ② 函数体
FUNC = '''


func _test_r819() -> void:
	## R819：占卜室「实际扣血」与四语代价行。
	## 三件事钉死：
	##   ① 代价只削上限（`lose_max_hp`），当前血只在新上限以下被钳；
	##   ② 幻象**进房就摇定并随存档** —— 「占卜 → 回标题 → 继续 → 重进」不能重摇；
	##   ③ 代价结果行 / 解读结果行走 i18n 模板，不再回落中文。
	print("-- R819 占卜室扣血与代价行")

	# ── ① 扣血语义（与 R727 同一条 `lose_max_hp`）──
	RunState.max_hp = 60
	RunState.hp = 60
	check(RunState.lose_max_hp(5) == 5 and RunState.max_hp == 55 and RunState.hp == 55,
			"R819 满血 60/60 占卜 → 55/55（上限 -5，当前血跟降）")
	RunState.max_hp = 55
	RunState.hp = 30
	check(RunState.lose_max_hp(5) == 5 and RunState.max_hp == 50 and RunState.hp == 30,
			"R819 残血 30/55 占卜 → 30/50（当前血一点都不掉）")
	RunState.max_hp = 6
	RunState.hp = 3
	check(RunState.lose_max_hp(5) == 5 and RunState.max_hp == 1 and RunState.hp == 1,
			"R819 上限 6 时占卜 → 1/1（至少留 1 点，当前血被钳到 1）")
	# 上限 5 时不该能占卜（按钮禁用）：函数本身也只给 4 点
	RunState.max_hp = 5
	RunState.hp = 5
	check(RunState.lose_max_hp(5) == 4 and RunState.max_hp == 1,
			"R819 上限 5 时最多只掉 4 点（按钮判据 max_hp <= 5 会禁用）")

	# ── ② 幻象编号随存档 ──
	RunState.max_hp = 50
	RunState.hp = 50
	RunState.divination_roll = 3
	var r819_snap: Dictionary = RunSave.snapshot()
	check(r819_snap.has("divination_roll") and int(r819_snap["divination_roll"]) == 3,
			"R819 snapshot 带 divination_roll")
	RunState.divination_roll = 0
	check(RunSave.apply(r819_snap) and RunState.divination_roll == 3,
			"R819 幻象编号读档往返（3 → 0 → apply → 3）")
	var r819_dirty: Dictionary = r819_snap.duplicate(true)
	r819_dirty["divination_roll"] = 9
	RunSave.apply(r819_dirty)
	check(RunState.divination_roll == 0, "R819 越界幻象编号（9）读档后归 0（不落进兜底分支）")
	r819_dirty.erase("divination_roll")
	RunSave.apply(r819_dirty)
	check(RunState.divination_roll == 0, "R819 老存档缺 divination_roll → 0（进房时补摇）")
	# 一局结束清零（换局不许沿用上一局的幻象）
	RunState.divination_roll = 2
	RunState.end_run()
	check(RunState.divination_roll == 0, "R819 一局结束 → 幻象编号清零")

	# ── ③ 源码锁 ──
	var ev_src := FileAccess.get_file_as_string("res://scripts/event_scene.gd")
	var save_src := FileAccess.get_file_as_string("res://scripts/run_save.gd")
	check_src(ev_src.contains("const DIVINATION_HP_COST := 5"),
			"R819 占卜代价常量仍是 5 点最大生命")
	check_src(ev_src.contains(
			"RunState.divination_roll = RunState.run_rng.randi_range(1, DIVINATION_KINDS)"),
			"R819 幻象摇定收在唯一一句（进房时）")
	var r819_pin := ev_src.find(
			"RunState.divination_roll = RunState.run_rng.randi_range(1, DIVINATION_KINDS)")
	check_src(r819_pin >= 0 and ev_src.find("RunSave.save_run()", r819_pin) > 0
			and ev_src.find("RunSave.save_run()", r819_pin) - r819_pin < 160,
			"R819 摇定之后立刻落盘（退出重进不能换一种幻象）")
	check_src(ev_src.count(
			"RunState.divination_roll = RunState.run_rng.randi_range(1, DIVINATION_KINDS)") == 1,
			"R819 只有进房那一处摇 —— 扣代价处只取不摇")
	check_src(ev_src.contains("_div_rolled = RunState.divination_roll"),
			"R819 扣代价时读的是存档里那一种幻象")
	check_src(ev_src.contains(
			"result_label.text = GameI18n.source(_div_result)"),
			"R819 解读结果行走 i18n 模板（带 %s 的卡名 / 道具名）")
	var r819_cost_line := ev_src.find(
			'"（占卜的代价：失去 %d 点最大生命 → %d / %d）"')
	check_src(r819_cost_line > 0
			and ev_src.rfind("GameI18n.source(", 0, r819_cost_line) > 0
			and r819_cost_line - ev_src.rfind("GameI18n.source(", 0, r819_cost_line) < 80,
			"R819 代价结果行包在 GameI18n.source() 里（含三个动态数值）")
	check_src(save_src.contains('"divination_roll": RunState.divination_roll'),
			"R819 存档写入 divination_roll")
	check_src(save_src.contains('d.get("divination_roll", 0)'),
			"R819 读档读 divination_roll（老档缺键兜 0）")

	# ── ④ 中文模板串必须与代码字面串逐字一致（模板匹配靠它）──
	var r819_ui: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://i18n/event_ui_zh_canonical.json"))
	var r819_row := ""
	if r819_ui is Dictionary:
		var r819_res: Variant = (r819_ui as Dictionary).get("results", {})
		if r819_res is Dictionary:
			var r819_div: Variant = (r819_res as Dictionary).get("divination", {})
			if r819_div is Dictionary:
				r819_row = str((r819_div as Dictionary).get("DIVINATION_COST_PAID", ""))
	check_src(r819_row == "（占卜的代价：失去 %d 点最大生命 → %d / %d）",
			"R819 中文模板与代码字面串逐字一致")
'''

block = FUNC.lstrip("\n").replace("\n", "\r\n")
if "func _test_r819()" not in raw.decode("utf-8", "ignore"):
    raw = raw.rstrip(b"\r\n") + b"\r\n\r\n\r\n" + block.encode("utf-8") + b"\r\n"

io.open(PATH, "wb").write(raw)
t = io.open(PATH, "rb").read()
print("crlf", t.count(b"\r\n"), "lf", t.count(b"\n"), "func", ("func _test_r819()" in t.decode("utf-8", "ignore")))
