# -*- coding: utf-8 -*-
"""R793 引擎层：刺墙 6073（工事被攻击反伤）+ 应急装甲 6074（玩家 HP 每回合封顶 20）。"""
import io
import sys

P = 'E:/work/card_rogue/scripts/game_engine.gd'
s = io.open(P, encoding='utf-8', newline='').read()


def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        print('FAIL %s 锚点命中 %d 次' % (tag, s.count(old)))
        sys.exit(1)
    s = s.replace(old, new)


CR = '\r\n'

# ── ① 常量 ─────────────────────────────────────────────────────────
rep(
    'const BRICK_RELIC_ID:= 6072' + CR + 'const BRICK_HP:= 4' + CR,
    'const BRICK_RELIC_ID:= 6072' + CR + 'const BRICK_HP:= 4' + CR
    + '# R793 刺墙（6073，一般档）：己方**工事被普通攻击**时，攻击者受 SPIKE_WALL_DMG 点伤害。' + CR
    + '#   挂点与启示者「电磁屏障」（9200 二阶段）同一处 —— 见 `attack()` 里那一段。' + CR
    + 'const SPIKE_WALL_RELIC_ID:= 6073' + CR
    + 'const SPIKE_WALL_DMG:= 5' + CR
    + '# R793 应急装甲（6074，一般档）：**玩家 HP** 每回合最多受 EMERGENCY_ARMOR_CAP 点伤害。' + CR
    + '#   与赫尔墨斯 `HERMES_DMG_CAP` 数值相同但口径不同：那条管一张**单位卡**（`Placement` 挂字段），' + CR
    + '#   这条管**玩家 HP**（额度只能记在引擎上，见 `_emergency_armor_cap()`）。' + CR
    + 'const EMERGENCY_ARMOR_RELIC_ID:= 6074' + CR
    + 'const EMERGENCY_ARMOR_CAP:= 20' + CR,
    'const')

# ── ② 实例变量 ─────────────────────────────────────────────────────
rep(
    'var _pawn_first_ally_done := false' + CR,
    'var _pawn_first_ally_done := false' + CR
    + '# R793 应急装甲：本回合玩家 HP **已实际受到**的伤害（额度 = EMERGENCY_ARMOR_CAP - 它）。' + CR
    + '# 与赫尔墨斯 `Placement.turn_dmg_key / turn_dmg_taken` 同一套「换回合 key 失配即归零」写法，' + CR
    + '# 只是玩家没有 Placement 可挂，额度记在引擎上；`start_game()` 一并清零。' + CR
    + 'var _armor_turn_key := -1' + CR
    + 'var _armor_turn_taken := 0' + CR,
    'var')

# ── ③ start_game 重置 ─────────────────────────────────────────────
rep(
    '\t_pawn_first_ally_done = false    # R792 兵：同上' + CR,
    '\t_pawn_first_ally_done = false    # R792 兵：同上' + CR
    + '\t_armor_turn_key = -1             # R793 应急装甲：额度每场战斗从零开始' + CR
    + '\t_armor_turn_taken = 0' + CR,
    'start_game')

# ── ④ 玩家 HP 收口：接上封顶 ───────────────────────────────────────
rep(
    '\tvar red:= _effect_damage_reduction()' + CR
    + '\tif red > 0:' + CR
    + '\t\tdmg = maxi(1, amount - red)' + CR
    + '\treturn _relic_damage_taken(dmg)' + CR,
    '\tvar red:= _effect_damage_reduction()' + CR
    + '\tif red > 0:' + CR
    + '\t\tdmg = maxi(1, amount - red)' + CR
    + '\t# R793 应急装甲（6074）：「每回合最多受到 20 点伤害」—— 排在减伤链**最后一格**，' + CR
    + '\t# 与赫尔墨斯 `_cap_turn_damage()` 同一位置口径（卡面说的是「受到」＝最终真正扣掉的血）。' + CR
    + '\treturn _emergency_armor_cap(_relic_damage_taken(dmg))' + CR,
    'hp_taken')

