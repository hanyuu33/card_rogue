# -*- coding: utf-8 -*-
"""R769 测试补强：给「-1 真生效」加一条**确定的**证据。

问题：_test_r769 里那张别职业卡是 `_random_other_class_card()` 摇出来的，
第一次跑摇到「鲜血堡垒」（0 费）—— `maxi(0, 0-1) == 0` 断言虽过，
但它证明不了 -1 落地，只证明了「0 费不会变负」。

补法：另取一张**确定 >=1 费**的别职业卡，手工挂上同一个标记，
直接验 `cost_of` 真降 1。这样「接线对」（表里有标记）与「效果对」（真降）
各有一条硬断言。
"""
P = r"E:\work\card_rogue\scripts\test_engine.gd"

raw = open(P, "rb").read()
assert raw.count(b"\r\n") > 0 and raw.count(b"\r\n") == raw.count(b"\n"), "期望纯 CRLF"

ANCHOR = "\t# ⑤ 满手 → 改投弃牌区的那张不带标记\r\n".encode("utf-8")
assert raw.count(ANCHOR) == 1, "锚点 %d" % raw.count(ANCHOR)

BLOCK = r'''	# ④' 「-1 真生效」的硬证据：上面那张是随机摇的，可能是 0 费（0-1 被 maxi(0,…) 夹住，
	#     断言虽过却嚼不出味道）。这里另取一张**确定 >=1 费**的别职业卡，挂同一个标记，
	#     直接验 cost_of 真降 1 —— 前者证接线，这条证效果。
	var r769_pick: CardData = null
	for pc: CardData in CardRepo.load_json().reward_pool():
		if r769_e._other_class_card(pc) and pc.cost >= 1 and pc.id != GameEngine.ECHO_ID:
			r769_pick = pc
			break
	check(r769_pick != null, "R769 准备：卡池里有 >=1 费的别职业卡")
	if r769_pick != null:
		var r769_inst := r769_e._new_own_card(r769_pick)
		r769_e.state.hand.append(r769_inst)
		r769_e.state.hand_cost_turn[r769_inst] = GameEngine.MONKEY_CLAW_DISCOUNT
		check(r769_e.cost_of(r769_inst) == r769_pick.cost - 1,
				"R769 猴爪：「%s」%d 费 → 本回合 %d 费（-1 真落地，没被 0 费夹住）"
				% [r769_pick.card_name, r769_pick.cost, r769_e.cost_of(r769_inst)])
		r769_e.state.hand.erase(r769_inst)
		r769_e.state.hand_cost_turn.erase(r769_inst)

'''.replace("\n", "\r\n").encode("utf-8")

raw = raw.replace(ANCHOR, BLOCK + ANCHOR)
open(P, "wb").write(raw)

chk = open(P, "rb").read()
assert chk.count(b"\r\n") == chk.count(b"\n"), "行尾被破坏"
assert chk.count(b"r769_pick") >= 4
print("已补「-1 真生效」断言，行尾仍纯 CRLF")
