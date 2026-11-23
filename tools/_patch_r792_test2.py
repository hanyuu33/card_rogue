# -*- coding: utf-8 -*-
"""R792 测试修正：
  ① R781 规则版本断言写死 == 3 —— 改成「两处一致且不低于 3」，以后升级不再假红；
  ② 第三层事件断言：`content_layers: [2, 3]` 会把第二层权重摊进来，
     真正该守的是「LAYERS[3] 自己不再登记 events 表」；
  ③ 板甲 / 兵的第二张卡放 Vector2i(6,1) 越界（棋盘 5 列），改用 (4,1)/(5,1)。
"""
import io
import sys

ROOT = 'E:/work/card_rogue/'
P = ROOT + 'scripts/test_engine.gd'
s = io.open(P, encoding='utf-8', newline='').read()


def rep(old, new):
    global s
    old = old.replace('\n', '\r\n')
    new = new.replace('\n', '\r\n')
    n = s.count(old)
    if n != 1:
        print('FAIL 命中 %d 次：%s' % (n, old[:80]))
        sys.exit(1)
    s = s.replace(old, new)
    print('OK  ', old.split('\n')[0][:60])


# ① 规则版本
rep('''	check(DailyChallenge.RULES_VERSION == 3 and DailyModifiers.RULES_VERSION == 3,
			"R781 规则版本：修饰语义变了 → 两处一起升到 3（%d/%d）" % [''',
    '''	# R792：奖励池变动后升到 4，这条从「写死 == 3」改成「两处一致 + 不低于 3」——
	# 守的是**两处必须同升**这条铁律，而不是某一个具体数字（写死会让每次升级都假红）。
	check(DailyChallenge.RULES_VERSION == DailyModifiers.RULES_VERSION and DailyChallenge.RULES_VERSION >= 3,
			"R781 规则版本：两处必须一致且不低于 3（%d/%d）" % [''')

# ② 第三层事件
rep('''	check(not GameLayers.has_events(GameLayers.LAYER_THREE) and GameLayers.event_weights(GameLayers.LAYER_THREE).is_empty(),
			"R792 第三层不再注册事件（事件池只剩第一 / 第二层）")''',
    '''	# ⚠️ 不能断言 `event_weights(3).is_empty()` —— `content_layers: [2, 3]` 会把
	# 第二层的 events 表摊进来（关卡池与事件池共用这份配置）。真正该守的是
	# 「LAYERS[3] 自己不再登记 events 表」：第三层没有事件节点，登记了也抽不到。
	var r792_l3: Dictionary = GameLayers.LAYERS.get(GameLayers.LAYER_THREE, {})

	check(not r792_l3.has("events"),
			"R792 第三层不再注册 events 表（内容池仍与第二层共用）")''')

# ③ 格子越界
rep('''	var r792_p2 := r792_plate.play_from_hand(0, Vector2i(6, 1))''',
    '''	var r792_p2 := r792_plate.play_from_hand(0, Vector2i(4, 1))''')
rep('''	var r792_n2 := r792_pawn.play_from_hand(0, Vector2i(6, 1))''',
    '''	var r792_n2 := r792_pawn.play_from_hand(0, Vector2i(4, 1))''')

io.open(P, 'w', encoding='utf-8', newline='').write(s)
print('测试修正完成')
