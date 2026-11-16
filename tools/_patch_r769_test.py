# -*- coding: utf-8 -*-
"""R769 回归：_test_r769 —— 猴爪发进手牌的那张，本回合费用 -1。

测的是「复用 hand_cost_turn」这条路的四个关键面：
  ① 标记真写进表
  ② cost_of 真降（显示 = 判定 = 实扣同走这一个口）
  ③ 离手立刻复原（判据是 hand.has，不是计时器）
  ④ 回合结束清表
  ⑤ 满手改投弃牌区的那张**不该**带标记（它不在手牌，标记无处生效）

test_engine.gd 是 CRLF，按字节改。
"""
P = r"E:\work\card_rogue\scripts\test_engine.gd"

raw = open(P, "rb").read()
assert raw.count(b"\r\n") > 0 and raw.count(b"\r\n") == raw.count(b"\n"), "期望纯 CRLF"

CALL_DONE = b"\t_test_r766()\r\n"
assert raw.count(CALL_DONE) == 1, "调用锚点 %d" % raw.count(CALL_DONE)
raw = raw.replace(CALL_DONE, CALL_DONE + b"\t_test_r769()\r\n")

BODY = r'''
func _test_r769() -> void:
	## R769 猴爪：发进手牌的**那张**，本回合费用 -1（店长追加口径）。
	## 走的是既有 `state.hand_cost_turn`（R276 随心组装同一张表），所以验的不是「新机制」，
	## 而是**接得对不对**：标记写进去、cost_of 真降、离手与回合末都自动复原。
	var r769_sv_deck: Array[int] = RunState.deck_ids.duplicate()
	var r769_sv_active: bool = RunState.run_active
	RunState.run_active = false

	var r769_e := _new_engine([], 20, 20, -1, false)
	r769_e.self_relics = [GameEngine.MONKEY_CLAW_RELIC_ID]
	r769_e.start_game(0)
	var r769_alien: CardData = null
	for c: CardData in r769_e.state.hand:
		# 排除回响 9102：它卡面写死「最低 1 费」，_cost_floor 会压住这 -1，断言会假红
		if r769_e._other_class_card(c) and c.id != GameEngine.ECHO_ID:
			r769_alien = c
	check(r769_alien != null,
			"R769 准备：第 1 回合手牌里拿到一张其他职业卡（否则后面的断言是空的）")
	if r769_alien != null:
		check(int(r769_e.state.hand_cost_turn.get(r769_alien, 0)) == GameEngine.MONKEY_CLAW_DISCOUNT,
				"R769 猴爪：发进手牌的那张打上「本回合费用 -1」标记")
		var r769_before: int = r769_alien.cost
		var r769_after: int = r769_e.cost_of(r769_alien)
		check(r769_after == maxi(0, r769_before - 1),
				"R769 猴爪：「%s」本回合费用 %d → %d（cost_of 唯一口）"
				% [r769_alien.card_name, r769_before, r769_after])
		check(r769_alien.cost == r769_before,
				"R769 猴爪：**不改卡面原型**（card.cost 仍是 %d）—— 减费只按实例记账"
				% r769_alien.cost)

		# ③ 离手即复原
		r769_e.state.hand.erase(r769_alien)
		check(r769_e.cost_of(r769_alien) == r769_before,
				"R769 猴爪：离手后立刻恢复原价（%d）" % r769_e.cost_of(r769_alien))
		r769_e.state.hand.append(r769_alien)

		# ④ 回合结束清表
		r769_e.end_turn()
		check(r769_e.state.hand_cost_turn.is_empty(),
				"R769 猴爪：回合结束清空本回合减费表（剩 %d 条）"
				% r769_e.state.hand_cost_turn.size())

	# ⑤ 满手 → 改投弃牌区的那张不带标记
	var r769_full := _new_engine([], 20, 20, -1, false)
	r769_full.self_relics = [GameEngine.MONKEY_CLAW_RELIC_ID]
	r769_full.start_game(0)
	r769_full.state.hand.clear()
	r769_full.state.hand_cost_turn.clear()
	var r769_proto: CardData = CardRepo.load_json().get_card(8002)
	while r769_full.state.hand.size() < FieldState.HAND_LIMIT:
		r769_full.state.hand.append(CardData.from_dict(r769_proto.to_dict()))
	var r769_disc_before: int = r769_full.state.discard.size()
	r769_full.turn_number = 1
	r769_full._claw_tick()
	check(r769_full.state.discard.size() == r769_disc_before + 1,
			"R769 猴爪：满手时那张照样有去处（进弃牌区，不蒸发）")
	check(r769_full.state.hand_cost_turn.is_empty(),
			"R769 猴爪：满手没进手牌 → 不写减费标记（剩 %d 条）"
			% r769_full.state.hand_cost_turn.size())

	# ⑥ 第 4 回合连发都不发，更不会带标记
	r769_full.state.hand.clear()
	r769_full.state.hand_cost_turn.clear()
	r769_full.turn_number = GameEngine.MONKEY_CLAW_TURNS + 1
	var r769_d4: int = r769_full.state.discard.size()
	r769_full._claw_tick()
	check(r769_full.state.discard.size() == r769_d4
			and r769_full.state.hand.is_empty() and r769_full.state.hand_cost_turn.is_empty(),
			"R769 猴爪：第 4 回合不再发卡、也不留减费标记")

	RunState.deck_ids = r769_sv_deck.duplicate()
	RunState.run_active = r769_sv_active
'''.replace("\n", "\r\n").encode("utf-8")

assert b"func _test_r769" not in raw, "已经有 _test_r769 了，别重复追加"
if not raw.endswith(b"\r\n"):
    raw += b"\r\n"
raw += b"\r\n" + BODY

open(P, "wb").write(raw)

chk = open(P, "rb").read()
assert chk.count(b"\r\n") == chk.count(b"\n"), "行尾被破坏"
assert chk.count(b"func _test_r769") == 1
assert chk.count(b"_test_r769()") == 2   # 定义 1 + 调用 1
print("test_engine.gd 已加 _test_r769，行尾仍纯 CRLF")
