#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 引擎层：刺墙扩面到 HP / 兔脚 / 钻头 / 卡牌包 / 智慧药剂。

锚点一律 exact-replace + assert count==1；行尾按文件原本口径写回（CRLF 三个、LF 其余）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def patch(path, pairs):
    p = ROOT + path
    raw = io.open(p, encoding="utf-8", newline="").read()
    lf = raw.count("\n")
    crlf = raw.count("\r\n")
    if lf not in (crlf, 0) and crlf != 0:
        print("FAIL %s 行尾混杂（lf %d / crlf %d），不动" % (path, lf, crlf))
        sys.exit(1)
    crlf_mode = crlf > 0
    s = raw.replace("\r\n", "\n")
    for old, new, note in pairs:
        n = s.count(old)
        if n != 1:
            print("FAIL %s 锚点命中 %d 次：%s" % (path, n, note))
            sys.exit(1)
        s = s.replace(old, new)
        print("OK  %s %s" % (path, note))
    if crlf_mode:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)


# ══ ① game_engine.gd ═══════════════════════════════════════════
patch("scripts/game_engine.gd", [
    # 常量
    ('const SPIKE_WALL_DMG:= 5\n# R793 应急装甲（6074，一般档）',
     'const SPIKE_WALL_DMG:= 5\n'
     '# R796 刺墙**扩面**（用户口径「工事和 HP 被攻击时」）：反伤触发面从「工事」加到\n'
     '#   「工事 + 玩家 HP」。常量不变，只多挂一处 —— 见 `attack_hp()` 里那一段。\n'
     '# R796 钻头（6077，一般档）：**X 费卡**的效果 X ≥ DRILL_X_MIN 时翻倍。\n'
     '#   ⚠️ 翻的是**效果的 X**，不是「要付的费用」—— 流星雨照样吃掉全部费用再放 2X 颗，\n'
     '#   枭熊照样付光费用，只是力量记 2X、生命记 9×(2X)。见 `_drill_x()`。\n'
     'const DRILL_RELIC_ID:= 6077\n'
     'const DRILL_X_MIN:= 6\n'
     '# R793 应急装甲（6074，一般档）',
     "(常量 +DRILL)"),

    # 钻头放大的唯一口
    ('func _meteor_shower(side: String, card: CardData) -> String:',
     'func _drill_x(x: int) -> int:\n'
     '\t## R796 钻头（6077）的**唯一口**：X 费卡的效果 X ≥ 6 → X 翻倍。\n'
     '\t## 两处调用，别只改一半：\n'
     '\t##   * 技能（流星雨 9083）→ `play_from_hand` 里的 `_x_spell_value`；\n'
     '\t##   * 单位（枭熊 9213）→ `place()` 里的 `x_unit`（力量 X / 生命 9X）。\n'
     '\t## 「半边生效」是最难查的一类 bug（法术吃了道具、传说卡没吃），所以两边必须同一口。\n'
     '\t## ⚠️ 只放大**效果**，不碰扣费：`_pay()` 依旧吃掉该方全部费用（`cost_of()` 同源），\n'
     '\t##    玩家不会因为拿了钻头就被多收钱。\n'
     '\tif x >= DRILL_X_MIN and RunState.has_relic(DRILL_RELIC_ID):\n'
     '\t\treturn x * 2\n'
     '\treturn x\n'
     '\n'
     '\n'
     'func _meteor_shower(side: String, card: CardData) -> String:',
     "(+_drill_x)"),

    ('	_x_spell_value = maxi(0, state.energy_of(SIDE_SELF)) if card.x_cost else 0',
     '	_x_spell_value = _drill_x(maxi(0, state.energy_of(SIDE_SELF))) if card.x_cost else 0',
     "(法术 X 过钻头)"),

    ('		x_unit = maxi(0, state.energy_of(SIDE_SELF))\n	var paid:= _pay(card)',
     '		x_unit = _drill_x(maxi(0, state.energy_of(SIDE_SELF)))\n	var paid:= _pay(card)',
     "(枭熊 X 过钻头)"),

    # 刺墙扩面：HP 被普通攻击
    ('	action.emit("hp", {"src": src, "dst": dst, "damage": dealt, "raw": power,\n'
     '		"side": side, "atk_name": attacker.card.card_name})\n',
     '	action.emit("hp", {"src": src, "dst": dst, "damage": dealt, "raw": power,\n'
     '		"side": side, "atk_name": attacker.card.card_name})\n'
     '	# ── R796 刺墙扩面（6073）：**HP 被普通攻击**时也反伤 ──\n'
     '	# 用户口径 R796「工事和 HP 被攻击时」。HP 直击走的是**本函数**（`attack()` 只管单位互殴），\n'
     '	# 所以反伤必须在 `attack()` 之外再补这一份 —— 只挂 `attack()` 永远等不到直击 HP 这一条。\n'
     '	# ⚠️ 溢出 / 打穿漏下来的 HP 伤害**不算**：那一笔是「工事被同一次攻击打穿」的余波，\n'
     '	#    同一次攻击已经在 `attack()` 里反过一次，再算就是一刀两反（5 → 10）。\n'
     '	# 位置：HP 飘字之后、攻击者的战后触发之前。攻击者被反死 → 直接收工，\n'
     '	# 不跑下面的潜影者重置 / 自动生成 / `_tap`（对已销毁的单位横置没有意义）。\n'
     '	var spike_hp_ok: bool = (side != SIDE_SELF and state.board.has(attacker)\n'
     '			and RunState.has_relic(SPIKE_WALL_RELIC_ID))\n'
     '	if spike_hp_ok:\n'
     '		var sw_hp:= _hit_unit(attacker, SPIKE_WALL_DMG, "刺墙", false)\n'
     '		_log("刺墙：%s 攻击我方 HP → 反受 %d 点伤害" % [attacker.card.card_name, sw_hp])\n'
     '		action.emit("spike_wall", {"cell": dst, "src": src, "amount": sw_hp,\n'
     '				"atk_name": attacker.card.card_name, "def_name": ""})\n'
     '		if attacker.health <= 0:\n'
     '			_destroy_dead()\n'
     '			_check_game_over()\n'
     '			return\n',
     "(刺墙 → HP)"),
])

