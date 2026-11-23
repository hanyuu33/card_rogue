# -*- coding: utf-8 -*-
"""R792 修正：测试段误追加进 _test_r781()，改为独立 _test_r792() 并在 _init 注册。"""
import io
import sys

ROOT = 'E:/work/card_rogue/'
P = ROOT + 'scripts/test_engine.gd'
s = io.open(P, encoding='utf-8', newline='').read()

MARK = '\t# ================= R792：板甲 / 兵 / 墙砖 + 猴爪进池 + 第三层事件 =============='
i = s.find(MARK)
if i < 0:
    print('FAIL 找不到 R792 段标记')
    sys.exit(1)
block = s[i:]
s = s[:i].rstrip('\r\n') + '\r\n'

# 段内 repo → 本函数自己的卡库变量
block = block.replace('repo.get_card(', 'r792_cards.get_card(')

# 注册调用
old_call = '\t_test_r781()\r\n'
if s.count(old_call) != 1:
    print('FAIL _test_r781() 调用命中 %d 次' % s.count(old_call))
    sys.exit(1)
s = s.replace(old_call, old_call + '\t_test_r792()\r\n')

# 追加独立函数
s = s + '\r\n\r\n' + 'func _test_r792() -> void:\r\n' \
    + '\t## R792（用户口径）：板甲 / 兵 / 墙砖 三件新道具 + 猴爪进奖励池 + 第三层不再注册事件。\r\n' \
    + '\tvar r792_cards := CardRepo.load_json()\r\n\r\n' \
    + block.replace('\r\n', '\r\n').lstrip('\r\n') + '\r\n'

io.open(P, 'w', encoding='utf-8', newline='').write(s)
print('OK 测试段移出 _test_r781 并注册 _test_r792()')
