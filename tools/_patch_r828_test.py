# -*- coding: utf-8 -*-
"""R828：板甲 6070 测试由「固定 +6」改为「当前层数 × 3」。CRLF 文件，代码行间保留空行。"""
import sys

PATH = 'scripts/test_engine.gd'
data = open(PATH, 'rb').read().decode('utf-8')
s = data.replace('\r\n', '\n')

OLD = "\n".join([
"\t# ② 板甲：第一个盟友 +6 生命、移速 5 → 1；第二个盟友完全不受影响",
"\tvar r792_plate_relics: Array[int] = [6070]",
"",
"\tRunState.relics = r792_plate_relics",
"",
"\tvar r792_plate := _new_engine([], 40, 40)",
"",
"\tr792_plate.state.energy = 30",
"",
"\tr792_plate.state.hand.clear()",
"",
"\tr792_plate.state.hand.append(CardData.from_dict(r792_cards.get_card(8006).to_dict()))   # 影子猫 1 费 1 血 速 5",
"",
"\tr792_plate.state.hand.append(CardData.from_dict(r792_cards.get_card(9028).to_dict()))   # 龙裔 1 费 12 血 速 1",
"",
"\tvar r792_p1 := r792_plate.play_from_hand(0, Vector2i(5, 1))",
"",
"\tvar r792_p2 := r792_plate.play_from_hand(0, Vector2i(4, 1))",
"",
"\tcheck(r792_p1 != null and r792_p1.health == 7 and r792_p1.card.health == 7,",
"\t\t\t\"R792 板甲：第一个盟友 1+6=7 生命（实得 %d）\" % (r792_p1.health if r792_p1 != null else -1))",
"",
"\tcheck(r792_p1 != null and r792_p1.effective_speed() == 1 and r792_p1.speed_cap == 1,",
"\t\t\t\"R792 板甲：第一个盟友移速 5 → 1（实得 %d）\" % (r792_p1.effective_speed() if r792_p1 != null else -1))",
"",
"\tcheck(r792_p2 != null and r792_p2.health == 12 and r792_p2.speed_cap == 0 and r792_p2.relic_bonus_hp == 0,",
"\t\t\t\"R792 板甲：第二个盟友不受影响（生命 %d、无移速上限）\" % (r792_p2.health if r792_p2 != null else -1))",
])

NEW = "\n".join([
"\t# ② 板甲：第一个盟友获得「当前层数 × 3」生命、移速 5 → 1；第二个盟友完全不受影响",
"\tvar r792_layer_save: int = RunState.current_layer",
"\tvar r792_plate_relics: Array[int] = [6070]",
"",
"\tRunState.relics = r792_plate_relics",
"",
"\tRunState.current_layer = GameLayers.LAYER_DEFAULT",
"",
"\tvar r792_plate := _new_engine([], 40, 40)",
"",
"\tr792_plate.state.energy = 30",
"",
"\tr792_plate.state.hand.clear()",
"",
"\tr792_plate.state.hand.append(CardData.from_dict(r792_cards.get_card(8006).to_dict()))   # 影子猫 1 费 1 血 速 5",
"",
"\tr792_plate.state.hand.append(CardData.from_dict(r792_cards.get_card(9028).to_dict()))   # 龙裔 1 费 12 血 速 1",
"",
"\tvar r792_p1 := r792_plate.play_from_hand(0, Vector2i(5, 1))",
"",
"\tvar r792_p2 := r792_plate.play_from_hand(0, Vector2i(4, 1))",
"",
"\tcheck(r792_p1 != null and r792_p1.health == 4 and r792_p1.card.health == 4,",
"\t\t\t\"R792 板甲：第一层第一个盟友 1+3=4 生命（实得 %d）\" % (r792_p1.health if r792_p1 != null else -1))",
"",
"\tcheck(r792_p1 != null and r792_p1.effective_speed() == 1 and r792_p1.speed_cap == 1,",
"\t\t\t\"R792 板甲：第一个盟友移速 5 → 1（实得 %d）\" % (r792_p1.effective_speed() if r792_p1 != null else -1))",
"",
"\tcheck(r792_p2 != null and r792_p2.health == 12 and r792_p2.speed_cap == 0 and r792_p2.relic_bonus_hp == 0,",
"\t\t\t\"R792 板甲：第二个盟友不受影响（生命 %d、无移速上限）\" % (r792_p2.health if r792_p2 != null else -1))",
"",
"\t# R828：第二层 2×3=6、第三层 3×3=9 —— 加值随层数放大，仍是「第一个盟友」同一额度",
"\tRunState.current_layer = GameLayers.LAYER_TWO",
"",
"\tvar r792_plate_l2 := _new_engine([], 40, 40)",
"",
"\tr792_plate_l2.state.energy = 30",
"",
"\tr792_plate_l2.state.hand.clear()",
"",
"\tr792_plate_l2.state.hand.append(CardData.from_dict(r792_cards.get_card(8006).to_dict()))",
"",
"\tvar r792_l2p := r792_plate_l2.play_from_hand(0, Vector2i(5, 1))",
"",
"\tcheck(r792_l2p != null and r792_l2p.health == 7,",
"\t\t\t\"R792 板甲：第二层第一个盟友 1+6=7 生命（实得 %d）\" % (r792_l2p.health if r792_l2p != null else -1))",
"",
"\tRunState.current_layer = GameLayers.LAYER_THREE",
"",
"\tvar r792_plate_l3 := _new_engine([], 40, 40)",
"",
"\tr792_plate_l3.state.energy = 30",
"",
"\tr792_plate_l3.state.hand.clear()",
"",
"\tr792_plate_l3.state.hand.append(CardData.from_dict(r792_cards.get_card(8006).to_dict()))",
"",
"\tvar r792_l3p := r792_plate_l3.play_from_hand(0, Vector2i(5, 1))",
"",
"\tcheck(r792_l3p != null and r792_l3p.health == 10,",
"\t\t\t\"R792 板甲：第三层第一个盟友 1+9=10 生命（实得 %d）\" % (r792_l3p.health if r792_l3p != null else -1))",
"",
"\tRunState.current_layer = r792_layer_save",
])

n = s.count(OLD)
if n != 1:
    print('OLD 锚点不唯一(%d)或不存在' % n)
    sys.exit(1)
s = s.replace(OLD, NEW)

out = s.replace('\n', '\r\n')
open(PATH, 'wb').write(out.encode('utf-8'))
print('test patch ok')
