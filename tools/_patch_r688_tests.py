# -*- coding: utf-8 -*-
"""R688 测试补丁：迅捷→幽深回响、镜像可叠加、填充卡换自愈 9065。保留 CRLF。"""
import sys

TE = "E:/work/card_rogue/scripts/test_engine.gd"
TR = "E:/work/card_rogue/scripts/test_reward.gd"


def load(p):
    raw = open(p, "rb").read().decode("utf-8")
    eol = "\r\n" if raw.count("\r\n") == raw.count("\n") else "\n"
    return raw.replace("\r\n", "\n"), eol


def save(p, txt, eol):
    open(p, "wb").write(txt.replace("\n", eol).encode("utf-8"))
    b = open(p, "rb").read()
    print("  %s → CRLF %d / LF %d" % (p.split("/")[-1], b.count(b"\r\n"), b.count(b"\n")))


te, TE_EOL = load(TE)
edits = []


def rep(old, new, tag, cnt=1):
    edits.append((old, new, tag, cnt))


# ① 44 处把 9002 当「无副作用填充效果卡」→ 换成自愈 9065（2 费稀有，打出不结算任何东西）
n9002 = te.count("repo.get_card(9002)")
assert n9002 == 44, "9002 填充卡出现 %d 次，预期 44" % n9002
te = te.replace("repo.get_card(9002)", "repo.get_card(9065)")

# ② 卡面数据：迅捷 → 幽深回响（锚点此时已是替换后的 9065）
rep('''	var swift := repo.get_card(9065)

	check(swift.is_effect() and swift.rarity == 1 and swift.cost == 2

			and swift.value == 2 and swift.traits.has("减伤"),

			"迅捷：效果卡 稀有 2 费 value=2（减伤，只护 HP；2026-09-30 由 3 费下调）")

''',
    '''	var echo_card := repo.get_card(9002)

	check(echo_card.card_name == "幽深回响" and echo_card.is_effect() and echo_card.cost == 2

			and echo_card.rarity == 1 and echo_card.traits.has("幽深回响") and echo_card.value == 6

			and echo_card.effect_text.contains("加入抽牌库")

			and echo_card.effect_text.contains("重复 X 次"),

			"幽深回响（R688 取代迅捷）：稀有 2 费效果卡，trait 幽深回响 value=6，文案「加入抽牌库」+「重复 X 次」")

''',
    "data", 1)

# ③ 镜像：文案改为「每回合前 X 次」
rep('''	# 镜像（9056）：2 费史诗效果卡；「每回合第一次使用效果牌时」把该牌的**同名副本**加入本局卡组，

	# **并抽一张卡**。不可叠加 → 效果区几张都只触发一次、只加一份、只抽一张（打出自己那一下不算触发）。
''',
    '''	# 镜像（9056）：2 费史诗效果卡；「每回合前 X 次使用效果牌时」把该牌的**同名副本**加入本局卡组，

	# **并抽一张卡**。R688 起**可叠加** → X = 效果区张数（单张时 X=1，就是原来的「每回合第一次」）。

	# 打出自己那一下仍然不算触发（调用时本卡还没进效果区）。
''',
    "mirror_cmt", 1)

rep('''			and nc_mirror.effect_text.contains("每回合第一次使用效果牌时")

			and nc_mirror.effect_text.contains("抽一张卡")

			and nc_mirror.effect_text.contains("不叠加"),

			"镜像：史诗 2 费效果卡，trait 镜像，文案「每回合第一次」+「抽一张卡」+「不叠加」")
''',
    '''			and nc_mirror.effect_text.contains("每回合前 X 次使用效果牌时")

			and nc_mirror.effect_text.contains("抽一张卡")

			and nc_mirror.effect_text.contains("X 为本卡在效果区的张数"),

			"镜像：史诗 2 费效果卡，trait 镜像，文案「每回合前 X 次」+「抽一张卡」+「X = 效果区张数」")
''',
    "mirror_assert", 1)