# ══ ② run_state.gd：兔脚 ═════════════════════════════════════
patch("scripts/run_state.gd", [
    ('const TOOL_DROP_CHANCE := 0.10\n',
     'const TOOL_DROP_CHANCE := 0.10\n'
     '## R796 兔脚（6076，一般档）：战斗胜利金币 +RABBIT_FOOT_GOLD、战斗掉落工具的概率\n'
     '## **加算** RABBIT_FOOT_TOOL_DROP（用户口径「＋10%（加算）」→ 10% → 20%，不是 ×1.1）。\n'
     '## 判据走 `RunState.has_relic()`（静态读全局），别用引擎的 `self_relics` 快照。\n'
     'const RABBIT_FOOT_RELIC_ID := 6076\n'
     'const RABBIT_FOOT_GOLD := 10\n'
     'const RABBIT_FOOT_TOOL_DROP := 0.10\n',
     "(兔脚常量)"),

    ('	if tool_drop_pledge > 0:\n'
     '		tool_drop_pledge -= 1\n'
     '	elif rng.randf() >= TOOL_DROP_CHANCE:\n'
     '		return -1\n',
     '	# R796 兔脚：概率**加算**（0.10 → 0.20）。放在 `randf()` 之前只算一个数，\n'
     '	# 不改变随机流的消费次数 —— 拿没拿兔脚，同一个种子摇出的那一颗 randf() 是同一颗。\n'
     '	var drop_chance := TOOL_DROP_CHANCE\n'
     '	if has_relic(RABBIT_FOOT_RELIC_ID):\n'
     '		drop_chance += RABBIT_FOOT_TOOL_DROP\n'
     '	if tool_drop_pledge > 0:\n'
     '		tool_drop_pledge -= 1\n'
     '	elif rng.randf() >= drop_chance:\n'
     '		return -1\n',
     "(兔脚掉率)"),

    ('static func gain_gold(amount: int) -> int:',
     'static func rabbit_foot_gold() -> int:\n'
     '\t## R796 兔脚（6076）：战斗胜利额外给的金币（没有这件道具 → 0）。\n'
     '\t## ⚠️ 只加在**战斗胜利**这一条上（`battle_scene` 的结算口），不进 `gold_for_tier()` ——\n'
     '\t##    那个函数是「按难度分级的基础掉落」的唯一口径，测试也按它断言，掺进道具会把它污染成\n'
     '\t##    「看背包的函数」。宝箱 / 事件 / 商店都不吃兔脚（用户口径写的是「战斗掉落金币」）。\n'
     '\tif has_relic(RABBIT_FOOT_RELIC_ID):\n'
     '\t\treturn RABBIT_FOOT_GOLD\n'
     '\treturn 0\n'
     '\n'
     '\n'
     'static func gain_gold(amount: int) -> int:',
     "(+rabbit_foot_gold)"),
])

