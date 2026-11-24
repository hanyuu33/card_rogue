# -*- coding: utf-8 -*-
"""R846：test_engine.gd 受影响回归改写（CRLF，按「标记行 + 行数」整段替换）。

改到的地方：R45（回转 / 影子猫）、R48（闪躲整块）、R55（地狱猫力量 0）、
R56（暗影之刃 X=张数）、R580（猫鼠 4 费）、R805（影子猫移速 2）。
R846 新增用例单独追加到文件末尾（见 tools/_append_r846_tests.py）。
"""
import io

P = "scripts/test_engine.gd"

BLOCKS = []


def block(marker, count, new):
    BLOCKS.append((marker, count, new))


# ── R45 回转 ────────────────────────────────────────────────
block("	# 回转（9089）：抽 X 张（X = 本回合已用数），本回合结束不弃", 25, """	# 回转（9089，R846 用户口径）：对一个目标造成 X 伤 + 抽 X 张
	# （X = 本回合**其他**卡张数），抽到的牌本回合结束不弃。
	var r45_sp := _new_engine([], 30, 30)
	var r45_sp_foe := r45_sp.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r45_sp.state.self_card_plays = 2
	r45_sp.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_sp.state.deck.append(_card(9097, "预判", "技能", 0, 0, 0, 0, 0))
	r45_sp.state.hand.append(repo.get_card(GameEngine.SPIN_DRAW_ID))
	r45_sp.use_spell(0, Vector2i(2, 1))
	check(r45_sp.state.hand.size() == 2, "回转：X=2 → 抽 2 张（实际 %d）" % r45_sp.state.hand.size())
	check(r45_sp_foe.health == 55 - 2,
			"回转：X=2 → 对一个目标造成 2 伤（R846 新增伤害，55 → %d）" % r45_sp_foe.health)
	var r45_sp_k1: CardData = r45_sp.state.hand[0]
	var r45_sp_k2: CardData = r45_sp.state.hand[1]
	r45_sp.end_turn()
	check(r45_sp.state.hand.has(r45_sp_k1) and r45_sp.state.hand.has(r45_sp_k2),
			"回转：回合结束抽到的 2 张仍留在手里（弃牌区只剩回转自己）")
""")

# ── R45 影子猫 ──────────────────────────────────────────────
block("	# 影子猫（8006）：含此卡本回合第 3 张打出 → 卡组随机技能卡入手", 31, """	# 影子猫（8006，R846 用户口径）：本回合已使用 3 张**其他**卡 → 抽 2 张
	var r45_sc := _new_engine([], 30, 30)
	r45_sc.state.self_card_plays = 3
	r45_sc.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_sc.state.deck.append(_card(9097, "预判", "技能", 0, 0, 0, 0, 0))
	r45_sc.state.hand.append(repo.get_card(GameEngine.SHADOW_CAT_ID))
	r45_sc.play_from_hand(0, Vector2i(4, 1))
	check(r45_sc.state.hand.size() == GameEngine.SHADOW_CAT_DRAW,
			"影子猫：其他卡已满 %d 张 → 抽 %d 张（实际 %d）" % [
					GameEngine.SHADOW_CAT_NEED, GameEngine.SHADOW_CAT_DRAW,
					r45_sc.state.hand.size()])
	var r45_sc2 := _new_engine([], 30, 30)
	r45_sc2.state.self_card_plays = 2
	r45_sc2.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_sc2.state.hand.append(repo.get_card(GameEngine.SHADOW_CAT_ID))
	r45_sc2.play_from_hand(0, Vector2i(4, 1))
	check(r45_sc2.state.hand.is_empty() and r45_sc2.state.deck.size() == 1,
			"影子猫：只有 2 张其他卡 → 效果落空，牌库不动")
""")

# ── R48 闪躲：卡数据 ────────────────────────────────────────
block("	check(r48_dodge_c != null and r48_dodge_c.card_name == \"闪躲\" and r48_dodge_c.cost == 0", 7,
      """	check(r48_dodge_c != null and r48_dodge_c.card_name == "闪躲" and r48_dodge_c.cost == 0
			and r48_dodge_c.rarity == 1 and r48_dodge_c.card_class == PlayerClass.ROGUE
			and r48_dodge_c.kind == "技能" and r48_dodge_c.target_mode == "unit",
			"闪躲 9103：0 费**稀有**暗影刺客技能，要选一个敌方单位（R846：普通→稀有 + 改效果）")
""")

