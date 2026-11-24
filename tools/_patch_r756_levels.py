# -*- coding: utf-8 -*-
"""R756 game_levels：新增二层普通困难「计量工坊」。"""
import io

P = "e:/work/card_rogue/scripts/game_levels.gd"


def L(s):
    return s.replace("\n", "\r\n")


raw = io.open(P, "r", encoding="utf-8", newline="").read()
assert "\r\n" in raw


def rep(old, new, why):
    global raw
    o = L(old)
    n = L(new)
    c = raw.count(o)
    assert c == 1, "%s：锚点命中 %d 次" % (why, c)
    raw = raw.replace(o, n)
    print("ok:", why)


# ---------------- ① 新关卡函数 ----------------
rep(
    '''		"enemy_effects": [9139],
		"tutorial": [],
	}


## 「巨炮防线」专属成长曲线（R539）''',
    '''		"enemy_effects": [9139],
		"tutorial": [],
	}


static func _metrology_works() -> Dictionary:
	## 第二层·普通敌人-困难「计量工坊」（R756）：三个「文职」单位排成一列。
	##   后排 常数测量员 9253（0/60 程1 速1）—— **作为行动的代替**分配 16 点伤害
	##     （`GameEngine._surveyor_act`）：由近及远、打倒一个把剩下的给下一个，
	##     分不完的打到玩家 HP；**这一次没打到 HP 就自己眩晕一回合**。
	##     题面由此成立：「拿一个够厚的单位堵住它」= 它每两回合才动一次；
	##     场上空着 = 每回合 16 点直接糊脸，两回合就送走 20 血的玩家。
	##   中排 精密计算者 9254（6/60 程1 速2）—— 我方**盟友或工事**入场后生命 > 15 就被压到
	##     15（`_compute_cap_tick`，在所有入场增益之后）。高血单位铺场不再是无脑解。
	##   前排 负载增量员 9255（4/60 程1 速1）—— 每回合往我方抽牌库塞一张「攻击」+ 一张
	##     「木栅栏」（`_loader_tick`）：牌库被稀释，木栅栏还会占场。
	## 三只都是 60 血：这关不拼「一口气拆掉后排」，而是拼「谁去堵、堵多久」。
	return {
		"name": "计量工坊",
		"key": "metrology_works",
		"tier": TIER_NORMAL_HARD,
		"layer": GameLayers.LAYER_TWO,
		"deck_key": "starter",
		"player_hp": 20,
		"enemy_hp": 30,
		"turn_limit": -1,
		"shuffle": true,
		"enemy_ai": true,
		"enemy_growth": LAYER2_GROWTH,
		"starting_hand": 0,
		"enemy_units": [
			[9253, "常数测量员", 0, 60, 1, 1, Vector2i(0, 1)],
			[9254, "精密计算者", 6, 60, 1, 2, Vector2i(1, 1)],
			[9255, "负载增量员", 4, 60, 1, 1, Vector2i(2, 1)],
		],
		"tutorial": [],
	}


## 「巨炮防线」专属成长曲线（R539）''',
    "新关卡函数",
)

# ---------------- ② 注册 ----------------
rep(
    '''			_sun_forge(), _hecaton(), _undead_legion(), _twin_cannon(),
			_laser_line(),''',
    '''			_sun_forge(), _hecaton(), _undead_legion(), _twin_cannon(),
			_metrology_works(),
			_laser_line(),''',
    "注册",
)

# ---------------- ③ 计数注释 ----------------
rep(
    '''	## 按分级从低到高：普通简单×8（第一层 4 + 第二层 4）→ 普通困难×9（第一层 4 + 第二层 5）→''',
    '''	## 按分级从低到高：普通简单×8（第一层 4 + 第二层 4）→ 普通困难×10（第一层 4 + 第二层 6；
	##   R756 计量工坊进二层）→''',
    "计数注释 1",
)
rep(
    '''	## Boss×7（第一层 3 + 第二层 3 + 第三层 1）。合计 39 关（R541 普罗诺亚之影进二层精英简单；''',
    '''	## Boss×7（第一层 3 + 第二层 3 + 第三层 1）。合计 40 关（R756 计量工坊进二层普通困难；
	##   R541 普罗诺亚之影进二层精英简单；''',
    "计数注释 2",
)

io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("written")
