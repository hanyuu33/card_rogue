# -*- coding: utf-8 -*-
"""R756 代码补丁：
 1) 苹果：+7 最大生命 + 回复 20% 最大生命值（不再回满）
 2) 占卜室：占卜要失去 5 点最大生命
 3) 契约核心：去掉「那张卡之后 +1 费」，改成签契约时塞一张「代偿」9252 进卡组
 4) 代偿：在手卡里期间其余手卡费用 +1（cost_of 唯一口）
 5) 胜利 /「胜利？」结算：整局结束时清空待领奖励（原来只认最后一层）
"""
import io
import sys


def load(p):
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    return (s.replace("\r\n", "\n") if crlf else s), crlf


def save(p, s, crlf):
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag, times=1):
    n = s.count(old)
    assert n == times, "%s: count=%d" % (tag, n)
    print("  ok  %s" % tag)
    return s.replace(old, new)


# ---------------------------------------------------------------- run_state
P = "scripts/run_state.gd"
s, c = load(P)

s = rep(s,
        "# R224 新道具：苹果（6027，奖励池）—— 获得时**立即 +7 最大生命并回复满生命值**。\n"
        "# R445（用户口径）：14 → 7，占卜室 / 苹果与医生两条来源共用这一个常量。",
        "# R224 新道具：苹果（6027，奖励池）—— 获得时**立即 +7 最大生命，并回复 20% 最大生命值**。\n"
        "# R445（用户口径）：14 → 7；R756（店长口径）：「回复满」改成**回复 20% 最大生命值**——\n"
        "# 它不再是一条「免费满血」，而是一口实打实的补给。",
        "run_state/苹果注释")

s = rep(s,
        "const APPLE_RELIC_ID := 6027\nconst APPLE_MAX_HP := 7\n",
        "const APPLE_RELIC_ID := 6027\nconst APPLE_MAX_HP := 7\n"
        "const APPLE_HEAL_PCT := 0.20   # R756：回复「最大生命」的 20%（原来是一次回满）\n",
        "run_state/苹果常量")

s = rep(s,
        "\t\tAPPLE_RELIC_ID:   # 苹果（R224/244/445）：立即 +7 最大生命，并**回复满**生命值\n"
        "\t\t\tgain_max_hp(APPLE_MAX_HP)\n"
        "\t\t\thp = max_hp\n",
        "\t\tAPPLE_RELIC_ID:   # 苹果（R224/244/445/756）：立即 +7 最大生命，并回复 20% 最大生命值\n"
        "\t\t\tgain_max_hp(APPLE_MAX_HP)\n"
        "\t\t\thp = mini(max_hp, hp + int(round(max_hp * APPLE_HEAL_PCT)))\n",
        "run_state/苹果结算")
save(P, s, c)

# ---------------------------------------------------------------- game_engine
P = "scripts/game_engine.gd"
s, c = load(P)

s = rep(s,
        "# R458 咒缚（6058，「契约的核心」选项 1）：每场战斗**打出的第一张卡费用 -CURSE_DISCOUNT**，\n"
        "# 且**只减这一次**；那张卡之后在本场战斗里费用 +CURSE_RAISE（按原价 +1，不叠那 -3）。\n"
        "# R497：由「第一张卡免费（费用归 0）」改为「-3 费」—— 高费卡不再白打。\n"
        "const CURSE_BIND_RELIC_ID := 6058\n"
        "const CURSE_DISCOUNT := 3\n"
        "const CURSE_RAISE := 1\n",
        "# R458 咒缚（6058，「契约的核心」选项 1）：每场战斗**打出的第一张卡费用 -CURSE_DISCOUNT**，\n"
        "# 且**只减这一次**（R497：由「第一张卡免费（费用归 0）」改为「-3 费」—— 高费卡不再白打）。\n"
        "# R756（店长口径）：**取消「那张卡之后 +1 费」那一半** —— 代价改成「签契约时往卡组里塞\n"
        "# 一张代偿 9252」。所以这里只剩减费那一半，涨价那一半由代偿自己承担。\n"
        "const CURSE_BIND_RELIC_ID := 6058\n"
        "const CURSE_DISCOUNT := 3\n"
        "# R756 代偿（9252）：**在手卡里期间**，其余手卡费用 +COMP_COST_RAISE。\n"
        "# 判据按**卡面 trait** 判（与「疲惫」同一写法），将来换皮只要留着 trait 就照样生效。\n"
        "const COMP_COST_TRAIT := \"代偿\"\n"
        "const COMP_COST_RAISE := 1\n",
        "engine/咒缚常量")

