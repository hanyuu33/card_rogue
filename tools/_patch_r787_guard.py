# -*- coding: utf-8 -*-
"""R787 收尾：smoke 提示文案对齐 + 新增「数值与标签同源」守卫。

为什么要多加一条守卫：`ENCHANT_DEFS.label`（卡面/商店显示）与
`RunState.enchant_mod()`（真正烤进 power 的数）是**两份**，现在都写 +8。
哪天只改一处，玩家就会看到「卡面写 +8、实际打 +10」这种最难查的漂移。
smoke 已有 name↔label 的守卫，但没有 label↔数值的守卫 —— 补上。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"
CRLF = "\r\n"


def load(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def save(rel, s):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(s)


# ── ① test_smoke.gd：失败提示里的「伤害 +10」（只是提示文字，但留着会误导排查）──
P = "scripts/test_smoke.gd"
s = load(P)
n = s.count("伤害 +10")
if n != 10:
    print("FAIL test_smoke 命中 %d 次（预期 10）" % n)
    sys.exit(1)
s = s.replace("伤害 +10", "伤害 +8")
# 老存档用例：mod 里烤的还是 +10，但**显示名**永远跟当前附魔表走（这是对的，别改回）
old_legacy = (
    "\t# R214：那张附魔是**没有 id 的老形态** mod（`{\"power\": 10}`）→ 按内容反推成 damage，\r\n"
    "\t# 卡面才能画出「伤害 +8」的附魔标记（老存档不能因为没有 id 就变成没标记）。\r\n"
)
new_legacy = (
    "\t# R214：那张附魔是**没有 id 的老形态** mod（`{\"power\": 10}`，R787 之前的数值）\r\n"
    "\t# → 按内容反推成 damage，卡面才能画出附魔标记（老存档不能因为没有 id 就变成没标记）。\r\n"
    "\t# ⚠️ 标记上的**名字**永远读当前附魔表（现在是「伤害 +8」），老存档烤着的 +10 是数值、\r\n"
    "\t#    不是标签 —— 这两件事本来就该分开。\r\n"
)
if s.count(old_legacy) != 1:
    print("FAIL 老存档注释锚点 %d" % s.count(old_legacy))
    sys.exit(1)
s = s.replace(old_legacy, new_legacy, 1)
bad = s.count("\n") - s.count(CRLF)
if bad != 0:
    print("FAIL EOL 裸 LF %d" % bad)
    sys.exit(1)
save(P, s)
print("OK", P, "改了", n, "处提示文案")

# ── ② test_engine.gd：加「数值与标签同源」守卫 ──
P = "scripts/test_engine.gd"
s = load(P)
anchor = (
    "\tcheck(RunState.enchant_mod(\"nope\").is_empty(),\r\n"
    "\r\n"
    "\t\t\"R214 附魔：未知 id → 空 mod（不会凭空造出一张附魔卡）\")\r\n"
)
if s.count(anchor) != 1:
    print("FAIL 锚点命中 %d" % s.count(anchor))
    sys.exit(1)

block = (
    "\r\n"
    "\t# R787：附魔「伤害 +8」的**数值真源**只有 `enchant_mod()` 一处 ——\r\n"
    "\t# 标签（卡面 / 商店 / 左栏都读它）里的数字必须与它逐个对上，\r\n"
    "\t# 否则玩家会看到「卡面写 +8、实际打 +10」这种最难查的漂移。\r\n"
    "\tvar r787_mod: Dictionary = RunState.enchant_mod(\"damage\")\r\n"
    "\tvar r787_label := str(CardData.ENCHANT_DEFS.get(\"damage\", {}).get(\"label\", \"\"))\r\n"
    "\tcheck(int(r787_mod.get(\"power\", 0)) == 8\r\n"
    "\t\t\tand r787_label.ends_with(\"+8\")\r\n"
    "\t\t\tand str(r787_mod.get(\"note\", \"\")).ends_with(\"+8\"),\r\n"
    "\t\t\"R787 附魔：伤害 +8 的数值与标签同源（power %d / 标签「%s」/ note「%s」）\"\r\n"
    "\t\t\t% [int(r787_mod.get(\"power\", 0)), r787_label, str(r787_mod.get(\"note\", \"\"))])\r\n"
)
s = s.replace(anchor, anchor + block, 1)
bad = s.count("\n") - s.count(CRLF)
if bad != 0:
    print("FAIL EOL 裸 LF %d" % bad)
    sys.exit(1)
save(P, s)
print("OK", P, "加了 R787 守卫")
