# -*- coding: utf-8 -*-
"""R778b：test_engine.gd 断言更新（数值 / 池子 / 关卡档位 / 构装体改名 / 9133 机制 / 灰烬龙战吼下线）。"""
import io
import sys

ROOT = "E:/work/card_rogue/"
P = ROOT + "scripts/test_engine.gd"

s = io.open(P, "r", encoding="utf-8", newline="").read()
assert s.count("\n") == s.count("\r\n")
s = s.replace("\r\n", "\n")


def rep(old, new, tag, expect=1):
    global s
    n = s.count(old)
    if n != expect:
        print("FAIL[%s] count=%d (expect %d)" % (tag, n, expect))
        sys.exit(1)
    s = s.replace(old, new)
    print("OK %s (x%d)" % (tag, n))


def rep_span(start_marker, end_marker, new, tag):
    """把 [start_marker 起点 .. end_marker 之后] 整段换掉。"""
    global s
    i = s.index(start_marker)
    j = s.index(end_marker, i) + len(end_marker)
    s = s[:i] + new + s[j:]
    print("OK %s（替换 %d 字符）" % (tag, j - i))


# ============ 1. 数值断言 ============
rep('and nc_archer.health == 18 and nc_archer.attack_range == 2',
    'and nc_archer.health == 15 and nc_archer.attack_range == 2',
    "鸭子弓手 health 断言")
rep('"鸭子弓手：怪物 3/18 程2 速1")', '"鸭子弓手：怪物 3/15 程2 速1（R778 血 18→15）")',
    "鸭子弓手 消息")

rep('and (lvl_ak.get("enemy_units", [])[0][3] as int) == 18',
    'and (lvl_ak.get("enemy_units", [])[0][3] as int) == 15',
    "弓手与骑士 单位血量")
rep('"弓手与骑士：弓手 3/18、骑士 3/30")', '"弓手与骑士：弓手 3/15、骑士 3/30（R778 弓手血 18→15）")',
    "弓手与骑士 消息")

rep('and cap.health == 55 and cap.attack_range == 1', 'and cap.health == 50 and cap.attack_range == 1',
    "鸭子队长 health 断言")
rep('"鸭子队长：怪物 6/55 程1 速1 行动2次（R449 攻 −1 / 血 +5）")',
    '"鸭子队长：怪物 6/50 程1 速1 行动2次（R449 攻 −1 / 血 +5；R778 血 55→50）")',
    "鸭子队长 消息")

# ============ 2. 池子数量 ============
rep('check(GameLevels.elite_pool().size() == 6,\n\n\t\t\t"第一层精英池 6 关（精简×3 + 精难×3：R158 鸭子窑上调进第一层精英简单；R449 哈气骑士团下调到第一层；R340 永夜鸭群）")',
    'check(GameLevels.elite_pool().size() == 7,\n\n\t\t\t"第一层精英池 7 关（精简×4 + 精难×3：R778 龙族巢穴从第二层整关移入精英简单；R158 鸭子窑上调进第一层精英简单；R449 哈气骑士团下调到第一层；R340 永夜鸭群）")',
    "第一层精英池 6→7")

rep('check(GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size() == 22,\n\n\t\t\t"第二层自带 22 关',
    'check(GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size() == 21,\n\n\t\t\t"第二层自带 21 关（R778 龙族巢穴移到第一层 −1）',
    "第二层 22→21")

rep('check(GameLevels.elite_pool(GameLayers.LAYER_TWO).size() == 9,\n\n\t\t\t"第二层精英池 9 关（专属：精英简单 5 + 精英困难 4；R722 巨炮防线上调到精英困难；R541 普罗诺亚之影（精英简单）；**R506 母舰空袭（精英困难）↔ 阿斯克勒庇厄斯的试炼（精英简单）互换档位**；R502 执法者的审判（精英简单）；R149 钢铁要塞 / R161 赫尔墨斯的试炼；R449 哈气骑士团已下调到第一层）")',
    'check(GameLevels.elite_pool(GameLayers.LAYER_TWO).size() == 8,\n\n\t\t\t"第二层精英池 8 关（专属：精英简单 3 + 精英困难 5；R778 龙族巢穴移到第一层 −1、阿斯克勒庇厄斯的试炼降为普通困难 −1、计量工坊升为精英困难 +1；R722 巨炮防线上调到精英困难；R541 普罗诺亚之影（精英简单）；R502 执法者的审判（精英简单）；R149 钢铁要塞 / R161 赫尔墨斯的试炼；R449 哈气骑士团已下调到第一层）")',
    "第二层精英池 9→8")

