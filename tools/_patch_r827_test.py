# -*- coding: utf-8 -*-
"""R827 刺墙一回合一次：test_engine.gd 补测试（保留 CRLF）。"""
P = "scripts/test_engine.gd"

with open(P, "rb") as f:
    s = f.read().decode("utf-8")

assert s.count("\r\n") > 0, "非 CRLF 文件，中止"
s = s.replace("\r\n", "\n")


def rep(old, new):
    global s
    c = s.count(old)
    assert c == 1, "anchor count=%d: %r" % (c, old[:60])
    s = s.replace(old, new)


# R793 刺墙工事：同回合第二刀不反 + 换回合恢复
r793_block = """\t# ②b 刺墙一回合一次（R827）：同回合第二刀不反；换回合恢复额度
\tvar r827_w_relics: Array[int] = [6073]
\tRunState.relics = r827_w_relics
\tvar r827_w := _new_engine([], 40, 40)
\tr827_w.state.energy = 30
\tr827_w.state.hand.clear()
\tr827_w.state.hand.append(CardData.from_dict(r793_cards.get_card(8001).to_dict()))
\tr827_w.state.hand.append(CardData.from_dict(r793_cards.get_card(8001).to_dict()))
\tvar r827_w1 := r827_w.play_from_hand(0, Vector2i(5, 0))
\tvar r827_w2 := r827_w.play_from_hand(0, Vector2i(5, 1))
\tvar r827_e1 := r827_w.state.place(
\t\t\tCardData.from_dict(r793_cards.get_card(1011).to_dict()),
\t\t\tVector2i(4, 0), GameEngine.SIDE_OPPONENT)
\tvar r827_e2 := r827_w.state.place(
\t\t\tCardData.from_dict(r793_cards.get_card(1011).to_dict()),
\t\t\tVector2i(4, 1), GameEngine.SIDE_OPPONENT)
\tcheck(r827_w1 != null and r827_w2 != null and r827_e1 != null and r827_e2 != null,
\t\t\t"R827 刺墙一回合一次：两个工事与两个攻击者就位")
\tvar r827_e1hp0: int = r827_e1.health
\tvar r827_e2hp0: int = r827_e2.health
\tr827_w.attack(Vector2i(4, 0), Vector2i(5, 0), GameEngine.SIDE_OPPONENT)
\tr827_w.attack(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
\tcheck(r827_e1.health == r827_e1hp0 - 5 and r827_e2.health == r827_e2hp0,
\t\t\t"R827 刺墙一回合一次：同回合两刀只反第一刀（%d/%d）" % [
\t\t\t\tr827_e1.health, r827_e2.health])
\tr827_w.turn_number += 1
\tr827_w.state.hand.clear()
\tr827_w.state.hand.append(CardData.from_dict(r793_cards.get_card(8001).to_dict()))
\tvar r827_w3 := r827_w.play_from_hand(0, Vector2i(5, 2))
\tvar r827_e3 := r827_w.state.place(
\t\t\tCardData.from_dict(r793_cards.get_card(1011).to_dict()),
\t\t\tVector2i(4, 2), GameEngine.SIDE_OPPONENT)
\tvar r827_e3hp0: int = r827_e3.health
\tr827_w.attack(Vector2i(4, 2), Vector2i(5, 2), GameEngine.SIDE_OPPONENT)
\tcheck(r827_e3.health == r827_e3hp0 - 5,
\t\t\t"R827 刺墙一回合一次：换回合后额度恢复（%d → %d）" % [r827_e3hp0, r827_e3.health])"""

rep('"R793 刺墙：攻击工事 → 攻击者 -5（%d → %d）" % [r793_foe_hp0, r793_foe.health])\n\n\t# ③ 刺墙只认工事',
    '"R793 刺墙：攻击工事 → 攻击者 -5（%d → %d）" % [r793_foe_hp0, r793_foe.health])\n\n' + r793_block + '\n\t# ③ 刺墙只认工事')

# R796 刺墙扩面：工事反过后同回合 HP 直击不反（共享额度）
r796_block = """\t# ②b 刺墙一回合一次（R827）：工事反过之后，同回合直击 HP 不再反（共享额度）
\tRunState.relics = [6073]
\tvar r827_sh := _new_engine([], 40, 40)
\tr827_sh.state.energy = 30
\tr827_sh.state.hand.clear()
\tr827_sh.state.hand.append(CardData.from_dict(r796_cards.get_card(8001).to_dict()))
\tvar r827_shw := r827_sh.play_from_hand(0, Vector2i(5, 0))
\tvar r827_she1 := r827_sh.state.place(
\t\t\tCardData.from_dict(r796_cards.get_card(1011).to_dict()),
\t\t\tVector2i(4, 0), GameEngine.SIDE_OPPONENT)
\tvar r827_she2 := r827_sh.state.place(
\t\t\tCardData.from_dict(r796_cards.get_card(1011).to_dict()),
\t\t\tVector2i(4, 1), GameEngine.SIDE_OPPONENT)
\tvar r827_she1hp0: int = r827_she1.health
\tvar r827_she2hp0: int = r827_she2.health
\tr827_sh.attack(Vector2i(4, 0), Vector2i(5, 0), GameEngine.SIDE_OPPONENT)
\tr827_sh.attack_hp(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
\tcheck(r827_she1.health == r827_she1hp0 - 5 and r827_she2.health == r827_she2hp0,
\t\t\t"R827 刺墙一回合一次：工事反过后同回合 HP 直击不反（共享额度 %d/%d）" % [
\t\t\t\tr827_she1.health, r827_she2.health])"""

rep('"R796 刺墙扩面：直击 HP → 攻击者 -5（%d → %d）" % [r796_foe_hp0, r796_foe.health])\n\n\t# ③ 不持道具时直击 HP 不反伤',
    '"R796 刺墙扩面：直击 HP → 攻击者 -5（%d → %d）" % [r796_foe_hp0, r796_foe.health])\n\n' + r796_block + '\n\t# ③ 不持道具时直击 HP 不反伤')

s = s.replace("\n", "\r\n")

with open(P, "wb") as f:
    f.write(s.encode("utf-8"))

print("DONE: CRLF=%d" % s.count("\r\n"))
