# -*- coding: utf-8 -*-
"""R775 补丁：cards.json —— 堡垒/鸭妈妈/影子猫/幽灵 加组合素材字段；影子猫「打出时→使用时」（保持 CRLF）。"""
import io

P = 'cards.json'
with io.open(P, 'r', encoding='utf-8', newline='') as f:
    s = f.read()
assert s.count('\r\n') > 0, 'cards.json 应该是 CRLF'

edits = []

# 影子猫 8006：改描述 + 加素材
edits.append((
    '      "effect_text": "打出时，若包含这张卡本回合打出的卡达到 3 张，从卡组将一张随机技能卡加入手卡。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "暗影",\r\n'
    '      "image": ""',
    '      "effect_text": "使用时，若包含这张卡本回合打出的卡达到 3 张，从卡组将一张随机技能卡加入手卡。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "暗影",\r\n'
    '      "image": "",\r\n'
    '      "upper_effect": {"trigger": "use", "effects": []},\r\n'
    '      "lower_effect": {"effects": [{"type": "fetch_skill", "if_third": true}]}'))

# 幽灵 8008：加素材（death 主扳机 + turn_start 自毁段 + fetch_skill）
edits.append((
    '      "effect_text": "自己回合开始时，这张卡破坏。这张卡破坏时，从卡组将一张随机技能卡加入手卡。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "暗影",\r\n'
    '      "image": ""',
    '      "effect_text": "自己回合开始时，这张卡破坏。这张卡破坏时，从卡组将一张随机技能卡加入手卡。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "暗影",\r\n'
    '      "image": "",\r\n'
    '      "upper_effect": {"trigger": "death", "effects": [], "turn_start_effects": [{"type": "self_destruct"}]},\r\n'
    '      "lower_effect": {"effects": [{"type": "fetch_skill"}]}'))

# 堡垒 8034：upgraded + bonus_hp_per_upgrade(3)
edits.append((
    '      "effect_text": "每拥有一层改造，这张卡获得 **+3 生命**。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "物理",\r\n'
    '      "image": ""',
    '      "effect_text": "每拥有一层改造，这张卡获得 **+3 生命**。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "物理",\r\n'
    '      "image": "",\r\n'
    '      "upper_effect": {"trigger": "upgraded", "effects": []},\r\n'
    '      "lower_effect": {"effects": [{"type": "bonus_hp_per_upgrade", "value": 3}]}'))

# 鸭妈妈 9250：use + summon 小鸭 ×2
edits.append((
    '      "effect_text": "使用时，在这张卡两边各召唤一只「小鸭」（如果可能）。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "自然",\r\n'
    '      "image": ""',
    '      "effect_text": "使用时，在这张卡两边各召唤一只「小鸭」（如果可能）。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "自然",\r\n'
    '      "image": "",\r\n'
    '      "upper_effect": {"trigger": "use", "effects": []},\r\n'
    '      "lower_effect": {"effects": [{"type": "summon", "value": 9251, "count": 2}]}'))

for i, (old, new) in enumerate(edits, 1):
    n = s.count(old)
    assert n == 1, '第 %d 处锚点匹配数=%d' % (i, n)
    s = s.replace(old, new)

with io.open(P, 'w', encoding='utf-8', newline='') as f:
    f.write(s)
with io.open(P, 'rb') as f:
    b = f.read()
print('cards.json OK  CRLF=%d LF=%d' % (b.count(b'\r\n'), b.count(b'\n') - b.count(b'\r\n')))
