# -*- coding: utf-8 -*-
"""R689 测试补丁：改疾风之力 / 群起攻之 / 生命循环三处旧口径，补种子与被眷顾者用例，同步图鉴计数。"""
import sys

WRITE = "--write" in sys.argv
P = "scripts/test_engine.gd"
raw = open(P, "rb").read().decode("utf-8")
assert raw.count("\r\n") == raw.count("\n"), "不是纯 CRLF"
out = raw.replace("\r\n", "\n")


def rep(old, new, tag, count=1):
    global out
    c = out.count(old)
    if c != count:
        raise SystemExit("[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, count))
    out = out.replace(old, new)


def blk(code):
    """test_engine.gd 的排版：每条语句之间空一行。"""
    rows = code.strip("\n").split("\n")
    return "\n\n".join(rows) + "\n"


def seg_replace(start_marker, end_marker, new_code, tag, start_at=0):
    """用行锚点替换一整段（含首尾行）。"""
    global out
    lines = out.split("\n")
    i = -1
    for k in range(start_at, len(lines)):
        if lines[k] == start_marker:
            i = k
            break
    if i < 0:
        raise SystemExit("[%s] 找不到起始行" % tag)
    j = -1
    for k in range(i, len(lines)):
        if lines[k] == end_marker:
            j = k
            break
    if j < 0:
        raise SystemExit("[%s] 找不到结束行" % tag)
    print("  [%s] 替换 %d..%d（%d 行）" % (tag, i + 1, j + 1, j - i + 1))
    new_lines = blk(new_code).split("\n")
    out = "\n".join(lines[:i] + new_lines + lines[j + 1:])
    return j + 1


# ── ① 图鉴计数 315 → 317 / 玩家 240 → 242 / 奖励池 199 → 200 ──────────────
rep("check(repo.all_cards().size() == 315,", "check(repo.all_cards().size() == 317,", "图鉴数")
rep('"图鉴 = 315 张（R632 −1：删工事罐子 9158；',
    '"图鉴 = 317 张（R689 +2：种子 9248 / 被眷顾者 9249；R632 −1：删工事罐子 9158；', "图鉴消息")
rep("check(grp_player.size() == 240 and grp_enemy.size() == 75,",
    "check(grp_player.size() == 242 and grp_enemy.size() == 75,", "分组数")
rep("（期望 240 / 75（R632 玩家 −1：删工事罐子 9158；",
    "（期望 242 / 75（R689 玩家 +2；R632 玩家 −1：删工事罐子 9158；", "分组消息")
rep("check(pool.size() == 199,", "check(pool.size() == 200,", "奖励池数")
rep('"奖励池 199 张（R572 +2：',
    '"奖励池 200 张（R689 +1：被眷顾者 9249 史诗进池（种子 9248 是 token 不进池）；R572 +2：', "奖励池消息")

# ── ② 疾风之力 ────────────────────────────────────────────────────────────
GALE = '''
	# 疾风之力（9045）：己方盟友进入战场 **或** 使用效果卡 → 随机对一个敌人造成 4 点伤害
	# R689 店长口径：触发源由「盟友登场」再扩一条「使用效果卡」—— 两条共用 `_wind_force_tick()`。

	var nc_wf := repo.get_card(9045)

	check(nc_wf.is_effect() and nc_wf.cost == 2 and nc_wf.rarity == 2

			and nc_wf.traits.has("疾风") and nc_wf.value == 4,

			"疾风之力：史诗效果卡 2 费、trait 疾风 value=4")

	var eng_wf := _new_engine([], 20, 20, -1, false)

	eng_wf.start_game(1)

	eng_wf.state.place(_card(9398, "敌狼", "盟友", 4, 3, 9), Vector2i(1, 0),

			GameEngine.SIDE_OPPONENT)

	var wf_foe: Placement = eng_wf.state.unit_at(Vector2i(1, 0))

	eng_wf.state.hand = [repo.get_card(9045)]

	eng_wf.state.energy = 5

	eng_wf.use_effect(0)

	check(wf_foe.health == 9,

			"疾风之力：打出它自己时还没进效果区 → 不自己触发自己（仍 %d）" % wf_foe.health)

	eng_wf.state.hand = [repo.get_card(9065)]

	eng_wf.state.energy = 5

	eng_wf.use_effect(0)

	check(wf_foe.health == 5,

			"疾风之力：使用另一张效果卡 → 敌人 -4（9 → %d）" % wf_foe.health)

	eng_wf.state.hand = [_card(8003, "农民", "盟友", 3, 3, 8)]

	eng_wf.state.energy = 5

	eng_wf.play_from_hand(0, Vector2i(4, 0))

	check(wf_foe.health == 1,

			"疾风之力：己方盟友登场 → 再 -4（5 → %d）" % wf_foe.health)

	var eng_wf2 := _new_engine([], 20, 20, -1, false)

	eng_wf2.start_game(1)

	eng_wf2.state.hand = [repo.get_card(9045)]

	eng_wf2.state.energy = 5

	eng_wf2.use_effect(0)

	eng_wf2.state.hand = [_card(8003, "农民", "盟友", 3, 3, 8)]

	eng_wf2.state.energy = 5

	eng_wf2.play_from_hand(0, Vector2i(4, 0))

	check(eng_wf2.state.hp_opponent == 16,

			"疾风之力：场上无敌人 → 直击敌方 HP 4 点（20 → %d）" % eng_wf2.state.hp_opponent)

	eng_wf2.state.hand = [repo.get_card(9065)]

	eng_wf2.state.energy = 5

	eng_wf2.use_effect(0)

	check(eng_wf2.state.hp_opponent == 12,

			"疾风之力：使用效果卡时场上无敌人 → 同样直击 HP（16 → %d）" % eng_wf2.state.hp_opponent)
'''
seg_replace('	# 疾风之力（9045）：每个己方盟友进入战场 → 随机对一个敌人造成 4 点伤害',
            '			"疾风之力：场上无敌人 → 直击敌方 HP 4 点（20 → %d）" % eng_wf2.state.hp_opponent)',
            GALE, "疾风之力")

# ── ③ 群起攻之 ────────────────────────────────────────────────────────────
RALLY = '''
	# ---- 群起攻之（9070，R689）：接通单位拿**接通位置**发起攻击 ----
	# 旧口径「不计算距离（全场可达）」已废：现在按「与它接通的己方单位位置」取最短距离，
	# 所以孤立单位仍然打不到，只有链上的位置才顶用。

	var nc_rally := repo.get_card(9070)

	check(nc_rally.card_name == "群起攻之" and nc_rally.is_effect() and nc_rally.cost == 2

			and nc_rally.rarity == 1 and nc_rally.traits.has("群起攻之")

			and nc_rally.traits.has("接通"),

			"群起攻之：稀有 2 费效果卡，trait 群起攻之 + 接通")

	var rl_e := _new_engine([], 20, 20, -1, false)

	rl_e.start_game(0)

	# 己方 A(5,3) / 己方 B(4,3) / 敌方 E(3,3)：A 与 B 四方向相邻 → 接通；B 与 E 相邻。
	# A 自己打 E 要 2 步（攻程 1 不够），借 B 的位置只要 1 步。
	var rl_a := rl_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),

			Vector2i(5, 3), GameEngine.SIDE_SELF)

	var rl_b := rl_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),

			Vector2i(4, 3), GameEngine.SIDE_SELF)

	rl_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1), Vector2i(3, 3),

			GameEngine.SIDE_OPPONENT)

	check(not rl_e.attack_targets(Vector2i(5, 3), GameEngine.SIDE_SELF, rl_a.card).has(Vector2i(3, 3)),

			"群起攻之：没这张效果卡时，A 打不到 E（曼哈顿 2 > 攻程 1）")

	rl_e.state.effects.append(repo.get_card(9070))	# 效果区放入群起攻之

	check(rl_e.attack_distance(Vector2i(5, 3), Vector2i(3, 3), GameEngine.SIDE_SELF, rl_a.card) == 1,

			"群起攻之：借接通单位 B 的位置算距离（2 → %d）"

			% rl_e.attack_distance(Vector2i(5, 3), Vector2i(3, 3), GameEngine.SIDE_SELF, rl_a.card))

	check(rl_e.attack_targets(Vector2i(5, 3), GameEngine.SIDE_SELF, rl_a.card).has(Vector2i(3, 3)),

			"群起攻之：激活后 A 能打到 E（借 B 的位置）")

	check(rl_e.attack_distance(Vector2i(4, 3), Vector2i(3, 3), GameEngine.SIDE_SELF, rl_b.card) == 1,

			"群起攻之：本来就相邻的单位距离仍是 1（不是旧口径的全场 0）")

	# 孤立单位（与 A / B 都不相邻）拿不到接通位置 → 仍按曼哈顿距离

	var rl_c := rl_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),

			Vector2i(5, 0), GameEngine.SIDE_SELF)

	check(rl_e.attack_distance(Vector2i(5, 0), Vector2i(3, 3), GameEngine.SIDE_SELF, rl_c.card) == 5

			and not rl_e.attack_targets(Vector2i(5, 0), GameEngine.SIDE_SELF, rl_c.card).has(Vector2i(3, 3)),

			"群起攻之：孤立单位没有接通位置可用 → 仍按曼哈顿算（打不到 E）")

	# 敌方效果区没有这张卡 → 敌人不受影响

	check(rl_e.attack_distance(Vector2i(3, 3), Vector2i(5, 3), GameEngine.SIDE_OPPONENT,

			rl_e.state.unit_at(Vector2i(3, 3)).card) == 2,

			"群起攻之：敌方效果区没有这张卡 → 敌人仍按曼哈顿距离")
'''
seg_replace('	# ---- 群起攻之（9070）：2 费稀有效果；接通单位攻击不计算距离 ----',
            '			"群起攻之：敌方效果区没有这张卡 → 敌人不受影响")',
            RALLY, "群起攻之")

# ── ④ 生命循环 + 种子 + 被眷顾者 ─────────────────────────────────────────
LIFE = '''
	# ---- R227 → R689：生命循环（9150，森林精魄 · **1 费史诗效果卡**）----
	# R689 店长口径：由「0 费技能、选一个盟友」改成效果卡 —— 使用时**己方所有盟友**获得
	# 「次元」+「死亡：将一张种子加入手卡」。带次元 → 被破坏进消耗区（不进弃牌区）。

	var lc_c := repo.get_card(9150)

	check(lc_c != null and lc_c.card_name == "生命循环" and lc_c.is_effect()

			and lc_c.cost == 1 and lc_c.rarity == 2 and lc_c.card_class == "森林精魄"

			and lc_c.target_mode == "none" and not lc_c.needs_target()

			and lc_c.traits.has("生命循环"),

			"R689 生命循环：森林精魄 1 费史诗效果卡，无目标（target_mode=none）")

	var lc_pool := repo.reward_pool_for("森林精魄")

	var lc_in_pool := false

	for lc_pc: CardData in lc_pool:

		if lc_pc.id == 9150:

			lc_in_pool = true

	check(lc_in_pool, "R689 生命循环：进森林精魄奖励池（史诗 rarity 2）")

	# ① 使用：**所有**己方盟友拿到「次元」+「死亡」+ life_cycle 标记；工事与敌方不算

	var lc_e := _new_engine([], 20, 20, -1, false)

	lc_e.start_game(1)

	var lc_ally := lc_e.state.place(_card(8003, "树人", "盟友", 3, 3, 8),

			Vector2i(4, 1), GameEngine.SIDE_SELF)

	var lc_ally2 := lc_e.state.place(_card(8003, "树人", "盟友", 3, 3, 8),

			Vector2i(3, 1), GameEngine.SIDE_SELF)

	var lc_wall := lc_e.state.place(_card(8005, "木栅栏", "工事", 1, 0, 6, 0, 0),

			Vector2i(4, 0), GameEngine.SIDE_SELF)

	var lc_foe := lc_e.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),

			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)

	lc_e.state.hand = [repo.get_card(9150)]

	lc_e.state.energy = 5

	var lc_ret := lc_e.use_effect(0)

	check(lc_ally.card.has_affix(GameEngine.AFFIX_DIMENSION)

			and lc_ally.card.has_affix(GameEngine.AFFIX_DEATH) and lc_ally.life_cycle

			and lc_ally2.life_cycle,

			"R689 生命循环：己方所有盟友获得「次元」+「死亡」并打上 life_cycle 标记（%s）" % lc_ret)

	check(not lc_wall.life_cycle and not lc_foe.life_cycle,

			"R689 生命循环：工事不是盟友、敌方单位也不吃（只授予己方盟友）")

	check(lc_e.state.effects.size() == 1 and lc_e.state.effects[0].id == 9150,

			"R689 生命循环：本体进效果区（效果卡不走弃牌区）")

	# ② 次元：被击破 → 进消耗区、不进弃牌区；死亡：手卡多一张**种子**

	lc_e.state.hand.clear()

	var lc_discard0: int = lc_e.state.discard.size()

	var lc_void0: int = lc_e.state.void_count

	lc_ally.health = 0

	lc_e._destroy(Vector2i(4, 1))

	check(lc_e.state.void_count == lc_void0 + 1

			and lc_e.state.discard.size() == lc_discard0,

			"R689 生命循环：带「次元」的单位被击破 → 进消耗区、不进弃牌区（void %d → %d）"

			% [lc_void0, lc_e.state.void_count])

	check(lc_e.state.hand.size() == 1 and (lc_e.state.hand[0] as CardData).id == 9248,

			"R689 生命循环：被破坏时加一张种子（9248）到手卡（手卡 %d 张）"

			% lc_e.state.hand.size())

	# ③ 离场还原：给盟友上生命循环 → 重启回手 → 手里那张不该带次元 / 死亡

	var lc_e3 := _new_engine([], 20, 20, -1, false)

	lc_e3.start_game(1)

	var lc_ally3 := lc_e3.state.place(_card(8003, "树人", "盟友", 3, 3, 8),

			Vector2i(4, 1), GameEngine.SIDE_SELF)

	check(lc_ally3 != null, "R689 生命循环：离场还原用例的前置盟友已就位")

	lc_e3.state.hand = [repo.get_card(9150)]

	lc_e3.state.energy = 5

	lc_e3.use_effect(0)

	lc_e3.state.hand.clear()

	lc_e3._reboot(Vector2i(4, 1), GameEngine.SIDE_SELF)

	var lc_back: CardData = null

	for lc_hc: CardData in lc_e3.state.hand:

		if lc_hc.id == 8003:

			lc_back = lc_hc

	check(lc_back != null and not lc_back.has_affix(GameEngine.AFFIX_DIMENSION)

			and not lc_back.has_affix(GameEngine.AFFIX_DEATH),

			"R689 生命循环：重启回手时「次元 / 死亡」已还原（回手那张不带这两个字段）")

	# ④ 种子（9248）：0 费效果卡 token；回合开始破坏自己 → 随机 +1 费 或 加一张随机卡

	var sd_c := repo.get_card(9248)

	check(sd_c != null and sd_c.card_name == "种子" and sd_c.is_effect()

			and sd_c.cost == 0 and sd_c.rarity == 5 and sd_c.card_class == "森林精魄"

			and sd_c.traits.has("种子") and sd_c.target_mode == "none",

			"R689 种子：0 费效果卡 token（rarity 5，不进奖励池）")

	var sd_pool_in := false

	for sd_pc: CardData in repo.reward_pool():

		if sd_pc.id == 9248:

			sd_pool_in = true

	check(not sd_pool_in, "R689 种子：token 卡不进奖励池（rarity 5 被 obtainable 过滤）")

	var sd_e := _new_engine([], 20, 20, -1, false)

	sd_e.start_game(1)

	sd_e.state.hand.clear()

	sd_e.state.discard.clear()

	sd_e.state.energy = 3

	sd_e.state.effects.append(CardData.from_dict(repo.get_card(9248).to_dict()))

	sd_e.state.effects.append(CardData.from_dict(repo.get_card(9248).to_dict()))

	sd_e._seed_tick(GameEngine.SIDE_SELF)

	var sd_gain: int = (sd_e.state.energy - 3) + sd_e.state.hand.size() + sd_e.state.discard.size()

	check(sd_e.state.effects.size() == 0 and sd_gain == 2,

			"R689 种子：效果区两张各结算一次（剩余 %d 张，合计收益 %d = 2 次）"

			% [sd_e.state.effects.size(), sd_gain])

	# ⑤ 被眷顾者（9249）：3 费史诗技能；复制抽牌库一张效果卡打出 + 回费 = 抽牌库效果卡张数

	var bls_c := repo.get_card(9249)

	check(bls_c != null and bls_c.card_name == "被眷顾者" and bls_c.is_spell()

			and bls_c.cost == 3 and bls_c.rarity == 2 and bls_c.card_class == "森林精魄"

			and bls_c.traits.has("被眷顾者"),

			"R689 被眷顾者：森林精魄 3 费史诗技能")

	var bls_e := _new_engine([], 20, 20, -1, false)

	bls_e.start_game(1)

	bls_e.state.effects.clear()

	bls_e.state.hand = [repo.get_card(9249)]

	bls_e.state.energy = 5

	bls_e.state.deck.clear()

	bls_e.state.deck.append(CardData.from_dict(repo.get_card(9065).to_dict()))

	bls_e.state.deck.append(CardData.from_dict(repo.get_card(8003).to_dict()))

	bls_e.state.deck.append(CardData.from_dict(repo.get_card(9066).to_dict()))

	var bls_deck0: int = bls_e.state.deck.size()

	var bls_ret := bls_e.use_spell(0)

	check(bls_e.state.effects.size() == 1

			and (bls_e.state.effects[0].id == 9065 or bls_e.state.effects[0].id == 9066),

			"R689 被眷顾者：从抽牌库打出一张**效果卡**（%s）" % bls_ret)

	check(bls_e.state.deck.size() == bls_deck0,

			"R689 被眷顾者：是「复制」不是取走（抽牌库仍 %d 张）" % bls_e.state.deck.size())

	check(bls_e.state.energy == 4,

			"R689 被眷顾者：3 费技能，回复抽牌库效果卡张数 2 → 费用 %d" % bls_e.state.energy)

	var bls_e2 := _new_engine([], 20, 20, -1, false)

	bls_e2.start_game(1)

	bls_e2.state.effects.clear()

	bls_e2.state.hand = [repo.get_card(9249)]

	bls_e2.state.energy = 5

	bls_e2.state.deck.clear()

	bls_e2.state.deck.append(CardData.from_dict(repo.get_card(8003).to_dict()))

	var bls_ret2 := bls_e2.use_spell(0)

	check(bls_ret2.contains("没有效果卡") and bls_e2.state.energy == 2

			and bls_e2.state.effects.is_empty(),

			"R689 被眷顾者：抽牌库里没有效果卡 → 落空且不回费（%s / 费用 %d）"

			% [bls_ret2, bls_e2.state.energy])
'''
seg_replace('	# ---- R227：生命循环（9150，森林精魄 · 普通 · 0 费技能；R429 由稀有下调）----',
            '			"R227 生命循环：重启回手时「次元 / 死亡」已还原（回手那张不带这两个字段）")',
            LIFE, "生命循环")

if WRITE:
    open(P, "wb").write(out.replace("\n", "\r\n").encode("utf-8"))
    b = open(P, "rb").read()
    print("写入 %s CRLF=%d LF=%d stray=%d" % (P, b.count(b"\r\n"), b.count(b"\n"),
                                             b.count(b"\r") - b.count(b"\r\n")))
else:
    print("干跑通过（未写入）")
