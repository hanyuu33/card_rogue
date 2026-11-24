# -*- coding: utf-8 -*-
"""R756 回归补丁：卡数基线 319→320 / 玩家 244→245，咒缚不再涨价，新增代偿 / 苹果 / 结算清空。"""
import io


def load(p):
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    return (s.replace("\r\n", "\n") if crlf else s), crlf


def save(p, s, crlf):
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag):
    n = s.count(old)
    assert n == 1, "%s: count=%d" % (tag, n)
    print("  ok  %s" % tag)
    return s.replace(old, new)


# ------------------------------------------------------------------ test_engine
P = "scripts/test_engine.gd"
s, c = load(P)

s = rep(s, "check(repo.all_cards().size() == 319,",
        "check(repo.all_cards().size() == 320,", "engine/卡数 320")

s = rep(s, '"图鉴 = 319 张（R692 +2：',
        '"图鉴 = 320 张（R756 +1：代偿 9252（契约核心的代价 · 2 费诅咒 · 次元 · 手卡里其余卡 +1 费）；R692 +2：',
        "engine/图鉴文案")

s = rep(s, "check(grp_player.size() == 244 and grp_enemy.size() == 75,",
        "check(grp_player.size() == 245 and grp_enemy.size() == 75,", "engine/分组 245")

s = rep(s, '"R738：319 张卡的 color 全部是元素族或空串（非法：%s）"',
        '"R738：320 张卡的 color 全部是元素族或空串（非法：%s）"', "engine/色相 320")

s = rep(s, "# ⑥ 咒缚（R497：第一张卡「-3 费」，不再是「归 0」），那张卡在本场 +1 费\n",
        "# ⑥ 咒缚（R497：第一张卡「-3 费」；R756：那张卡不再涨价 —— 代价改成一张「代偿」）\n",
        "engine/⑥ 注释")

s = rep(s,
        "\tcheck(r458_e.cost_of(r458_h0) == r458_h0.cost + GameEngine.CURSE_RAISE,\n"
        "\n"
        "\t\t\t\"R497 咒缚：同一张卡之后按原价 +%d 结算（%d → %d），不叠那 -3\"\n"
        "\n"
        "\t\t\t% [GameEngine.CURSE_RAISE, r458_h0.cost, r458_e.cost_of(r458_h0)])\n",
        "\tcheck(r458_e.cost_of(r458_h0) == r458_h0.cost,\n"
        "\n"
        "\t\t\t\"R756 咒缚：同一张卡之后回到原价（%d → %d），不再 +1 费\"\n"
        "\n"
        "\t\t\t% [r458_h0.cost, r458_e.cost_of(r458_h0)])\n",
        "engine/⑥ 不再涨价")

s = rep(s,
        "\tcheck(r458_e.state.curse_free and not r458_e.state.curse_raise.has(r458_x),\n",
        "\tcheck(r458_e.state.curse_free,\n", "engine/⑥ X 费卡判据")

BLOCK = """	# ⑥b R756 代偿（9252）：在手卡里时其余手卡 +1 费 —— 自己不吃自己那一口、离手即恢复
	var r756_deck: Array[CardData] = []

	var r756_e := _new_engine(r756_deck, 30, 30, -1, false)

	r756_e.start_game()

	var r756_a: CardData = _card(8003, "农民", "盟友", 5, 3, 8)

	var r756_cd: CardData = r458_repo.get_card(9252)

	var r756_comp: CardData = CardData.from_dict(r756_cd.to_dict())

	r756_e.state.hand.clear()

	r756_e.state.hand.append(r756_a)

	check(r756_e.cost_of(r756_a) == 5,
			"R756 代偿：手里没有代偿时照原价（%d）" % r756_e.cost_of(r756_a))

	r756_e.state.hand.append(r756_comp)

	check(r756_e.cost_of(r756_a) == 6,
			"R756 代偿：手里有代偿 → 其他手卡 +1 费（%d）" % r756_e.cost_of(r756_a))

	check(r756_e.cost_of(r756_comp) == 2,
			"R756 代偿：代偿自己不吃自己那 +1（%d）" % r756_e.cost_of(r756_comp))

	r756_e.state.hand.clear()

	check(r756_e.cost_of(r756_a) == 5,
			"R756 代偿：离手即恢复原价（%d）" % r756_e.cost_of(r756_a))

	check(r756_cd != null and r756_cd.is_curse() and r756_cd.cost == 2
			and r756_cd.affixes.has("次元"),
			"R756 代偿：2 费诅咒 + 「次元」（打出即消失）")

	check_src(FileAccess.get_file_as_string("res://scripts/game_engine.gd")
			.contains("_hand_has_compensation(card)"),
			"R756 源码锁：代偿的涨价走 cost_of 唯一口")

	check_src(FileAccess.get_file_as_string("res://scripts/event_scene.gd")
			.contains("RunState.add_card(CORE_COMP_CARD_ID)"),
			"R756 源码锁：签契约当场把「代偿」塞进卡组")

	check_src(FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
			.contains("if _run_next_layer <= 0:"),
			"R756 源码锁：整局结束（胜利 / 胜利？）都清空待领奖励")

	# ⑥c R756 苹果：+7 最大生命，并回复 20% 最大生命值（不再回满）
	var r756_sv_max := RunState.max_hp

	var r756_sv_hp := RunState.hp

	var r756_sv_relics := RunState.relics.duplicate()

	# `gain_relic` 对「还活着的重复持有」直接 return —— 先把它从栏里摘掉，测试才可复现。
	RunState.relics.erase(RunState.APPLE_RELIC_ID)

	RunState.max_hp = 50

	RunState.hp = 10

	RunState.gain_relic(RunState.APPLE_RELIC_ID)

	check(RunState.max_hp == 57 and RunState.hp == 28,
			"R756 苹果：最大生命 50→57、当前生命 10→28（+7 与 20%% × 57 = 11；满值为 %d / %d）"
			% [RunState.hp, RunState.max_hp])

	RunState.max_hp = r756_sv_max

	RunState.hp = r756_sv_hp

	RunState.relics = r756_sv_relics

"""

s = rep(s, "\t# 没这件道具 → 一点免费都不给\n", BLOCK + "\t# 没这件道具 → 一点免费都不给\n",
        "engine/新增 R756 块")

save(P, s, c)

# ------------------------------------------------------------------ test_reward
P = "scripts/test_reward.gd"
s, c = load(P)
s = rep(s, 'check(all.size() == 319, "卡牌库 319 张（R692 +2：',
        'check(all.size() == 320, "卡牌库 320 张（R756 +1：代偿 9252；R692 +2：',
        "reward/卡数 320")
save(P, s, c)

print("all test patches applied")
