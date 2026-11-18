# -*- coding: utf-8 -*-
"""R792 引擎补丁：板甲 / 兵 / 墙砖 三件道具的实际效果。

设计口径：
  * 生命加成 → `Placement.relic_bonus_hp`（场上有、离场由 `_card_leaving_field` 还原），
    同时并进 `p.card.health` 与 `p.health` —— 与栅栏修复术（fence_bonus_hp）同一套
    「烤进场上卡 + 记账 + 离场还原」写法，血条 / 上限 / 重组全部自动正确。
  * 移速上限 → `Placement.speed_cap`（0 = 不设限），走 `effective_speed()` 唯一出口。
  * 双动 → `Placement.first_ally_twice`，走 `FieldState.unit_actions()` 唯一口。
  * 「每场战斗第一个盟友」= 本场**第一个落地的己方盟友**（手牌打出与涂装机器人
    变出来同一口径，与竖琴「两条来路一个值」的约定一致）；重置点在 `start_game()`。
"""
import io
import sys

ROOT = 'E:/work/card_rogue/'


def rw(path, old, new, count=1):
    p = ROOT + path
    s = io.open(p, encoding='utf-8', newline='').read()
    old = old.replace('\n', '\r\n') if '\r\n' not in old else old
    new = new.replace('\n', '\r\n') if '\r\n' not in new else new
    n = s.count(old)
    if n != count:
        print('FAIL %s: 命中 %d 次（期望 %d）' % (path, n, count))
        print(repr(old[:260]))
        sys.exit(1)
    io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
    print('OK   %s' % path)


# ── 1. placement.gd：三个字段 ────────────────────────────────────────
rw('scripts/placement.gd',
   '''var totem_atk: int = 0
''',
   '''var totem_atk: int = 0
## R792 道具给的**额外生命**（板甲 6070 +6 / 墙砖 6072 +4）—— 与 `fence_bonus_hp` 同构：
## 已经并进 `p.card.health` 与 `p.health`（血条 / 上限 / 重组都能直接读到），
## 只在这里记「有多少是道具给的」，离场由 `_card_leaving_field()` 减回去。
## ⚠️ 单独开字段而不是复用 `fence_bonus_hp`：那条徽标写的是「栅栏加固」，
##    共用会让玩家看到一件道具加成被标成另一件。
var relic_bonus_hp: int = 0
## R792 板甲（6070）：移动速度**上限**（0 = 不设限）。「变为 1」走 `effective_speed()`
## 出口 —— 移动、AI 队列、界面全部自动读到，不必在 `_move_bfs` 里另写分支。
## 取 `mini` 而不是硬赋值：本来就不动（0 速）的工事不该被板甲**加**成 1 速。
var speed_cap: int = 0
## R792 兵（6071）：本场第一个盟友可以行动两次。读在 `FieldState.unit_actions()` ——
## 与疾行 / 哈气 / 赫利俄斯同一条「取最大」通道，落地与回合重置自动一致。
var first_ally_twice: bool = false
''')

# ── 2. placement.gd：effective_speed 上限 ───────────────────────────
rw('scripts/placement.gd',
   '''	if boss_phase >= 2:
		sp -= GameEngine.REVELATOR_SPEED_DOWN
	return maxi(0, sp)''',
   '''	if boss_phase >= 2:
		sp -= GameEngine.REVELATOR_SPEED_DOWN
	# R792 板甲（6070）：移速上限取 `mini` —— 「变为 1」只对本来更快的单位生效，
	# 原本 0 速（工事 / 不动单位）保持 0，不会反而被加成 1 速。
	if speed_cap > 0:
		sp = mini(sp, speed_cap)
	return maxi(0, sp)''')

# ── 3. placement.gd：信息栏徽标 ─────────────────────────────────────
rw('scripts/placement.gd',
   '''	if poem_atk > 0:
		out.append({"label": "诗：力量 +%d（本场，不叠加）" % poem_atk,
				"col": COL_B, "kind": "buff"})''',
   '''	if poem_atk > 0:
		out.append({"label": "诗：力量 +%d（本场，不叠加）" % poem_atk,
				"col": COL_B, "kind": "buff"})
	# R792 三件道具的可见来源（数值早已并进 health / effective_speed / unit_actions，
	# 这里只补「是谁给的」，判据只看字段本身有没有值）。
	if relic_bonus_hp > 0:
		out.append({"label": "道具：额外生命 +%d（本场）" % relic_bonus_hp,
				"col": COL_B, "kind": "buff"})
	if speed_cap > 0:
		out.append({"label": "板甲：移动速度降为 %d" % speed_cap,
				"col": COL_B, "kind": "debuff"})
	if first_ally_twice:
		out.append({"label": "兵：本场可行动两次",
				"col": COL_B, "kind": "buff"})''')

# ── 4. field_state.gd：unit_actions 双动 ────────────────────────────
rw('scripts/field_state.gd',
   '''	if p.card.id == GameEngine.SUN_FORGE_FURY_ID and has_sun_forge(side):
		n = maxi(n, GameEngine.SUN_FORGE_ACTIONS)
	return n''',
   '''	if p.card.id == GameEngine.SUN_FORGE_FURY_ID and has_sun_forge(side):
		n = maxi(n, GameEngine.SUN_FORGE_ACTIONS)
	# R792 兵（6071）：本场第一个盟友可以行动两次 —— 与上面几条同一条「取最大」通道，
	# 于是 place / reset_units / apply_extra_actions 三处自动一致，不会出现
	# 「上场那回合只动一次、下回合才双动」的错位。
	if p.first_ally_twice:
		n = maxi(n, GameEngine.PAWN_ACTIONS)
	return n''')

