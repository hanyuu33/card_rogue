# -*- coding: utf-8 -*-
"""R819 第二轮：幻象改为「种子+层+节点」派生，重写 _test_r819。"""
import io

PATH = "scripts/test_engine.gd"
s = io.open(PATH, encoding="utf-8", newline="").read()

MARK = "func _test_r819() -> void:"
idx = s.find(MARK)
assert idx > 0, "找不到 R819 用例"
head = s[:idx].rstrip("\r\n")

FUNC = '''func _test_r819() -> void:
	## R819：占卜室「实际扣血」+ 幻象不可重摇 + 代价行的三语模板。
	##   ① 代价只削上限（`lose_max_hp`），当前血只在新上限以下被钳；
	##   ② 幻象由「种子 + 层 + 节点」派生 —— 回标题继续 / 重进本房都换不了同房间的结果；
	##   ③ 代价结果行与解读结果行走 i18n 模板，不再回落中文。
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

	# ── ② 幻象派生：同房间必然同一结果 ──
	var r819_one: int = RunState.divination_roll_for(20261119, 1, 7, 4)
	check(r819_one >= 1 and r819_one <= 4, "R819 幻象编号落在 1~4（实际 %d）" % r819_one)
	check(RunState.divination_roll_for(20261119, 1, 7, 4) == r819_one,
			"R819 同种子 / 同层 / 同节点 → 同一种幻象（回标题继续也换不了）")
	var r819_seen := {}
	for r819_i in 40:
		r819_seen[RunState.divination_roll_for(20261119, 1, r819_i, 4)] = true
	check(r819_seen.size() >= 3, "R819 幻象确实按房间变化（40 间出现 %d 种）" % r819_seen.size())
	var r819_moved := 0
	for r819_i in 20:
		var r819_a: int = RunState.divination_roll_for(20261119, 1, r819_i, 4)
		var r819_b: int = RunState.divination_roll_for(20261119, 2, r819_i, 4)
		if r819_a != r819_b:
			r819_moved += 1
	check(r819_moved > 0, "R819 换层后幻象重排（20 间里 %d 间变了）" % r819_moved)
	var r819_seed_b: int = RunState.divination_roll_for(7, 1, 7, 4)
	check(r819_seed_b >= 1 and r819_seed_b <= 4, "R819 换种子照样落在 1~4（实际 %d）" % r819_seed_b)

	# ── ③ 源码锁 ──
	var ev_src := FileAccess.get_file_as_string("res://scripts/event_scene.gd")
	check_src(ev_src.contains("const DIVINATION_HP_COST := 5"),
			"R819 占卜代价常量仍是 5 点最大生命")
	check_src(not ev_src.contains("_div_rolled = RunState.run_rng.randi_range"),
			"R819 占卜幻象不再走 run_rng（否则退出重进能重摇）")
	check_src(ev_src.count("RunState.divination_roll_for(") == 2,
			"R819 幻象派生只有两处：进房铺场 + 结算兜底")
	check_src(ev_src.contains("result_label.text = GameI18n.source(_div_result)"),
			"R819 解读结果行走 i18n 模板（带 %s 的卡名 / 道具名）")
	var r819_cost_line := ev_src.find(
			'"（占卜的代价：失去 %d 点最大生命 → %d / %d）"')
	var r819_src_at := ev_src.substr(0, maxi(0, r819_cost_line)).rfind("GameI18n.source(")
	check_src(r819_cost_line > 0 and r819_src_at > 0
			and r819_cost_line - r819_src_at < 80,
			"R819 代价结果行包在 GameI18n.source() 里（含三个动态数值）")

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

out = head + "\r\n\r\n\r\n" + FUNC.replace("\n", "\r\n")
io.open(PATH, "w", encoding="utf-8", newline="").write(out)
b = io.open(PATH, "rb").read()
print("crlf", b.count(b"\r\n"), "lf", b.count(b"\n"))
print("r819 funcs", b.count(b"func _test_r819"))
