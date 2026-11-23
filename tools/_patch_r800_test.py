#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：test_engine 加 `_test_r800()`（余音 9274 / 音符 9275）并在 _init 里注册。

覆盖：
  ① 数据层（X 费 / 稀有 / 吟游诗人 / 次元 / event_only）
  ② 余音 X=3 → 抽牌库 +3 张音符、费用清空
  ③ 余音 X=0 → 合法施放、一张不加
  ④ 音符 → +2 费、抽 2 张、用后进消耗区（不进弃牌区）
  ⑤ 奖励池：音符不进任何池，余音在（含隐藏职业的池内）
  ⑥ 钻头 6077：余音 X=6 → 12 张（与 9272 / 9273 同源）
  ⑦ 源码锁
"""
P = "scripts/test_engine.gd"
d = open(P, "rb").read().decode("utf-8")

BLOCK = '''func _test_r800() -> void:
	## R800（用户口径）：吟游诗人稀有技能「余音」9274 + 内部卡「音符」9275
	##   · 9274 余音（吟游诗人 · 稀有 · X 费）：将 X 张「音符」加入抽牌库
	##   · 9275 音符（0 费技能 · 次元）：获得 2 点费用，抽 2 张卡；用后进消耗区
	## 「次元」在这里是**机制而不是装饰**：音符若进弃牌区就会被洗回牌库，
	## 一张余音就能变成「+2 费 + 抽 2 张」的永动机 —— ④ 专门盯这条。
	var r800_repo := CardRepo.load_json()
	var r800_sv: Array[int] = RunState.relics.duplicate()
	var r800_c1: CardData = r800_repo.get_card(9274)
	var r800_c2: CardData = r800_repo.get_card(9275)

	# ① 数据层
	check(r800_c1 != null and r800_c1.is_spell() and r800_c1.x_cost and r800_c1.cost == 0
			and r800_c1.rarity == 1 and r800_c1.card_class == "吟游诗人"
			and r800_c1.target_mode == "none" and not r800_c1.needs_target(),
			"R800 数据层：余音 9274 = 吟游诗人稀有 X 费技能，无需选目标")
	check(r800_c2 != null and r800_c2.is_spell() and r800_c2.cost == 0
			and not r800_c2.x_cost and r800_c2.has_affix("次元"),
			"R800 数据层：音符 9275 = 0 费技能，带「次元」（用后消失）")
	check(r800_c2 != null and r800_c2.event_only,
			"R800 数据层：音符是内部卡（event_only → 不进任何获得池）")

	# ② 余音 X = 3 → 抽牌库 +3 张音符，费用清空
	RunState.relics = []
	var r800_e1 := _new_engine([], 40, 40)
	r800_e1.state.hand.clear()
	r800_e1.state.hand.append(CardData.from_dict(r800_c1.to_dict()))
	r800_e1.state.energy = 3
	check(r800_e1.state.deck.is_empty(), "R800 余音：施放前抽牌库为空")
	r800_e1.use_spell(0)
	check(r800_e1.state.deck.size() == 3,
			"R800 余音：X=3 → 抽牌库 +3 张（实际 %d）" % r800_e1.state.deck.size())
	var r800_ok := true
	for r800_dc: CardData in r800_e1.state.deck:
		if r800_dc == null or r800_dc.id != 9275:
			r800_ok = false
	check(r800_ok, "R800 余音：塞进抽牌库的是「音符」9275")
	check(r800_e1.state.energy == 0, "R800 余音：一次吃掉全部费用（3 → 0）")

	# ③ 余音 X = 0：合法施放，一张都不加
	var r800_e2 := _new_engine([], 40, 40)
	r800_e2.state.hand.clear()
	r800_e2.state.hand.append(CardData.from_dict(r800_c1.to_dict()))
	r800_e2.state.energy = 0
	check(r800_e2.can_pay_card(r800_e2.state.hand[0]), "R800 余音：0 费也能使用（X 记 0）")
	r800_e2.use_spell(0)
	check(r800_e2.state.deck.is_empty(), "R800 余音：X=0 时一张音符都不加")

	# ④ 音符：+2 费、抽 2 张、用后进消耗区（不进弃牌区 → 不会被洗回牌库）
	RunState.relics = []
	var r800_e3 := _new_engine([], 40, 40)
	r800_e3.state.deck.clear()
	for _i in 3:
		r800_e3.state.deck.append(CardData.from_dict(r800_repo.get_card(1051).to_dict()))
	r800_e3.state.hand.clear()
	r800_e3.state.hand.append(CardData.from_dict(r800_c2.to_dict()))
	r800_e3.state.energy = 0
	var r800_disc0: int = r800_e3.state.discard.size()
	var r800_void0: int = r800_e3.state.void_count
	r800_e3.use_spell(0)
	check(r800_e3.state.energy == 2,
			"R800 音符：获得 2 点费用（0 → %d）" % r800_e3.state.energy)
	check(r800_e3.state.hand.size() == 2,
			"R800 音符：抽 2 张进手牌（实际 %d）" % r800_e3.state.hand.size())
	check(r800_e3.state.void_count == r800_void0 + 1,
			"R800 音符：带「次元」→ 用后进消耗区（void %d → %d）"
					% [r800_void0, r800_e3.state.void_count])
	check(r800_e3.state.discard.size() == r800_disc0,
			"R800 音符：不进弃牌区（否则会被洗回牌库，变成无限回费）")
	var r800_note_in_discard := false
	for r800_dc2: CardData in r800_e3.state.discard:
		if r800_dc2 != null and r800_dc2.id == 9275:
			r800_note_in_discard = true
	check(not r800_note_in_discard, "R800 音符：弃牌区里一张音符都没有")

	# ⑤ 奖励池：音符是内部卡（event_only）→ 连含隐藏职业的池子都不该收；余音正常在池内
	var r800_pool: Array[CardData] = r800_repo.reward_pool(true)
	var r800_has_note := false
	var r800_has_encore := false
	for r800_pc: CardData in r800_pool:
		if r800_pc.id == 9275:
			r800_has_note = true
		if r800_pc.id == 9274:
			r800_has_encore = true
	check(not r800_has_note, "R800 奖励池：音符 9275 不进任何获得池（event_only 生效）")
	check(r800_has_encore, "R800 奖励池：余音 9274 本身是可获得的正常卡")

	# ⑥ 钻头 6077：余音 X ≥ 6 → 翻倍；与连斩 / 炮火就位共用同一个 `_x_spell_value`
	RunState.relics = [6077]
	var r800_e4 := _new_engine([], 40, 40)
	r800_e4.state.hand.clear()
	r800_e4.state.hand.append(CardData.from_dict(r800_c1.to_dict()))
	r800_e4.state.energy = 6
	r800_e4.use_spell(0)
	check(r800_e4.state.deck.size() == 12,
			"R800 钻头：余音 X=6 → 翻倍成 12 张音符（实际 %d）" % r800_e4.state.deck.size())

	# ⑦ 源码锁：两个结算口都在，且 X 只读 `_x_spell_value`（别各写一套）
	var r800_ge := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r800_ge.contains("func _encore(")
			and r800_ge.contains("func _note_spell(")
			and r800_ge.contains("const NOTE_ID:= 9275")
			and r800_ge.contains("maxi(0, _x_spell_value)"),
			"R800 源码锁：余音 / 音符走 _encore / _note_spell，X 仍是 _x_spell_value 一条口")

	RunState.relics = r800_sv
	print("  · R800：余音 9274 / 音符 9275（X 费塞 X 张，音符 0 费 · 次元）")


'''

# 定义插在 _test_r793 之前（即 _test_r799 之后）
# ⚠️ BLOCK 在源码里是 LF，本文件是纯 CRLF —— 不转就会插出一段混合行尾。
BLOCK = BLOCK.replace("\n", "\r\n")
anchor_def = "func _test_r793() -> void:\r\n"
assert d.count(anchor_def) == 1, d.count(anchor_def)
d = d.replace(anchor_def, BLOCK + anchor_def)

# 注册插在 _test_r799() 之后
anchor_call = "\t_test_r799()\r\n\r\n\tprint(\"== 结果："
assert d.count(anchor_call) == 1, d.count(anchor_call)
d = d.replace(anchor_call, "\t_test_r799()\r\n\t_test_r800()\r\n\r\n\tprint(\"== 结果：")

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
assert b.count(b"\n") == b.count(b"\r\n"), "行尾被改成 LF 了"
print("test_engine.gd ok: CRLF %d" % b.count(b"\r\n"))
