import io

P = 'scripts/battle_scene.gd'
t = open(P, 'rb').read().decode('utf-8')

NEW = '''func _draw_hand_bonus_mark(r: Rect2) -> void:
	## 手卡「额外效果可触发」的金色标记（判定在 `engine.hand_bonus_ready`，这里只管画）。
	## R783（店长口径「效果生效的框比较粗糙」）：旧版是一圈 2.2k 纯金**直角**粗线 + 0.20
	## 平涂，贴在圆角卡面上像绕了一圈黄胶带。改了两版才收住：
	##   · 圆角化之后发现"一个颜色一根线"永远像塑料 —— 金属感靠的是**明暗台阶**；
	##   · 金环还必须**离开卡边**，卡面自带金漆边，贴上去两条金会糊成一条。
	## 现在的画法（由外向内）：
	##   ① 外侧发丝线（与主环之间留 ~2.6k 的缝 → 双线）
	##   ② 主环四层叠出圆管的明暗：暗边 → 金身 → 亮芯 → 高光
	##   ③ 四角各一段更亮的短弧（角部聚光），是最见精致的一笔
	##   ④ 慢呼吸：金色分量的 alpha 随 sin 轻微起伏，读作"生效中"而非静态贴纸
	## 金星徽章画在最外层，压住右上角。
	var k := r.size.y / CardFace.CARD_H_DESIGN
	var col := COL_HAND_BONUS
	var breath := 0.5 + 0.5 * sin(float(_now()) / 1000.0 * 2.2)
	var cr := 7.0 * k
	var ring := r.grow(2.4 * k)
	# ① 外侧发丝线（细、淡，只负责"这圈不是贴纸"）
	_round_frame(r.grow(5.0 * k), cr + 2.2 * k,
			Color(col.r, col.g, col.b, 0.34 + 0.22 * breath), 0.8 * k)
	# ② 主环：四层同心地叠出金属圆管的明暗
	_round_frame(ring, cr, Color(0.34, 0.22, 0.03, 0.92), 3.3 * k)
	_round_frame(ring, cr, Color(0.78, 0.55, 0.10, 0.96), 2.2 * k)
	_round_frame(ring, cr, Color(col.r, col.g, col.b, 0.98), 1.2 * k)
	_round_frame(ring, cr, Color(1.0, 0.94, 0.74, 0.30 + 0.30 * breath), 0.45 * k)
	# ③ 环内暖光：整体极淡（0.04）—— 卡面被"照亮"一点点，但不糊住画面
	draw_rect(ring, Color(col.r, col.g, col.b, 0.030 + 0.025 * breath), true)
	# ④ 四角聚光：只点亮角尖那一小段，比整圈加亮更"收"
	var hot := Color(1.0, 0.97, 0.82, 0.55 + 0.32 * breath)
	draw_arc(Vector2(ring.position.x + cr, ring.position.y + cr), cr, PI * 1.10, PI * 1.40, 8,
			hot, 2.0 * k, true)
	draw_arc(Vector2(ring.end.x - cr, ring.position.y + cr), cr, PI * 1.60, PI * 1.90, 8,
			hot, 2.0 * k, true)
	draw_arc(Vector2(ring.end.x - cr, ring.end.y - cr), cr, PI * 0.10, PI * 0.40, 8,
			hot, 2.0 * k, true)
	draw_arc(Vector2(ring.position.x + cr, ring.end.y - cr), cr, PI * 0.60, PI * 0.90, 8,
			hot, 2.0 * k, true)
	# ⑤ 右上金星：双环 + 光晕，压在环角上（读作"盖章"）
	var star := r.position + Vector2(r.size.x + 0.4 * k, 2.0 * k)
	var sr := 7.0 * k
	draw_circle(star, sr * 1.45, Color(col.r, col.g, col.b, 0.10 + 0.07 * breath))
	draw_circle(star, sr, Color(0.09, 0.08, 0.11, 0.96))
	draw_arc(star, sr, 0, TAU, 24, Color(0.78, 0.55, 0.10, 0.98), 2.0 * k, true)
	draw_arc(star, sr - 1.1 * k, 0, TAU, 24,
			Color(col.r, col.g, col.b, 0.90), 1.0 * k, true)
	_draw_string_center(_font_bold, int(9 * k), "\u2605", star, col, -1)

'''

s = t.index('func _draw_hand_bonus_mark(r: Rect2) -> void:')
e = t.index('func _draw_drag() -> void:')
assert s < e
NEW = NEW.replace('\n', '\r\n')
t = t[:s] + NEW + t[e:]
open(P, 'wb').write(t.encode('utf-8'))
b = open(P, 'rb').read()
print('OK CRLF', b.count(b'\r\n'), 'bare', b.count(b'\n') - b.count(b'\r\n'))
