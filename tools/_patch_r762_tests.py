# -*- coding: utf-8 -*-
"""R762 回归：CRLF 原样回写，锚点必须各唯一。"""
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "scripts" / "test_engine.gd"
raw = p.read_bytes()
assert b"\r\n" in raw
call_anchor = b"\t_test_r761()\r\n"
assert raw.count(call_anchor) == 1
raw = raw.replace(call_anchor, b"\t_test_r761()\r\n\t_test_r762()\r\n", 1)

block = r'''

# ================= R762：开始游戏 → 标准 / 每日挑战 =================
func _test_r762() -> void:
	DailyChallenge.set_test_mode()
	var d0 := "2026-11-16"
	var d1 := "2027-02-28"
	var c0 := DailyChallenge.config_for_date(d0)
	var c1 := DailyChallenge.config_for_date(d1)
	check(DailyChallenge.valid_date(d0) and DailyChallenge.valid_date("2028-02-29")
			and not DailyChallenge.valid_date("2027-02-29"),
			"R762 日期：合法日历日才接受（含闰年）")
	check(c0 == DailyChallenge.config_for_date(d0)
			and int(c0.get("seed", 0)) != int(c1.get("seed", 0)),
			"R762 根种子：同日确定、异日不同，不依赖上一局 run_seed")
	check(PlayerClass.ids().has(str(c0.get("class", "")))
			and int(c0.get("difficulty", -1)) == DailyChallenge.FIXED_DIFFICULTY
			and c0.get("deck", []) == PlayerClass.start_deck_ids(str(c0.get("class", ""))),
			"R762 固定配置：可见职业轮换 / 难度 2 / 标准初始 13 张，隐藏职业不入池")
	var r762_rng_state: int = RunState.run_rng.state
	DailyChallenge.config_for_date(d0)
	check(RunState.run_rng.state == r762_rng_state,
			"R762 配置计算不消耗 run_rng（跑图随机链不被每日入口推歪）")
	check(DailyChallenge.begin_attempt(c0) and not DailyChallenge.begin_attempt(c0)
			and DailyChallenge.begin_attempt(c1),
			"R762 一天一次：同日第二次拒绝，次日可开；续档不经过此入口")
	var r762_entry := {
		"daily_date": d0, "daily_rules": DailyChallenge.RULES_VERSION,
		"seed": c0["seed"], "class": c0["class"], "difficulty": c0["difficulty"],
		"result": "win", "layer": 3, "battles": 8, "elites": 2,
		"hp": 17, "gold": 90, "secs": 600,
	}
	DailyChallenge.record_result(r762_entry)
	var r762_saved := DailyChallenge.attempt_for(d0)
	check(str(r762_saved.get("result", "")) == "win"
			and int(r762_saved.get("score", 0)) == DailyChallenge.score_of(r762_entry)
			and int(r762_saved.get("score", 0)) > 10000,
			"R762 成绩：结算落本地，分数由进度 / 胜负 / 血量 / 金币确定")
	check(DailyChallenge.local_scores().size() == 1
			and str(DailyChallenge.local_scores()[0].get("date", "")) == d0,
			"R762 本地榜：只收已结算局，进行中那局不占名次")
	check(DailyChallenge.leaderboard_name(d0) == "DAILY_20261116_V1",
			"R762 Steam 榜名：每天 + 规则版本各一张")

	# 发布版新档的难度上限通常是 0；每日固定 2 必须绕过这一道账号差异。
	GameBuild.set_test_release(1)
	RunState.start_run([], GameLayers.LAYER_DEFAULT, str(c0["class"]), 0, "", c0)
	check(RunState.run_seed == int(c0["seed"]) and RunState.daily_date == d0
			and RunState.daily_rules == DailyChallenge.RULES_VERSION
			and RunState.difficulty == DailyChallenge.FIXED_DIFFICULTY,
			"R762 发布版：固定难度不被解锁上限钳回 0，根种子与规则入 RunState")
	var r762_snap := RunSave.snapshot()
	RunState.daily_date = ""
	RunState.daily_rules = 0
	RunSave.apply(r762_snap)
	check(RunState.daily_date == d0 and RunState.daily_rules == DailyChallenge.RULES_VERSION,
			"R762 续档：daily_date / rules 随 snapshot → apply 往返")
	RunRecord.begin_run(str(c0["class"]))
	RunRecord.finish("lose", true)
	var r762_records := RunRecord.list_records()
	check(not r762_records.is_empty()
			and str(r762_records[-1].get("daily_date", "")) == d0
			and int(r762_records[-1].get("daily_rules", 0)) == DailyChallenge.RULES_VERSION,
			"R762 RunRecord：终局记录带 daily 标记（标准老记录仍可缺省）")
	GameBuild.set_test_release(-1)
	RunState.end_run()
	RunRecord.clear_all()
	DailyChallenge.set_test_mode()

	var r762_title := FileAccess.get_file_as_string("res://scripts/title_scene.gd")
	var r762_lb := FileAccess.get_file_as_string("res://scripts/daily_leaderboard.gd")
	check_src(r762_title.contains("SceneFx.goto(\"res://scenes/mode_select.tscn\")")
			and r762_lb.contains("findOrCreateLeaderboard")
			and r762_lb.contains("uploadLeaderboardScore")
			and r762_lb.contains("downloadLeaderboardEntries")
			and r762_lb.contains("true, _details, _handle"),
			"R762 接线锁：开始游戏进模式选择；Steam 建榜 / keep-best 上传 / 读取前十齐全")
'''
raw += block.replace("\n", "\r\n").encode("utf-8")
p.write_bytes(raw)
print("OK", len(raw), "bytes")
