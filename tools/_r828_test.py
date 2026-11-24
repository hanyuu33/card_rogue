# -*- coding: utf-8 -*-
# R828 test_engine.gd 补丁：翻面写死件数 + 新增 _test_r828
import io

P = 'scripts/test_engine.gd'
CRLF = '\r\n'   # test_engine.gd 是 CRLF

def rep(old, new):
    raw = io.open(P, 'r', encoding='utf-8', newline='').read()
    n = raw.count(old)
    assert n == 1, '锚点 count=%d: %r' % (n, old[:90])
    raw = raw.replace(old, new)
    io.open(P, 'w', encoding='utf-8', newline='').write(raw)
    print('OK  ' + old[:60].replace(CRLF, '\\n'))

# ── 1. R826 音乐盒 ④：2 → 3 ──
rep('r826_e.state.deck.size() == 2 and r826_note_in_deck == 2,',
    'r826_e.state.deck.size() == 3 and r826_note_in_deck == 3,')
rep('"R826 引擎：音乐盒加 2 张音符进抽牌库（deck %d / 音符 %d）"',
    '"R826 引擎：音乐盒加 3 张音符进抽牌库（deck %d / 音符 %d）"')

# ── 2. R826 La ⑩：抽3→4、力量+3→+2 ──
rep('# ── ⑩ La：抽 3 张各 -1 费；盟友 / 工事力量 +3 ──',
    '# ── ⑩ La：抽 4 张各 -1 费；盟友 / 工事力量 +2 ──')
rep('if int(e_la.state.card_discount.get(c, 0)) != 1 or c.power != 6:',
    'if int(e_la.state.card_discount.get(c, 0)) != 1 or c.power != 5:')
rep('check(la_farmers == 3 and la_ok,',
    'check(la_farmers == 4 and la_ok,')
rep('"R826 La：抽 3 张农民，各 -1 费、力量 +3（%d 张 / ok=%s）"',
    '"R826 La：抽 4 张农民，各 -1 费、力量 +2（%d 张 / ok=%s）"')
rep('\tfor _i in 3:' + CRLF + '\t\te_la.state.deck.append(CardData.from_dict(repo.get_card(8003).to_dict()))',
    '\tfor _i in 4:' + CRLF + '\t\te_la.state.deck.append(CardData.from_dict(repo.get_card(8003).to_dict()))')

# ── 3. R822 ⑤ 池子分流：11→12、5→6 ──
rep('# ── ⑤ 池子分流：11 = 6 + 5，互不重叠（R824 鸭子闹钟 6085 归鸭绅士 / R826 音乐盒 6086 归卷卷）──',
    '# ── ⑤ 池子分流：12 = 6 + 6，互不重叠（R824 鸭子闹钟 6085 / R828 这是礼帽 6087 归鸭绅士，R826 音乐盒 6086 归卷卷）──')
rep('check(r822_all.size() == 11,',
    'check(r822_all.size() == 12,')
rep('"R824 池：二层起始池全量 11 件（R822 的 9 + 鸭子闹钟 6085 + 音乐盒 6086，实际 %d）"',
    '"R824 池：二层起始池全量 12 件（R822 的 9 + 鸭子闹钟 6085 + 音乐盒 6086 + 这是礼帽 6087，实际 %d）"')
rep('check(r822_duck.size() == 5,',
    'check(r822_duck.size() == 6,')
rep('"R824 池：鸭绅士 5 件（含鸭子闹钟，实际 %d）" % r822_duck.size())',
    '"R824 池：鸭绅士 6 件（含鸭子闹钟 + 礼帽，实际 %d）" % r822_duck.size())')
rep('check(r822_duck_pool == r822_duck, "R824 池：遇到鸭绅士时出的就是那 5 件")',
    'check(r822_duck_pool == r822_duck, "R824 池：遇到鸭绅士时出的就是那 6 件")')
