# -*- coding: utf-8 -*-
"""R824 测试：改 R822 的「9 / 4 / 5」与试玩版断言，追加 _test_r824。

⚠️ test_engine.gd 是 CRLF **且大多数行之间空一行**；锚点一律先折成 LF 再拼，
   多行块用「切片替换」（找首尾标记）而不是整段字面量，免得被空行数坑。
"""
import io

P = "E:/work/card_rogue/scripts/test_engine.gd"
raw = io.open(P, encoding="utf-8", newline="").read()
assert raw.count("\r\n") > 0 and raw.count("\n") == raw.count("\r\n"), "行尾不是纯 CRLF"
t = raw.replace("\r\n", "\n")


def sub(old, new, tag, expect=1):
    n = t.count(old)
    assert n == expect, "[%s] 命中 %d 次" % (tag, n)
    print("  OK", tag)
    return t.replace(old, new)


# ── ① 两处写死的道具总数 79 → 80 ──
t = sub('check(icon577_src_ok and icon577_repo.all_relics().size() == 79,',
        'check(icon577_src_ok and icon577_repo.all_relics().size() == 80,',
        "R577b 件数 79→80")
t = sub('"R577b 保真锁：79 件道具的 id 都能在 relics.json 源文本里找到',
        '"R577b 保真锁：80 件道具的 id 都能在 relics.json 源文本里找到',
        "R577b 文案")
t = sub('缺陷时钟 6084）")\n\t# ② 取图口',
        '缺陷时钟 6084 / R824 +鸭子闹钟 6085）")\n\t# ② 取图口',
        "R577b 文案补 R824")
t = sub('check(r810_repo.all_relics().size() == 79, "R810 数据层：道具总数 79 件")',
        'check(r810_repo.all_relics().size() == 80, "R824 数据层：道具总数 80 件（+鸭子闹钟 6085）")',
        "R810 总数")

# ── ② R822 池子断言：9 → 10、4 → 5、并集 10 ──
t = sub('	# ── ⑤ 池子分流：9 = 5 + 4，互不重叠 ──',
        '	# ── ⑤ 池子分流：10 = 5 + 5，互不重叠（R824 加的鸭子闹钟 6085 归鸭绅士）──',
        "⑤ 标题")
t = sub('	check(r822_all.size() == 9, "R822 池：二层起始池全量仍是 9 件（实际 %d）" % r822_all.size())',
        '	check(r822_all.size() == 10,\n\n			"R824 池：二层起始池全量 10 件（R822 的 9 + 鸭子闹钟 6085，实际 %d）"\n\n			% r822_all.size())',
        "全量 10")
t = sub('	check(r822_duck.size() == 4, "R822 池：鸭绅士 4 件（实际 %d）" % r822_duck.size())',
        '	check(r822_duck.size() == 5,\n\n			"R824 池：鸭绅士 5 件（含鸭子闹钟，实际 %d）" % r822_duck.size())',
        "鸭绅士 5")
t = sub('	check(r822_duck_pool == r822_duck, "R822 池：遇到鸭绅士时出的就是那 4 件")',
        '	check(r822_duck_pool == r822_duck, "R824 池：遇到鸭绅士时出的就是那 5 件")',
        "duck_pool 文案")
t = sub('	check(r822_union.size() == 9,',
        '	check(r822_union.size() == 10,',
        "并集 10")
t = sub('"R822 池：5 + 4 = 原 9 件，一件没丢（实际 %d）" % r822_union.size())',
        '"R824 池：5 + 5 = 10 件，一件没丢（实际 %d）" % r822_union.size())',
        "并集文案")
t = sub('	##   ② 两位主持人的道具池**互斥**，且并集必须还是原来那 9 件 —— 少一件就是内容凭空蒸发。',
        '	##   ② 两位主持人的道具池**互斥**，且并集必须是二层池全量（R822 是 9 件，R824 起 10 件）\n'
        '	##      —— 少一件就是内容凭空蒸发。',
        "② 注释")

# ── ③ ⑪ 试玩版块：整段换成「也派生、也分流」（切片替换，避开空行数）──
START = "	# ── ⑪ 试玩版：不进鸭绅士，但那 4 件要留在卷卷池发得出去 ──"
END = "	# ── ⑫ 老调用点不受影响"
i = t.find(START)
j = t.find(END)
assert i >= 0 and j > i, "⑪ 块定位失败 i=%d j=%d" % (i, j)
NEW = """	# ── ⑪ 试玩版（R824 店长口径「试玩版改为给鸭绅士」）：主持人与池子都不再例外 ──

	GameBuild.set_test_demo(1)

	check(RunState.layer2_host(424242) == r822_a,

			"R824 试玩版：主持人与正式版同一条派生（不再恒卷卷）")

	check(r822_relics.layer2_ids_for(RunState.LAYER2_HOST_BUNBUN) == r822_bun,

			"R824 试玩版：卷卷池与正式版一致（5 件）")

	check(r822_relics.layer2_ids_for(RunState.LAYER2_HOST_DUCK) == r822_duck_pool,

			"R824 试玩版：鸭绅士池与正式版一致（5 件，含鸭子闹钟）")

	GameBuild.set_test_demo(-1)

"""
t = t[:i] + NEW + t[j:]
print("  OK ⑪ 试玩版块")

