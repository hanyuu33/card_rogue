# -*- coding: utf-8 -*-
"""R775 补丁：card_data.gd 的 ASSEMBLE_EFFECT_TYPES 加 3 个新动作（保持 CRLF）。"""
import io

P = 'scripts/card_data.gd'
with io.open(P, 'r', encoding='utf-8', newline='') as f:
    s = f.read()
assert s.count('\r\n') > 0, 'card_data.gd 应该是 CRLF'

old = '\t"fetch_cheapest_ally", "recall_ally_from_discard",\r\n]'
new = ('\t"fetch_cheapest_ally", "recall_ally_from_discard",\r\n'
       '\t# R775：三条新动作 —— 堡垒「每层改造 +生命」/ 影子猫·幽灵「从卡组随机技能卡入手」/ 幽灵「自毁」。\r\n'
       '\t"bonus_hp_per_upgrade", "fetch_skill", "self_destruct",\r\n]')

n = s.count(old)
assert n == 1, '锚点匹配数=%d' % n
s = s.replace(old, new)
with io.open(P, 'w', encoding='utf-8', newline='') as f:
    f.write(s)
with io.open(P, 'rb') as f:
    b = f.read()
print('card_data.gd OK  CRLF=%d LF=%d' % (b.count(b'\r\n'), b.count(b'\n') - b.count(b'\r\n')))