# ── ⑤ 新函数：应急装甲封顶（紧跟 _hp_damage_taken 之后）─────────────
ANCHOR_FN = CR + CR + 'func _wild_form_first_hit(attacker: Placement, raw: int) -> int:' + CR
NEW_FN = (
    CR + CR
    + 'func _emergency_armor_cap(dmg: int) -> int:' + CR
    + '\t## R793 应急装甲（6074，一般档）：「每回合最多受到 20 点伤害」—— **管玩家 HP**。' + CR
    + '\t## 位置 = `_hp_damage_taken()` 的最后一格（风暴屏障 / 石肤 / 效果减伤 / 道具减伤全算完），' + CR
    + '\t## 理由同赫尔墨斯：卡面写「受到」＝最终真正扣掉的血，封顶放在减伤之前会被后面的减伤再拉回来。' + CR
    + '\t## ⚠️ 玩家 HP 伤害有**两条**落地路：`_damage_player()`（技能 / 溢出 / 效果）与' + CR
    + '\t##    `attack_hp()` 里的直扣（敌人普攻直击，没有外包一层 `_damage_player`）。' + CR
    + '\t##    本函数挂在两者**共同的**上游 `_hp_damage_taken()` —— 挂 `_damage_player()` 会漏掉普攻那一条。' + CR
    + '\t## 回合口径 = `turn_number`（整轮）；换回合 key 失配，额度自动归零，不用扫状态重置。' + CR
    + '\t## 不锈钢盆（6041）在这条链**之后**吸收，它吃掉的份额仍计入额度：盆有总量上限，' + CR
    + '\t## 玩家视角是「装甲已经挡下来了」，与赫尔墨斯「护甲不占额度」不必强行统一。' + CR
    + '\tif dmg <= 0 or not self_relics.has(EMERGENCY_ARMOR_RELIC_ID):' + CR
    + '\t\treturn dmg' + CR
    + '\tif _armor_turn_key != turn_number:' + CR
    + '\t\t_armor_turn_key = turn_number' + CR
    + '\t\t_armor_turn_taken = 0' + CR
    + '\tvar left:= maxi(0, EMERGENCY_ARMOR_CAP - _armor_turn_taken)' + CR
    + '\tif left <= 0:' + CR
    + '\t\t_log("应急装甲：本回合已受满 %d 点伤害，这一下全免" % EMERGENCY_ARMOR_CAP)' + CR
    + '\t\taction.emit("armor_capped", {"blocked": dmg, "dealt": 0,' + CR
    + '\t\t\t\t"cap": EMERGENCY_ARMOR_CAP})' + CR
    + '\t\treturn 0' + CR
    + '\tif dmg <= left:' + CR
    + '\t\t_armor_turn_taken += dmg' + CR
    + '\t\treturn dmg' + CR
    + '\tvar blocked:= dmg - left' + CR
    + '\t_log("应急装甲：本回合伤害上限 %d 点 —— 这一下 %d 封顶到 %d" % [' + CR
    + '\t\t\tEMERGENCY_ARMOR_CAP, dmg, left])' + CR
    + '\taction.emit("armor_capped", {"blocked": blocked, "dealt": left,' + CR
    + '\t\t\t"cap": EMERGENCY_ARMOR_CAP})' + CR
    + '\t_armor_turn_taken = EMERGENCY_ARMOR_CAP' + CR
    + '\treturn left' + CR
)
rep(ANCHOR_FN, NEW_FN + ANCHOR_FN, 'new_fn')

# ── ⑥ 刺墙：attack() 里接在电磁屏障之后 ─────────────────────────────
ANCHOR_ATK = (
    '\t\tif attacker.health <= 0:' + CR
    + '\t\t\t_destroy_dead()' + CR
    + '\tif state.board.has(src):' + CR
    + '\t\tif attacker.card.id == LURKER_ID and attacker.ramp_atk > 0:' + CR
)
NEW_ATK = (
    '\t\tif attacker.health <= 0:' + CR
    + '\t\t\t_destroy_dead()' + CR
    + '\t# ── R793 刺墙（6073）：己方**工事被普通攻击**时，攻击者受 SPIKE_WALL_DMG 点伤害 ──' + CR
    + '\t# 挂点与上面「电磁屏障」同一处（防守方结算完、`_tap` 之前），三条理由：' + CR
    + '\t#   * 排在 `_reap` 之后 —— 工事被一击打穿也照样触发（卡面写「被攻击时」，不是「存活时」）；' + CR
    + '\t#   * 反伤走 `_hit_unit`（吃光环 / 护盾 / 减伤，与技能同一口径），击杀走 `_destroy_dead`；' + CR
    + '\t#   * 攻击者被打死时下面 `board.has(src)` 为假，自然跳过横置。' + CR
    + '\t# ⚠️ 只认**普通攻击**：`attack()` 是普攻唯一的结算口，技能 / 效果打过来不经过这里。' + CR
    + '\tvar spike_wall_ok: bool = (defender.owner == SIDE_SELF' + CR
    + '\t\t\tand defender.card.kind == "工事"' + CR
    + '\t\t\tand RunState.has_relic(SPIKE_WALL_RELIC_ID))' + CR
    + '\tif state.board.has(src) and spike_wall_ok:' + CR
    + '\t\tvar sw:= _hit_unit(attacker, SPIKE_WALL_DMG, "刺墙", false)' + CR
    + '\t\t_log("刺墙：%s 攻击工事 %s → 反受 %d 点伤害" % [' + CR
    + '\t\t\t\tattacker.card.card_name, defender.card.card_name, sw])' + CR
    + '\t\taction.emit("spike_wall", {"cell": dst, "src": src, "amount": sw,' + CR
    + '\t\t\t\t"atk_name": attacker.card.card_name,' + CR
    + '\t\t\t\t"def_name": defender.card.card_name})' + CR
    + '\t\tif attacker.health <= 0:' + CR
    + '\t\t\t_destroy_dead()' + CR
    + '\tif state.board.has(src):' + CR
    + '\t\tif attacker.card.id == LURKER_ID and attacker.ramp_atk > 0:' + CR
)
rep(ANCHOR_ATK, NEW_ATK, 'attack')

io.open(P, 'w', encoding='utf-8', newline='').write(s)
b = open(P, 'rb').read()
print('game_engine.gd CRLF', b.count(b'\r\n'), 'LF-only', b.count(b'\n') - b.count(b'\r\n'))
print('OK')
