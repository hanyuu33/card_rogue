# -*- coding: utf-8 -*-
"""R799：test_engine.gd 增加 _test_r799()（连斩 9272 / 炮火就位 9273）。CRLF。"""
P = "scripts/test_engine.gd"
raw = open(P, "rb").read().decode("utf-8")
d = raw


def rep(old, new, tag):
    global d
    n = d.count(old)
    assert n == 1, "%s count=%d" % (tag, n)
    d = d.replace(old, new)


TEST = """
func _test_r799() -> void:
	## R799（用户口径）：两张新的 **X 费** 技能卡
	##   · 9272 连斩（暗影刺客 · 稀有）：对一个目标 7 伤 × X 次
	##   · 9273 炮火就位（机械之心 · 史诗）：X 张「聚能炮击」进抽牌库 + 全体 3 伤 × X 次
	## X 一律走 `_x_spell_value` —— 钻头 6077 的「X ≥ 6 翻倍」因此在两处同源生效。
	var r799_repo := CardRepo.load_json()
	var r799_sv: Array[int] = RunState.relics.duplicate()
	var r799_c1: CardData = r799_repo.get_card(9272)
	var r799_c2: CardData = r799_repo.get_card(9273)

	# ① 数据层
	check(r799_c1 != null and r799_c1.is_spell() and r799_c1.x_cost and r799_c1.cost == 0
			and r799_c1.rarity == 1 and r799_c1.card_class == "暗影刺客"
			and r799_c1.target_mode == "unit" and r799_c1.needs_target(),
			"R799 数据层：连斩 9272 = 暗影刺客稀有 X 费技能，需要选目标")
	check(r799_c2 != null and r799_c2.is_spell() and r799_c2.x_cost and r799_c2.cost == 0
			and r799_c2.rarity == 2 and r799_c2.card_class == "机械之心"
			and r799_c2.target_mode == "none" and not r799_c2.needs_target(),
			"R799 数据层：炮火就位 9273 = 机械之心史诗 X 费技能，全体无需选目标")

	# ② 连斩：X = 3 → 3 刀 × 7 = 21，费用清空，不溢到任何一方 HP
	RunState.relics = []
	var r799_e1 := _new_engine([], 40, 40)
	var r799_f1 := r799_e1.state.place(
			CardData.from_dict(r799_repo.get_card(1051).to_dict()),   # 亡灵领主 8/55
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r799_hp1: int = r799_f1.health
	r799_e1.state.hand.clear()
	r799_e1.state.hand.append(CardData.from_dict(r799_c1.to_dict()))
	r799_e1.state.energy = 3
	r799_e1.use_spell(0, Vector2i(2, 1))
	check(r799_hp1 - r799_f1.health == 21,
			"R799 连斩：X=3 → 3 刀 × 7 = 21 点伤害（实际 %d）" % (r799_hp1 - r799_f1.health))
	check(r799_e1.state.energy == 0, "R799 连斩：一次吃掉全部费用（3 → 0）")
	check(r799_e1.state.hp_self == 40 and r799_e1.state.hp_opponent == 40,
			"R799 连斩：伤害没有溢到任何一方 HP")

	# ③ 连斩 X = 0：合法施放，一刀不出
	var r799_e2 := _new_engine([], 40, 40)
	var r799_f2 := r799_e2.state.place(
			CardData.from_dict(r799_repo.get_card(1051).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r799_hp2: int = r799_f2.health
	r799_e2.state.hand.clear()
	r799_e2.state.hand.append(CardData.from_dict(r799_c1.to_dict()))
	r799_e2.state.energy = 0
	check(r799_e2.can_pay_card(r799_e2.state.hand[0]), "R799 连斩：0 费也能使用（X 记 0）")
	r799_e2.use_spell(0, Vector2i(2, 1))
	check(r799_f2.health == r799_hp2 and r799_e2.state.hp_opponent == 40,
			"R799 连斩：X=0 时一刀不出、不产生任何伤害")

	# ④ 连斩：目标中途倒下 → 剩余段数作废，**不能**落到空格上溢成对敌方 HP 的伤害
	RunState.relics = []
	var r799_e3 := _new_engine([], 40, 40)
	var r799_f3 := r799_e3.state.place(
			CardData.from_dict(r799_repo.get_card(1051).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r799_f3.health = 8     # 第 1 刀 7 → 剩 1；第 2 刀倒；第 3 刀应作废
	r799_e3.state.hand.clear()
	r799_e3.state.hand.append(CardData.from_dict(r799_c1.to_dict()))
	r799_e3.state.energy = 3
	r799_e3.use_spell(0, Vector2i(2, 1))
	check(r799_f3.health <= 0, "R799 连斩：目标在第 2 刀倒下")
	check(r799_e3.state.hp_opponent == 40 and r799_e3.state.hp_self == 40,
			"R799 连斩：目标倒下后剩余次数作废，没有幽灵伤害漏到 HP（2 排非后排，本就不该溢出）")

	# ⑤ 炮火就位：X = 2 → 抽牌库 +2 张聚能炮击，场上两个敌人各吃 3 × 2 = 6
	RunState.relics = []
	var r799_e4 := _new_engine([], 40, 40)
	var r799_g1 := r799_e4.state.place(
			CardData.from_dict(r799_repo.get_card(1051).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r799_g2 := r799_e4.state.place(
			CardData.from_dict(r799_repo.get_card(1013).to_dict()),   # 灰烬龙 9/45
			Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	var r799_g1hp: int = r799_g1.health
	var r799_g2hp: int = r799_g2.health
	r799_e4.state.hand.clear()
	r799_e4.state.hand.append(CardData.from_dict(r799_c2.to_dict()))
	r799_e4.state.energy = 2
	check(r799_e4.state.deck.is_empty(), "R799 炮火就位：施放前抽牌库为空")
	r799_e4.use_spell(0)
	check(r799_e4.state.deck.size() == 2,
			"R799 炮火就位：X=2 → 抽牌库 +2 张（实际 %d）" % r799_e4.state.deck.size())
	var r799_ok := true
	for r799_dc: CardData in r799_e4.state.deck:
		if r799_dc == null or r799_dc.id != 9145:
			r799_ok = false
	check(r799_ok, "R799 炮火就位：加进抽牌库的是「聚能炮击」9145")
	check(r799_g1hp - r799_g1.health == 6 and r799_g2hp - r799_g2.health == 6,
			"R799 炮火就位：X=2 → 两个敌人各吃 3 × 2 = 6 点（%d / %d）" % [
					r799_g1hp - r799_g1.health, r799_g2hp - r799_g2.health])
	check(r799_e4.state.energy == 0, "R799 炮火就位：一次吃掉全部费用（2 → 0）")

	# ⑥ 炮火就位 X = 0：不加卡也不伤害
	var r799_e5 := _new_engine([], 40, 40)
	var r799_h1 := r799_e5.state.place(
			CardData.from_dict(r799_repo.get_card(1051).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r799_h1hp: int = r799_h1.health
	r799_e5.state.hand.clear()
	r799_e5.state.hand.append(CardData.from_dict(r799_c2.to_dict()))
	r799_e5.state.energy = 0
	r799_e5.use_spell(0)
	check(r799_e5.state.deck.is_empty() and r799_h1.health == r799_h1hp,
			"R799 炮火就位：X=0 时不加卡、不造成伤害")

	# ⑦ 钻头 6077：X ≥ 6 → 翻倍，且**两处效果同源**（次数与卡数一起翻）
	RunState.relics = [6077]
	var r799_e6 := _new_engine([], 40, 40)
	var r799_k1 := r799_e6.state.place(
			CardData.from_dict(r799_repo.get_card(1051).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r799_k1.health = 200
	var r799_k1hp: int = r799_k1.health
	r799_e6.state.hand.clear()
	r799_e6.state.hand.append(CardData.from_dict(r799_c1.to_dict()))
	r799_e6.state.energy = 6
	r799_e6.use_spell(0, Vector2i(2, 1))
	check(r799_k1hp - r799_k1.health == 84,
			"R799 钻头：连斩 X=6 → 翻倍成 12 → 12 × 7 = 84（实际 %d）" % (r799_k1hp - r799_k1.health))
	var r799_e7 := _new_engine([], 40, 40)
	r799_e7.state.place(CardData.from_dict(r799_repo.get_card(1051).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r799_e7.state.hand.clear()
	r799_e7.state.hand.append(CardData.from_dict(r799_c2.to_dict()))
	r799_e7.state.energy = 6
	r799_e7.use_spell(0)
	check(r799_e7.state.deck.size() == 12,
			"R799 钻头：炮火就位 X=6 → 12 张聚能炮击进抽牌库（卡数也跟着翻，实际 %d）"
					% r799_e7.state.deck.size())

	# ⑧ 源码锁：两张卡的 X 都读 `_x_spell_value`，不许各写一套
	var r799_ge := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r799_ge.contains("func _link_slash(")
			and r799_ge.contains("func _barrage(")
			and r799_ge.contains("maxi(0, _x_spell_value)"),
			"R799 源码锁：连斩 / 炮火就位的 X 同走 _x_spell_value（钻头一处翻倍两处生效）")

	RunState.relics = r799_sv
	print("  · R799：连斩 9272 / 炮火就位 9273（X 费，钻头同源翻倍）")
"""

TEST = TEST.replace("\n", "\r\n")

ANCHOR = ('\tRunState.relics = r797_sv\r\n'
          '\tprint("  · R797：龟壳 6078（受伤 -2，上回合未攻击）")\r\n'
          '\r\n'
          '\r\n'
          'func _test_r793() -> void:\r\n')
NEW = ('\tRunState.relics = r797_sv\r\n'
       '\tprint("  · R797：龟壳 6078（受伤 -2，上回合未攻击）")\r\n'
       '\r\n'
       + TEST + '\r\n'
       'func _test_r793() -> void:\r\n')
rep(ANCHOR, NEW, "func")

rep("\t_test_r797()\r\n", "\t_test_r797()\r\n\t_test_r799()\r\n", "register")

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
print("_test_r799 出现", b.decode("utf-8").count("_test_r799"))
