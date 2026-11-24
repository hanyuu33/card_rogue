# -*- coding: utf-8 -*-
"""R805：test_engine.gd 加诅咒娃娃 / 诡异洋房测试，并同步三处计数。保持 CRLF。"""
import io

P = "E:/work/card_rogue/scripts/test_engine.gd"
d = open(P, "rb").read().decode("utf-8")
assert "\r\n" in d
crlf0 = d.count("\r\n")


def rep(old, new, cnt=1):
    global d
    o = old.replace("\n", "\r\n")
    n = new.replace("\n", "\r\n")
    assert d.count(o) == cnt, "锚点命中 %d 次（应 %d）：%r" % (d.count(o), cnt, old[:70])
    d = d.replace(o, n)


# ① 图鉴总数 336 → 337
rep('check(repo.all_cards().size() == 336,', 'check(repo.all_cards().size() == 337,')
rep('"图鉴 = 336 张（R800 玩家 +2：余音 9274',
    '"图鉴 = 337 张（R805 玩家 +1：诅咒娃娃 9276（0 费诅咒 · 不可打出 · 「保存」· 事件「诡异洋房」的代价，rarity 6 不进随机池）；R800 玩家 +2：余音 9274')

# ② 玩家图鉴 258 → 259
rep('（期望 258 / 78（R800 玩家 +2：余音 9274 / 音符 9275',
    '（期望 259 / 78（R805 玩家 +1：诅咒娃娃 9276；R800 玩家 +2：余音 9274 / 音符 9275')

# ③ 第二层事件池 15 → 16
rep('\tcheck(l2_ev_kinds.size() == 15 and l2_ev_kinds.has("smith") \\',
    '\tcheck(l2_ev_kinds.size() == 16 and l2_ev_kinds.has("smith") \\')
rep('\t\t\tand l2_ev_kinds.has("flyer") and not l2_ev_kinds.has("statue"),',
    '\t\t\tand l2_ev_kinds.has("flyer") and l2_ev_kinds.has("haunted_house") \\\n'
    '\t\t\tand not l2_ev_kinds.has("statue"),')
rep('+ R473 武术大师 + R555 飞行器 = 15 种子类型（R573 删除蓝色大肥鱼；R754 加奇异雕像；R763d 雕像挪去第一层；R794 +巧克力工厂）',
    '+ R473 武术大师 + R555 飞行器 + R805 诡异洋房 = 16 种子类型（R573 删除蓝色大肥鱼；R754 加奇异雕像；R763d 雕像挪去第一层；R794 +巧克力工厂；R805 +诡异洋房）')

# ④ 调用点
rep('\t_test_r800()\n\n\tprint("== 结果：',
    '\t_test_r800()\n\t_test_r805()\n\n\tprint("== 结果：')

