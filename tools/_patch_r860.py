# -*- coding: utf-8 -*-
"""R860：刺墙 6073 伤害 5→4；兵 6071 「第一个盟友」→「第三个盟友」。

一次性精确替换，每处带锚点断言；.gd 保持 CRLF，JSON 保持 LF。
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 首次运行在前三个文件落盘后中断；这几个已应用，重跑时跳过。
_ALREADY_DONE = {"scripts/game_engine.gd", "scripts/placement.gd", "scripts/field_state.gd"}


def rep(path, pairs, crlf=False):
    if path in _ALREADY_DONE:
        print("skip (already patched)", path)
        return
    p = os.path.join(ROOT, path)
    b = open(p, "rb").read()
    for old, new in pairs:
        if crlf:
            ob = old.replace("\n", "\r\n").encode("utf-8")
            nb = new.replace("\n", "\r\n").encode("utf-8")
        else:
            ob = old.encode("utf-8")
            nb = new.encode("utf-8")
        n = b.count(ob)
        assert n == 1, "[%s] expected 1 hit, got %d: %s" % (path, n, old[:90])
        b = b.replace(ob, nb, 1)
    open(p, "wb").write(b)
    print("patched", path, "(%d replacements)" % len(pairs))


# ── ① 引擎：刺墙数值 + 兵改计数 ───────────────────────────────────────────
rep("scripts/game_engine.gd", [
    ("# R792 兵（6071，一般档）：每场战斗**第一个盟友**可以行动两次。",
     "# R860 兵（6071，一般档）：每场战斗**第三个盟友**可以行动两次。"),

    ("const PAWN_ACTIONS:= 2\n",
     "const PAWN_ACTIONS:= 2\n"
     "const PAWN_AT:= 3     # R860 兵：本场第 3 个落地的己方盟友才获得双动\n"),

    ("const SPIKE_WALL_DMG:= 5\n",
     "const SPIKE_WALL_DMG:= 4\n"),

    ("\t_pawn_first_ally_done = false    # R792 兵：同上\n",
     "\t_pawn_ally_used = 0              # R860 兵：本场计数归零（第 3 个盟友双动）\n"),

    ("# R792 板甲 / 兵：本场「第一个盟友」的额度是否已经发过（每场战斗各一次）。\n"
     "# 两件道具分开记 —— 只持有一件时另一个标记永远不动，将来加第二件同型道具也不打架。\n"
     "var _plate_first_ally_done := false\n"
     "var _pawn_first_ally_done := false\n",
     "# R792 板甲：本场「第一个盟友」的额度是否已经发过；R860 兵：计本场已落地几个盟友。\n"
     "# 两件道具分开记 —— 只持有一件时另一个标记永远不动，将来加第二件同型道具也不打架。\n"
     "var _plate_first_ally_done := false\n"
     "var _pawn_ally_used := 0\n"),

    ("\t# ── R792 兵（6071）──────────────────────────────────────────────\n"
     "\t# 同一个「第一个盟友」可以行动两次。`first_ally_twice` 只为 `unit_actions()` 提供判据，\n"
     "\t# 但**落地这一刻**行动轮数已经发过了（`place()` 里按老的 unit_actions 发的），\n"
     "\t# 所以这里必须按差额补发一次 —— 走 `grant_actions` 唯一口，别直接写 `acts_left`。\n"
     "\tif RunState.has_relic(PAWN_RELIC_ID) and p.owner == SIDE_SELF and card.kind == \"盟友\" and not _pawn_first_ally_done:\n"
     "\t\t_pawn_first_ally_done = true\n"
     "\t\tp.first_ally_twice = true\n"
     "\t\tstate.grant_actions(p, state.unit_actions(p, SIDE_SELF))\n"
     "\t\t_log(\"兵：第一个盟友 %s 本场可以行动两次\" % card.card_name)\n",
     "\t# ── R860 兵（6071）──────────────────────────────────────────────\n"
     "\t# 本场**第 3 个**落地的己方盟友可以行动两次（原为第 1 个）。`pawn_ally_twice` 只为\n"
     "\t# `unit_actions()` 提供判据，落地这一刻行动轮数已按老口径发过，\n"
     "\t# 所以这里必须按差额补发一次 —— 走 `grant_actions` 唯一口，别直接写 `acts_left`。\n"
     "\tif RunState.has_relic(PAWN_RELIC_ID) and p.owner == SIDE_SELF and card.kind == \"盟友\":\n"
     "\t\t_pawn_ally_used += 1\n"
     "\t\tif _pawn_ally_used == PAWN_AT:\n"
     "\t\t\tp.pawn_ally_twice = true\n"
     "\t\t\tstate.grant_actions(p, state.unit_actions(p, SIDE_SELF))\n"
     "\t\t\t_log(\"兵：第 %d 个盟友 %s 本场可以行动两次\" % [_pawn_ally_used, card.card_name])\n"),

    ("\t# 己方盟友 —— 与板甲 6070 / 兵 6071 同一条判据：手牌打出与涂装机器人 8080「变成」\n",
     "\t# 己方盟友 —— 与板甲 6070 同一条判据（兵 6071 自 R860 起改为第 3 个）：手牌打出与涂装机器人 8080「变成」\n"),
], crlf=True)

# ── ② Placement 字段 / FieldState 判据 ────────────────────────────────────
rep("scripts/placement.gd", [
    ("## R792 兵（6071）：本场第一个盟友可以行动两次。读在 `FieldState.unit_actions()` ——\n"
     "## 与疾行 / 哈气 / 赫利俄斯同一条「取最大」通道，落地与回合重置自动一致。\n"
     "var first_ally_twice: bool = false\n",
     "## R860 兵（6071）：本场第三个盟友可以行动两次。读在 `FieldState.unit_actions()` ——\n"
     "## 与疾行 / 哈气 / 赫利俄斯同一条「取最大」通道，落地与回合重置自动一致。\n"
     "## 「第几个」由引擎计数判定（`_pawn_ally_used == PAWN_AT`），这里只标记已授予。\n"
     "var pawn_ally_twice: bool = false\n"),
    ("\tif first_ally_twice:\n", "\tif pawn_ally_twice:\n"),
], crlf=True)

rep("scripts/field_state.gd", [
    ("\t# R792 兵（6071）：本场第一个盟友可以行动两次 —— 与上面几条同一条「取最大」通道，\n",
     "\t# R860 兵（6071）：本场第三个盟友可以行动两次 —— 与上面几条同一条「取最大」通道，\n"),
    ("\tif p.first_ally_twice:\n", "\tif p.pawn_ally_twice:\n"),
], crlf=True)

# ── ③ 测试：刺墙数值 5→4；兵改第 3 个 ─────────────────────────────────────
rep("scripts/test_engine.gd", [
    ("\t# ③ 兵：第一个盟友当回合就有 2 轮行动；第二个只 1 轮\n",
     "\t# ③ 兵（R860）：第 3 个盟友当回合就有 2 轮行动；前两个只 1 轮\n"),
    ("\tr792_pawn.state.hand.append(CardData.from_dict(r792_cards.get_card(9028).to_dict()))\n"
     "\n"
     "\tr792_pawn.state.hand.append(CardData.from_dict(r792_cards.get_card(9028).to_dict()))\n",
     "\tr792_pawn.state.hand.append(CardData.from_dict(r792_cards.get_card(9028).to_dict()))\n"
     "\n"
     "\tr792_pawn.state.hand.append(CardData.from_dict(r792_cards.get_card(9028).to_dict()))\n"
     "\n"
     "\tr792_pawn.state.hand.append(CardData.from_dict(r792_cards.get_card(9028).to_dict()))\n"),
    ("\tvar r792_n2 := r792_pawn.play_from_hand(0, Vector2i(4, 1))\n",
     "\tvar r792_n2 := r792_pawn.play_from_hand(0, Vector2i(4, 1))\n"
     "\tvar r792_n3 := r792_pawn.play_from_hand(0, Vector2i(6, 1))\n"),
    ("\tcheck(r792_n1 != null and r792_n1.acts_left == 2 and r792_pawn.state.unit_actions(r792_n1, \"self\") == 2,\n"
     "\t\t\t\"R792 兵：第一个盟友本回合就有 2 轮行动（acts_left=%d）\" % (r792_n1.acts_left if r792_n1 != null else -1))\n"
     "\n"
     "\tcheck(r792_n2 != null and r792_n2.acts_left == 1 and not r792_n2.first_ally_twice,\n"
     "\t\t\t\"R792 兵：第二个盟友只行动一次\")\n",
     "\tcheck(r792_n1 != null and r792_n1.acts_left == 1 and not r792_n1.pawn_ally_twice,\n"
     "\t\t\t\"R860 兵：第一个盟友只行动一次（acts_left=%d）\" % (r792_n1.acts_left if r792_n1 != null else -1))\n"
     "\n"
     "\tcheck(r792_n2 != null and r792_n2.acts_left == 1 and not r792_n2.pawn_ally_twice,\n"
     "\t\t\t\"R860 兵：第二个盟友只行动一次\")\n"
     "\n"
     "\tcheck(r792_n3 != null and r792_n3.acts_left == 2 and r792_pawn.state.unit_actions(r792_n3, \"self\") == 2,\n"
     "\t\t\t\"R860 兵：第三个盟友本回合就有 2 轮行动（acts_left=%d）\" % (r792_n3.acts_left if r792_n3 != null else -1))\n"),
    ("\t# ⑤ 源码守卫：「第一个盟友」两个额度各只发一次，重置点在 start_game\n",
     "\t# ⑤ 源码守卫：板甲「第一个盟友」只发一次；R860 兵按计数第 3 个才发，重置点在 start_game\n"),
    ("\tcheck_src(r792_ge_src.contains(\"_plate_first_ally_done = false\") and r792_ge_src.contains(\"_pawn_first_ally_done = false\") and r792_ge_src.contains(\"state.grant_actions(p, state.unit_actions(p, SIDE_SELF))\"),\n"
     "\t\t\t\"R792 源码守卫：兵的双动走 grant_actions 补发，两个额度在 start_game 重置\")\n",
     "\tcheck_src(r792_ge_src.contains(\"_plate_first_ally_done = false\") and r792_ge_src.contains(\"_pawn_ally_used = 0\") and r792_ge_src.contains(\"if _pawn_ally_used == PAWN_AT:\") and r792_ge_src.contains(\"state.grant_actions(p, state.unit_actions(p, SIDE_SELF))\"),\n"
     "\t\t\t\"R860 源码守卫：兵按计数第 3 个才发双动、走 grant_actions 补发，start_game 归零\")\n"),

    ("\t# ② 刺墙扩面：敌人**直击我方 HP** → 攻击者 -5（原来只管工事，这条永远不触发）\n",
     "\t# ② 刺墙扩面：敌人**直击我方 HP** → 攻击者 -4（原来只管工事，这条永远不触发）\n"),
    ("\tcheck(r796_foe.health == r796_foe_hp0 - 5,\n"
     "\t\t\t\"R796 刺墙扩面：直击 HP → 攻击者 -5（%d → %d）\" % [r796_foe_hp0, r796_foe.health])\n",
     "\tcheck(r796_foe.health == r796_foe_hp0 - 4,\n"
     "\t\t\t\"R860 刺墙：直击 HP → 攻击者 -4（%d → %d）\" % [r796_foe_hp0, r796_foe.health])\n"),
    ("\tcheck(r827_she1.health == r827_she1hp0 - 5 and r827_she2.health == r827_she2hp0,\n",
     "\tcheck(r827_she1.health == r827_she1hp0 - 4 and r827_she2.health == r827_she2hp0,\n"),

    ("\t## R793（用户口径）：刺墙 6073（己方工事被攻击 → 攻击者受 5 伤）/\n",
     "\t## R860：刺墙 6073 伤害由 5 下调为 4（工事 / HP 被攻击 → 攻击者受 4 伤）/\n"),
    ("\t# ② 刺墙：敌方普攻打我方工事 → 攻击者 -5\n",
     "\t# ② 刺墙：敌方普攻打我方工事 → 攻击者 -4\n"),
    ("\tcheck(r793_foe.health == r793_foe_hp0 - 5,\n"
     "\t\t\t\"R793 刺墙：攻击工事 → 攻击者 -5（%d → %d）\" % [r793_foe_hp0, r793_foe.health])\n",
     "\tcheck(r793_foe.health == r793_foe_hp0 - 4,\n"
     "\t\t\t\"R860 刺墙：攻击工事 → 攻击者 -4（%d → %d）\" % [r793_foe_hp0, r793_foe.health])\n"),
    ("\tcheck(r827_e1.health == r827_e1hp0 - 5 and r827_e2.health == r827_e2hp0,\n",
     "\tcheck(r827_e1.health == r827_e1hp0 - 4 and r827_e2.health == r827_e2hp0,\n"),
    ("\tcheck(r827_e3.health == r827_e3hp0 - 5,\n",
     "\tcheck(r827_e3.health == r827_e3hp0 - 4,\n"),
], crlf=True)

# ── ④ 数据层 + 四语文案 ───────────────────────────────────────────────────
rep("relics.json", [
    ('"desc": "每场战斗使用的第一个盟友可以行动两次（不叠加）。"',
     '"desc": "每场战斗使用的第三个盟友可以行动两次（不叠加）。"'),
    ('"desc": "每回合一次：你的工事或你的生命被攻击时，对攻击者造成 5 点伤害。"',
     '"desc": "每回合一次：你的工事或你的生命被攻击时，对攻击者造成 4 点伤害。"'),
])

rep("i18n/noncard_zh_canonical.json", [
    ('"6071": {"name": "兵", "desc": "每场战斗使用的第一个盟友可以行动两次（不叠加）。"}',
     '"6071": {"name": "兵", "desc": "每场战斗使用的第三个盟友可以行动两次（不叠加）。"}'),
    ('"6073": {"name": "刺墙", "desc": "每回合一次：你的工事或你的生命被攻击时，对攻击者造成 5 点伤害。"}',
     '"6073": {"name": "刺墙", "desc": "每回合一次：你的工事或你的生命被攻击时，对攻击者造成 4 点伤害。"}'),
])

rep("i18n/noncard_en.json", [
    ('"6071": {"name": "Pawn", "desc": "The first Ally you play each combat can act twice (does not stack)."}',
     '"6071": {"name": "Pawn", "desc": "The third Ally you play each combat can act twice (does not stack)."}'),
    ('"6073": {"name": "Spike Wall", "desc": "Once per turn: whenever one of your Structures or your HP is attacked, deal 5 damage to the attacker."}',
     '"6073": {"name": "Spike Wall", "desc": "Once per turn: whenever one of your Structures or your HP is attacked, deal 4 damage to the attacker."}'),
])

rep("i18n/noncard_ja.json", [
    ('"6071": {"name": "ポーン", "desc": "各戦闘で最初に使う味方は2回行動できる（重複しない）。"}',
     '"6071": {"name": "ポーン", "desc": "各戦闘で3番目に使う味方は2回行動できる（重複しない）。"}'),
    ('"6073": {"name": "トゲの壁", "desc": "1ターンに1回：自分の構造物または自分のHPが攻撃されたとき、攻撃者に5ダメージを与える。"}',
     '"6073": {"name": "トゲの壁", "desc": "1ターンに1回：自分の構造物または自分のHPが攻撃されたとき、攻撃者に4ダメージを与える。"}'),
])

rep("i18n/noncard_es.json", [
    ('"6071": {"name": "Peón", "desc": "El primer Aliado que juegas en cada combate puede actuar dos veces (no se acumula)."}',
     '"6071": {"name": "Peón", "desc": "El tercer Aliado que juegas en cada combate puede actuar dos veces (no se acumula)."}'),
    ('"6073": {"name": "Muro de Púas", "desc": "Una vez por turno: cuando una de tus Estructuras o tu Vida es atacada, inflige 5 de daño al atacante."}',
     '"6073": {"name": "Muro de Púas", "desc": "Una vez por turno: cuando una de tus Estructuras o tu Vida es atacada, inflige 4 de daño al atacante."}'),
])

rep("art_src/2026-11-18_道具图标_R793/README.md", [
    ("使攻击者受到 5 伤害", "使攻击者受到 4 伤害"),
])

print("== R860 补丁完成 ==")
