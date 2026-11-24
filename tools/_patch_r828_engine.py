# -*- coding: utf-8 -*-
"""R828：板甲 6070 加值由固定 +6 改为「当前层数 × 3」。CRLF 文件，normalize 后替换、写回 CRLF。"""
import sys

PATH = 'scripts/game_engine.gd'
data = open(PATH, 'rb').read().decode('utf-8')
s = data.replace('\r\n', '\n')


def rep(old, new):
    global s
    n = s.count(old)
    if n != 1:
        print('锚点不唯一(%d)或不存在: %r' % (n, old[:60]))
        sys.exit(1)
    s = s.replace(old, new)


# ── 改动 1：常量定义块 ──────────────────────────────────────────────
rep(
"""# R792 板甲（6070，一般档）：每场战斗**使用的第一个盟友** +6 生命（不叠加），
#   但移动速度变为 1。加的血并进 `relic_bonus_hp`（场上有、离场还原）；
#   移速走 `Placement.speed_cap` → `effective_speed()` 出口。
const PLATE_RELIC_ID:= 6070
const PLATE_HP:= 6
const PLATE_SPEED:= 1""",
"""# R792 板甲（6070，一般档）：每场战斗**使用的第一个盟友**获得「当前层数 × 3」生命
#   （不叠加），但移动速度变为 1。加的血并进 `relic_bonus_hp`（场上有、离场还原）；
#   移速走 `Placement.speed_cap` → `effective_speed()` 出口。层数 = `RunState.current_layer`。
const PLATE_RELIC_ID:= 6070
const PLATE_HP_PER_LAYER:= 3
const PLATE_SPEED:= 1""",
)

# ── 改动 2：触发点注释 + 代码 ───────────────────────────────────────
rep(
"""	# ── R792 板甲（6070）────────────────────────────────────────────
	# 「每场战斗使用的第一个盟友」+6 生命（不叠加），但移速变为 1。
	#   * 「第一个」以**本场第一个落地的己方盟友**为准 —— 手牌打出与涂装机器人
	#     8080「变成」出来的单位共用本函数，两条来路必须给同一个结论（竖琴约定）；
	#   * 加的血并进 `relic_bonus_hp` + `card.health` + `health`，离场由
	#     `_card_leaving_field()` 减回去，不会让同一张卡回手再上场叠成 +12；
	#   * 移速走 `speed_cap`（`mini` 语义，0 速单位不受影响）。
	if RunState.has_relic(PLATE_RELIC_ID) and p.owner == SIDE_SELF and card.kind == "盟友" and not _plate_first_ally_done:
		_plate_first_ally_done = true
		p.relic_bonus_hp += PLATE_HP
		p.card.health += PLATE_HP
		p.health += PLATE_HP
		p.speed_cap = PLATE_SPEED
		_log("板甲：第一个盟友 %s 获得 +%d 生命（%d），移动速度降为 %d"
				% [card.card_name, PLATE_HP, p.health, p.effective_speed()])""",
"""	# ── R792 板甲（6070）────────────────────────────────────────────
	# 「每场战斗使用的第一个盟友」获得「当前层数 × 3」生命（不叠加），但移速变为 1。
	#   * 「第一个」以**本场第一个落地的己方盟友**为准 —— 手牌打出与涂装机器人
	#     8080「变成」出来的单位共用本函数，两条来路必须给同一个结论（竖琴约定）；
	#   * 加的血并进 `relic_bonus_hp` + `card.health` + `health`，离场由
	#     `_card_leaving_field()` 减回去，不会让同一张卡回手再上场叠双份；
	#   * 移速走 `speed_cap`（`mini` 语义，0 速单位不受影响）。
	#   * R828：加值由固定 +6 改为「当前层数 × 3」（第一层 3 / 第二层 6 / 第三层 9）。
	if RunState.has_relic(PLATE_RELIC_ID) and p.owner == SIDE_SELF and card.kind == "盟友" and not _plate_first_ally_done:
		_plate_first_ally_done = true
		var plate_hp: int = RunState.current_layer * PLATE_HP_PER_LAYER
		p.relic_bonus_hp += plate_hp
		p.card.health += plate_hp
		p.health += plate_hp
		p.speed_cap = PLATE_SPEED
		_log("板甲：第一个盟友 %s 获得 +%d 生命（%d），移动速度降为 %d"
				% [card.card_name, plate_hp, p.health, p.effective_speed()])""",
)

out = s.replace('\n', '\r\n')
open(PATH, 'wb').write(out.encode('utf-8'))
print('engine patch ok')
