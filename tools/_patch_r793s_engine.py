# -*- coding: utf-8 -*-
"""R793 patch 4/4 —— 引擎与单位字段：大师之剑「每场第一个盟友 +10 力量」。"""
import io, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


def patch(path, pairs):
    p = ROOT.rstrip("/") + "/" + path
    raw = io.open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            o = old.replace("\n", "\r\n")
            n = new.replace("\n", "\r\n")
        else:
            o, n = old, new
        c = txt.count(o)
        assert c == 1, "%s: count=%d for %r" % (path, c, old[:70])
        txt = txt.replace(o, n)
    io.open(p, "wb").write(txt.encode("utf-8"))
    print("OK %-34s %d -> %d  (%s)" % (path, len(raw), len(txt.encode("utf-8")),
                                       "CRLF" if crlf else "LF"))


# ------------------------------------------------------------ game_engine.gd
CONST_BLOCK = '''const POEM_REBATE:= 1
# R793 大师之剑（6075，事件「林中的剑」拔剑获得，**不进奖励池**）：
#   每场战斗**使用的第一个盟友** +`MASTER_SWORD_ATK` 力量 —— 与竖琴 6052 / 诗 6069 同一套
#   持续 buff 写法（只写 `Placement.master_sword_atk`，由 `effective_power()` 出口，
#   赋值不累加、**绝不写回 `card.power`**）。
# ⚠️ 为什么单开字段：骑士剑 6053 用的是 `sword_atk`，两件道具可以同时在身上，
#   共用一个字段会互相覆盖（后落地的那件赢，先落地那件静默失效）。
const MASTER_SWORD_ID:= 6075
const MASTER_SWORD_ATK:= 10
'''

VAR_BLOCK = '''var _poem_used := false
# R793 大师之剑（6075）：本场「第一个盟友」的额度是否已经发过（每场战斗一次，start_game 重置）。
var _master_sword_first_ally_done := false
'''

RESET_BLOCK = '''\t_poem_used = false          # R761 诗：每场战斗从「这回合还没回费」开始
\t_master_sword_first_ally_done = false   # R793 大师之剑：第一个盟友的额度每场重置
'''

BUFF_BLOCK = '''\t# ── R793 大师之剑（6075）────────────────────────────────────────────
\t# 每场战斗**使用的第一个盟友** +10 力量（本场一次）。「第一个」= 本场第一个落地的
\t# 己方盟友 —— 与板甲 6070 / 兵 6071 同一条判据：手牌打出与涂装机器人 8080「变成」
\t# 出来的单位共用本函数，两条来路必须给同一个结论（竖琴 6052 的老约定）。
\t# 只写 Placement 字段（`effective_power()` 出口）—— `place()` 接管的是卡库共享实例，
\t# 烤进 `card.power` 的话同一张卡再上场会叠成 +20。
\tif (RunState.has_relic(MASTER_SWORD_ID) and p.owner == SIDE_SELF
\t\t\tand card.kind == "盟友" and not _master_sword_first_ally_done):
\t\t_master_sword_first_ally_done = true
\t\tp.master_sword_atk = MASTER_SWORD_ATK
\t\t_log("大师之剑：第一个盟友 %s 获得 +%d 力量（%d）"
\t\t\t\t% [card.card_name, MASTER_SWORD_ATK, p.effective_power()])
'''

patch("scripts/game_engine.gd", [
    ('const POEM_REBATE:= 1\n', CONST_BLOCK),
    ('var _poem_used := false\n', VAR_BLOCK),
    ('\t_poem_used = false          # R761 诗：每场战斗从「这回合还没回费」开始\n', RESET_BLOCK),
    ('\tvar beast_hp:= _beast_hp_bonus(card)\n', BUFF_BLOCK + '\tvar beast_hp:= _beast_hp_bonus(card)\n'),
])

# ------------------------------------------------------------ placement.gd
PLACE_FIELD = '''var poem_atk: int = 0
## R793 大师之剑（6075）：**每场战斗第一个盟友** +10 力量 —— 与竖琴 / 诗 / 骑士剑
## 逐字同构的持续 buff（字段 + `effective_power()` 出口，绝不写回 `card.power`）。
## 「第一个」由引擎判断（`_master_sword_first_ally_done`），这里只负责「在场上就生效」。
## ⚠️ 与 `sword_atk`（骑士剑 6053）分开：两件道具可同时持有，共用字段会互相覆盖。
var master_sword_atk: int = 0
'''

POWER_OLD = '\t\t\t+ totem_atk + poem_atk\n'
POWER_NEW = '\t\t\t+ totem_atk + poem_atk + master_sword_atk\n'

SAVE_OLD = '\t"mass_mnemo_turn", "sleep_left", "stun_left", "harp_atk", "sword_atk", "poem_atk",\n'
SAVE_NEW = '\t"mass_mnemo_turn", "sleep_left", "stun_left", "harp_atk", "sword_atk", "poem_atk",\n\t"master_sword_atk",\n'

LINE_OLD = ('\tif poem_atk > 0:\n'
            '\t\tout.append({"label": "诗：力量 +%d（本场，不叠加）" % poem_atk,\n'
            '\t\t\t\t"col": COL_B, "kind": "buff"})\n')
LINE_NEW = LINE_OLD + ('\tif master_sword_atk > 0:\n'
                       '\t\tout.append({"label": "大师之剑：力量 +%d（本场第一个盟友）" % master_sword_atk,\n'
                       '\t\t\t\t"col": COL_B, "kind": "buff"})\n')

patch("scripts/placement.gd", [
    ('var poem_atk: int = 0\n', PLACE_FIELD),
    (POWER_OLD, POWER_NEW),
    (SAVE_OLD, SAVE_NEW),
    (LINE_OLD, LINE_NEW),
])

print("patch 4/4 done")