rep('check(r822_union.size() == 11,',
    'check(r822_union.size() == 12,')
rep('"R824 池：6 + 5 = 11 件，一件没丢（实际 %d）" % r822_union.size())',
    '"R824 池：6 + 6 = 12 件，一件没丢（实际 %d）" % r822_union.size())')

# ── 4. R822 ⑥ 归属白名单：礼帽 6087 是「非鸭但归鸭绅士」的特例 ──
rep('\t\tif r822_rel2 == null or not r822_rel2.relic_name.contains("鸭"):',
    '\t\tif r822_rel2 == null or (not r822_rel2.relic_name.contains("鸭") and r822_id4 != GameEngine.TOP_HAT_RELIC_ID):')

# ── 5. R577b 保真锁：81 → 82 ──
rep('check(icon577_src_ok and icon577_repo.all_relics().size() == 81,',
    'check(icon577_src_ok and icon577_repo.all_relics().size() == 82,')
rep('"R577b 保真锁：81 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086）")',
    '"R577b 保真锁：82 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R828 +这是礼帽 6087）")')

# ── 6. R824 数据层（R810 里）：81 → 82 ──
rep('check(r810_repo.all_relics().size() == 81, "R824 数据层：道具总数 81 件（+鸭子闹钟 6085 / R826 音乐盒 6086）")',
    'check(r810_repo.all_relics().size() == 82, "R824 数据层：道具总数 82 件（+鸭子闹钟 6085 / R826 音乐盒 6086 / R828 这是礼帽 6087）")')

# ── 7. 注册区：_test_r826 后追加 _test_r828 ──
rep('\t_test_r826()' + CRLF + CRLF + '\tprint("== 结果："',
    '\t_test_r826()' + CRLF + '\t_test_r828()' + CRLF + CRLF + '\tprint("== 结果："')

