# -*- coding: utf-8 -*-
"""R787：商店附魔「伤害 +10」→「伤害 +8」。

真源只有一处：`RunState.enchant_mod("damage")` 的 `power`。
其余全是**同一组数字的副本**（会漂移的都不该留着）：
  · CardData.ENCHANT_DEFS 的 label / desc（显示名唯一真源）
  · shop_scene.ENCHANTS 的 name / desc（smoke 逐条比对，分叉即红）
  · i18n 四语 + glossary 的 enchantments 词条（GameI18n.source 按中文串查）
  · 注释里引用的「伤害 +10」（不写清楚会误导下一个人以为真源还是 10）
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def load(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def save(rel, s):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag, crlf=None):
    n = s.count(old)
    if n != 1:
        print("FAIL [%s] 命中 %d 次：%r" % (tag, n, old[:70]))
        sys.exit(1)
    s = s.replace(old, new, 1)
    return s


def check_eol(rel, s, crlf):
    if crlf:
        bad = s.count("\n") - s.count("\r\n")
        if bad != 0:
            print("FAIL EOL [%s] 有 %d 个裸 LF" % (rel, bad))
            sys.exit(1)


# ─────────────────────────── run_state.gd（LF）───────────────────────────
P = "scripts/run_state.gd"
s = load(P)
s = rep(s,
        "（费用 -1 / 伤害 +10 / 次元 +2力+10血 / 保存）",
        "（费用 -1 / 伤害 +8 / 次元 +2力+10血 / 保存）", "rs-note1")
s = rep(s,
        "用户口径「伤害 +10 限制只能附魔给技能卡」",
        "用户口径「伤害 +8 限制只能附魔给技能卡」", "rs-note2")
s = rep(s,
        "消费 → 这张技能卡造成的伤害 +10。",
        "消费 → 这张技能卡造成的伤害 +8。", "rs-note3")
s = rep(s,
        '\t\t"damage": m = {"power": 10, "note": "伤害 +10"}',
        '\t\t"damage": m = {"power": 8, "note": "伤害 +8"}', "rs-mod")
s = rep(s,
        "\t## 费用 -1 / 次元(+2力+10血) / 保存 / 伤害 +10（带 note）。",
        "\t## 费用 -1 / 次元(+2力+10血) / 保存 / 伤害 +N（带 note）。\n"
        "\t## ⚠️ 数值本身**不**参与反推（R787 把 +10 下调成 +8 之后，老存档里那批\n"
        "\t##    `{\"power\": 10, \"note\": \"伤害 +10\"}` 仍然要认成 damage）—— 只认「有没有增量」。",
        "rs-reverse-note")
s = rep(s,
        "\t# 「伤害 +10」附魔改的是**结算值**",
        "\t# 「伤害 +8」附魔改的是**结算值**", "rs-note4")
check_eol(P, s, False)
save(P, s)
print("OK", P)

# ─────────────────────── card_data.gd（CRLF）───────────────────────
P = "scripts/card_data.gd"
s = load(P)
s = rep(s,
        "## 副本的 cost / power / health / affixes（费用 -1、伤害 +10、次元 +2力+10血、保存），",
        "## 副本的 cost / power / health / affixes（费用 -1、伤害 +8、次元 +2力+10血、保存），",
        "cd-note1")
s = rep(s,
        '\t"damage": {"label": "伤害 +10", "icon": "shop_icon_damage", "col": "f08a5a",\r\n'
        '\t\t\t"desc": "这张技能卡造成的伤害 +10。"},',
        '\t"damage": {"label": "伤害 +8", "icon": "shop_icon_damage", "col": "f08a5a",\r\n'
        '\t\t\t"desc": "这张技能卡造成的伤害 +8。"},',
        "cd-def")
s = rep(s,
        "\t# 与「伤害 +10」共用同一套消费点",
        "\t# 与「伤害 +8」共用同一套消费点", "cd-note2")
s = rep(s,
        "## 「伤害 +10」那种数值写死的附魔用不到它",
        "## 「伤害 +8」那种数值写死的附魔用不到它", "cd-note3")
s = rep(s,
        "（R226：伤害 +10 附魔的资格判据）",
        "（R226：伤害 +8 附魔的资格判据）", "cd-note4")
s = rep(s,
        "## 附魔的显示名（「费用 -1」/「伤害 +10」/「次元之力」/「保存」/「起手」）。",
        "## 附魔的显示名（「费用 -1」/「伤害 +8」/「次元之力」/「保存」/「起手」）。",
        "cd-note5")
check_eol(P, s, True)
save(P, s)
print("OK", P)

# ─────────────────────── shop_scene.gd（CRLF）───────────────────────
P = "scripts/shop_scene.gd"
s = load(P)
s = rep(s,
        '{"id": "damage", "name": "伤害 +10", "desc": "这张技能卡造成的伤害 +10（只能选能直接造成伤害的技能卡）",',
        '{"id": "damage", "name": "伤害 +8", "desc": "这张技能卡造成的伤害 +8（只能选能直接造成伤害的技能卡）",',
        "shop-ench")
check_eol(P, s, True)
save(P, s)
print("OK", P)

# ─────────────────────── battle_scene.gd（CRLF）───────────────────────
P = "scripts/battle_scene.gd"
s = load(P)
s = rep(s,
        "（不然出图里会出现「工事带伤害 +10」这种玩家",
        "（不然出图里会出现「工事带伤害 +8」这种玩家", "bs-note1")
s = rep(s,
        "伤害 +10 只给技能卡 / 次元之力只给盟友·工事 / 保存任意。",
        "伤害 +8 只给技能卡 / 次元之力只给盟友·工事 / 保存任意。", "bs-note2")
s = rep(s,
        "\t\tfx.power = 10     # 附魔「伤害 +10」烤进 power",
        "\t\tfx.power = 8      # 附魔「伤害 +8」烤进 power", "bs-demo1")
s = rep(s,
        "\t\t\t\t\tRunState.enchant_deck_card(di, {\"power\": 10})",
        "\t\t\t\t\tRunState.enchant_deck_card(di, {\"power\": 8})", "bs-demo2")
check_eol(P, s, True)
save(P, s)
print("OK", P)

# ─────────────────────── game_engine.gd（CRLF）───────────────────────
P = "scripts/game_engine.gd"
s = load(P)
s = rep(s,
        "荧光草 / 魔法塔 / 附魔「伤害 +10」对主刀与弹跳**都**生效。",
        "荧光草 / 魔法塔 / 附魔「伤害 +8」对主刀与弹跳**都**生效。", "ge-note1")
s = rep(s,
        "# R210：商店附魔「伤害 +10」的**唯一消费点**",
        "# R210：商店附魔「伤害 +8」的**唯一消费点**", "ge-note2")
s = rep(s,
        "## 打出时那张技能卡被附魔烤进去的 `power`（伤害 +10）—— 只补进 AOE，不吃其它技能加成。",
        "## 打出时那张技能卡被附魔烤进去的 `power`（伤害 +8）—— 只补进 AOE，不吃其它技能加成。",
        "ge-note3")
check_eol(P, s, True)
save(P, s)
print("OK", P)