rep('"R398 三层精英池 = 第二层 9 关（content_layers [2, 3]；R541 普罗诺亚之影 +1；R449 哈气骑士团下调后 −1、R451 母舰空袭 +1、R502 执法者的审判 +1；**R722 巨炮防线上调精英困难 +1**；实际 %d。**实际抽关只取困难档，见 R506b**）" % r398_pool.size()',
    '"R398 三层精英池 = 第二层 8 关（content_layers [2, 3]；R778 龙族巢穴移走 / 阿斯克勒庇厄斯降档 −2、计量工坊升档 +1；R541 普罗诺亚之影 +1；R451 母舰空袭 +1、R502 执法者的审判 +1；**R722 巨炮防线上调精英困难 +1**；实际 %d。**实际抽关只取困难档，见 R506b**）" % r398_pool.size()',
    "R398 池 9→8")

rep('"R506b 三层精英抽关池 = 第二层精英困难 4 关（R722 巨炮防线加入；实际 %d）" % r506b_pool.size()',
    '"R506b 三层精英抽关池 = 第二层精英困难 5 关（R722 巨炮防线 + R778 计量工坊；实际 %d）" % r506b_pool.size()',
    "R506b 4→5")

rep('"内置关卡共 40 关（8 普简 + 10 普难 + 8 精英简单 + 7 精英困难 + 7 Boss；',
    '"内置关卡共 40 关（8 普简 + 10 普难 + 7 精英简单 + 8 精英困难 + 7 Boss；R778 龙族巢穴→一层精英简单、阿斯克勒庇厄斯→普通困难、计量工坊→精英困难；',
    "总关数分布注释")

# ============ 3. 档位断言 ============
rep('"R162 阿斯克勒庇厄斯的试炼：第二层·精英简单（R506 与母舰空袭互换档位），1 只阿斯克勒庇厄斯在后排中央（0,1），元组程速 2/2")',
    '"R162 阿斯克勒庇厄斯的试炼：第二层·普通敌人-困难（R506 曾下调到精英简单，R778 再降为普通困难），1 只阿斯克勒庇厄斯在后排中央（0,1），元组程速 2/2")',
    "R162 消息")

rep('"R758 计量工坊：二层普通困难关卡，三只单位")',
    '"R758 计量工坊：二层精英困难关卡（R778 由普通困难升档），三只单位")',
    "R758 消息")
rep('"R758 计量工坊：后排 0/60 常数测量员 · 中排 6/60 速2 精密计算者 · 前排 4/60 负载增量员")',
    '"R758 计量工坊：后排 0/80 常数测量员 · 中排 6/80 速2 精密计算者 · 前排 4/80 负载增量员（R778 统一 60→80）")',
    "R758 血量消息")

# ============ 4. 使魔之力挂载关卡数 ============
rep('check(r60_lv == 2, "R60 使魔之力 9115 挂在 2 个巫师关卡（实际 %d）" % r60_lv)',
    'check(r60_lv == 1, "R60 使魔之力 9115 挂在 1 个巫师关卡（R778 队长与巫师改用鸭子之力；实际 %d）" % r60_lv)',
    "使魔之力挂载 2→1")

# ============ 5. 构状体 → 构装体（全篇统一，含 traits 断言与文案）============
n = s.count("构状体")
s = s.replace("构状体", "构装体")
print("OK 构状体→构装体 x%d" % n)

# ============ 6. 9133 卡数据断言 ============
rep('''	check(r149_hecate.kind == "盟友" and r149_hecate.power == 3 and r149_hecate.health == 35

			and r149_hecate.attack_range == 1 and r149_hecate.move_speed == 1

			and r149_hecate.traits.has(GameEngine.FUSE_TRAIT),

			"R149 量产型赫卡同克瑞斯：盟友 3/35 程1 速1，带「铸造」trait")''',
    '''	check(r149_hecate.kind == "盟友" and r149_hecate.power == 3 and r149_hecate.health == 60

			and r149_hecate.attack_range == 1 and r149_hecate.move_speed == 1

			and r149_hecate.traits.has("铸甲")

			and not r149_hecate.traits.has(GameEngine.FUSE_TRAIT),

			"R778 量产型赫卡同克瑞斯：盟友 3/60 程1 速1，带「铸甲」trait（不再铸造）")''',
    "9133 卡数据断言")

rep('''	check(r149_oni.kind == "盟友" and r149_oni.power == 10 and r149_oni.health == 80

			and r149_oni.attack_range == 1 and r149_oni.move_speed == 1''',
    '''	check(r149_oni.kind == "盟友" and r149_oni.power == 10 and r149_oni.health == 100

			and r149_oni.attack_range == 1 and r149_oni.move_speed == 3''',
    "9132 数值断言")
rep('"R149 俄倪厄：盟友 10/80 程1 速1（R424 血 50→80），自带双动（actions=2 +「疾行」字段）")',
    '"R149 俄倪厄：盟友 10/100 程1 速3（R424 血 50→80；R778 血 80→100、速 1→3），自带双动（actions=2 +「疾行」字段）")',
    "9132 消息")

