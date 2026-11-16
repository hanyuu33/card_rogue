# -*- coding: utf-8 -*-
"""R776 修正补丁：
1) test_reward.gd 的卡牌库总数 327 → 329（上一版漏改，reward 套件红 1 条）；
2) 引擎动作事件 "inspire" → "anthem"（8077「激发」已占用该名字，复用会让
   激励乐章弹出「激发 ×N 轮」的假飘字）；
3) 管风琴的 organ 事件带上命中格子，界面按格挂飘字；
4) battle_scene 补两个动作的界面反馈（此前未知 kind 会被静默忽略，等于没有反馈）。
"""
import io

EDITS = []


def edit(path, old, new, tag):
    s = io.open(path, "rb").read().decode("utf-8")
    n = s.count(old)
    assert n == 1, "%s 命中 %d 次" % (tag, n)
    io.open(path, "wb").write(s.replace(old, new).encode("utf-8"))
    print("OK", tag)


# ── ① test_reward：卡牌库总数 ────────────────────────────
edit(
    "scripts/test_reward.gd",
    'check(all.size() == 327, "卡牌库 327 张（R773 +1：呼唤 9266',
    'check(all.size() == 329, "卡牌库 329 张（R776 +2：激励乐章 9267 / 管风琴 9268；'
    'R773 +1：呼唤 9266',
    "reward 卡牌库 327→329",
)

# ── ② 引擎动作事件改名 + 带命中格子 ──────────────────────
edit(
    "scripts/game_engine.gd",
    '\taction.emit("inspire", {"count": n, "other": other, "side": side})\r\n',
    '\t# ⚠️ 事件名是 `anthem` 不是 `inspire`：8077「激发」早已占用 `inspire`，\r\n'
    '\t# 复用会让界面按「激发 ×N 轮」的假飘字渲染（battle_scene 的 inspire 分支只认\r\n'
    '\t# count / dmg / cells）。两张卡的效果毫不相干，事件名也必须分开。\r\n'
    '\taction.emit("anthem", {"count": n, "other": other, "power": ANTHEM_POWER,\r\n'
    '\t\t\t"other_power": ANTHEM_POWER_OTHER, "side": side})\r\n',
    "anthem 事件改名",
)
edit(
    "scripts/game_engine.gd",
    '\t\taction.emit("organ", {"hits": 0, "dmg": total, "hp": total, "organs": organs})\r\n',
    '\t\taction.emit("organ", {"hits": 0, "dmg": total, "hp": total, "organs": organs,\r\n'
    '\t\t\t\t"cells": []})\r\n',
    "organ 空场事件",
)
edit(
    "scripts/game_engine.gd",
    '\taction.emit("organ", {"hits": hit, "dmg": total, "organs": organs})\r\n',
    '\taction.emit("organ", {"hits": hit, "dmg": total, "organs": organs,\r\n'
    '\t\t\t"cells": cells})\r\n',
    "organ 命中事件",
)

# ── ③ battle_scene：两个动作的界面反馈 ───────────────────
HANDLERS = '''\t\t"anthem":
\t\t\t# 激励乐章（9267，R776）：本回合全场盟友 +4 力量，其他职业盟友改为 +6。
\t\t\t# 飘字写清两个数 —— 同一张卡两种数值，只写一个会被读成「另一个是 bug」。
\t\t\tsfx.play("spell")
\t\t\t_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 12),
\t\t\t\t\t"text": "激励乐章 · %d 个盟友 +%d 力量（其他职业 +%d）"
\t\t\t\t\t\t% [int(data.get("count", 0)), int(data.get("power", 0)),
\t\t\t\t\t\t\tint(data.get("other_power", 0))],
\t\t\t\t\t"col": Color("4fb0d8"), "start": n, "dur": 1500})
\t\t"organ":
\t\t\t# 管风琴（9268，R776）：每用一张技能卡 → 所有敌人各 3 伤（场上每台各结算一份）。
\t\t\t# 飘字**按格逐个挂**（引擎给的是真正命中的格子）：命中几个写几处，
\t\t\t# 不做「全体 -N」那种假汇总。
\t\t\tsfx.play("hit")
\t\t\tfor og_c: Vector2i in (data.get("cells", []) as Array):
\t\t\t\tvar og_pos := _cell_center(og_c)
\t\t\t\t_fx_push_cell(FxArt.SKILL_SHADOW, og_c, n, 460, 150.0)
\t\t\t\t_floaters.append({"pos": og_pos + Vector2(0, -12), "sc": _grid_scroll,
\t\t\t\t\t\t"text": "管风琴 -%d" % int(data.get("dmg", 0)),
\t\t\t\t\t\t"col": Color("3d7fb8"), "start": n, "dur": 1200})
'''
HANDLERS = HANDLERS.replace("\r\n", "\n").replace("\n", "\r\n")

edit(
    "scripts/battle_scene.gd",
    '\t\t"gale":\r\n',
    HANDLERS + '\t\t"gale":\r\n',
    "battle_scene 两个动作处理器",
)

print("全部完成")