# ── R48 闪躲：行为（原全员嘲讽整块）────────────────────────
block("	# 闪躲：本回合所有友方单位获得嘲讽（含后上场的单位，R542 改效果）", 117, """	# 闪躲（9103，R846 用户口径）：使一个敌方单位力量 -X，X = 本回合打出的牌数
	check(r48_dodge_c.effect_text.contains("力量 -X")
			and r48_dodge_c.effect_text.contains("本回合打出的牌数"),
			"闪躲：卡面文案 = 使一个敌方单位力量 -X（%s）" % r48_dodge_c.effect_text)

	var r48_d := _new_engine([], 30, 30)
	var r48_d_foe := r48_d.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r48_d.state.self_card_plays = 3
	r48_d.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d.use_spell(0, Vector2i(2, 1))
	check(r48_d_foe.effective_power() == 5 and r48_d_foe.debuff_stage == 1,
			"闪躲：本回合已打 3 张 → 敌方力量 8 → %d（debuff_stage 1，它回合结束清）"
			% r48_d_foe.effective_power())
	check(r48_d.state.energy == 5, "闪躲：0 费（费用 5 → %d）" % r48_d.state.energy)

	# 第二张继续叠：本回合第 4 张 → 再 -4
	r48_d.state.self_card_plays = 4
	r48_d.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d.use_spell(0, Vector2i(2, 1))
	check(r48_d_foe.effective_power() == 1,
			"闪躲：第二张再 -4 → 力量 %d（降力可叠加，与敲晕 / 威慑同源）"
			% r48_d_foe.effective_power())

	# 指到自己的单位 → 落空（不白降）
	var r48_d_own := r48_d.state.place(_card(8005, "幽影", "盟友", 3, 3, 8, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r48_d.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	var r48_d_msg := str(r48_d.use_spell(r48_d.state.hand.size() - 1, Vector2i(4, 1)))
	check(r48_d_own.effective_power() == 3 and r48_d_msg.contains("敌方单位"),
			"闪躲：指到己方单位 → 落空（己方力量仍是 %d，返回「%s」）"
			% [r48_d_own.effective_power(), r48_d_msg])

	# 本回合第一张就打它 → X=0，力量不变
	var r48_d0 := _new_engine([], 30, 30)
	var r48_d0_foe := r48_d0.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r48_d0.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d0.use_spell(0, Vector2i(2, 1))
	check(r48_d0_foe.effective_power() == 8,
			"闪躲：本回合还没打出别的卡 → X=0，力量不变（%d）"
			% r48_d0_foe.effective_power())

	# 敌方 AI 打出无效
	var r48_d5 := _new_engine([], 30, 30)
	var r48_d5_msg := str(r48_d5._run_spell_effect(r48_dodge_c, null, GameEngine.SIDE_OPPONENT))
	check(r48_d5_msg.contains("敌方 AI"),
			"闪躲：敌方 AI 打出无效（%s）" % r48_d5_msg)

	# R846 源码锁：全员嘲讽那条机制整条删除，嘲讽只剩「卡面自带」一个来源
	var r846_dodge_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r846_dodge_src.find("func _dodge_spell(side: String, card: CardData, target)") >= 0
			and r846_dodge_src.find("var _taunt_all_active") < 0
			and r846_dodge_src.find("func taunt_all_active") < 0,
			"R846 源码：闪躲只做敌方降力，全员嘲讽窗口（_taunt_all_active）已删除")
""")

# ── R55 地狱猫：卡数据 ─────────────────────────────────────
block("	check(r55_cat != null and r55_cat.card_name == \"地狱猫\" and r55_cat.kind == \"盟友\"", 9,
      """	check(r55_cat != null and r55_cat.card_name == "地狱猫" and r55_cat.kind == "盟友"
			and r55_cat.cost == 0 and r55_cat.power == 0 and r55_cat.health == 1
			and r55_cat.attack_range == 1 and r55_cat.move_speed == 1
			and r55_cat.rarity == 1 and r55_cat.card_class == PlayerClass.ROGUE,
			"R243 地狱猫 8019：0 费**稀有**暗影刺客盟友 0/1 程1 速1（R846 初始力量 1 → 0）")
""")

# ── R55 地狱猫：成长数值 ───────────────────────────────────
block("	check(r55_cat_p.end_atk == 3 and r55_cat_p.health == 1 + 3 * 2", 37, """	check(r55_cat_p.end_atk == 3 and r55_cat_p.health == 1 + 3 * 2
			and r55_cat_p.effective_power() == 3,
			"地狱猫：剩余 3 点 → 力量 0→3、生命 1→7（实际 力%d 生%d）"
			% [r55_cat_p.effective_power(), r55_cat_p.health])
	check(r55_fort_p.end_atk == 3 and r55_fort_p.health == 1 + 3 * 3
			and r55_fort_p.effective_power() == 3,
			"鲜血堡垒：剩余 3 点 → 力量 0→3、生命 1→10（实际 力%d 生%d）"
			% [r55_fort_p.effective_power(), r55_fort_p.health])

	# 成长是**永久**的：第二次结算继续累加，回合结束不清零
	r55_a.state.energy = 2
	r55_a._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_cat_p.end_atk == 5 and r55_cat_p.effective_power() == 5
			and r55_cat_p.health == 1 + 5 * 2,
			"地狱猫：成长累加不清零（再 +2 → 力量 5、生命 11）")
	r55_a.state.energy = 0
	r55_a.state.reset_units(GameEngine.SIDE_SELF)
	check(r55_cat_p.end_atk == 5 and r55_cat_p.effective_power() == 5,
			"地狱猫：reset_units 不会清掉回合结束成长（仍为 5）")
""")

