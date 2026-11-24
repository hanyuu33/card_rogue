# -*- coding: utf-8 -*-
"""R842 补丁 ⑤ 测试：新增 `_test_r842()` + 注册 + 道具总数 84 → 85。

test_engine.gd 是 CRLF，按 CRLF 写回。
"""
import io

P = "E:/work/card_rogue/scripts/test_engine.gd"

TEST = '''func _test_r842() -> void:
	## R842（店长口径）：新增一层事件「龙石板」——
	##   选项 1「强力的龙」= 卡组一张盟友 / 工事吃附魔「力量 +8」
	##     （`brawn`，事件独有：沿用「伤害 +8」的标记外观，不进商店 / 随机池）；
	##   选项 2「尊贵的龙」= 道具「稀有价值」6090：同名卡最多留 3 张，多出来的随机撕掉，
	##     **每因此效果删除一张卡**失去 5 点生命；会当场致死时不能选。
	var repo := CardRepo.load_json()
	var rrepo := RelicRepo.load_json()
	var r842_sv_deck: Array[int] = RunState.deck_ids.duplicate()
	var r842_sv_mods: Array = RunState.deck_mods.duplicate()
	var r842_sv_hp := RunState.hp
	var r842_sv_max := RunState.max_hp
	var r842_sv_relics: Array[int] = RunState.relics.duplicate()
	var r842_sv_seed := RunState.run_seed
	var r842_sv_layer := RunState.current_layer
	var r842_sv_node := RunState.current_node_id

	# ── ① 附魔数据层：brawn 定义齐，且**只有盟友 / 工事**能吃 ──
	check(CardData.ENCHANT_DEFS.has("brawn")
			and CardData.enchant_name("brawn") == "力量 +8"
			and CardData.enchant_icon_name("brawn") == "shop_icon_damage"
			and CardData.enchant_color("brawn").is_equal_approx(Color("f08a5a")),
			"R842 附魔：brawn = 力量 +8 / 沿用「伤害 +8」的图标与环色")
	check(CardData.ENCHANT_DEFS.size() == 8 and not CardData.random_enchant_ids().has("brawn"),
			"R842 附魔：附魔表 7 → 8，且事件专属不进随机池（实际 %d 种：%s）"
			% [CardData.ENCHANT_DEFS.size(), str(CardData.random_enchant_ids())])
	check(RunState.enchant_ok("brawn", repo.get_card(8003), 9999)
			and RunState.enchant_ok("brawn", repo.get_card(8001), 9999),
			"R842 附魔：盟友（树人 8003）与工事（木栅栏 8001）都能附")
	check(not RunState.enchant_ok("brawn", repo.get_card(9003), 9999)
			and not RunState.enchant_ok("brawn", repo.get_card(9180), 9999),
			"R842 附魔：技能卡 / 效果卡附不上（力量对它们没有消费点）")

	# ── ② 附魔落地：只动选中那一张 + 同一张不能吃第二个 ──
	RunState.deck_ids = [8003, 8003]
	RunState.deck_mods = [{}, {}]
	var r842_p0 := repo.get_card(8003).power
	check(RunState.enchant_deck_card(0, RunState.enchant_mod("brawn")),
			"R842 附魔：enchant_deck_card 接受 brawn")
	var r842_c := RunState.card_with_mod(repo, 0)
	check(r842_c != null and r842_c.power == r842_p0 + 8 and r842_c.enchant == "brawn"
			and r842_c.has_enchant() and r842_c.effect_text.contains("【附魔】力量 +8"),
			"R842 附魔：+8 烤进 power（%d → %d）、记下附魔 id、卡面补标注"
			% [r842_p0, r842_c.power if r842_c != null else -1])
	var r842_c2 := RunState.card_with_mod(repo, 1)
	check(r842_c2 != null and r842_c2.power == r842_p0 and r842_c2.enchant == "",
			"R842 附魔：没选中的那张一字不动（power 仍 %d）" % [r842_p0])
	check(not RunState.enchant_ok("brawn", r842_c, 0),
			"R842 附魔：同一张卡不能吃第二个附魔")
	check(RunState.strip_enchant(r842_c) and r842_c.power == r842_p0 and r842_c.enchant == "",
			"R842 附魔：strip_enchant 能原样撤回（复制术不继承附魔那条路还能走）")

	# ── ③ 稀有价值：只数「因此效果删掉」的卡，且随机顺序是派生的 ──
	RunState.deck_ids = [8003, 8003, 8003, 8003, 8003, 9003, 9003, 9003, 9003]
	RunState.deck_mods = [{}, {}, {}, {}, {}, {}, {}, {}, {}]
	RunState.hp = 30
	RunState.max_hp = 40
	check(RunState.rare_value_damage(repo) == 15,
			"R842 稀有价值：5 张同名 + 4 张同名 → 撕 3 张 = 15 点（实际 %d）"
			% RunState.rare_value_damage(repo))
	var r842_plan_a := RunState.rare_value_targets(repo)
	var r842_plan_b := RunState.rare_value_targets(repo)
	check(r842_plan_a == r842_plan_b and r842_plan_a.size() == 3,
			"R842 稀有价值：同一局同一间房删哪几张是派生的（重进换不了，%s）" % str(r842_plan_a))
	check(not RunState.rare_value_lethal(repo),
			"R842 稀有价值：30 血挨 15 点还剩 15 → 可以选")
	RunState.hp = 15
	check(RunState.rare_value_lethal(repo),
			"R842 稀有价值：15 血撞 15 点伤害 → 会当场倒下，这个选项不能选")
	RunState.hp = 16
	check(not RunState.rare_value_lethal(repo),
			"R842 稀有价值：16 血刚好活下来（判据是 <= 0 才算死）")

	RunState.hp = 30
	var r842_res := RunState.rare_value_prune(repo)
	check(bool(r842_res.get("ok", false)) and (r842_res["deleted"] as Array).size() == 3
			and int(r842_res["damage"]) == 15 and RunState.hp == 15,
			"R842 稀有价值：撕 3 张 → 失去 15 点（现 %d / %d）" % [RunState.hp, RunState.max_hp])
	check(RunState.deck_ids.size() == 6,
			"R842 稀有价值：卡组 9 → 6 张（实际 %d）" % RunState.deck_ids.size())
	var r842_names := {}
	for cid: int in RunState.deck_ids:
		var nm := repo.get_card(cid).card_name
		r842_names[nm] = int(r842_names.get(nm, 0)) + 1
	check(int(r842_names.get("树人", 0)) == 3 and int(r842_names.get("火焰箭", 0)) == 3,
			"R842 稀有价值：每个名字正好剩 3 张（%s）" % str(r842_names))

	# 会致死时**结算口**也要拒绝（不能只靠按钮置灰）
	RunState.deck_ids = [8003, 8003, 8003, 8003]
	RunState.deck_mods = [{}, {}, {}, {}]
	RunState.hp = 5
	var r842_block := RunState.rare_value_prune(repo)
	check(not bool(r842_block.get("ok", true)) and RunState.deck_ids.size() == 4
			and RunState.hp == 5,
			"R842 稀有价值：会致死的结算被拒 —— 一张不删、血不动")

	# 带锁的卡（月亮 9180）不参与撕卡
	RunState.deck_ids = [9180, 9180, 9180, 9180]
	RunState.deck_mods = [{}, {}, {}, {}]
	RunState.hp = 30
	check(RunState.rare_value_targets(repo).is_empty() and RunState.rare_value_damage(repo) == 0,
			"R842 稀有价值：带 no_remove 的卡不进候选（与 delete_deck_card 同一道闸）")

	# ── ④ 道具与事件登记 ──
	var r842_rel := rrepo.get_relic(6090)
	check(r842_rel != null and r842_rel.relic_name == "稀有价值"
			and r842_rel.kind == "即时" and r842_rel.source == "事件"
			and r842_rel.tier == "一般",
			"R842 数据：6090 稀有价值（即时 · 事件 · 一般）")
	check(r842_rel != null and r842_rel.desc.contains("3") and r842_rel.desc.contains("5"),
			"R842 文案：道具描述写着 3 张 / 5 点（%s）" % (r842_rel.desc if r842_rel else ""))
	check(RunState.RARE_VALUE_ID == 6090 and RunState.RARE_VALUE_MAX_COPIES == 3
			and RunState.RARE_VALUE_LOSS == 5,
			"R842 常量：6090 / 上限 3 张 / 每张 5 点")
	check(not rrepo.reward_ids().has(6090) and not rrepo.initial_ids().has(6090)
			and not rrepo.layer2_ids().has(6090),
			"R842 池：事件专属 —— 奖励 / 初始 / 二层起始都不进")
	check(DemoScope.allows_relic(6090), "R842 试玩版：6090 在 demo_scope 基线里（道具全登陆）")

	var r842_w1 := GameLayers.event_weights(GameLayers.LAYER_DEFAULT)
	var r842_w2 := GameLayers.event_weights(GameLayers.LAYER_TWO)
	check(r842_w1.has("dragon_slab") and int(r842_w1["dragon_slab"]) > 0,
			"R842 事件：第一层事件池含龙石板（权重 %d）" % int(r842_w1.get("dragon_slab", 0)))
	check(not r842_w2.has("dragon_slab"),
			"R842 事件：第二层不登记（第一层专属，别顺手抄过去）")
	check(str(GameLayers.EVENT_NAMES.get("dragon_slab", "")) == "龙石板",
			"R842 事件：EVENT_NAMES 有中文名（日志 / 界面读它）")
	check(DemoScope.allows_event("dragon_slab"), "R842 试玩版：事件在 demo_scope 白名单里")

	# ── ⑤ 源码口径（导出包里 .gd 是 binary tokens → 必须走 check_src）──
	var r842_es := FileAccess.get_file_as_string("res://scripts/event_scene.gd")
	check_src(r842_es.contains("const DRAGON_SLAB_RELIC_ID := 6090")
			and r842_es.contains('const DRAGON_ENCHANT_ID := "brawn"'),
			"R842 事件：道具 6090 / 附魔 brawn 的常量对")
	check_src(r842_es.contains('if _is_dragon_slab():\\n\\t\\treturn "dragon_slab"'),
			"R842 事件：_kind() 认 dragon_slab（漏了会点亮休息处的篝火背景）")
	check_src(r842_es.contains("and not _is_dragon_slab()"),
			"R842 事件：_is_treasure() 兜底排除 dragon_slab")
	check_src(r842_es.contains("or _is_dragon_slab() \\\\"),
			"R842 事件：_refresh() 白名单含 dragon_slab")
	check_src(r842_es.contains("RunState.rare_value_lethal(CardRepo.load_json())")
			and r842_es.contains("RunState.rare_value_prune(repo)"),
			"R842 事件：置灰与结算读同一套判据（lethal 先拦，prune 再拦）")

	# ── ⑥ 四语文案齐 ──
	for r842_code in ["zh_canonical", "en", "ja", "es"]:
		var r842_nc := FileAccess.get_file_as_string("res://i18n/noncard_%s.json" % r842_code)
		check_src(r842_nc.contains('"6090"'), "R842 文案：noncard_%s 有 6090" % r842_code)
		var r842_nar := FileAccess.get_file_as_string("res://i18n/narrative_%s.json" % r842_code)
		check_src(r842_nar.contains('"dragon_slab"') and r842_nar.contains("DRAGON_SLAB_DESC"),
				"R842 文案：narrative_%s 有龙石板长文" % r842_code)
		var r842_ui := FileAccess.get_file_as_string("res://i18n/event_ui_%s.json" % r842_code)
		check_src(r842_ui.contains("NOBLE_GAINED") and r842_ui.contains("LETHAL_DISABLED"),
				"R842 文案：event_ui_%s 有选项 / 结果 key" % r842_code)
	var r842_ui_en := FileAccess.get_file_as_string("res://i18n/event_ui_en.json")
	check_src(r842_ui_en.contains("Power +8") and r842_ui_en.contains("Rare Value"),
			"R842 文案：英文复用属术语「Power +8」与道具名「Rare Value」")

	# ── 还原 ──
	RunState.deck_ids = r842_sv_deck
	RunState.deck_mods = r842_sv_mods
	RunState.hp = r842_sv_hp
	RunState.max_hp = r842_sv_max
	RunState.relics = r842_sv_relics
	RunState.run_seed = r842_sv_seed
	RunState.current_layer = r842_sv_layer
	RunState.current_node_id = r842_sv_node


'''