# ── 5. game_engine.gd：常量 ─────────────────────────────────────────
rw('scripts/game_engine.gd',
   '''const HARP_RELIC_ID:= 6052
const HARP_ATK:= 2
''',
   '''const HARP_RELIC_ID:= 6052
const HARP_ATK:= 2
# R792 板甲（6070，一般档）：每场战斗**使用的第一个盟友** +6 生命（不叠加），
#   但移动速度变为 1。加的血并进 `relic_bonus_hp`（场上有、离场还原）；
#   移速走 `Placement.speed_cap` → `effective_speed()` 出口。
const PLATE_RELIC_ID:= 6070
const PLATE_HP:= 6
const PLATE_SPEED:= 1
# R792 兵（6071，一般档）：每场战斗**第一个盟友**可以行动两次。
#   读在 `FieldState.unit_actions()`（唯一口），落地时还要补发一次行动轮数。
const PAWN_RELIC_ID:= 6071
const PAWN_ACTIONS:= 2
# R792 墙砖（6072，一般档）：所有己方工事生命 +4（持续生效，不叠加）。
#   与竖琴逐字同构 —— 只写 Placement 字段 + 出口，绝不写回 `card.power` 那种共享基数。
const BRICK_RELIC_ID:= 6072
const BRICK_HP:= 4
''')

# ── 6. game_engine.gd：实例标记 ─────────────────────────────────────
rw('scripts/game_engine.gd',
   'var _poem_used := false\n',
   'var _poem_used := false\n'
   '# R792 板甲 / 兵：本场「第一个盟友」的额度是否已经发过（每场战斗各一次）。\n'
   '# 两件道具分开记 —— 只持有一件时另一个标记永远不动，将来加第二件同型道具也不打架。\n'
   'var _plate_first_ally_done := false\n'
   'var _pawn_first_ally_done := false\n')

# ── 7. start_game：每场战斗重置 ─────────────────────────────────────
rw('scripts/game_engine.gd',
   '\t_poem_used = false          # R761 诗：每场战斗从「这回合还没回费」开始\n',
   '\t_poem_used = false          # R761 诗：每场战斗从「这回合还没回费」开始\n'
   '\t_plate_first_ally_done = false   # R792 板甲：第一个盟友的额度每场重置\n'
   '\t_pawn_first_ally_done = false    # R792 兵：同上\n')

# ── 8. _relic_on_enter_buffs：三段效果 ──────────────────────────────
rw('scripts/game_engine.gd',
   '\tvar beast_hp:= _beast_hp_bonus(card)\n',
   '''	# ── R792 板甲（6070）────────────────────────────────────────────
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
				% [card.card_name, PLATE_HP, p.health, p.effective_speed()])
	# ── R792 兵（6071）──────────────────────────────────────────────
	# 同一个「第一个盟友」可以行动两次。`first_ally_twice` 只为 `unit_actions()` 提供判据，
	# 但**落地这一刻**行动轮数已经发过了（`place()` 里按老的 unit_actions 发的），
	# 所以这里必须按差额补发一次 —— 走 `grant_actions` 唯一口，别直接写 `acts_left`。
	if RunState.has_relic(PAWN_RELIC_ID) and p.owner == SIDE_SELF and card.kind == "盟友" and not _pawn_first_ally_done:
		_pawn_first_ally_done = true
		p.first_ally_twice = true
		state.grant_actions(p, state.unit_actions(p, SIDE_SELF))
		_log("兵：第一个盟友 %s 本场可以行动两次" % card.card_name)
	# ── R792 墙砖（6072）────────────────────────────────────────────
	# 所有己方工事 +4 生命（持续生效，不叠加）：同一张工事回手再上场也只 +4，
	# 因为离场时 `_card_leaving_field()` 已经把这一份减掉了。
	if RunState.has_relic(BRICK_RELIC_ID) and p.owner == SIDE_SELF and card.kind == "工事":
		p.relic_bonus_hp += BRICK_HP
		p.card.health += BRICK_HP
		p.health += BRICK_HP
		_log("墙砖：%s 获得 +%d 生命（%d）" % [card.card_name, BRICK_HP, p.health])
	var beast_hp:= _beast_hp_bonus(card)
''')

# ── 9. _card_leaving_field：还原 ────────────────────────────────────
rw('scripts/game_engine.gd',
   '\tif p.fence_bonus_hp <= 0 and p.fence_bonus_traits.is_empty() and p.upgrade_hp <= 0 \\',
   '\tif p.fence_bonus_hp <= 0 and p.relic_bonus_hp <= 0 and p.fence_bonus_traits.is_empty() and p.upgrade_hp <= 0 \\')

rw('scripts/game_engine.gd',
   '\tout.health = maxi(1, p.card.health - p.fence_bonus_hp - p.upgrade_hp)',
   '\tout.health = maxi(1, p.card.health - p.fence_bonus_hp - p.relic_bonus_hp - p.upgrade_hp)')

print('引擎层完成')
