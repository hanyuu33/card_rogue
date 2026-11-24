# -*- coding: utf-8 -*-
"""R778b：game_levels.gd 关卡配置改动（按函数块做 exact-replace）。"""
import io
import sys

ROOT = "E:/work/card_rogue/"
P = ROOT + "scripts/game_levels.gd"

s = io.open(P, "r", encoding="utf-8", newline="").read()
assert s.count("\n") == s.count("\r\n"), "game_levels.gd 应为纯 CRLF"
s = s.replace("\r\n", "\n")


def func_block(name):
    i = s.index("static func _%s() -> Dictionary:" % name)
    j = s.index("\n\t}\n", i) + len("\n\t}\n")
    return i, j


def rep_in(name, old, new, tag):
    global s
    i, j = func_block(name)
    body = s[i:j]
    n = body.count(old)
    if n != 1:
        print("FAIL[%s/%s] count=%d" % (name, tag, n))
        sys.exit(1)
    s = s[:i] + body.replace(old, new, 1) + s[j:]
    print("OK %s / %s" % (name, tag))


# ---------- 1. 队长与巫师：效果卡换成鸭子之力 9013 ----------
rep_in("captain_wizard",
       '\t## 敌方效果卡「使魔之力 9115」：使魔鸭子每回合开始力量 +1（永久）。',
       '\t## R778：敌方效果卡由「使魔之力 9115」换成「鸭子之力 9013」\n'
       '\t## （每回合开始所有友方单位力量 +1，每个单位最多累计 +4）。',
       "注释换效果卡")
rep_in("captain_wizard", '"enemy_effects": [9115],', '"enemy_effects": [9013],', "effects 9013")

# ---------- 2. 龙族巢穴：整关重写（去铁壁卫兵、去战吼、移到第一层）----------
i, j = func_block("dragon_nest")
new_dragon = '''static func _dragon_nest() -> Dictionary:
	## 第一层·精英敌人-简单「龙族巢穴」（R778：从第二层**整关移到第一层**）：
	## 后排中央灰烬龙（5/45 速 2，一回合行动两次）+ 中排两翼幼龙（5/25 程 2，
	## 死亡召唤龙裔 4/12）。
	## R778 三处改动：① 灰烬龙的「战吼」效果删除（卡面已清空，引擎 `_battlecry()`
	## 里的 ash 分支同步下线）；② 前排中央的铁壁卫兵（1011，嘲讽）移除 ——
	## 这一关现在只有三只龙；③ 不再带 `LAYER2_GROWTH`，按第一层的默认成长走
	## （原来是二层关，成长轴跟着二层）。
	return {
		"name": "龙族巢穴",
		"key": "dragon_nest",
		"tier": TIER_ELITE_EASY,
		"layer": GameLayers.LAYER_DEFAULT,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"starting_hand": 0,
		"enemy_units": [
			[1013, "灰烬龙", 5, 45, 1, 2, Vector2i(0, 1)],
			[1014, "幼龙", 5, 25, 2, 1, Vector2i(1, 0)],
			[1014, "幼龙", 5, 25, 2, 1, Vector2i(1, 2)],
		],
		"tutorial": [],
	}
'''
s = s[:i] + new_dragon + s[j:]
print("OK dragon_nest 整块重写")

# ---------- 3. 阿斯克勒庇厄斯的试炼：精英简单 → 普通困难 ----------
rep_in("asclepius", '"tier": TIER_ELITE_EASY,', '"tier": TIER_NORMAL_HARD,', "tier 普通困难")
rep_in("asclepius",
       '\t## 第二层·精英敌人-简单（R162 进池；**R506 与母舰空袭互换档位，下调到精英简单**）：',
       '\t## 第二层·普通敌人-困难（R162 进池；R506 下调到精英简单；**R778 再下调为普通困难**）：',
       "注释档位")

# ---------- 4. 计量工坊：三只 60 → 80、普通困难 → 精英困难 ----------
rep_in("metrology_works",
       '\t## 第二层·普通敌人-困难「计量工坊」（R758）：三个「文职」单位排成一列。',
       '\t## 第二层·精英敌人-困难「计量工坊」（R758；**R778 由普通困难升到精英困难**）：\n'
       '\t## 三个「文职」单位排成一列。',
       "注释档位")
rep_in("metrology_works", '"tier": TIER_NORMAL_HARD,', '"tier": TIER_ELITE_HARD,', "tier 精英困难")
rep_in("metrology_works",
       '\t## 三只都是 60 血：这关不拼「一口气拆掉后排」，而是拼「谁去堵、堵多久」。',
       '\t## 三只都是 80 血（R778：60 → 80，随档位一起上调）：这关不拼「一口气拆掉后排」，\n'
       '\t## 而是拼「谁去堵、堵多久」。',
       "注释血量")
rep_in("metrology_works", '[9260, "常数测量员", 0, 60, 1, 1,', '[9260, "常数测量员", 0, 80, 1, 1,', "测量员 80")
rep_in("metrology_works", '[9261, "精密计算者", 6, 60, 1, 2,', '[9261, "精密计算者", 6, 80, 1, 2,', "计算者 80")
rep_in("metrology_works", '[9262, "负载增量员", 4, 60, 1, 1,', '[9262, "负载增量员", 4, 80, 1, 1,', "增量员 80")

# ---------- 5. 第三层精英池注释（计量工坊进精英困难 → 4 关变 5 关）----------
s = s.replace(
    "\t## **全部** 9 关（简单 5 + 困难 4）；这里收窄到困难 4 关\n"
    "\t## （机甲巨兵 / 钢铁要塞 / 母舰空袭 / **R722 巨炮防线**），且不随 `elite_wins` 变化。",
    "\t## **全部** 9 关（简单 4 + 困难 5）；这里收窄到困难 5 关\n"
    "\t## （机甲巨兵 / 钢铁要塞 / 母舰空袭 / R722 巨炮防线 / **R778 计量工坊**），\n"
    "\t## 且不随巧克力强弱判定变化（R778 起精英强弱看当前巧克力）。", 1)
print("OK third_elite_pool 注释")

# ---------- 6. 全关卡单位行数值同步 ----------
counts = {
    '[9017, "鸭子弓手", 3, 18, 2, 1,': '[9017, "鸭子弓手", 3, 15, 2, 1,',
    '[9012, "鸭子队长", 6, 55, 1, 1,': '[9012, "鸭子队长", 6, 50, 1, 1,',
    '[9132, "俄倪厄", 10, 80, 1, 1,': '[9132, "俄倪厄", 10, 100, 1, 3,',
    '[9133, "量产型赫卡同克瑞斯", 3, 35, 1, 1,': '[9133, "量产型赫卡同克瑞斯", 3, 60, 1, 1,',
}
for old, new in counts.items():
    n = s.count(old)
    if n == 0:
        print("FAIL 单位行未找到: %s" % old)
        sys.exit(1)
    s = s.replace(old, new)
    print("OK 单位行替换 x%d  %s" % (n, old[:34]))

io.open(P, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n"))
print("LEVELS DONE")