s = rep(s,
        "\t\t\t_log(\"咒缚：本场战斗的第一张卡费用 -%d（那张卡之后费用 +%d）\"\n"
        "\t\t\t\t\t% [CURSE_DISCOUNT, CURSE_RAISE])\n",
        "\t\t\t_log(\"咒缚：本场战斗的第一张卡费用 -%d\" % CURSE_DISCOUNT)\n",
        "engine/咒缚开局日志")

s = rep(s,
        "\t# R458 咒缚（6058）的另一半：被 -N 费打出的那张卡，**本场战斗**费用 +CURSE_RAISE。\n"
        "\t# 它是「涨价」，所以排在所有减费之后（与契约签订者 8024 同一个位置口径）；\n"
        "\t# 而咒缚自己的 -N 又排在它之后 —— 所以「第一张卡 -3、之后原价 +1」两者不会互相吃掉。\n"
        "\tif side == SIDE_SELF and card != null:\n"
        "\t\tc += int(state.curse_raise.get(card, 0))\n",
        "\t# R756 代偿（9252）：「这张卡在手卡时，**其他**手卡费用 +1」——\n"
        "\t# 与「疲惫」同一条路（只在手牌里生效、离手即恢复原价），排在所有减费之后。\n"
        "\t# ⚠️ `_hand_has_compensation(card)` 把「正在算费用的这一张」排除在外：\n"
        "\t#    代偿自己不吃自己那 +1。\n"
        "\tif side == SIDE_SELF and card != null and _hand_has_compensation(card):\n"
        "\t\tc += COMP_COST_RAISE\n",
        "engine/cost_of 代偿")

s = rep(s,
        "func _hand_has_curse() -> bool:\n"
        "\t## 当前手牌里是否有「疲惫」（9149）—— R223 难度 5 的涨价判据。\n"
        "\tfor c: CardData in state.hand:\n"
        "\t\tif c != null and c.traits.has(FATIGUE_TRAIT):\n"
        "\t\t\treturn true\n"
        "\treturn false\n",
        "func _hand_has_trait(t: String) -> bool:\n"
        "\t## 手牌里是否有一张带 `t` 这个**卡面 trait** 的卡（涨价类判据的唯一口）。\n"
        "\tfor c: CardData in state.hand:\n"
        "\t\tif c != null and c.traits.has(t):\n"
        "\t\t\treturn true\n"
        "\treturn false\n"
        "\n"
        "\n"
        "func _hand_has_curse() -> bool:\n"
        "\t## 当前手牌里是否有「疲惫」（9149）—— R223 难度 5 的涨价判据。\n"
        "\treturn _hand_has_trait(FATIGUE_TRAIT)\n"
        "\n"
        "\n"
        "func _hand_has_compensation(self_card: CardData = null) -> bool:\n"
        "\t## R756 代偿（9252）：「这张卡在手卡时，**其他**手卡费用 +1」的判据。\n"
        "\t## `self_card` = 正在算费用的那一张（代偿自己不吃自己那 +1）。\n"
        "\t## ⚠️ 只看手牌，不看场上 / 弃牌区 —— 卡面写的就是「在手卡时」。\n"
        "\tfor c: CardData in state.hand:\n"
        "\t\tif c != null and c != self_card and c.traits.has(COMP_COST_TRAIT):\n"
        "\t\t\treturn true\n"
        "\treturn false\n",
        "engine/手牌 trait 判据")