# ── R56 黑暗领主 + 地狱猫 ─────────────────────────────────
block("	check(r56_cat_p.end_atk == 6 and r56_cat_p.effective_power() == 7", 5,
      """	check(r56_cat_p.end_atk == 6 and r56_cat_p.effective_power() == 6,
			"黑暗领主优先结算：地狱猫读到 1+5=6 点（力量 0 → %d）"
			% r56_cat_p.effective_power())
""")

# ── R56 暗影之刃：X = 张数 ────────────────────────────────
block("	# 暗影之刃：X = 本回合**已花掉**的费用（不是剩余费用）", 59, """	# 暗影之刃（R846）：X = 本回合**已使用的卡牌张数**（不再看花了多少费用）
	var r56_d := _new_engine([], 30, 30)
	r56_d.state.effects.append(CardData.from_dict(r56_blade.to_dict()))
	var r56_foe := r56_d.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r56_d.state.energy = 5
	r56_d.state.self_card_plays = 4
	r56_d._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_foe.health == 30 - 4,
			"暗影之刃：本回合已用 4 张卡 → 随机敌人受 4 伤（30 → %d）" % r56_foe.health)

	# 一点费用都没花（剩 5）也照样按张数结算 —— 与「已花费用」口径彻底脱钩
	var r56_e := _new_engine([], 30, 30)
	r56_e.state.effects.append(CardData.from_dict(r56_blade.to_dict()))
	var r56_foe2 := r56_e.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r56_e.state.energy = 5
	r56_e.state.self_card_plays = 2
	r56_e._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_foe2.health == 28 and r56_e.state.energy == 5,
			"暗影之刃：费用一分没花（剩 %d）也按 2 张卡结算（30 → %d）" % [
					r56_e.state.energy, r56_foe2.health])

	# 本回合一张卡都没用过 → 落空
	var r56_f := _new_engine([], 30, 30)
	r56_f.state.effects.append(CardData.from_dict(r56_blade.to_dict()))
	var r56_foe3 := r56_f.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r56_f.state.energy = 5
	r56_f._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_foe3.health == 30, "暗影之刃：本回合没用过卡 → 落空（敌人 30 血不变）")
""")

# ── R580 猫鼠游戏：4 费 ───────────────────────────────────
block("			and r580_cm.is_spell() and r580_cm.cost == 5 and r580_cm.rarity == 0", 1,
      "			and r580_cm.is_spell() and r580_cm.cost == 4 and r580_cm.rarity == 0")
block("			\"R580 卡数据：猫鼠游戏 = 5 费普通技能 · 暗影刺客 · locked\")", 1,
      "			\"R580 卡数据：猫鼠游戏 = 4 费普通技能 · 暗影刺客 · locked（R846：5 → 4）\")")

# ── R805 蜂蜜：影子猫移速 5 → 2 ───────────────────────────
block("	check(r804_p1 != null and r804_p1.effective_speed() == 6,", 3,
      """	check(r804_p1 != null and r804_p1.effective_speed() == 3,
			"R805 蜂蜜：影子猫移速 2 → 3（R846 从 5 降；实得 %d）"
			% (r804_p1.effective_speed() if r804_p1 != null else -1))
""")
block("	check(r804_p4 != null and r804_p4.effective_speed() == 5 and r804_p4.honey_spd == 0,", 2,
      """	check(r804_p4 != null and r804_p4.effective_speed() == 2 and r804_p4.honey_spd == 0,
			"R805 没蜂蜜：移速保持 2（加成不烤进 CardData 留残留）")
""")
block("	check(r804_cards.get_card(8006).move_speed == 5,", 2,
      """	check(r804_cards.get_card(8006).move_speed == 2,
			"R805 卡库里的影子猫仍是 2 速（R846 从 5 降；蜂蜜没烤进共享 CardData）")
""")


def main():
    raw = io.open(P, "r", encoding="utf-8", newline="").read()
    assert raw.count("\n") == raw.count("\r\n"), "test_engine.gd 不是纯 CRLF"
    lines = raw.replace("\r\n", "\n").split("\n")

    # 从后往前替换，避免行号漂移
    spans = []
    for marker, count, new in BLOCKS:
        idx = [i for i, l in enumerate(lines) if l.startswith(marker)]
        assert len(idx) == 1, "标记命中 %d 次：%r" % (len(idx), marker[:60])
        spans.append((idx[0], count, new))
    spans.sort(key=lambda s: s[0], reverse=True)

    for start, count, new in spans:
        lines[start:start + count] = new.rstrip("\n").split("\n")

    out = "\n".join(lines).replace("\n", "\r\n")
    io.open(P, "w", encoding="utf-8", newline="").write(out)
    print("TEST_ENGINE_OK（%d 段）" % len(spans))


if __name__ == "__main__":
    main()