def main():
    with io.open(P, "rb") as f:
        s = f.read().decode("utf-8")
    assert s.count("\r\n") > 0

    blob = TEST.replace("\n", "\r\n")
    anchor = "func _test_r835() -> void:"
    assert s.count(anchor) == 1, s.count(anchor)
    s = s.replace(anchor, blob + anchor, 1)

    call = "\t_test_r833()\r\n"
    assert s.count(call) == 1, s.count(call)
    s = s.replace(call, "\t_test_r833()\r\n\t_test_r842()\r\n", 1)

    # 道具总数 84 → 85（四处件数断言）
    pairs = [
        ("check(icon577_src_ok and icon577_repo.all_relics().size() == 84,",
         "check(icon577_src_ok and icon577_repo.all_relics().size() == 85,"),
        ('"R577b 保真锁：84 件道具的 id 都能在 relics.json 源文本里找到',
         '"R577b 保真锁：85 件道具的 id 都能在 relics.json 源文本里找到'),
        ("R835 +空故事书 6089）\")", "R835 +空故事书 6089 / R842 +稀有价值 6090）\")"),
        ('check(r810_repo.all_relics().size() == 84, "R824 数据层：道具总数 84 件',
         'check(r810_repo.all_relics().size() == 85, "R824 数据层：道具总数 85 件'),
        ("check(r834_demo_all == 84,", "check(r834_demo_all == 85,"),
        ('"R829 试玩版：demo 下 all_relics 仍是 84（道具档「全部登陆」）")',
         '"R829 试玩版：demo 下 all_relics 仍是 85（道具档「全部登陆」）")'),
        ("check(r835_demo_init.has(6089) and r835_demo_start1.has(6089) and r835_demo_all == 84,",
         "check(r835_demo_init.has(6089) and r835_demo_start1.has(6089) and r835_demo_all == 85,"),
        ('"R835 试玩版：demo 下初始池（%d 件）与第一层起点池都含 6089，all_relics 仍 84"',
         '"R835 试玩版：demo 下初始池（%d 件）与第一层起点池都含 6089，all_relics 仍 85"'),
    ]
    for old, new in pairs:
        o = old.replace("\n", "\r\n")
        n = new.replace("\n", "\r\n")
        assert s.count(o) == 1, "锚点 %d 次：%r" % (s.count(o), old[:50])
        s = s.replace(o, n)

    with io.open(P, "wb") as f:
        f.write(s.encode("utf-8"))
    print("OK test_engine.gd")


main()
