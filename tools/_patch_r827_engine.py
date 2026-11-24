# -*- coding: utf-8 -*-
"""R827 刺墙「一回合一次」：game_engine.gd 精确补丁（保留 CRLF）。"""
P = "scripts/game_engine.gd"

with open(P, "rb") as f:
    s = f.read().decode("utf-8")

assert s.count("\r\n") > 0, "非 CRLF 文件，中止"
s = s.replace("\r\n", "\n")  # 统一 LF 处理


def rep(old, new):
    global s
    c = s.count(old)
    assert c == 1, "anchor count=%d: %r" % (c, old[:60])
    s = s.replace(old, new)


# 1) var 定义（顶格，-1 后 6 空格）
rep(
    "var _thorn_ring_turn:= -1      # R307 荆棘指环：上次触发是第几回合（每回合一次）\n",
    "var _thorn_ring_turn:= -1      # R307 荆棘指环：上次触发是第几回合（每回合一次）\n"
    "var _spike_wall_turn:= -1      # R827 刺墙：上次触发是第几回合（每回合一次）\n",
)

# 2) 常量注释（R796 扩面注释后追加 R827）
rep(
    "# R796 刺墙**扩面**（用户口径「工事和 HP 被攻击时」）：反伤触发面从「工事」加到\n"
    "#   「工事 + 玩家 HP」。常量不变，只多挂一处 —— 见 `attack_hp()` 里那一段。\n",
    "# R796 刺墙**扩面**（用户口径「工事和 HP 被攻击时」）：反伤触发面从「工事」加到\n"
    "#   「工事 + 玩家 HP」。常量不变，只多挂一处 —— 见 `attack_hp()` 里那一段。\n"
    "# R827 刺墙**一回合一次**：反伤每回合（turn_number 口径）至多触发一次 ——\n"
    "#   `_spike_wall_turn` 记上次触发的回合号，工事反伤与 HP 反伤**共用同一个额度**。\n",
)

# 3) _reset（前导一个 tab）
rep(
    "\t_thorn_ring_turn = -1\n",
    "\t_thorn_ring_turn = -1\n"
    "\t_spike_wall_turn = -1\n",
)

# 4) attack() 触发点（and 前 3 tab、if 前 1 tab、块内 2 tab）
rep(
    "\tvar spike_wall_ok: bool = (defender.owner == SIDE_SELF\n"
    "\t\t\tand defender.card.kind == \"工事\"\n"
    "\t\t\tand RunState.has_relic(SPIKE_WALL_RELIC_ID))\n"
    "\tif state.board.has(src) and spike_wall_ok:\n",
    "\tvar spike_wall_ok: bool = (defender.owner == SIDE_SELF\n"
    "\t\t\tand defender.card.kind == \"工事\"\n"
    "\t\t\tand RunState.has_relic(SPIKE_WALL_RELIC_ID)\n"
    "\t\t\tand _spike_wall_turn != turn_number)\n"
    "\tif state.board.has(src) and spike_wall_ok:\n"
    "\t\t_spike_wall_turn = turn_number\n",
)

# 5) attack_hp() 触发点
rep(
    "\tvar spike_hp_ok: bool = (side != SIDE_SELF and state.board.has(src)\n"
    "\t\t\tand RunState.has_relic(SPIKE_WALL_RELIC_ID))\n"
    "\tif spike_hp_ok:\n",
    "\tvar spike_hp_ok: bool = (side != SIDE_SELF and state.board.has(src)\n"
    "\t\t\tand RunState.has_relic(SPIKE_WALL_RELIC_ID)\n"
    "\t\t\tand _spike_wall_turn != turn_number)\n"
    "\tif spike_hp_ok:\n"
    "\t\t_spike_wall_turn = turn_number\n",
)

s = s.replace("\n", "\r\n")  # 转回 CRLF

with open(P, "wb") as f:
    f.write(s.encode("utf-8"))

print("DONE: CRLF=%d" % s.count("\r\n"))