# ── 8. 文件末尾追加 _test_r828 函数体 ──
tail = '''"R826 Si：随机 7×7 = 49 伤击破 40 血敌人")'''
new_func = '''"R826 Si：随机 7×7 = 49 伤击破 40 血敌人")


func _test_r828() -> void:
	## R828（店长口径）：① 音乐盒 6086 从「2 张」改「3 种」；② La 9282 从「抽 3 +3 力」改「抽 4 +2 力」；
	## ③ 新增二层鸭绅士道具「这是礼帽」6087 —— 己方盟友/工事死亡 → 洗回抽牌库 + 本局费用 -2 + 获得次元。
	var repo := CardRepo.load_json()
	var rrepo := RelicRepo.load_json()

	# ── ① 数据层：音乐盒 3 种 / La 抽4+2 / 礼帽在库 ──
	check(rrepo.get_relic(6086).desc.contains("3 种"),
			"R828 数据：音乐盒 desc 写「3 种」（%s）" % rrepo.get_relic(6086).desc)
	check(repo.get_card(9282).effect_text.contains("抽 4")
			and repo.get_card(9282).effect_text.contains("力量 +2"),
			"R828 数据：La 写「抽 4」「力量 +2」（%s）" % repo.get_card(9282).effect_text)
	var r828_hat := rrepo.get_relic(6087)
	check(r828_hat != null and r828_hat.relic_name == "这是礼帽"
			and r828_hat.kind == "战斗" and r828_hat.source == "二层" and r828_hat.tier == "一般",
			"R828 数据：6087 这是礼帽（战斗 · 二层 · 一般）")
	check(r828_hat.desc.contains("洗回") and r828_hat.desc.contains("次元")
			and r828_hat.desc.contains("费用 -2"),
			"R828 文案：写着洗回 / 次元 / 费用 -2（%s）" % r828_hat.desc)
	check(GameEngine.TOP_HAT_RELIC_ID == 6087 and GameEngine.TOP_HAT_DISCOUNT == 2,
			"R828 常量：6087 / -2 费")

	# ── ② 池子：礼帽归鸭绅士，不进卷卷 / 初始 / 奖励 / 事件 ──
	check(rrepo.layer2_ids().has(6087), "R828 池：礼帽在二层起始池")
	check(rrepo.duck_host_ids().has(6087), "R828 池：礼帽归鸭绅士")
	check(rrepo.layer2_ids_for(RunState.LAYER2_HOST_DUCK).has(6087),
			"R828 池：遇到鸭绅士能抽到礼帽")
	check(not rrepo.layer2_ids_for(RunState.LAYER2_HOST_BUNBUN).has(6087),
			"R828 池：卷卷没有礼帽（归属不重叠）")
	check(not rrepo.initial_ids().has(6087) and not rrepo.reward_ids().has(6087)
			and not rrepo.event_ids().has(6087), "R828 池：不进初始 / 奖励 / 事件池")
	check(DemoScope.allows_relic(6087), "R828 试玩版：6087 在 demo_scope 基线里")

	# ── ③ 引擎：礼帽 —— 己方盟友死亡 → 洗回抽牌库 + 本局 -2 费 + 次元 ──
	var r828_e := _new_engine([], 40, 40, -1, false)
	r828_e.self_relics = [6087]
	var r828_ally := r828_e.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
			Vector2i(0, 0), GameEngine.SIDE_SELF)
	check(r828_ally != null, "R828 礼帽：树人（盟友）成功上场")
	r828_ally.health = 0
	r828_e._destroy_dead()
	var r828_hat_back := 0
	var r828_hat_cut := 0
	for c in r828_e.state.deck:
		if c.id == 8003 and c.has_affix(GameEngine.AFFIX_DIMENSION):
			r828_hat_back += 1
			if int(r828_e.state.card_discount.get(c, 0)) == 2:
				r828_hat_cut += 1
	check(r828_hat_back == 1 and r828_hat_cut == 1,
			"R828 礼帽：盟友死亡洗回抽牌库并带次元、-2 费（deck 里 %d 张 / %d 张 -2 费）"
			% [r828_hat_back, r828_hat_cut])

	# ── ④ 不带礼帽 → 盟友死亡进弃牌区（对照）──
	var r828_e2 := _new_engine([], 40, 40, -1, false)
	r828_e2.self_relics = []
	var r828_ally2 := r828_e2.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
			Vector2i(0, 0), GameEngine.SIDE_SELF)
	r828_ally2.health = 0
	r828_e2._destroy_dead()
	check(r828_e2.state.discard.size() == 1 and r828_e2.state.deck.is_empty(),
			"R828 礼帽：不带礼帽盟友进弃牌区（discard %d / deck %d）"
			% [r828_e2.state.discard.size(), r828_e2.state.deck.size()])

	# ── ⑤ 工事也触发 ──
	var r828_e3 := _new_engine([], 40, 40, -1, false)
	r828_e3.self_relics = [6087]
	var r828_fort := r828_e3.state.place(CardData.from_dict(repo.get_card(8001).to_dict()),
			Vector2i(0, 0), GameEngine.SIDE_SELF)
	r828_fort.health = 0
	r828_e3._destroy_dead()
	var r828_fort_back := 0
	for c in r828_e3.state.deck:
		if c.id == 8001 and c.has_affix(GameEngine.AFFIX_DIMENSION):
			r828_fort_back += 1
	check(r828_fort_back == 1, "R828 礼帽：工事死亡也洗回抽牌库并带次元（%d）" % r828_fort_back)
'''
raw = io.open(P, 'r', encoding='utf-8', newline='').read()
assert raw.count(tail) == 1, '文件末尾锚点 count=%d' % raw.count(tail)
raw = raw.replace(tail, new_func)
io.open(P, 'w', encoding='utf-8', newline='').write(raw)
print('OK  追加 _test_r828 函数体')

print('\ntest_engine 补丁完成')
