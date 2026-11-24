import io, sys

P = 'scripts/battle_scene.gd'
t = open(P, 'rb').read().decode('utf-8')

NEW = '''func _draw_hand_bonus_mark(r: Rect2) -> void:
	## 手卡「额外效果可触发」的金色标记（判定在 `engine.hand_bonus_ready`，这里只管画）。
	## R783（店长口径「效果生效的框比较粗糙」）：旧版是一圈 2.2k 纯金**直角**粗线 + 0.20
	## 平涂，贴在圆角卡面上像绕了一圈黄胶带。第一次改圆角双线仍嫌"厚" —— 卡面自己就是
	## 金漆边，金环贴着画会跟它糊成一条。所以现在改成**悬浮**双线金环：
	##   ① 环整体外扩 2.6k，与卡边之间留一条缝（缝里补极淡暖光 = 光从卡边渗出来）
	##   ② 由外向内三层：暗色压边（把卡从背景里拎出来）→ 外侧发丝线 → 主金环
	##   ③ 四角各一段加亮短弧（角部聚光），是最见精致的一笔
	##   ④ 慢呼吸：金色分量的 alpha 随 sin 轻微起伏，读作"生效中"而非静态贴纸
	## 金星徽章画在最外层，压住右上角。
	var k := r.size.y / CardFace.CARD_H_DESIGN
	var col := COL_HAND_BONUS
	var breath := 0.5 + 0.5 * sin(float(_now()) / 1000.0 * 2.2)
	var cr := 7.0 * k
	# ① 暗色压边：金色落在浅色木地板 / 亮水面上才有对比
	_round_frame(r.grow(6.2 * k), cr + 3.2 * k, Color(0.05, 0.04, 0.02, 0.55), 2.0 * k)
	# ② 外侧发丝线（与主环之间留 ~1.8k 的缝 → 双线）
	_round_frame(r.grow(4.4 * k), cr + 1.6 * k,
			Color(col.r, col.g, col.b, 0.46 + 0.26 * breath), 1.0 * k)
	# ③ 主金环
	_round_frame(r.grow(2.6 * k), cr, Color(col.r, col.g, col.b, 0.96), 1.7 * k)
	# ④ 环内暖光：整体极淡（0.05）—— 卡面被"照亮"一点点，但不糊住画面
	draw_rect(r.grow(2.6 * k), Color(col.r, col.g, col.b, 0.045 + 0.035 * breath), true)
	# ⑤ 四角聚光：每角一小段更亮的弧，比整圈加亮更"收"
	var hot := Color(1.0, minf(1.0, col.g + 0.10), minf(1.0, col.b + 0.16),
			0.52 + 0.36 * breath)
	var ring := r.grow(2.6 * k)
	var hr := cr
	draw_arc(Vector2(ring.position.x + cr, ring.position.y + cr), hr, PI * 1.07, PI * 1.43, 8,
			hot, 2.1 * k, true)
	draw_arc(Vector2(ring.end.x - cr, ring.position.y + cr), hr, PI * 1.57, PI * 1.93, 8,
			hot, 2.1 * k, true)
	draw_arc(Vector2(ring.end.x - cr, ring.end.y - cr), hr, PI * 0.07, PI * 0.43, 8,
			hot, 2.1 * k, true)
	draw_arc(Vector2(ring.position.x + cr, ring.end.y - cr), hr, PI * 0.57, PI * 0.93, 8,
			hot, 2.1 * k, true)
	# ⑥ 右上金星：双环 + 光晕，压在环的右上角上（读作"盖章"）
	var star := r.position + Vector2(r.size.x + 0.6 * k, 2.2 * k)
	var sr := 7.0 * k
	draw_circle(star, sr * 1.45, Color(col.r, col.g, col.b, 0.10 + 0.07 * breath))
	draw_circle(star, sr, Color(0.09, 0.08, 0.11, 0.96))
	draw_arc(star, sr, 0, TAU, 24, Color(col.r, col.g, col.b, 0.95), 1.5 * k, true)
	draw_arc(star, sr * 1.18, 0, TAU, 24,
			Color(col.r, col.g, col.b, 0.22 + 0.18 * breath), 0.9 * k, true)
	_draw_string_center(_font_bold, int(9 * k), "\u2605", star, col, -1)

'''

s = t.index('func _draw_hand_bonus_mark(r: Rect2) -> void:')
e = t.index('func _draw_drag() -> void:')
assert s < e
t = t[:s] + NEW + t[e:]

# 去掉出图分支里的临时探针
t = t.replace('\t\tprint("[HB] entered, hand=", engine.state.hand.size())\t\t# ', '\t\t# ')
t = t.replace('\t\tprint("[HB] after, hand=", engine.state.hand.size(), " first=", engine.state.hand[0].card_name)\r\n', '')
t = t.replace('\t\tprint("[HB] after, hand=", engine.state.hand.size(), " first=", engine.state.hand[0].card_name)\n', '')

assert '[HB]' not in t, 'probe left'
open(P, 'wb').write(t.encode('utf-8'))
print('OK')