s = rep(s,
        "\t# R458 咒缚（6058）：「第一张卡 -3 费」在这里**兑现成账** —— 额度用掉，并给这一张\n"
        "\t# 记一笔本场战斗 +CURSE_RAISE 费（再次上手时按原价 +1 结算，不叠那 -3）。\n",
        "\t# R458 咒缚（6058）：「第一张卡 -3 费」在这里**兑现成账** —— 额度用掉就完事。\n"
        "\t# R756：那张卡**不再涨价**（代价已改成签契约时塞进卡组的一张「代偿」），这里不记账。\n",
        "engine/咒缚收尾注释")

s = rep(s,
        "\t\tstate.curse_free = false\n"
        "\t\tstate.curse_raise[played] = int(state.curse_raise.get(played, 0)) + CURSE_RAISE\n"
        "\t\t_log(\"咒缚：第一张卡「%s」费用 -%d —— 它在本场战斗的费用 +%d\"\n"
        "\t\t\t\t% [played.card_name, CURSE_DISCOUNT, CURSE_RAISE])\n",
        "\t\tstate.curse_free = false\n"
        "\t\t_log(\"咒缚：第一张卡「%s」费用 -%d\" % [played.card_name, CURSE_DISCOUNT])\n",
        "engine/咒缚收尾实现")
save(P, s, c)

# ---------------------------------------------------------------- field_state
P = "scripts/field_state.gd"
s, c = load(P)
s = rep(s,
        "## R458 咒缚（6058）：CardData -> int。被减费打出的那张卡在本场战斗里的**涨价**\n"
        "##（再次上手才吃；战斗结束随 FieldState 一起丢）。\n"
        "var curse_raise := {}\n",
        "",
        "field_state/删 curse_raise")
save(P, s, c)

# ---------------------------------------------------------------- event_scene
P = "scripts/event_scene.gd"
s, c = load(P)

s = rep(s,
        "获得「苹果」：最大生命 +7，并回复满生命值。",
        "获得「苹果」：最大生命 +7，并回复 20% 最大生命值。",
        "event/苹果描述")

s = rep(s,
        "占卜师收完钱就不见了，只留下这颗球，和一阵檀香。\"\"\"",
        "占卜师收完钱就不见了，只留下这颗球，和一阵檀香。\n"
        "（占卜的代价：失去 5 点最大生命。）\"\"\"",
        "event/占卜描述")

s = rep(s,
        "const DIVINATION_KINDS := 4\n",
        "const DIVINATION_KINDS := 4\n"
        "## R756（店长口径）：占卜**要付代价** —— 失去 5 点最大生命（与「源数之力」同一条\n"
        "## `RunState.lose_max_hp` 口径：只削上限，不额外扣当前生命）。\n"
        "const DIVINATION_HP_COST := 5\n",
        "event/占卜代价常量")

s = rep(s,
        "\t\t\tdesc.text = DIVINATION_DESC\n"
        "\t\t\trest_btn.text = \"进行占卜\"\n"
        "\t\t\trest_btn.disabled = false\n",
        "\t\t\tdesc.text = DIVINATION_DESC\n"
        "\t\t\t# R756：占卜要付代价 —— 失去 DIVINATION_HP_COST 点最大生命。\n"
        "\t\t\t# 付不起就不让点：`lose_max_hp` 会「至少留 1 点」，不拦等于白占一次。\n"
        "\t\t\tif RunState.max_hp <= DIVINATION_HP_COST:\n"
        "\t\t\t\trest_btn.text = \"最大生命不足（占卜需失去 %d 点）\" % DIVINATION_HP_COST\n"
        "\t\t\t\trest_btn.disabled = true\n"
        "\t\t\telse:\n"
        "\t\t\t\trest_btn.text = \"进行占卜（失去 %d 点最大生命）\" % DIVINATION_HP_COST\n"
        "\t\t\t\trest_btn.disabled = false\n",
        "event/占卜按钮")

