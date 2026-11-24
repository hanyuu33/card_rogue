# -*- coding: utf-8 -*-
"""R767 回归：注册 _test_r767() 并在文末追加实现。
test_engine.gd 是 CRLF，按字节改并保持行尾。"""
import sys

P = "scripts/test_engine.gd"
raw = open(P, "rb").read()
assert raw.count(b"\r\n") == raw.count(b"\n"), "期望纯 CRLF"

REG_OLD = b"\t_test_r766()\r\n"
REG_NEW = b"\t_test_r766()\r\n\t_test_r767()\r\n"
if raw.count(REG_OLD) != 1:
    print("注册锚点计数异常:", raw.count(REG_OLD))
    sys.exit(1)
if b"_test_r767" in raw:
    print("已经打过补丁，跳过")
    sys.exit(0)

BODY = r'''
func _test_r767() -> void:
	# R767 每日挑战：修饰池 / 随机卡组 / 效果落地。
	# 这三块都是「同一天所有人完全一样」的东西，所以每条断言都在**可复现**这一侧使劲。
	var r767_date := "2026-11-16"
	var r767_cfg := DailyChallenge.config_for_date(r767_date)

	# ① 规则版本：两个模块必须同步
	check(DailyChallenge.RULES_VERSION == DailyModifiers.RULES_VERSION,
			"R767 规则版本：DailyChallenge 与 DailyModifiers 同步（%d）" % DailyChallenge.RULES_VERSION)
	check(int(r767_cfg.get("rules", 0)) == DailyModifiers.RULES_VERSION,
			"R767 配置：rules 写进 config（%d）" % int(r767_cfg.get("rules", 0)))

	# ② 每天 4 条修饰 = 2 增益 + 2 减益，且每条都在池里、都带 fx
	var r767_mods: Array = r767_cfg.get("mods", [])
	check(r767_mods.size() == DailyModifiers.BUFF_COUNT + DailyModifiers.DEBUFF_COUNT,
			"R767 修饰：每天 4 条（实得 %d）" % r767_mods.size())
	var r767_buff := 0
	var r767_debuff := 0
	var r767_all_ok := true
	for k: Variant in r767_mods:
		var e := DailyModifiers.entry(str(k))
		if e.is_empty() or (e.get("fx", {}) as Dictionary).is_empty():
			r767_all_ok = false
			continue
		if str(e.get("kind", "")) == "buff":
			r767_buff += 1
		else:
			r767_debuff += 1
	check(r767_all_ok, "R767 修饰：每条都在池里且带 fx")
	check(r767_buff == DailyModifiers.BUFF_COUNT and r767_debuff == DailyModifiers.DEBUFF_COUNT,
			"R767 修饰：2 增益 + 2 减益（实得 %d / %d）" % [r767_buff, r767_debuff])

	# ③ 确定性：同日两次一致、连续几天基本不同（Steam 榜的前提）
	var r767_again: Array = DailyChallenge.config_for_date(r767_date).get("mods", [])
	check(str(r767_again) == str(r767_mods), "R767 确定性：同一天两次 config 完全一致")
	var r767_diff := 0
	for d: String in ["2026-11-17", "2026-11-18", "2026-11-19", "2026-11-20", "2026-11-21"]:
		if str(DailyChallenge.config_for_date(d).get("mods", [])) != str(r767_mods):
			r767_diff += 1
	check(r767_diff >= 3, "R767 确定性：连续 5 天至少 3 天修饰不同（实得 %d）" % r767_diff)

	# ④ 效果合并：`_mul` 后缀相乘，其余相加
	var r767_fx := DailyModifiers.fx_of(["STURDY", "ANEMIC"])
	check(absf(float(r767_fx.get("hp_mul", 0.0)) - 1.15 * 0.88) < 0.0001,
			"R767 合并：两条 _mul 相乘（实得 %.4f）" % float(r767_fx.get("hp_mul", 0.0)))
	var r767_fx2 := DailyModifiers.fx_of(["RICH", "POOR"])
	check(absf(float(r767_fx2.get("gold", 0.0)) - 30.0) < 0.0001,
			"R767 合并：金币修饰相加（实得 %.1f）" % float(r767_fx2.get("gold", 0.0)))

	# ⑤ 随机卡组：15 张 · 栅栏与攻击各至少 4 · 至少 1 张盟友 · 同日一致 · 无隐藏职业
	var r767_deck: Array = r767_cfg.get("deck", [])
	check(r767_deck.size() >= DailyModifiers.DECK_TOTAL,
			"R767 卡组：至少 %d 张（实得 %d）" % [DailyModifiers.DECK_TOTAL, r767_deck.size()])
	var r767_fence := 0
	var r767_atk := 0
	for v: Variant in r767_deck:
		if int(v) == DailyModifiers.FENCE_ID:
			r767_fence += 1
		elif int(v) == DailyModifiers.ATTACK_ID:
			r767_atk += 1
	check(r767_fence >= 4 and r767_atk >= 4,
			"R767 卡组：木栅栏 %d / 攻击 %d（各至少 4，保住开局下限）" % [r767_fence, r767_atk])
	var r767_repo := CardRepo.load_json()
	var r767_ally := 0
	var r767_hidden := 0
	for v: Variant in r767_deck:
		var c: CardData = r767_repo.get_card(int(v))
		if c == null:
			continue
		if c.kind == "盟友":
			r767_ally += 1
		if PlayerClass.is_hidden_class(c.card_class):
			r767_hidden += 1
	check(r767_ally >= 1, "R767 卡组：至少 1 张盟友（实得 %d）" % r767_ally)
	check(r767_hidden == 0, "R767 卡组：不含隐藏职业卡（实得 %d）" % r767_hidden)
	var r767_deck2: Array = DailyChallenge.config_for_date(r767_date).get("deck", [])
	check(str(r767_deck2) == str(r767_deck), "R767 卡组：同一天两次一致")

	# ⑥ 修饰真的作用到 RunState 那几个唯一取数口
	var r767_sv_fx: Dictionary = RunState.daily_fx.duplicate(true)
	var r767_sv_diff := RunState.difficulty
	RunState.set_difficulty(0)
	RunState.daily_fx = {}
	var r767_base_gold := RunState.start_gold()
	var r767_base_hp := RunState.max_hp_mul()
	var r767_base_energy := RunState.energy_per_turn()
	var r767_base_choco := RunState.chocolate_per_layer()
	var r767_base_rest := RunState.rest_pct()
	RunState.daily_fx = {"gold": 80, "hp_mul": 1.15, "energy": 1, "choco": 3,
			"rare_mul": 1.6, "rest": 0.15, "enemy_hp": 0.2, "enemy_power": 1}
	check(RunState.start_gold() == r767_base_gold + 80, "R767 生效：金币修饰叠进 start_gold()")
	check(absf(RunState.max_hp_mul() - r767_base_hp * 1.15) < 0.0001,
			"R767 生效：生命修饰乘进 max_hp_mul()")
	check(RunState.energy_per_turn() == r767_base_energy + 1,
			"R767 生效：费用修饰叠进 energy_per_turn()（%d）" % RunState.energy_per_turn())
	check(RunState.chocolate_per_layer() == r767_base_choco + 3,
			"R767 生效：巧克力修饰叠进 chocolate_per_layer()（%d）" % RunState.chocolate_per_layer())
	check(absf(RunState.rare_weight_mul() - 1.6) < 0.0001,
			"R767 生效：稀有度修饰乘进 rare_weight_mul()")
	check(absf(RunState.rest_pct() - r767_base_rest - 0.15) < 0.0001,
			"R767 生效：休息回复叠进 rest_pct()")
	check(absf(RunState.enemy_hp_bonus_pct() - 0.2) < 0.0001,
			"R767 生效：敌人生命叠进 enemy_hp_bonus_pct()")
	check(RunState.enemy_power_bonus() == 1,
			"R767 生效：敌人攻击叠进 enemy_power_bonus()")

	# ⑦ 下限保护：费用不许被减到 0；金币不许为负
	RunState.daily_fx = {"energy": -99, "gold": -9999}
	check(RunState.energy_per_turn() >= 1,
			"R767 下限：费用修饰不会把每回合费用抹到 0（%d）" % RunState.energy_per_turn())
	check(RunState.start_gold() == 0, "R767 下限：金币修饰不会让初始金币为负（%d）" % RunState.start_gold())

	# ⑧ 标准局必须是「零影响」：daily_fx 为空时四个口回到原值
	RunState.daily_fx = {}
	check(RunState.start_gold() == r767_base_gold and RunState.energy_per_turn() == r767_base_energy
			and is_equal_approx(RunState.max_hp_mul(), r767_base_hp),
			"R767 标准局：daily_fx 为空时取数口与改动前完全一致")

	# ⑨ 每日修饰只属于这一局：end_run 要把它清干净
	RunState.daily_fx = {"gold": 80}
	RunState.end_run(false)
	check(RunState.daily_fx.is_empty(), "R767 收尾：end_run 清空 daily_fx（不带到下一局）")

	# 还原
	RunState.daily_fx = r767_sv_fx
	RunState.set_difficulty(r767_sv_diff)
'''

body = BODY.replace("\n", "\r\n").lstrip("\r\n")
raw = raw.replace(REG_OLD, REG_NEW, 1)
raw = raw + body.encode("utf-8")
open(P, "wb").write(raw)

out = open(P, "rb").read()
print("CRLF ok:", out.count(b"\r\n") == out.count(b"\n"))
print("注册次数:", out.count(b"_test_r767()"))
