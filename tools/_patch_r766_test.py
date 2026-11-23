# -*- coding: utf-8 -*-
"""R766 测试：猴爪（6066）+ 懊悔（9265）。

追加 `_test_r766()` 并在 R763 之后调用。test_engine.gd 是 **CRLF**，按 \\r\\n 拼。
"""
import pathlib

P = pathlib.Path(r"E:\work\card_rogue\scripts\test_engine.gd")
raw = P.read_bytes()
assert raw.count(b"\r\n") == raw.count(b"\n"), "test_engine 行尾不是纯 CRLF"
src = raw.decode("utf-8")

BODY = r'''
# ================= R766：猴爪（6066）+ 懊悔（9265）=================
# 店长口径（原话）：
#   「新增道具 猴爪 —— 每场战斗前三个回合，将一张任意其他职业随机卡加入你的手卡，
#    将一张懊悔加入你的卡组。懊悔：1费诅咒。选弃牌区一张其他职业卡消失。次元。」
# 三处口径都在这里钉住：
#   ① 「其他职业」唯一判据 `_other_class_card()`（有归属 + 不是自己）—— 公用卡与诅咒都不算；
#   ② 「加入卡组」= 永久 `RunState.deck_ids`，**本场抽牌堆不掺**；
#   ③ 「消失」= 本场对战移除（从弃牌区抹掉），不是「删除」。
func _test_r766() -> void:
	var r766_repo := CardRepo.load_json()
	var r766_regret: CardData = r766_repo.get_card(9265)
	var r766_claw = RelicRepo.load_json().get_relic(6066)

	# 收尾要还原的全局
	var r766_sv_deck: Array[int] = RunState.deck_ids.duplicate()
	var r766_sv_cls: String = RunState.player_class
	var r766_sv_active: bool = RunState.run_active
	RunState.run_active = false   # 别把测试里打的牌写进玩家成就统计

	# ① 数据真在库
	check(r766_regret != null and r766_regret.kind == "诅咒" and r766_regret.cost == 1
			and r766_regret.affixes.has("次元") and r766_regret.target_mode == "none",
			"R766 数据：懊悔 9265 = 1 费诅咒 · 带「次元」· 不取场地目标")
	check(r766_regret != null and r766_regret.effect_text.contains("弃牌区")
			and r766_regret.effect_text.contains("其他职业"),
			"R766 数据：懊悔文案同时写明「弃牌区」与「其他职业」")
	check(r766_claw != null and str(r766_claw.kind) == "战斗",
			"R766 数据：猴爪 6066 在库，kind = 战斗")

	# ② 「其他职业」判据：本职业 false / 别职业 true / 公用卡 false
	RunState.player_class = PlayerClass.DRUID
	var r766_own: CardData = null
	var r766_other: CardData = null
	var r766_common: CardData = null
	for c: CardData in r766_repo.reward_pool():
		if c.card_class == PlayerClass.DRUID and r766_own == null:
			r766_own = c
		elif c.card_class != "" and c.card_class != PlayerClass.DRUID and r766_other == null:
			r766_other = c
		elif c.card_class == "" and r766_common == null:
			r766_common = c
	var r766_probe := _new_engine([], 20, 20, -1, false)
	check(r766_own != null and r766_other != null,
			"R766 判据：卡池里能同时找到本职业卡与别职业卡（否则后面的断言是空的）")
	if r766_own != null and r766_other != null:
		check(not r766_probe._other_class_card(r766_own),
				"R766 判据：本职业卡「%s」不算其他职业" % r766_own.card_name)
		check(r766_probe._other_class_card(r766_other),
				"R766 判据：别职业卡「%s」算其他职业" % r766_other.card_name)
		check(not r766_probe._other_class_card(r766_regret),
				"R766 判据：诅咒（class 留空）不算其他职业")
	if r766_common != null:
		check(not r766_probe._other_class_card(r766_common),
				"R766 判据：公用卡「%s」不算其他职业（与诗 6069 的口径故意不同）"
				% r766_common.card_name)

	# ③ 猴爪：前三个回合各发一张外来卡 + 一张「懊悔」进卡组；第 4 回合不再发
	# ⚠️ 用空 deck 开战 → 正常抽牌抽不到东西，手牌里留下的就是猴爪发的那张。
	var r766_e := _new_engine([], 20, 20, -1, false)
	r766_e.self_relics = [GameEngine.MONKEY_CLAW_RELIC_ID]
	var r766_base := RunState.deck_ids.size()
	r766_e.start_game(0)
	check(RunState.deck_ids.size() == r766_base + 1
			and RunState.deck_ids[RunState.deck_ids.size() - 1] == 9265,
			"R766 猴爪：第 1 回合「懊悔」进卡组（%d → %d）"
			% [r766_base, RunState.deck_ids.size()])
	var r766_hand_alien := []
	for c: CardData in r766_e.state.hand:
		if r766_e._other_class_card(c):
			r766_hand_alien.append(c.card_name)
	check(r766_hand_alien.size() == 1,
			"R766 猴爪：第 1 回合手牌多一张其他职业卡（%s）" % str(r766_hand_alien))
	check(r766_e.state.deck.is_empty(),
			"R766 猴爪：外来卡只进手牌 —— 本场抽牌堆里没有被塞东西")

	for r766_t in [2, 3]:
		r766_e.state.hand.clear()
		r766_e._begin_turn(GameEngine.SIDE_SELF)
		check(RunState.deck_ids.size() == r766_base + r766_t,
				"R766 猴爪：第 %d 回合再进一张「懊悔」（卡组 %d 张）"
				% [r766_t, RunState.deck_ids.size()])
	r766_e.state.hand.clear()
	r766_e._begin_turn(GameEngine.SIDE_SELF)
	check(RunState.deck_ids.size() == r766_base + 3,
			"R766 猴爪：第 4 回合停手（卡组仍是 %d 张）" % RunState.deck_ids.size())
	check(r766_e.state.hand.is_empty(),
			"R766 猴爪：第 4 回合不再发外来卡")

	# ④ 没有猴爪时一张都不发（判据是道具，不是「回合数到了」）
	RunState.deck_ids = r766_sv_deck.duplicate()
	var r766_no := _new_engine([], 20, 20, -1, false)
	r766_no.self_relics = []
	var r766_no_base := RunState.deck_ids.size()
	r766_no.start_game(0)
	check(RunState.deck_ids.size() == r766_no_base,
			"R766 猴爪：没这件道具 → 卡组不变")
	var r766_no_alien := 0
	for c2: CardData in r766_no.state.hand:
		if r766_no._other_class_card(c2):
			r766_no_alien += 1
	check(r766_no_alien == 0, "R766 猴爪：没这件道具 → 不发外来卡")

	# ⑤ 懊悔：只列弃牌区的**其他职业卡**，选中即本场消失
	var r766_rg := _new_engine([], 20, 20, -1, false)
	r766_rg.start_game(0)
	r766_rg.state.hand.clear()
	r766_rg.state.discard.clear()
	if r766_other != null:
		r766_rg.state.discard.append(CardData.from_dict(r766_other.to_dict()))
	if r766_own != null:
		r766_rg.state.discard.append(CardData.from_dict(r766_own.to_dict()))
	var r766_opts: Array = r766_rg.regret_options()
	check(r766_opts.size() == 1,
			"R766 懊悔：候选只列其他职业卡（弃牌区 2 张，候选 %d 张）" % r766_opts.size())
	r766_rg.state.hand.append(CardData.from_dict(r766_regret.to_dict()))
	var r766_cast := r766_rg.use_spell(0)
	check(r766_rg.regret_pending,
			"R766 懊悔：打出后进入「从弃牌区选一张」状态（引擎返回：%s）" % str(r766_cast))
	var r766_dsize := r766_rg.state.discard.size()
	var r766_target_name: String = r766_rg.state.discard[r766_opts[0]].card_name
	check(r766_rg.regret_pick(int(r766_opts[0])),
			"R766 懊悔：选中「%s」→ 结算成功" % r766_target_name)
	check(r766_rg.state.discard.size() == r766_dsize - 1,
			"R766 懊悔：那张卡从弃牌区移除（消失 = 本场对战移除）")
	check(not r766_rg.regret_pending, "R766 懊悔：结算后状态收口")
	var r766_left_other := 0
	for i3 in r766_rg.state.discard.size():
		if r766_rg._other_class_card(r766_rg.state.discard[i3]):
			r766_left_other += 1
	check(r766_left_other == 0, "R766 懊悔：弃牌区不再剩其他职业卡")

	# ⑥ 弃牌区没有其他职业卡 → 白打，不开面板（不会卡在选卡页）
	var r766_rg2 := _new_engine([], 20, 20, -1, false)
	r766_rg2.start_game(0)
	r766_rg2.state.hand.clear()
	r766_rg2.state.discard.clear()
	r766_rg2.state.hand.append(CardData.from_dict(r766_regret.to_dict()))
	var r766_cast2 := r766_rg2.use_spell(0)
	check(not r766_rg2.regret_pending,
			"R766 懊悔：弃牌区没有其他职业卡 → 不开面板（返回：%s）" % str(r766_cast2))

	# ⑦ 选卡期间不许再出别的牌（引擎兜底，界面另有模态）
	var r766_rg3 := _new_engine([], 20, 20, -1, false)
	r766_rg3.start_game(0)
	r766_rg3.state.hand.clear()
	r766_rg3.state.discard.clear()
	if r766_other != null:
		r766_rg3.state.discard.append(CardData.from_dict(r766_other.to_dict()))
	r766_rg3.state.hand.append(CardData.from_dict(r766_regret.to_dict()))
	r766_rg3.regret_pending = true
	r766_rg3.state.hand.append(CardData.from_dict(r766_regret.to_dict()))
	var r766_block := r766_rg3.use_spell(1)
	check(r766_block.contains("懊悔"),
			"R766 懊悔：选卡期间出别的牌被拦（返回：%s）" % str(r766_block))

	# 还原
	RunState.deck_ids = r766_sv_deck
	RunState.player_class = r766_sv_cls
	RunState.run_active = r766_sv_active
'''

CALL_OLD = "	_test_r763()\r\n"
CALL_NEW = "	_test_r763()\r\n\r\n	_test_r766()\r\n"
assert "func _test_r766" not in src, "已经补过了？"
assert src.count(CALL_OLD) == 1, "调用点锚点不唯一"
src = src.replace(CALL_OLD, CALL_NEW)

src = src.rstrip("\r\n") + "\r\n" + BODY.replace("\n", "\r\n")

P.write_bytes(src.encode("utf-8"))
raw2 = P.read_bytes()
print("appended _test_r766, size", len(src), "CRLF intact:", raw2.count(b"\r\n") == raw2.count(b"\n"))