s = rep(s,
        "\tif _is_divination():\n"
        "\t\tif _div_stage == 0:\n"
        "\t\t\t# 进行占卜：1~4 随机（**走本局 run_rng**，同种子一致）\n"
        "\t\t\t_div_rolled = RunState.run_rng.randi_range(1, DIVINATION_KINDS)\n"
        "\t\t\t_div_stage = 1\n"
        "\t\t\t_apply_divination_text()\n",
        "\tif _is_divination():\n"
        "\t\tif _div_stage == 0:\n"
        "\t\t\t# R756：先付代价（失去 5 点最大生命）再占卜；付不起就不让占（按钮同判据）。\n"
        "\t\t\tif RunState.max_hp <= DIVINATION_HP_COST:\n"
        "\t\t\t\treturn\n"
        "\t\t\tvar div_paid := RunState.lose_max_hp(DIVINATION_HP_COST)\n"
        "\t\t\t# 进行占卜：1~4 随机（**走本局 run_rng**，同种子一致）\n"
        "\t\t\t_div_rolled = RunState.run_rng.randi_range(1, DIVINATION_KINDS)\n"
        "\t\t\t_div_stage = 1\n"
        "\t\t\t_apply_divination_text()\n"
        "\t\t\tif div_paid > 0:\n"
        "\t\t\t\tresult_label.text = \"（占卜的代价：失去 %d 点最大生命 → %d / %d）\" % [\n"
        "\t\t\t\t\t\tdiv_paid, RunState.hp, RunState.max_hp]\n",
        "event/占卜结算")

s = rep(s,
        "##   选项 1 订立契约 → 道具「咒缚」（每场战斗第一张卡 -3 费 / 那张卡本场 +1 费）\n",
        "##   选项 1 订立契约 → 道具「咒缚」（每场战斗第一张卡 -3 费）+ 一张「代偿」进卡组\n"
        "##                        （R756：代价从「那张卡之后 +1 费」改成这张诅咒）\n",
        "event/契约头注释")

s = rep(s,
        "const CORE_CURSE_ID := 6058       # 咒缚（选项 1 的事件道具）\n",
        "const CORE_CURSE_ID := 6058       # 咒缚（选项 1 的事件道具）\n"
        "## R756（店长口径）：签契约**不再**让首张卡在之后涨价 —— 代价改成\n"
        "## 「当场往卡组里塞一张代偿 9252（2 费诅咒 · 次元 · 在手卡里期间其余手卡 +1 费）」。\n"
        "const CORE_COMP_CARD_ID := 9252\n",
        "event/契约常量")

s = rep(s,
        "\t##   · 选项 1 订立契约 → 道具「咒缚」；\n",
        "\t##   · 选项 1 订立契约 → 道具「咒缚」+ 往卡组塞一张「代偿」（R756）；\n",
        "event/契约铺排注释")

s = rep(s,
        "\t\trest_btn.text = \"订立契约（获得道具「咒缚」）\"\n",
        "\t\trest_btn.text = \"订立契约（「咒缚」+ 一张「代偿」）\"\n",
        "event/契约按钮")

s = rep(s,
        "\tRunState.gain_relic(CORE_CURSE_ID)\n"
        "\tvar rel := RelicRepo.load_json().get_relic(CORE_CURSE_ID)\n"
        "\t_core_pick = \"contract\"\n"
        "\t_claim_reward(rest_btn)\n"
        "\tdesc.text = CORE_CONTRACT_DESC\n"
        "\t_core_result = \"「咒缚」已收进道具栏：%s\" % (rel.desc if rel != null else \"\")\n",
        "\tRunState.gain_relic(CORE_CURSE_ID)\n"
        "\t# R756：契约的代价写在**签的这一刻** —— 当场塞一张「代偿」进卡组（不是「那张卡涨价」）。\n"
        "\tRunState.add_card(CORE_COMP_CARD_ID)\n"
        "\tvar rel := RelicRepo.load_json().get_relic(CORE_CURSE_ID)\n"
        "\tvar comp := CardRepo.load_json().get_card(CORE_COMP_CARD_ID)\n"
        "\t_core_pick = \"contract\"\n"
        "\t_claim_reward(rest_btn)\n"
        "\tdesc.text = CORE_CONTRACT_DESC\n"
        "\t_core_result = \"获得道具「咒缚」，一张「%s」已加入你的卡组。（咒缚：%s）\" % [\n"
        "\t\t\tcomp.card_name if comp != null else \"代偿\",\n"
        "\t\t\trel.desc if rel != null else \"\"]\n",
        "event/契约落账")
