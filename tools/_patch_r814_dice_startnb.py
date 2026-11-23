# -*- coding: utf-8 -*-
"""R814：修「水晶骰子重摇把第一层起点邻居也遮成 ?」的规则冲突。

R192（玩家口径）：第一层起点后第一格只可能是事件 / 一般战斗，**不得出现「?」房**。
生成期在 `_make_cells` 里为此写死了 `hidden = false`；
但 `reroll_as_unknown`（骰子把非固定房间翻成 ? 的唯一实现口）对该格照样写了
`hidden = true` —— 内容仍是 battle/event，玩家看到的却是「?」，规则被掀掉。

R192 的老测试不带骰子（`RogueMap.generate(rng, LAYER_DEFAULT)`），所以一直绿着。

改动：
  ① rogue_map.gd：重摇时第一层起点邻居保持明牌（内容照旧重摇）。
  ② test_engine.gd：在 R192 段追加「带骰子」的三条断言。

幂等：每处 assert count==1。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


def sub(s, old, new, tag, crlf=False):
    if crlf:
        old = old.replace("\n", "\r\n")
        new = new.replace("\n", "\r\n")
    n = s.count(old)
    if n == 0 and s.count(new) >= 1:
        print("  [skip] %s（已是新值）" % tag)
        return s
    assert n == 1, "[%s] count=%d" % (tag, n)
    print("  [ok]   %s" % tag)
    return s.replace(old, new)


# ── ① rogue_map.gd ──
p = "scripts/rogue_map.gd"
s = read(p)
s = sub(
    s,
    "\t\tvar w := _unknown_weights(cell3, layer, start_nbs)\n"
    "\t\tvar t := \"\"\n"
    "\t\tif start_nbs.has(i3) and layer == GameLayers.LAYER_DEFAULT:\n"
    "\t\t\tt = _weighted(w, rng)\n"
    "\t\telse:\n"
    "\t\t\tt = _weighted_far(w, rng, col_of(i3), row_of(i3), far_norm)\n"
    "\t\tcell3[\"type\"] = t\n"
    "\t\tcell3[\"hidden\"] = true\n"
    "\t\tcell3[\"revealed\"] = false\n",
    "\t\tvar w := _unknown_weights(cell3, layer, start_nbs)\n"
    "\t\tvar is_l1_start_nb := start_nbs.has(i3) and layer == GameLayers.LAYER_DEFAULT\n"
    "\t\tvar t := \"\"\n"
    "\t\tif is_l1_start_nb:\n"
    "\t\t\tt = _weighted(w, rng)\n"
    "\t\telse:\n"
    "\t\t\tt = _weighted_far(w, rng, col_of(i3), row_of(i3), far_norm)\n"
    "\t\tcell3[\"type\"] = t\n"
    "\t\t# R814：第一层起点邻居**保持明牌**。`_make_cells` 为 R192 写死过 `hidden = false`\n"
    "\t\t# （「第一层起点后第一格不得出现「?」房」），本函数却把所有非固定格一律翻成 ?，\n"
    "\t\t# 内容仍是战斗/事件、但玩家看到「?」→ 规则在显示层被掀掉。\n"
    "\t\t# ⚠️ 只豁免**第一层**：第二层起点邻居本来就允许是 ?（R192 只禁精英/篝火）。\n"
    "\t\tcell3[\"hidden\"] = not is_l1_start_nb\n"
    "\t\tcell3[\"revealed\"] = is_l1_start_nb\n",
    "reroll 起点邻居保明牌",
)
write(p, s)

# ── ② test_engine.gd：R192 段追加带骰子断言 ──
p = "scripts/test_engine.gd"
s = read(p)
anchor = ('\tcheck(q_r192_seen_b and q_r192_seen_e,\n'
          '\n'
          '\t\t\t"R192 第一层起点邻居：事件与一般战斗都确实会出现（未被写死成单一类型）")\n')
assert s.count(anchor.replace("\n", "\r\n")) == 1, "R192 锚点未命中"

add = (
    '\n'
    '\t# ---- R814：R192 的约束在**带骰子**时也得成立 ----\n'
    '\t# R192 的老测试走 `RogueMap.generate(rng, LAYER)`（不带 dice_rng），只覆盖生成期；\n'
    '\t# 而骰子的重摇是另一条路（`reroll_as_unknown` 把所有非固定格翻成 ?）。\n'
    '\t# 实测（tools/_check_r813b_dice.gd，24 张）：修之前起点邻居 55/55 全显示成 ?。\n'
    '\tvar q_r814_bad_l1 := ""\n'
    '\tvar q_r814_bad_l2 := ""\n'
    '\tfor q_r814_i in 40:\n'
    '\t\tvar q_r814_rng := RandomNumberGenerator.new()\n'
    '\t\tq_r814_rng.seed = 140000 + q_r814_i\n'
    '\t\tvar q_r814_dice := RandomNumberGenerator.new()\n'
    '\t\tq_r814_dice.seed = 240000 + q_r814_i\n'
    '\t\tvar q_r814_m1: Array = RogueMap.generate(q_r814_rng, GameLayers.LAYER_DEFAULT,\n'
    '\t\t\t\tq_r814_dice, {})\n'
    '\t\tvar q_r814_s1: Dictionary = RogueMap.start_cell(q_r814_m1)\n'
    '\t\tfor q_r814_nid: int in (q_r814_s1["doors"] as Array):\n'
    '\t\t\tvar q_r814_c: Dictionary = q_r814_m1[q_r814_nid]\n'
    '\t\t\tvar q_r814_t := str(q_r814_c.get("type", ""))\n'
    '\t\t\tif q_r814_t != "event" and q_r814_t != "battle":\n'
    '\t\t\t\tq_r814_bad_l1 = "层1#%d 类型=%s" % [q_r814_nid, q_r814_t]\n'
    '\t\t\tif bool(q_r814_c.get("hidden", false)):\n'
    '\t\t\t\tq_r814_bad_l1 = "层1#%d 被遮成?房" % q_r814_nid\n'
    '\t\tvar q_r814_dice2 := RandomNumberGenerator.new()\n'
    '\t\tq_r814_dice2.seed = 340000 + q_r814_i\n'
    '\t\tvar q_r814_m2: Array = RogueMap.generate(q_r814_rng, GameLayers.LAYER_TWO,\n'
    '\t\t\t\tq_r814_dice2, {})\n'
    '\t\tvar q_r814_s2: Dictionary = RogueMap.start_cell(q_r814_m2)\n'
    '\t\tfor q_r814_nid2: int in (q_r814_s2["doors"] as Array):\n'
    '\t\t\tvar q_r814_t2 := str(q_r814_m2[q_r814_nid2].get("type", ""))\n'
    '\t\t\tif q_r814_t2 == "elite" or q_r814_t2 == "rest":\n'
    '\t\t\t\tq_r814_bad_l2 = "层2#%d 类型=%s" % [q_r814_nid2, q_r814_t2]\n'
    '\tcheck(q_r814_bad_l1 == "",\n'
    '\t\t\t"R814 带骰子：第一层起点邻居仍是事件/一般战斗，**没被遮成 ? 房**（违例：%s）"\n'
    '\t\t\t% ("无" if q_r814_bad_l1 == "" else q_r814_bad_l1))\n'
    '\tcheck(q_r814_bad_l2 == "",\n'
    '\t\t\t"R814 带骰子：第二层起点邻居仍不出精英/篝火（违例：%s）"\n'
    '\t\t\t% ("无" if q_r814_bad_l2 == "" else q_r814_bad_l2))\n'
    '\t# 反面对照：除起点邻居外的非固定格**必须**被遮成 ?（否则「只修了症状、骰子失效」）\n'
    '\tvar q_r814_other_q := 0\n'
    '\tvar q_r814_other_n := 0\n'
    '\tvar q_r814_rng3 := RandomNumberGenerator.new()\n'
    '\tq_r814_rng3.seed = 140777\n'
    '\tvar q_r814_dice3 := RandomNumberGenerator.new()\n'
    '\tq_r814_dice3.seed = 240777\n'
    '\tvar q_r814_m3: Array = RogueMap.generate(q_r814_rng3, GameLayers.LAYER_DEFAULT,\n'
    '\t\t\tq_r814_dice3, {})\n'
    '\tvar q_r814_nb := {}\n'
    '\tfor q_r814_d: int in (RogueMap.start_cell(q_r814_m3)["doors"] as Array):\n'
    '\t\tq_r814_nb[int(q_r814_d)] = true\n'
    '\tfor q_r814_c3: Dictionary in q_r814_m3:\n'
    '\t\tvar q_r814_i3 := int(q_r814_c3.get("id", -1))\n'
    '\t\tif RogueMap.is_fixed_open(q_r814_c3) or q_r814_nb.has(q_r814_i3):\n'
    '\t\t\tcontinue\n'
    '\t\tq_r814_other_n += 1\n'
    '\t\tif bool(q_r814_c3.get("hidden", false)):\n'
    '\t\t\tq_r814_other_q += 1\n'
    '\tcheck(q_r814_other_n > 0 and q_r814_other_q == q_r814_other_n,\n'
    '\t\t\t"R814 带骰子：其余非固定格**全部**变成 ? 房（%d / %d）"\n'
    '\t\t\t% [q_r814_other_q, q_r814_other_n])\n'
)
s = s.replace(anchor.replace("\n", "\r\n"), anchor.replace("\n", "\r\n") + add.replace("\n", "\r\n"))
print("  [ok]   R814 断言段")
write(p, s)

print("--- eol ---")
for f in ("scripts/rogue_map.gd", "scripts/test_engine.gd"):
    b = io.open(ROOT + f, "rb").read()
    cr, lf = b.count(b"\r\n"), b.count(b"\n")
    print("  %-26s CRLF=%-6d LF=%-6d %s" % (f, cr, lf,
          "OK" if (cr == 0 or cr == lf) else "!!! 混行"))
print("done")
