import io

P = 'scripts/battle_scene.gd'
raw = open(P, 'rb').read().decode('utf-8')
t = raw.replace('\r\n', '\n')

# ① 把金环挪到卡面**之前**画（卡牌自己的数值徽章压在环上）
A = '\tvar bonus := engine.hand_bonus_ready(card)\n\t_draw_card_face(card, Rect2(r.position - pivot, r.size), card.health, selected, false,\n'
B = ('\tvar bonus := engine.hand_bonus_ready(card)\n'
     '\t# R783b：金环必须画在卡面**之前** —— 卡牌底部的力量 / 生命徽章圆心压在卡框下沿、\n'
     '\t# 一半探到卡外，画在之后再亮的环会横穿它们，把数字盖住（店长口径「框把数字挡住了」）。\n'
     '\tif bonus:\n'
     '\t\t_draw_hand_bonus_mark(Rect2(r.position - pivot, r.size))\n'
     '\t_draw_card_face(card, Rect2(r.position - pivot, r.size), card.health, selected, false,\n')
assert t.count(A) == 1
t = t.replace(A, B, 1)

# ② 卡面之后只剩金星（星徽要压在卡角上）
C = ('\tif bonus:\n'
     '\t\t_draw_hand_bonus_mark(Rect2(r.position - pivot, r.size))\n'
     '\t# R209：')
D = ('\tif bonus:\n'
     '\t\t_draw_hand_bonus_star(Rect2(r.position - pivot, r.size))\n'
     '\t# R209：')
assert t.count(C) == 1
t = t.replace(C, D, 1)

# ③ 把金星那一段从 _draw_hand_bonus_mark 里剪出来，单独立一个函数
i = t.index('\t# ⑤ 右上金星')
j = t.index('func _draw_drag() -> void:')
STAR = '''func _draw_hand_bonus_star(r: Rect2) -> void:
	## 右上角金星（R783b 从 `_draw_hand_bonus_mark` 里拆出来的）。
	## **必须画在卡面之后**：金环让到卡面底下是为了不压住数值徽章，但星徽是"盖章"，
	## 得压在卡角上，所以单独留这一个调用点在 `_draw_card_face` 后面。
	var k := r.size.y / CardFace.CARD_H_DESIGN
	var col := COL_HAND_BONUS
	var breath := 0.5 + 0.5 * sin(float(_now()) / 1000.0 * 2.2)
	var star := r.position + Vector2(r.size.x + 0.4 * k, 2.0 * k)
	var sr := 7.0 * k
	draw_circle(star, sr * 1.45, Color(col.r, col.g, col.b, 0.10 + 0.07 * breath))
	draw_circle(star, sr, Color(0.09, 0.08, 0.11, 0.96))
	draw_arc(star, sr, 0, TAU, 24, Color(0.78, 0.55, 0.10, 0.98), 2.0 * k, true)
	draw_arc(star, sr - 1.1 * k, 0, TAU, 24,
			Color(col.r, col.g, col.b, 0.90), 1.0 * k, true)
	_draw_string_center(_font_bold, int(9 * k), "\u2605", star, col, -1)


'''
t = t[:i] + STAR + t[j:]

# ④ 函数头注释补一句 z 序
E = '	## 金星徽章画在最外层，压住右上角。\n'
F = ('	## ⚠️ 只画**环**，调用点在 `_draw_card_face` **之前** —— 卡牌底部的力量 / 生命徽章\n'
     '	##    圆心压在卡框下沿、一半探到卡外，环画在之后会横穿它们把数字盖掉（R783b）。\n'
     '	##    右上角金星另走 `_draw_hand_bonus_star()`，那个要压在卡面上。\n')
assert t.count(E) == 1
t = t.replace(E, F, 1)

open(P, 'wb').write(t.replace('\n', '\r\n').encode('utf-8'))
b = open(P, 'rb').read()
print('OK CRLF', b.count(b'\r\n'), 'bare', b.count(b'\n') - b.count(b'\r\n'))