# ============ 7. 9133 机制测试段（铸造 ①-⑤ → 铸甲）============
new_hecate = '''	# ① R778：铸甲 —— `side` 这一方回合开始时，每只 9133 给随机一个**其他**友方单位 +10 护甲

	var r778_e := _new_engine([], 30, 30)

	var r778_h := r778_e.state.place(CardData.from_dict(r149_hecate.to_dict()),

			Vector2i(0, 0), GameEngine.SIDE_OPPONENT)

	var r778_ally := r778_e.state.place(CardData.from_dict(r149_oni.to_dict()),

			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)

	r778_e.start_game()

	check(r778_h.fuse_left == 0 and r778_ally.armor == 0,

			"R778 铸甲：不再挂铸造倒计时（fuse_left=%d），开局双方护甲都是 0"

			% r778_h.fuse_left)

	r778_e.end_turn()      # → 敌方回合开始

	check(r778_ally.armor == GameEngine.HECATE_ARMOR_GAIN and r778_h.armor == 0,

			"R778 铸甲：敌方回合开始 → 随机一个**其他**友方 +10 护甲（俄倪厄 %d / 自己 %d）"

			% [r778_ally.armor, r778_h.armor])

	r778_e.end_turn()      # → 我方回合

	r778_e.end_turn()      # → 敌方回合开始

	check(r778_ally.armor == GameEngine.HECATE_ARMOR_GAIN * 2,

			"R778 铸甲：每回合都结算（两回合累计 %d）" % r778_ally.armor)

	check(r778_e.state.unit_at(Vector2i(0, 0)) != null

			and r778_e.state.unit_at(Vector2i(0, 0)).card.id == 9133,

			"R778 不再变钢铁要塞：量产型赫卡同克瑞斯本体仍在原格")

	# ② 场上没有「其他」友方单位 → 跳过，不报错也不加自己

	var r778_e2 := _new_engine([], 30, 30)

	var r778_h2 := r778_e2.state.place(CardData.from_dict(r149_hecate.to_dict()),

			Vector2i(0, 0), GameEngine.SIDE_OPPONENT)

	r778_e2.start_game()

	r778_e2.end_turn()

	check(r778_h2.armor == 0 and r778_e2.state.unit_at(Vector2i(0, 0)) != null,

			"R778 铸甲：只有自己时不给任何人加护甲（armor=%d）" % r778_h2.armor)

	# ③ 护甲走 `Placement.armor`，受击时优先吸收（与阿斯克勒庇厄斯共用唯一口）

	check(r778_h2.armor == 0, "R778 铸甲：护甲字段初始为 0（受击吸收见 R162 用例）")'''

rep_span("\t# ① 上场挂表（`place()` 是唯一初始化口）",
         '\tcheck(not r149_show2, "R149 倒计时归零后不再显示该条目")',
         new_hecate, "9133 铸造段重写为铸甲")

# ============ 8. 灰烬龙战吼下线（14166 段）============
rep('''	# ---- 战吼（所属阵营第一个回合开始时触发一次）----

	var om_bc := _new_engine([], 20, 30, -1, false)

	om_bc.state.place(om_repo.get_card(1013), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)

	om_bc.state.place(om_repo.get_card(1053), Vector2i(3, 1), GameEngine.SIDE_SELF)

	var om_bc_hp := om_bc.state.unit_at(Vector2i(3, 1)).health

	om_bc._begin_turn(GameEngine.SIDE_OPPONENT)

	var om_bc1 := om_bc.state.unit_at(Vector2i(3, 1))

	check(om_bc1 != null and om_bc1.health == om_bc_hp - 4,

			"灰烬龙战吼：对我方单位造成 4 点伤害")

	om_bc._begin_turn(GameEngine.SIDE_OPPONENT)

	var om_bc2 := om_bc.state.unit_at(Vector2i(3, 1))

	check(om_bc2 == null or om_bc2.health == om_bc_hp - 4, "战吼只触发一次")''',
    '''	# ---- R778：灰烬龙的战吼已整条删除（卡面清空 + trait 移除 + 引擎分支下线）----

	var om_bc := _new_engine([], 20, 30, -1, false)

	om_bc.state.place(om_repo.get_card(1013), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)

	om_bc.state.place(om_repo.get_card(1053), Vector2i(3, 1), GameEngine.SIDE_SELF)

	var om_bc_hp := om_bc.state.unit_at(Vector2i(3, 1)).health

	om_bc._begin_turn(GameEngine.SIDE_OPPONENT)

	var om_bc1 := om_bc.state.unit_at(Vector2i(3, 1))

	check(om_bc1 != null and om_bc1.health == om_bc_hp,

			"R778 灰烬龙战吼已删：敌方回合开始不再对全场造成 4 伤（%d → %d）"

			% [om_bc_hp, -1 if om_bc1 == null else om_bc1.health])''',
    "灰烬龙战吼效果测试改为下线")

