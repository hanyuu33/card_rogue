# -*- coding: utf-8 -*-
"""R752 补丁：test_traps —— 三件新工具的结算段（⑩）。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:160])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


NEW_BLOCK = '''	# ---- ⑩ R752：三件新工具的结算 ----
	# ① 快送鸭 7010：**先腾空自己那一格再填满** —— 用完之后工具栏必须是 3/3。
	#    顺序反了（先填后摘）就是 2/3，玩家会以为「填满」这条效果打了折扣。
	var saved_seed752 := RunState.run_seed
	var saved_seq752 := RunState.tool_deliver_seq
	RunState.run_seed = 20261115
	RunState.tool_deliver_seq = 0
	RunState.traps = [7010, -1, 7010]
	var duck_eng := _engine()
	check(duck_eng.use_tool(7010, 0), "快送鸭：use_tool 带槽号结算成功")
	check(RunState.trap_free_slots() == 0, "快送鸭：用完之后工具栏 3/3（自己那格也算填上）")
	var fill_all_shop := true
	for du_i in RunState.TRAP_SLOTS:
		var du_t: TrapData = repo.get_trap(RunState.trap_at(du_i))
		if du_t == null or not du_t.in_shop() or du_t.rest_only:
			fill_all_shop = false
	check(fill_all_shop, "快送鸭：填进去的都是**有售价的商店工具**（非卖品 / 烤肉不会冒出来）")
	# 满栏时不顶掉已有工具：只在空槽里填，玩家手里的东西不该被这个效果换掉。
	RunState.traps = [7001, 7001, 7001]
	RunState.tool_deliver_seq = 1
	check(RunState.fill_toolbar_with_shop_tools() == 0
			and RunState.traps == [7001, 7001, 7001], "快送鸭：满栏时一件不换（不覆盖已有工具）")
	# 派生流：同一 (seed, 序号) 必得同一结果，且不碰 run_rng。
	RunState.traps = [-1, -1, -1]
	RunState.tool_deliver_seq = 7
	var d_first: Array[int] = []
	RunState.fill_toolbar_with_shop_tools()
	for du_i in RunState.TRAP_SLOTS:
		d_first.append(RunState.trap_at(du_i))
	RunState.traps = [-1, -1, -1]
	RunState.tool_deliver_seq = 7
	RunState.fill_toolbar_with_shop_tools()
	var d_again: Array[int] = []
	for du_i in RunState.TRAP_SLOTS:
		d_again.append(RunState.trap_at(du_i))
	check(d_first == d_again, "快送鸭：同一条派生种子出同一批工具（读档重进不会换货）")
	RunState.run_seed = saved_seed752
	RunState.tool_deliver_seq = saved_seq752

	# ② 万能牌 7009：抽牌库**空** → 用不了（不能白开一个空面板）。
	RunState.traps = [7009, -1, -1]
	var wc_eng := _engine()
	check(not wc_eng.begin_tool_pick(7009) and wc_eng.tool_pick_kind == "",
			"万能牌：抽牌库是空的 → 直接拒绝（不开空面板）")
	# 抽牌库有卡 → 候选 = 全部；确认后得到**幻影复制**（原卡留在牌库里）。
	var wc_proto: CardData = CardRepo.load_json().get_card(8001)
	wc_eng.state.deck.clear()
	wc_eng.state.deck.append(CardData.from_dict(wc_proto.to_dict()))
	wc_eng.state.deck.append(CardData.from_dict(wc_proto.to_dict()))
	check(wc_eng.begin_tool_pick(7009) and wc_eng.tool_pick_kind == "deck_copy",
			"万能牌：抽牌库有货 → 进入选卡（deck_copy）")
	check(wc_eng.tool_pick_cards().size() == 2, "万能牌：候选 = 抽牌库全部张数（2 张）")
	var wc_hand_before := wc_eng.state.hand.size()
	check(wc_eng.tool_pick_confirm(0), "万能牌：确认第 1 张 → 结算成功")
	check(wc_eng.state.hand.size() == wc_hand_before + 1, "万能牌：手牌 +1")
	check(wc_eng.state.deck.size() == 2, "万能牌：原卡**留在**抽牌库里（这是复制，不是取走）")
	var wc_copy: CardData = wc_eng.state.hand[wc_eng.state.hand.size() - 1]
	check(wc_copy != wc_eng.state.deck[0] and wc_copy.own_copy,
			"万能牌：拿到的是独立副本（不是牌库那个共享实例）")
	check(wc_copy.is_ephemeral and wc_copy.affixes.has(GameEngine.AFFIX_DIMENSION)
			and not wc_copy.affixes.has(GameEngine.AFFIX_PHANTOM),
			"万能牌：幻影复制 = 回合结束消失 + 次元（用后消失）、不带「幻影」字段（不会无限链）")
	check(wc_eng.cost_of(wc_copy) == 0, "万能牌：复制品在手时费用为 0")
	# 离手即恢复原价：`hand_free` 的判据是「此刻还在手牌里」，打出 / 弃掉自动失效。
	wc_eng.state.hand.erase(wc_copy)
	wc_eng.state.discard.append(wc_copy)
	check(wc_eng.cost_of(wc_copy) == wc_copy.cost,
			"万能牌：离手后恢复原费用（%d）" % wc_copy.cost)
	# 取消：什么都没发生（工具留在工具栏里，由界面决定不摘槽）。
	wc_eng.state.hand.erase(wc_copy)
	check(wc_eng.begin_tool_pick(7009), "万能牌：再开一次选卡")
	wc_eng.tool_pick_cancel()
	check(wc_eng.tool_pick_kind == "" and wc_eng.state.hand.size() == wc_hand_before,
			"万能牌：取消 → 状态清空、手牌不变")

	# ③ 神秘牌 7011：候选 = 随机 3 张**本职业奖励卡**；确认后入手且本回合 0 费。
	var my_eng := _engine()
	check(my_eng.begin_tool_pick(7011) and my_eng.tool_pick_kind == "random3",
			"神秘牌：进入选卡（random3）")
	var my_cards: Array = my_eng.tool_pick_cards()
	check(my_cards.size() == 3, "神秘牌：候选正好 3 张")
	var my_ids: Array[int] = []
	var my_in_pool := true
	var my_pool: Array[CardData] = CardRepo.load_json().reward_pool_for(RunState.player_class)
	for pc: CardData in my_pool:
		my_ids.append(int(pc.id))
	var my_distinct := true
	for mc: CardData in my_cards:
		if not my_ids.has(int(mc.id)):
			my_in_pool = false
	if my_cards.size() == 3 and int((my_cards[0] as CardData).id) == int((my_cards[1] as CardData).id):
		my_distinct = false
	if my_cards.size() == 3 and int((my_cards[0] as CardData).id) == int((my_cards[2] as CardData).id):
		my_distinct = false
	if my_cards.size() == 3 and int((my_cards[1] as CardData).id) == int((my_cards[2] as CardData).id):
		my_distinct = false
	check(my_in_pool, "神秘牌：3 张候选都来自本职业奖励卡池")
	check(my_distinct, "神秘牌：3 张候选互不相同")
	var my_hand_before := my_eng.state.hand.size()
	check(my_eng.tool_pick_confirm(1), "神秘牌：确认第 2 张 → 结算成功")
	check(my_eng.state.hand.size() == my_hand_before + 1, "神秘牌：手牌 +1")
	var my_got: CardData = my_eng.state.hand[my_eng.state.hand.size() - 1]
	check(my_eng.state.turn_free.has(my_got), "神秘牌：入手的那张记了「本回合费用 0」")
	check(my_eng.cost_of(my_got) == 0, "神秘牌：本回合费用为 0")
	check(my_eng.tool_pick_kind == "", "神秘牌：结算后待选状态清空（面板会自己关）")

	# ④ 手牌满 → 两种选卡型工具都不许用（否则复制品会被 `_grant_to_hand` 丢进弃牌/消耗区）。
	var hf_eng := _engine()
	hf_eng.state.deck.append(CardData.from_dict(wc_proto.to_dict()))
	while not hf_eng.state.hand_full():
		hf_eng.state.hand.append(CardData.new())
	check(not hf_eng.begin_tool_pick(7009) and not hf_eng.begin_tool_pick(7011),
			"手牌满（10 张）时万能牌 / 神秘牌都拒绝使用")
	check(not hf_eng.use_tool(7009) and not hf_eng.use_tool(7011),
			"选卡型工具**不走** use_tool（避免界面误当「已结算」而摘槽）")

	RunState.traps = [-1, -1, -1]
'''

patch("scripts/test_traps.gd", [
    (
        """	RunState.traps = [-1, -1, -1]
	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
""",
        NEW_BLOCK + """	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
""",
    ),
])

print("OK")