save(P, s, c)

# ---------------------------------------------------------------- battle_scene
P = "scripts/battle_scene.gd"
s, c = load(P)

s = rep(s,
        "\t\t\t# R472（用户口径「打完 3 层 boss 游戏都胜利了，不需要结算奖励了，直接提示胜利」）：\n"
        "\t\t\t# 最后一层 Boss 打完 = 整局结束，卡组 / 道具 / 金币都不会再被下一局用到 ——\n"
        "\t\t\t# 还弹一个「共 N 件，待领 N 件」的奖励页纯属多此一举。这里把这一批直接清掉，\n"
        "\t\t\t# 结算面板接上「胜利」提示（奖励窗的打开判据是 `pending_reward_count() > 0`，\n"
        "\t\t\t# 清空之后它自己就不会弹了）。\n"
        "\t\t\t# ⚠️ 金币 / boss 记账 / 击杀统计都在上面已经结算完，别一起清。\n"
        "\t\t\tif _run_boss_win and GameLayers.next_layer(RunState.current_layer) <= 0:\n"
        "\t\t\t\tRunState.pending_rewards = []\n"
        "\t\t\t\tRunState.pending_relic_drop = -1\n"
        "\t\t\t\tRunState.relic_choice = []\n",
        "",
        "battle/删旧清空块")

s = rep(s,
        "\t\t\t\tif _run_next_layer == GameLayers.LAYER_THREE \\\n"
        "\t\t\t\t\t\tand not RunState.can_enter_third_layer():\n"
        "\t\t\t\t\t_run_next_layer = 0\n",
        "\t\t\t\tif _run_next_layer == GameLayers.LAYER_THREE \\\n"
        "\t\t\t\t\t\tand not RunState.can_enter_third_layer():\n"
        "\t\t\t\t\t_run_next_layer = 0\n"
        "\t\t\t# R472（用户口径「打完 3 层 boss 游戏都胜利了，不需要结算奖励了，直接提示胜利」）：\n"
        "\t\t\t# **这一局到此为止**时，卡组 / 道具 / 金币都不会再被用到 —— 留一批「待领 N 件」\n"
        "\t\t\t# 纯属多此一举（奖励窗的打开判据就是 `pending_reward_count() > 0`）。\n"
        "\t\t\t# R756：判据从「没有下一层」改成「这次真的结束」—— 原来只认最后一层，\n"
        "\t\t\t# 「打通二层但信物不齐 = 胜利？」那条路会把整批奖励（含雕像祝福必掉的工具）\n"
        "\t\t\t# 一起带进结算页，玩家还能从胜利面板点「查看奖励」进去领一堆带不走的东西。\n"
        "\t\t\t# ⚠️ 必须放在 `_run_next_layer` 算完之后（它可能被上面那段清成 0）。\n"
        "\t\t\t# ⚠️ 金币 / boss 记账 / 击杀统计都在上面已经结算完，别一起清。\n"
        "\t\t\tif _run_next_layer <= 0:\n"
        "\t\t\t\tRunState.pending_rewards = []\n"
        "\t\t\t\tRunState.pending_relic_drop = -1\n"
        "\t\t\t\tRunState.relic_choice = []\n",
        "battle/新清空块")
save(P, s, c)

print("all code patches applied")