# ============ 9. R363 段：文案 / 效果 / 源码锁 ============
rep_span("\t# ---- R363：灰烬龙战吼的演出与口径 / 幼龙死亡不会连带另一只 ----",
         '\t\t\t% ("?" if r363_ash == null else r363_ash.effect_text))',
         '''	# ---- R363 / R778：灰烬龙卡面与「战吼已下线」/ 幼龙死亡不会连带另一只 ----

	# ① R778：灰烬龙的战吼**整条删除** —— 卡面 effect_text 清空、「战吼」trait 移除，

	#    引擎 `_battlecry()` 里的 ash 分支同步下线（`_battlecry_ash` 函数已不存在）。

	var r363_repo := CardRepo.load_json()

	var r363_ash: CardData = r363_repo.get_card(1013)

	check(r363_ash != null and r363_ash.effect_text == ""

			and not r363_ash.traits.has("战吼"),

			"R778 文案：灰烬龙卡面清空、不再带「战吼」trait（实际 %s）"

			% ("?" if r363_ash == null else str(r363_ash.traits)))''',
    "R363 ①文案")

rep_span("\t# ② 真实效果：我方**全部单位（含工事）**各 4；己方大营不动；我方 HP 不动",
         '\t\t\t"R363 灰烬龙：两个目标的受击带 0/1 序号（实际 %s）" % str(r363_seqs))',
         '''	# ② R778：战吼下线后 → 敌方回合开始**谁都不掉血**（原来这里各吃 4 点）

	var r363_e := _new_engine([], 20, 30, -1, false)

	r363_e.state.place(_card(1013, "灰烬龙", "盟友", 7, 5, 45), Vector2i(0, 1),

			GameEngine.SIDE_OPPONENT)

	r363_e.state.place(_card(8003, "树人", "盟友", 3, 3, 8), Vector2i(3, 0),

			GameEngine.SIDE_SELF)

	r363_e.state.place(_card(8001, "木栅栏", "工事", 1, 0, 6), Vector2i(4, 1),

			GameEngine.SIDE_SELF)

	var r363_hp0 := r363_e.state.hp_self

	r363_e._begin_turn(GameEngine.SIDE_OPPONENT)

	var r363_u: Placement = r363_e.state.unit_at(Vector2i(3, 0))

	check(r363_u != null and r363_u.health == 8,

			"R778 灰烬龙：战吼已删 → 我方单位不再掉血（8 → %d）"

			% (-1 if r363_u == null else r363_u.health))

	var r363_fc: Placement = r363_e.state.unit_at(Vector2i(4, 1))

	check(r363_fc != null and r363_fc.health == 6,

			"R778 灰烬龙：工事也不再掉血（6 → %d）" % (-1 if r363_fc == null else r363_fc.health))

	check(r363_e.state.hp_self == r363_hp0,

			"R778 灰烬龙：我方 HP 不动（%d → %d）" % [r363_hp0, r363_e.state.hp_self])''',
    "R363 ②效果")

rep_span("\t# ⑤ 源码锁：引擎先报发动者 / 界面有战吼演出与错峰落地",
         '\t\t\t"R363 源码锁：击破飘字带卡名（两只同卡也能指出是哪只死了）")',
         '''	# ⑤ 源码锁：`_battlecry_ash` 与 `ASH_DRAGON_AOE` 已从引擎删除（防止被加回来）

	var r363_esrc := FileAccess.get_file_as_string("res://scripts/game_engine.gd")

	check_src(r363_esrc.find("_battlecry_ash") < 0,

			"R778 源码锁：引擎里已无 `_battlecry_ash`（战吼整条下线）")

	check_src(r363_esrc.find("ASH_DRAGON_AOE") < 0,

			"R778 源码锁：`ASH_DRAGON_AOE` 常量已删")

	var r363_ui2 := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")

	check_src(r363_ui2.find('"battlecry":') >= 0,

			"R363 源码锁：界面仍接着战吼事件（骨架保留，以后加战吼不用再接线）")

	check_src(r363_esrc.find('fi["seq"] = seq') >= 0,

			"R363 源码锁：多目标受击把 seq 带进 fx_impact")

	check_src(r363_ui2.find('bool(data.get("summon", false))') >= 0

			and r363_ui2.find('"text": "召唤 %s"') >= 0,

			"R363 源码锁：召唤有身份提示（玩家分得出「死了变成」还是「旁边那只被换」）")

	check_src(r363_ui2.find('"text": "%s 击破" % str(card.card_name)') >= 0,

			"R363 源码锁：击破飘字带卡名（两只同卡也能指出是哪只死了）")''',
    "R363 ⑤源码锁")

io.open(P, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n"))
print("TESTS DONE")