# ── ④ 注册 _test_r824 ──
t = sub("	_test_r822()", "	_test_r822()\n\n	_test_r824()", "注册")

# ── ⑤ 追加 _test_r824 ──
NEW_FN = """

func _test_r824() -> void:

	## R824（店长口径）：① 试玩版**改为也出鸭绅士**；② 新增二层鸭绅士道具「鸭子闹钟」6085 ——
	## 每场战斗的第 2 回合抽 1 张卡并获得 1 点费用；第 5 回合起技能伤害 +1。
	##
	## 两条最容易写漏的：
	##   · 6085 归鸭绅士之后，卷卷池必须**不含**它 —— 否则归属白分，两边都抽得到；
	##   · 「第 5 回合起」是**从第 5 回合开始一直有效**，不是「只在第 5 回合」。

	var r824_repo := RelicRepo.load_json()

	var r824_rel: RelicData = r824_repo.get_relic(6085)

	check(r824_rel != null and r824_rel.relic_name == "鸭子闹钟",

			"R824 数据层：6085 鸭子闹钟在库")

	check(r824_rel.kind == "战斗" and r824_rel.source == "二层" and r824_rel.tier == "一般",

			"R824 数据层：战斗类 · 二层来源 · 一般档（实际 %s / %s / %s）"

			% [r824_rel.kind, r824_rel.source, r824_rel.tier])

	check(r824_rel.desc.contains("第 2 回合") and r824_rel.desc.contains("第 5 回合")

			and r824_rel.desc.contains("技能伤害 +1"),

			"R824 文案：写着第 2 回合 / 第 5 回合起技能 +1（%s）" % r824_rel.desc)

	# 常量为唯一数值来源：文案里的 2 / 5 / +1 与引擎常量必须一致

	check(GameEngine.DUCK_ALARM_RELIC_ID == 6085 and GameEngine.DUCK_ALARM_TURN == 2

			and GameEngine.DUCK_ALARM_ENERGY == 1 and GameEngine.DUCK_ALARM_DRAW == 1

			and GameEngine.DUCK_ALARM_SPELL_FROM == 5 and GameEngine.DUCK_ALARM_SPELL == 1,

			"R824 常量：6085 / 第 2 回合 / +1 费 / 抽 1 / 第 5 回合起技能 +1")

	# 图标（每个道具都必须有 relic_icon_<id>.png，缺一张 R577b 就红）

	check(ResourceLoader.exists(UiAssets.relic_icon_path(6085)),

			"R824 素材：relic_icon_6085.png 在包里")

	# ── ① 池子归属：只归鸭绅士；第一层初始池 / 奖励池 / 事件池都不许有它 ──

	check(r824_repo.duck_host_ids().has(6085), "R824 池：鸭子闹钟归鸭绅士")

	check(r824_repo.layer2_ids_for(RunState.LAYER2_HOST_DUCK).has(6085),

			"R824 池：遇到鸭绅士能抽到鸭子闹钟")

	check(not r824_repo.layer2_ids_for(RunState.LAYER2_HOST_BUNBUN).has(6085),

			"R824 池：遇到卷卷没有鸭子闹钟（归属不重叠）")

	check(not r824_repo.initial_ids().has(6085) and not r824_repo.reward_ids().has(6085)

			and not r824_repo.event_ids().has(6085),

			"R824 池：不进第一层初始池 / 奖励池 / 事件池")

	# ── ② 试玩版：6085 在基线里（R814 口径「道具全部登陆」），且鸭绅士在试玩版可达 ──

	check(DemoScope.allows_relic(6085), "R824 试玩版：6085 在 demo_scope 基线里")

	var r824_demo_backup := RunState.run_seed

	GameBuild.set_test_demo(1)

	var r824_demo_host := RunState.layer2_host(424242)

	check(r824_repo.layer2_ids_for(RunState.LAYER2_HOST_DUCK).has(6085),

			"R824 试玩版：鸭绅士池里仍有鸭子闹钟")

	GameBuild.set_test_demo(-1)

	check(r824_demo_host == RunState.layer2_host(424242),

			"R824 试玩版：主持人派生与正式版一致（%d / %d）"

			% [r824_demo_host, RunState.layer2_host(424242)])

	RunState.run_seed = r824_demo_backup

	# ── ③ 引擎：第 1 回合不发，第 2 回合 +1 费 + 多抽 1 张，第 3 回合恢复 ──

	var r824_eng := _new_engine(_ordered_deck(), 40, 40, -1, false)

	r824_eng.self_relics = [6085]

	r824_eng.start_game()

	check(r824_eng.state.energy == FieldState.ENERGY_PER_TURN,

			"R824 引擎：第 1 回合不多给费（实际 %d）" % r824_eng.state.energy)

	check(r824_eng.state.hand.size() == FieldState.HAND_DRAW_PER_TURN,

			"R824 引擎：第 1 回合不多抽（实际 %d）" % r824_eng.state.hand.size())

	r824_eng.end_turn()

	r824_eng.end_turn()

	check(r824_eng.turn_number == 2,

			"R824 引擎：两次 end_turn 后是我方第 2 回合（实际 %d）" % r824_eng.turn_number)

	check(r824_eng.state.energy == FieldState.ENERGY_PER_TURN + 1,

			"R824 引擎：第 2 回合费用 +1（%d + 1，实际 %d）"

			% [FieldState.ENERGY_PER_TURN, r824_eng.state.energy])

	check(r824_eng.state.hand.size() == FieldState.HAND_DRAW_PER_TURN + 1,

			"R824 引擎：第 2 回合多抽 1 张（%d + 1，实际 %d）"

			% [FieldState.HAND_DRAW_PER_TURN, r824_eng.state.hand.size()])

	r824_eng.end_turn()

	r824_eng.end_turn()

	check(r824_eng.state.energy == FieldState.ENERGY_PER_TURN,

			"R824 引擎：第 3 回合不再给费（实际 %d）" % r824_eng.state.energy)

	check(r824_eng.state.hand.size() == FieldState.HAND_DRAW_PER_TURN,

			"R824 引擎：第 3 回合不再多抽（实际 %d）" % r824_eng.state.hand.size())

	# ── ④ 技能伤害：第 3 / 4 回合不加，第 5 回合起 +1 且一直有效 ──

	check(r824_eng._spell_dmg(GameEngine.SIDE_SELF, 10) == 10,

			"R824 技能：第 3 回合仍是 10（实际 %d）"

			% r824_eng._spell_dmg(GameEngine.SIDE_SELF, 10))

	r824_eng.end_turn()

	r824_eng.end_turn()

	check(r824_eng.turn_number == 4 and r824_eng._spell_dmg(GameEngine.SIDE_SELF, 10) == 10,

			"R824 技能：第 4 回合仍是 10（回合 %d）" % r824_eng.turn_number)

	r824_eng.end_turn()

	r824_eng.end_turn()

	check(r824_eng.turn_number == 5,

			"R824 技能：推进到我方第 5 回合（实际 %d）" % r824_eng.turn_number)

	check(r824_eng._spell_dmg(GameEngine.SIDE_SELF, 10) == 11,

			"R824 技能：第 5 回合起 +1（10 → 实际 %d）"

			% r824_eng._spell_dmg(GameEngine.SIDE_SELF, 10))

	r824_eng.end_turn()

	r824_eng.end_turn()

	check(r824_eng.turn_number == 6 and r824_eng._spell_dmg(GameEngine.SIDE_SELF, 10) == 11,

			"R824 技能：第 6 回合仍然 +1（回合 %d）" % r824_eng.turn_number)

	# 对照组：不拿鸭子闹钟 → 第 5 回合也是 10（加成只来自这件道具）

	var r824_ctrl := _new_engine(_ordered_deck(), 40, 40, -1, false)

	r824_ctrl.start_game()

	for _r824_i in 4:

		r824_ctrl.end_turn()

		r824_ctrl.end_turn()

	check(r824_ctrl.turn_number == 5

			and r824_ctrl._spell_dmg(GameEngine.SIDE_SELF, 10) == 10,

			"R824 技能：对照组第 5 回合仍是 10（回合 %d）" % r824_ctrl.turn_number)

	# ── ⑤ 敌方侧不受影响（加成只给己方）──

	check(r824_eng._spell_dmg(GameEngine.SIDE_ENEMY, 10) == 10,

			"R824 技能：敌方技能伤害不吃这件道具（实际 %d）"

			% r824_eng._spell_dmg(GameEngine.SIDE_ENEMY, 10))
"""

assert t.rstrip().endswith("RunState.run_rng.state = r822_rng_state_bak"), "文件尾不是 R822 收尾"
t = t.rstrip("\n") + "\n" + NEW_FN

out = t.replace("\n", "\r\n")
io.open(P, "w", encoding="utf-8", newline="").write(out)
print("WROTE test_engine.gd %d 字节" % len(out))
