# -*- coding: utf-8 -*-
"""R778b：补齐剩余测试断言（龙族巢穴换层 / 阿斯克勒庇厄斯降档 / 池子数量 / 计量工坊档位与血量）。"""
import io
import sys

ROOT = "E:/work/card_rogue/"
P = ROOT + "scripts/test_engine.gd"

s = io.open(P, "r", encoding="utf-8", newline="").read()
assert s.count("\n") == s.count("\r\n")
s = s.replace("\r\n", "\n")


def rep(old, new, tag):
    global s
    n = s.count(old)
    if n != 1:
        print("FAIL[%s] count=%d" % (tag, n))
        sys.exit(1)
    s = s.replace(old, new, 1)
    print("OK %s" % tag)


# 1. 龙族巢穴不再属于第二层
rep('''	# ---- 4 个新关卡都属于第二层 ----

	for om_nm in ["寒冰防线", "亡灵军团", "龙族巢穴", "机甲巨兵"]:

		var om_lv := _level_named(om_nm)

		check(not om_lv.is_empty() and int(om_lv["layer"]) == GameLayers.LAYER_TWO,

				"新关卡「%s」属于第二层" % om_nm)''',
    '''	# ---- 新关卡都属于第二层（R778：龙族巢穴已整关移到第一层，单独断言）----

	for om_nm in ["寒冰防线", "亡灵军团", "机甲巨兵"]:

		var om_lv := _level_named(om_nm)

		check(not om_lv.is_empty() and int(om_lv["layer"]) == GameLayers.LAYER_TWO,

				"新关卡「%s」属于第二层" % om_nm)

	var om_dn := _level_named("龙族巢穴")

	check(not om_dn.is_empty() and int(om_dn["layer"]) == GameLayers.LAYER_DEFAULT

			and int(om_dn["tier"]) == GameLevels.TIER_ELITE_EASY,

			"R778 龙族巢穴：整关移到第一层·精英敌人-简单（原第二层）")''',
    "龙族巢穴换层")

# 2. R162 档位
rep('''	check(str(r162_lvl["name"]) == "阿斯克勒庇厄斯的试炼"

			and int(r162_lvl["tier"]) == GameLevels.TIER_ELITE_EASY''',
    '''	check(str(r162_lvl["name"]) == "阿斯克勒庇厄斯的试炼"

			and int(r162_lvl["tier"]) == GameLevels.TIER_NORMAL_HARD''',
    "R162 档位")

# 3. R398 / R506b 池子数量
rep("\tcheck(r398_pool.size() == 9,", "\tcheck(r398_pool.size() == 8,", "R398 数量")
rep("\tcheck(r506b_pool.size() == 4,", "\tcheck(r506b_pool.size() == 5,", "R506b 数量")

# 4. R758 档位与血量
rep('''	check(str(r758_lvl["key"]) == "metrology_works"

			and int(r758_lvl["tier"]) == GameLevels.TIER_NORMAL_HARD''',
    '''	check(str(r758_lvl["key"]) == "metrology_works"

			and int(r758_lvl["tier"]) == GameLevels.TIER_ELITE_HARD''',
    "R758 档位")

rep('check(int(r758_units[0][0]) == 9260 and int(r758_units[0][3]) == 60',
    'check(int(r758_units[0][0]) == 9260 and int(r758_units[0][3]) == 80',
    "R758 测量员血量")

io.open(P, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n"))
print("TESTS2 DONE")