# ⑤ 测试函数本体，插在 _test_r794 之前
BODY = '''func _test_r805() -> void:
	## R805：新诅咒「诅咒娃娃」9276 + 第二层事件「诡异洋房」haunted_house。
	##   · 诅咒娃娃：不可打出 · 带「保存」（回合结束不弃）· 回合结束自己受 3 伤 ·
	##     回合开始时它若在弃牌区就自己爬回手牌（丢出去也甩不掉）。
	##   · 诡异洋房：探索 = 一件随机**传奇**道具 + 一组**史诗**卡牌，当场开奖励页领取
	##     （直连 `_reward_panel.open()`，**不经过战斗胜利面板**）＋ 强制一张诅咒娃娃入组。
	var r805_repo := CardRepo.load_json()
	var r805_doll: CardData = r805_repo.get_card(9276)

	# ① 数据层
	check(r805_doll != null and r805_doll.is_curse() and r805_doll.unplayable
			and r805_doll.rarity == 6 and r805_doll.cost == 0,
			"R805 数据层：诅咒娃娃 9276 = 诅咒卡 · 不可打出 · 0 费 · rarity 6")
	check(r805_doll != null and r805_doll.has_affix("保存"),
			"R805 数据层：诅咒娃娃带「保存」——回合结束不弃，常驻手牌")
	var r805_in_pool := false
	for c: CardData in r805_repo.reward_pool():
		if c.id == 9276:
			r805_in_pool = true
	check(not r805_in_pool,
			"R805 数据层：诅咒娃娃不进随机奖励池（只能从事件拿，不许从三选一刷出来）")

	# ② 回合结束：手上有它 → 自己受 3 点伤害
	RunState.relics = []
	var r805_e1 := _new_engine([], 40, 40)
	r805_e1.state.hand.clear()
	r805_e1.state.hand.append(CardData.from_dict(r805_doll.to_dict()))
	r805_e1._curse_doll_tick()
	check(r805_e1.state.hp_self == 37,
			"R805 诅咒娃娃：回合结束手上一张 → 自己受 3 伤（40 → %d）" % r805_e1.state.hp_self)

	# ③ 走 end_turn() 的真接入点（只测单函数证明不了接线）
	var r805_e2 := _new_engine([], 40, 40)
	r805_e2.state.hand.clear()
	r805_e2.state.hand.append(CardData.from_dict(r805_doll.to_dict()))
	r805_e2.end_turn()
	check(r805_e2.state.hp_self == 37,
			"R805 诅咒娃娃：接在 end_turn 上同样扣 3（40 → %d）" % r805_e2.state.hp_self)
	var r805_kept := false
	for c: CardData in r805_e2.state.hand:
		if c.id == 9276:
			r805_kept = true
	check(r805_kept,
			"R805 诅咒娃娃：「保存」生效 —— 回合结束没被弃掉，仍在手牌里继续扣血")

	# ④ 同名多张各算一次
	var r805_e3 := _new_engine([], 40, 40)
	r805_e3.state.hand.clear()
	r805_e3.state.hand.append(CardData.from_dict(r805_doll.to_dict()))
	r805_e3.state.hand.append(CardData.from_dict(r805_doll.to_dict()))
	r805_e3._curse_doll_tick()
	check(r805_e3.state.hp_self == 34,
			"R805 诅咒娃娃：手上两张 → 6 点伤害（40 → %d）" % r805_e3.state.hp_self)

	# ⑤ 回合开始：它在弃牌区 → 回手
	var r805_e4 := _new_engine([], 40, 40)
	r805_e4.state.hand.clear()
	r805_e4.state.discard.clear()
	r805_e4.state.discard.append(CardData.from_dict(r805_doll.to_dict()))
	r805_e4._curse_doll_return()
	var r805_back := 0
	for c: CardData in r805_e4.state.hand:
		if c.id == 9276:
			r805_back += 1
	check(r805_back == 1 and r805_e4.state.discard.is_empty(),
			"R805 诅咒娃娃：回合开始它在弃牌区 → 自己爬回手牌（丢出去也甩不掉）")

	# ⑥ 手牌满 → 留在弃牌区（不消失、不破上限；下个回合再试）
	var r805_e5 := _new_engine([], 40, 40)
	r805_e5.state.hand.clear()
	r805_e5.state.discard.clear()
	var r805_filler: CardData = r805_repo.get_card(1051)
	for _i in FieldState.HAND_LIMIT:
		r805_e5.state.hand.append(CardData.from_dict(r805_filler.to_dict()))
	r805_e5.state.discard.append(CardData.from_dict(r805_doll.to_dict()))
	r805_e5._curse_doll_return()
	var r805_still := 0
	for c: CardData in r805_e5.state.discard:
		if c.id == 9276:
			r805_still += 1
	check(r805_still == 1 and r805_e5.state.hand.size() == FieldState.HAND_LIMIT,
			"R805 诅咒娃娃：手牌满时留在弃牌区（不静默消失，也不突破 HAND_LIMIT）")

	# ⑦ 事件注册：第二层 16 种、显示名
	var r805_l2 := GameLayers.event_kinds(GameLayers.LAYER_TWO)
	check(r805_l2.has("haunted_house") and r805_l2.size() == 16,
			"R805 事件：诡异洋房登记在第二层（事件池 %d 种）" % r805_l2.size())
	check(GameLayers.event_name("haunted_house") == "诡异洋房",
			"R805 事件：显示名「诡异洋房」")

	# ⑧ 必定传奇：`roll_legendary_relic()` 只从传奇档取
	RunState.relics = []
	var r805_lid := RunState.roll_legendary_relic()
	var r805_rel := RelicRepo.load_json().get_relic(r805_lid) if r805_lid > 0 else null
	check(r805_rel != null and r805_rel.is_legendary(),
			"R805 事件：`roll_legendary_relic()` 必定从传奇档取（拿到 %d / %s）" % [
				r805_lid, r805_rel.tier if r805_rel != null else "空"])

	# ⑨ 事件源码契约：探索 = 史诗卡牌 + 诅咒入组 + 直开奖励页
	var r805_src := FileAccess.get_file_as_string("res://scripts/event_scene.gd")
	var r805_at := r805_src.find("func _explore_haunted_house()")
	var r805_body := ""
	if r805_at >= 0:
		var r805_end := r805_src.find("\\nfunc ", r805_at + 10)
		r805_body = r805_src.substr(r805_at,
				(r805_end - r805_at) if r805_end > r805_at else 2600)
	check_src(r805_body.contains("queue_card_reward(\\"epic\\"")
			and r805_body.contains("add_card(HAUNTED_CURSE_ID)")
			and r805_body.contains("_reward_panel.open()"),
			"R805 事件：探索 = 史诗卡牌三选一 + 诅咒娃娃入组 + 当场开奖励页")
	check_src(not ("_present_win_panel" in r805_src),
			"R805 事件：奖励页直连 —— 事件页根本不碰战斗胜利面板（没有「战斗胜利」那一屏）")

'''

rep('func _test_r794() -> void:',
    BODY + 'func _test_r794() -> void:')

crlf1 = d.count("\r\n")
io.open(P, "wb").write(d.encode("utf-8"))
print("ok crlf %d -> %d (+%d)" % (crlf0, crlf1, crlf1 - crlf0))