# ④ 威慑段尾追加两组 R688 新用例
rep('''			"威慑：2 张 → 本回合第 3 次使用不再触发（仍是 -20）")

''',
    '''			"威慑：2 张 → 本回合第 3 次使用不再触发（仍是 -20）")

	# ---- R688 镜像可叠加：效果区 2 张 → 本回合前 2 次使用效果牌各触发一次 ----

	var mir_e5 := _new_engine([], 20, 20, -1, false)

	mir_e5.start_game(1)

	mir_e5.state.effects.append(repo.get_card(9056))

	mir_e5.state.effects.append(repo.get_card(9056))

	for mir_i in 3:

		mir_e5.state.hand = [repo.get_card(9065)]

		mir_e5.state.energy = 9

		mir_e5.use_effect(0)

	var mir_cnt := 0

	for mir_l in mir_e5.log:

		if str(mir_l).contains("镜像：将一张"):

			mir_cnt += 1

	check(mir_cnt == 2,

			"镜像（R688 可叠加）：2 张 → 前 2 次使用效果牌各触发一次，第 3 次不再触发（实际 %d）" % mir_cnt)

	# ---- R688 幽深回响（9002）：使用时复制进抽牌库；回合开始按效果区张数打 X 下 6 点 ----

	var echo_e := _new_engine([], 30, 30, -1, false)

	echo_e.start_game(1)

	echo_e.state.place(_card(9405, "沙包甲", "盟友", 0, 0, 60, 5), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)

	echo_e.state.deck = [repo.get_card(9065)]

	echo_e.state.hand = [repo.get_card(9002)]

	echo_e.state.energy = 9

	echo_e.use_effect(0)

	check(echo_e.state.effects.size() == 1 and echo_e.state.deck.size() == 2

			and echo_e.state.deck[1].id == 9002,

			"幽深回响：本体留在效果区，同时一张同名副本进抽牌库（抽牌库 1 → 2）")

	echo_e.end_turn()

	echo_e.end_turn()

	var echo_hp1: int = echo_e.state.unit_at(Vector2i(1, 0)).health

	check(echo_hp1 == 54,

			"幽深回响：回合开始按效果区 1 张 → 打 1 下 6 点（60 → 54，实际 %d）" % echo_hp1)

	var echo_e2 := _new_engine([], 30, 30, -1, false)

	echo_e2.start_game(1)

	echo_e2.state.effects.append(repo.get_card(9002))

	echo_e2.state.effects.append(repo.get_card(9002))

	echo_e2.state.place(_card(9405, "沙包甲", "盟友", 0, 0, 60, 5), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)

	echo_e2.end_turn()

	echo_e2.end_turn()

	check(echo_e2.state.unit_at(Vector2i(1, 0)).health == 48,

			"幽深回响：效果区 2 张 → 本回合打 2 下（60 → 48）")

	var echo_e3 := _new_engine([], 30, 30, -1, false)

	echo_e3.start_game(1)

	echo_e3.state.effects.append(repo.get_card(9002))

	echo_e3.end_turn()

	echo_e3.end_turn()

	var echo_foe_hp: int = echo_e3.state.hp_opponent

	check(echo_foe_hp == 24,

			"幽深回响：场上没有敌方单位 → 直击对方 HP（30 → 24，实际 %d）" % echo_foe_hp)

''',
    "new_cases", 1)

# ⑤ 文件头注释里的旧卡名
rep('## 回合结束弃全部手牌、牌库空时弃牌洗回、抽空提示、效果卡（迅捷减伤）、',
    '## 回合结束弃全部手牌、牌库空时弃牌洗回、抽空提示、效果卡（幽深回响 / 减伤通道）、',
    "header", 1)

# ⑥ 镜像用例里的旧卡名注释
rep('	# 镜像已在效果区 → 之后再打效果牌：复制「迅捷」入卡组，**再抽一张**（draw() 取牌库尾 → 抽回副本）',
    '	# 镜像已在效果区 → 之后再打效果牌：复制那张牌入卡组，**再抽一张**（draw() 取牌库尾 → 抽回副本）',
    "mirror_use_cmt", 1)

out = te
for old, new, tag, cnt in edits:
    c = out.count(old)
    if c != cnt:
        raise SystemExit("[%s] 锚点命中 %d 次（预期 %d），拒绝写入" % (tag, c, cnt))
    out = out.replace(old, new)

assert out.count("repo.get_card(9002)") == 5, \
    "预期 5 处 9002（数据 1 + 新用例 4），实际 %d" % out.count("repo.get_card(9002)")

tr, TR_EOL = load(TR)
tr_old = '''	var sv := repo.get_card(9002).to_dict()
	check(CardData.from_dict(sv).value == 2, "to_dict/from_dict 保留效果数值 value")'''
tr_new = '''	var sv := repo.get_card(9002).to_dict()
	check(CardData.from_dict(sv).value == 6,
			"to_dict/from_dict 保留效果数值 value（R688 幽深回响 value=6）")'''
assert tr.count(tr_old) == 1, "test_reward 锚点不唯一"

if "--write" in sys.argv:
    save(TE, out, TE_EOL)
    save(TR, tr.replace(tr_old, tr_new), TR_EOL)
else:
    print("dry-run：test_engine %d 处锚点 + 填充卡替换，test_reward 1 处；未落盘" % len(edits))
