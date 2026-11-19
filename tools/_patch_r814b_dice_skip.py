# -*- coding: utf-8 -*-
"""R814b：把「起点邻居保明牌」改成「起点邻居整格跳过重摇」。

R814 第一版是「重摇内容 + 强制 hidden=false」—— 内容会换、且**破坏幂等**：
`reroll_as_unknown` 的「跳过已 hidden 的格子」判据永远对它不成立，
第二次调用会把它再算进重摇格数（R312 那条「再调一次是空操作」当场红）。

改为整格 `continue`：
  * 内容不动 —— 它本来就是 battle/event（R192 已保证），再摇一次同类毫无意义；
  * hidden 保持 false —— 显示规则成立；
  * 幂等自然成立 —— 它压根不参与重摇。

随后把 R312 的两条「除固定房间外全部是 ?」按新口径豁免第一层起点邻居。
"""
import io

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


# ── ① 实现：起点邻居整格跳过 ──
p = "scripts/rogue_map.gd"
s = read(p)
s = sub(
    s,
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
    "\t\tcell3[\"revealed\"] = is_l1_start_nb\n"
    "\t\tcell3[\"event_kind\"] = \"\"\n",
    "\t\t# R814：第一层起点邻居**整格不参与重摇**（内容与显示都不动）。\n"
    "\t\t# R192 要求它「只可能是事件 / 一般战斗、不得是 ? 房」，`_make_cells` 为此写死\n"
    "\t\t# `hidden = false`；本函数早先把它一并翻成 ?，规则就在显示层被掀掉了。\n"
    "\t\t# 而「重摇成另一个 battle/event」本身没有意义 —— 它本来就只在这两类里。\n"
    "\t\t# ⚠️ 必须整格跳过而不是「重摇后强制 hidden=false」：后者让本函数的幂等判据\n"
    "\t\t#    （跳过 hidden 的格子）永远对它不成立，第二次调用会再算一遍重摇格数。\n"
    "\t\t# ⚠️ 只豁免**第一层**：第二层起点邻居本来就允许是 ?（R192 只禁精英/篝火）。\n"
    "\t\tif start_nbs.has(i3) and layer == GameLayers.LAYER_DEFAULT:\n"
    "\t\t\tcontinue\n"
    "\t\tvar w := _unknown_weights(cell3, layer, start_nbs)\n"
    "\t\tvar t := _weighted_far(w, rng, col_of(i3), row_of(i3), far_norm)\n"
    "\t\tcell3[\"type\"] = t\n"
    "\t\tcell3[\"hidden\"] = true\n"
    "\t\tcell3[\"revealed\"] = false\n"
    "\t\tcell3[\"event_kind\"] = \"\"\n",
    "reroll 起点邻居整格跳过",
)
write(p, s)

# ── ② R312 两条断言：豁免起点邻居 ──
p = "scripts/test_engine.gd"
s = read(p)
s = sub(
    s,
    "\tvar r312_nonfixed_hidden := true\n"
    "\n"
    "\tfor c312: Dictionary in r312_dice:\n"
    "\n"
    "\t\tif RogueMap.is_fixed_open(c312):\n"
    "\n"
    "\t\t\tcontinue\n"
    "\n"
    "\t\tif not bool(c312[\"hidden\"]) or bool(c312[\"revealed\"]) \\\n"
    "\n"
    "\t\t\t\tor RogueMap.display_type(c312) != \"unknown\":\n"
    "\n"
    "\t\t\tr312_nonfixed_hidden = false\n"
    "\n"
    "\tcheck(r312_nonfixed_hidden, \"R312 水晶骰子：除固定房间外，所有房间都是「?」\")\n",
    "\tvar r312_nonfixed_hidden := true\n"
    "\n"
    "\t# R814：第一层起点邻居**也不在**重摇名单里（R192 要求它保持明牌的战斗/事件）。\n"
    "\t# 这是本轮唯一的口径变化，来源见 `RogueMap.reroll_as_unknown()` 的 R814 注释。\n"
    "\tvar r312_start_nb := {}\n"
    "\tvar r312_start_i := RogueMap.idx(RogueMap.START_COL, RogueMap.START_ROW)\n"
    "\tif r312_start_i >= 0 and r312_start_i < r312_dice.size():\n"
    "\t\tfor r312_nbd: int in (r312_dice[r312_start_i][\"doors\"] as Array):\n"
    "\t\t\tr312_start_nb[int(r312_nbd)] = true\n"
    "\n"
    "\tfor c312: Dictionary in r312_dice:\n"
    "\n"
    "\t\tif RogueMap.is_fixed_open(c312) or r312_start_nb.has(int(c312.get(\"id\", -1))):\n"
    "\n"
    "\t\t\tcontinue\n"
    "\n"
    "\t\tif not bool(c312[\"hidden\"]) or bool(c312[\"revealed\"]) \\\n"
    "\n"
    "\t\t\t\tor RogueMap.display_type(c312) != \"unknown\":\n"
    "\n"
    "\t\t\tr312_nonfixed_hidden = false\n"
    "\n"
    "\tcheck(r312_nonfixed_hidden,\n"
    "\n"
    "\t\t\t\"R312/R814 水晶骰子：除固定房间与第一层起点邻居外，所有房间都是「?」\")\n",
    "R312 断言A",
    crlf=True,
)
s = sub(
    s,
    "\tvar r312_live_ok := true\n"
    "\n"
    "\tfor c: Dictionary in r312_live:\n"
    "\n"
    "\t\tif RogueMap.is_fixed_open(c):\n"
    "\n"
    "\t\t\tcontinue\n"
    "\n"
    "\t\tif RogueMap.display_type(c) != \"unknown\":\n"
    "\n"
    "\t\t\tr312_live_ok = false\n"
    "\n"
    "\tcheck(r312_live_ok, \"R312 水晶骰子：重摇后非固定房间全部读作「?」\")\n",
    "\tvar r312_live_ok := true\n"
    "\n"
    "\tvar r312_live_nb := {}\n"
    "\tif r312_start_i >= 0 and r312_start_i < r312_live.size():\n"
    "\t\tfor r312_lnd: int in (r312_live[r312_start_i][\"doors\"] as Array):\n"
    "\t\t\tr312_live_nb[int(r312_lnd)] = true\n"
    "\tfor c: Dictionary in r312_live:\n"
    "\n"
    "\t\tif RogueMap.is_fixed_open(c) or r312_live_nb.has(int(c.get(\"id\", -1))):\n"
    "\n"
    "\t\t\tcontinue\n"
    "\n"
    "\t\tif RogueMap.display_type(c) != \"unknown\":\n"
    "\n"
    "\t\t\tr312_live_ok = false\n"
    "\n"
    "\tcheck(r312_live_ok,\n"
    "\n"
    "\t\t\t\"R312/R814 水晶骰子：重摇后非固定房间（起点邻居除外）全部读作「?」\")\n",
    "R312 断言B",
    crlf=True,
)
write(p, s)

print("--- eol ---")
for f in ("scripts/rogue_map.gd", "scripts/test_engine.gd"):
    b = io.open(ROOT + f, "rb").read()
    cr, lf = b.count(b"\r\n"), b.count(b"\n")
    print("  %-26s CRLF=%-6d LF=%-6d %s" % (f, cr, lf,
          "OK" if (cr == 0 or cr == lf) else "!!! 混行"))
print("done")
