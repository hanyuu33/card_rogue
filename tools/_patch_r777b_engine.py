# -*- coding: utf-8 -*-
"""R777b 疾风乐章（9270）引擎落地 —— game_engine.gd 是 CRLF。

三处：
  ① 常量 WIND_SONG_ID / WIND_SONG_SPEED
  ② `_wind_song_apply()` 结算函数
  ③ `_free_effect_play()` 里按 id 挂分支（效果卡的唯一生效口）
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENG = os.path.join(ROOT, "scripts", "game_engine.gd")
s = io.open(ENG, "rb").read().decode("utf-8")
assert "WIND_SONG_ID" not in s, "WIND_SONG_ID 已存在"


def sub(old, new, tag):
    global s
    n = s.count(old)
    assert n == 1, "%s：锚点命中 %d 次" % (tag, n)
    s = s.replace(old, new)


# ── ① 常量 ────────────────────────────────────────────────────────────────
sub('const RAINBOW_CUT:= 1       # 每张费用本局 -1\r\n',
    'const RAINBOW_CUT:= 1       # 每张费用本局 -1\r\n'
    '# R777b 疾风乐章（9270，吟游诗人 2 费史诗效果卡）：\r\n'
    '#   己方所有**盟友**移动速度 +1；**其他职业盟友**不给移速，改为「一回合行动两次」。\r\n'
    '# ⚠️ 双动复用哈气那套 `Placement.haste_double`（单点永久、单位离场自动消失）——\r\n'
    '#    `unit_actions()` 每回合都读它，所以不必在回合开始再刷一遍；\r\n'
    '#    写成「改 card.actions」会把双动焊到卡面数值上，改造 / 复制卡都会跟着走，不行。\r\n'
    'const WIND_SONG_ID:= 9270\r\n'
    'const WIND_SONG_SPEED:= 1     # 非其他职业盟友：移动速度 +1\r\n',
    "常量")

# ── ② 结算函数（挂在 _roll_recruit_cards 之前，与彩虹诗同区）──────────────
sub('func _roll_recruit_cards() -> Array:\r\n',
    'func _wind_song_apply(side: String) -> void:\r\n'
    '\t## R777b 疾风乐章（9270）：己方所有**盟友**移动速度 +1；\r\n'
    '\t## 「原本职业不属于自己」的盟友（`_other_class_card()` 唯一判据）改为**一回合行动两次**。\r\n'
    '\t## * 双动走 `Placement.haste_double`（与哈气同一条单点永久通道）→ `unit_actions()`\r\n'
    '\t##   每回合自动给到，`reset_units()` 也不用额外处理；\r\n'
    '\t## * 当回合立刻能多动一次：走 `grant_actions()` 的差额口（已经把两轮走完的单位\r\n'
    '\t##   会撤掉横置、补出新的一轮）—— 这正是「打出当回合就生效」的成色；\r\n'
    '\t## * 工事 / 场地不算「盟友」（卡面写的是盟友）；\r\n'
    '\t## * 遍历按格子排序 → 同种子回放时日志顺序稳定。\r\n'
    '\tvar cells: Array[Vector2i] = []\r\n'
    '\tfor cell: Vector2i in state.board:\r\n'
    '\t\tcells.append(cell)\r\n'
    '\tcells.sort()\r\n'
    '\tvar moved := 0\r\n'
    '\tvar doubled := 0\r\n'
    '\tfor cell2: Vector2i in cells:\r\n'
    '\t\tvar p: Placement = state.unit_at(cell2)\r\n'
    '\t\tif p == null or p.owner != side or p.card.kind != "盟友":\r\n'
    '\t\t\tcontinue\r\n'
    '\t\tif _other_class_card(p.card):\r\n'
    '\t\t\tp.haste_double = true\r\n'
    '\t\t\tstate.grant_actions(p, FieldState.HASTE_ACTIONS)\r\n'
    '\t\t\tdoubled += 1\r\n'
    '\t\t\t_log("疾风乐章：%s（其他职业）一回合行动两次" % p.card.card_name)\r\n'
    '\t\telse:\r\n'
    '\t\t\t# 与改造 `_feed_upgrade_card()` 同一口径：场上 card 已是独立副本，直接抬数值。\r\n'
    '\t\t\tp.card.move_speed += WIND_SONG_SPEED\r\n'
    '\t\t\tmoved += 1\r\n'
    '\t\t\t_log("疾风乐章：%s 移动速度 +%d（→%d）"\r\n'
    '\t\t\t\t\t% [p.card.card_name, WIND_SONG_SPEED, p.card.move_speed])\r\n'
    '\tif moved + doubled <= 0:\r\n'
    '\t\t_log("疾风乐章：场上没有盟友 → 效果落空")\r\n'
    '\taction.emit("wind_song", {"moved": moved, "doubled": doubled, "side": side})\r\n'
    '\r\n'
    '\r\n'
    'func _roll_recruit_cards() -> Array:\r\n',
    "结算函数")

# ── ③ 效果卡生效口 ────────────────────────────────────────────────────────
sub('\tif card.id == LIFE_CYCLE_ID:\r\n'
    '\t\t_life_cycle_all(SIDE_SELF)\r\n',
    '\tif card.id == LIFE_CYCLE_ID:\r\n'
    '\t\t_life_cycle_all(SIDE_SELF)\r\n'
    '\t# R777b 疾风乐章 9270（效果卡）：己方盟友移速 +1；其他职业盟友改为每回合行动两次。\r\n'
    '\tif card.id == WIND_SONG_ID:\r\n'
    '\t\t_wind_song_apply(SIDE_SELF)\r\n',
    "效果卡分支")

assert "\n" not in s.replace("\r\n", "")
io.open(ENG, "wb").write(s.encode("utf-8"))
print("[ok] game_engine.gd 已写入 9270")

chk = io.open(ENG, "rb").read().decode("utf-8")
assert "const WIND_SONG_ID:= 9270" in chk and "func _wind_song_apply" in chk
assert chk.count("_wind_song_apply(SIDE_SELF)") == 1
print("[ok] 复核通过")