# ══ ③ battle_scene.gd：金币记账 + 两种新工具的播报 ═══════════
patch("scripts/battle_scene.gd", [
    ('			var gold_gain := RunState.gold_for_tier(tier)\n'
     '			if gold_gain > 0:\n'
     '				RunState.gain_gold(gold_gain)\n'
     '				gold_total += gold_gain\n'
     '				gold_parts.append(GameI18n.ui("reward", "REWARD_GOLD_PART_BATTLE", "战斗 %d") % gold_gain)\n',
     '			var gold_gain := RunState.gold_for_tier(tier)\n'
     '			if gold_gain > 0:\n'
     '				RunState.gain_gold(gold_gain)\n'
     '				gold_total += gold_gain\n'
     '				gold_parts.append(GameI18n.ui("reward", "REWARD_GOLD_PART_BATTLE", "战斗 %d") % gold_gain)\n'
     '			# R796 兔脚（6076）：战后金币 +10。**单独记一项**（不并进上面那条「战斗 %d」）——\n'
     '			# R423 的口径就是「结算面板要说清这些钱从哪来」，并进去等于把道具效果藏了。\n'
     '			var rabbit_gold := RunState.rabbit_foot_gold()\n'
     '			if rabbit_gold > 0:\n'
     '				RunState.gain_gold(rabbit_gold)\n'
     '				gold_total += rabbit_gold\n'
     '				gold_parts.append(GameI18n.ui("reward", "REWARD_GOLD_PART_RABBIT_FOOT", "兔脚 %d") % rabbit_gold)\n',
     "(兔脚金币记账)"),

    ('	elif td.ally_atk > 0:\n'
     '		_say("已使用「%s」，本场所有盟友 +%d 力量" % [td.trap_name, td.ally_atk])\n'
     '	else:\n'
     '		_say("已使用「%s」，回复 %d 点费用" % [td.trap_name, td.energy])\n',
     '	elif td.ally_atk > 0:\n'
     '		_say("已使用「%s」，本场所有盟友 +%d 力量" % [td.trap_name, td.ally_atk])\n'
     '	elif td.fill_hand:\n'
     '		# R796 卡牌包 7013：报「补进来几张」而不是「手牌满了」——\n'
     '		# 手牌本来就满时 `use_tool` 直接拒绝（见那边的早退），走不到这里。\n'
     '		_say("已使用「%s」，手牌补到 %d 张" % [td.trap_name, engine.state.hand.size()])\n'
     '	elif td.draw_cards > 0:\n'
     '		# R796 智慧药剂 7014：手牌满时抽到的会直接进弃牌区（与战斗中一切抽卡同口径），\n'
     '		# 所以这里只报「抽了几张」，不承诺「全都进手里」。\n'
     '		_say("已使用「%s」，抽 %d 张卡" % [td.trap_name, td.draw_cards])\n'
     '	else:\n'
     '		_say("已使用「%s」，回复 %d 点费用" % [td.trap_name, td.energy])\n',
     "(新工具播报)"),
])

print("DONE")
