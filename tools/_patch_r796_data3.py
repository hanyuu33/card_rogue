#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 数据层 · 补丁 ③：TrapData 新字段 / 奖励池 id / RULES_VERSION。"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def rep(p, old, new, note=""):
    path = ROOT + p
    s = io.open(path, encoding="utf-8", newline="").read()
    n = s.count(old)
    if n != 1:
        print("FAIL %s 锚点命中 %d 次 %s" % (p, n, note))
        sys.exit(1)
    io.open(path, "w", encoding="utf-8", newline="").write(s.replace(old, new))
    print("OK  %s %s" % (p, note))


# ── TrapData：fill_hand / draw_cards ─────────────────────────────
rep("scripts/trap_data.gd",
    'var fill_toolbar := false\n',
    'var fill_toolbar := false\n'
    '## R796：卡牌包 7013 —— 使用后**用随机卡牌填满手牌**（不选卡、当场结算）。\n'
    '## 与 `fill_toolbar` 是同一条思路的两个栏位：一个补工具栏，一个补手牌。\n'
    'var fill_hand := false\n'
    '## R796：智慧药剂 7014 —— 使用后**抽这么多张卡**（走 `_draw_many`，手牌满时照常\n'
    '## 进弃牌区，与战斗中一切抽卡同一口径）。\n'
    'var draw_cards := 0\n',
    "(+fill_hand/draw_cards)")

rep("scripts/trap_data.gd",
    '''func is_usable() -> bool:
	return (heal_pct > 0 or energy > 0 or ally_atk > 0
			or pick_kind != "" or fill_toolbar)''',
    '''func is_usable() -> bool:
	return (heal_pct > 0 or energy > 0 or ally_atk > 0
			or pick_kind != "" or fill_toolbar or fill_hand or draw_cards > 0)''',
    "(is_usable)")

rep("scripts/trap_data.gd",
    '\tt.fill_toolbar = bool(d.get("fill_toolbar", false))\n',
    '\tt.fill_toolbar = bool(d.get("fill_toolbar", false))\n'
    '\tt.fill_hand = bool(d.get("fill_hand", false))\n'
    '\tt.draw_cards = int(d.get("draw_cards", 0))\n',
    "(from_dict)")

rep("scripts/trap_data.gd",
    '## 判据只看数据：带 heal_pct / energy / ally_atk / pick_kind / fill_toolbar 的就是使用型，',
    '## 判据只看数据：带 heal_pct / energy / ally_atk / pick_kind / fill_toolbar /\n'
    '## fill_hand / draw_cards 的就是使用型，',
    "(注释)")

# ── 奖励池：6076 / 6077 ──────────────────────────────────────────
rep("scripts/relic_repo.gd",
    '''	# R793：加「刺墙」6073（己方工事被攻击 → 攻击者受 5 伤）与「应急装甲」6074
	#   （玩家 HP 每回合最多受 20 伤）。同样一般档、不锁剧情。
	var ids: Array[int] = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051, 6052, 6053, 6054, 6060, 6064, 6065, 6066,
			6070, 6071, 6072, 6073, 6074]''',
    '''	# R793：加「刺墙」6073（己方工事被攻击 → 攻击者受 5 伤）与「应急装甲」6074
	#   （玩家 HP 每回合最多受 20 伤）。同样一般档、不锁剧情。
	# R796：加「兔脚」6076（战后金币 +10、工具掉率 +10% 加算）与「钻头」6077
	#   （X 费卡 X ≥ 6 时翻倍）。都是「战后 / 出牌时」被动，一般档、不锁剧情。
	var ids: Array[int] = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024,
			6026, 6028, 6029, 6040, 6041, 6042, 6043, 6044, 6045, 6046,
			6050, 6051, 6052, 6053, 6054, 6060, 6064, 6065, 6066,
			6070, 6071, 6072, 6073, 6074, 6076, 6077]''',
    "(+6076/6077)")

# ── RULES_VERSION 5 → 6（两处同升）───────────────────────────────
rep("scripts/daily_modifiers.gd", "const RULES_VERSION := 5",
    "const RULES_VERSION := 6", "(5→6)")
rep("scripts/daily_challenge.gd", "const RULES_VERSION := 5",
    "const RULES_VERSION := 6", "(5→6)")

print("DONE")
