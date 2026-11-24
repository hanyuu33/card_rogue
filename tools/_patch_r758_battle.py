# -*- coding: utf-8 -*-
"""R758 battle_scene：常数测量员的计量特效（复用 primal 队列）+ 三个动作的播报。"""
import io

P = "e:/work/card_rogue/scripts/battle_scene.gd"
raw = io.open(P, "r", encoding="utf-8", newline="").read()
assert "\r\n" in raw


def rep(old, new, why):
    global raw
    o = old.replace("\n", "\r\n")
    n = new.replace("\n", "\r\n")
    c = raw.count(o)
    assert c == 1, "%s：命中 %d" % (why, c)
    raw = raw.replace(o, n)
    print("ok:", why)


# ---------------- ① 贴图变量 ----------------
rep(
    'var _primal_tex_fire: Texture2D = preload("res://assets/fx/fx_primal_fire.png")\n',
    '''var _primal_tex_fire: Texture2D = preload("res://assets/fx/fx_primal_fire.png")
## R758：常数测量员（9253）的「计量」贴图 —— 金色刻度环，与土 / 火同尺寸同用法。
var _primal_tex_survey: Texture2D = preload("res://assets/fx/fx_survey_beam.png")
''',
    "贴图变量",
)

# ---------------- ② 分段投射按 source 选贴图 ----------------
rep(
    '''	var fire := str(f.source) == "火元素"
	var tex := _primal_tex_fire if fire else _primal_tex_earth
''',
    '''	var src_name := str(f.source)
	var fire := src_name == "火元素"
	# R758：常数测量员走第三张图（金色刻度环）—— 与土 / 火共用同一条分段投射通道，
	# 只在「画哪张图 / 落地圈怎么转」上分开，不另起一套动画（否则三段时序要各写一遍）。
	var survey := src_name == GameEngine.SURVEYOR_NAME
	var tex := _primal_tex_earth
	if fire:
		tex = _primal_tex_fire
	elif survey:
		tex = _primal_tex_survey
''',
    "选贴图",
)

# ---------------- ③ 飞行圈的区分（测量员：双弧、顺时针扫） ----------------
rep(
    '''		pos.y -= sin(t * PI) * (45.0 if fire else 12.0)
		draw_arc(dst, 28.0, 0, TAU, 32, Color(1, 0.7, 0.3, 0.6), 2.0)
		draw_texture_rect(tex, Rect2(pos - Vector2(30, 38), Vector2(60, 60)), false)
''',
    '''		pos.y -= sin(t * PI) * (45.0 if fire else 12.0)
		if survey:
			# 「计量」的读法：一圈扫过去的表盘 —— 起始角随时间转，玩家看得出它在「读」。
			var spin := float(n - int(f.start)) * 0.008
			draw_arc(dst, 30.0, spin, spin + TAU * 0.72, 28,
					Color(1.0, 0.85, 0.45, 0.65), 2.0)
			draw_arc(dst, 20.0, - spin * 1.6, - spin * 1.6 + TAU * 0.5, 20,
					Color(1.0, 0.92, 0.62, 0.45), 1.5)
		else:
			draw_arc(dst, 28.0, 0, TAU, 32, Color(1, 0.7, 0.3, 0.6), 2.0)
		draw_texture_rect(tex, Rect2(pos - Vector2(30, 38), Vector2(60, 60)), false)
''',
    "飞行圈",
)

# ---------------- ④ 落地飘字：把常数测量员加进白名单 ----------------
rep(
    '''	if kind == "fx_impact" and _primal_landing and str(data.get("source", "")) in ["土元素", "火元素"]:
		var cell: Vector2i = data.cell
		var col := Color("ff742a") if str(data.source) == "火元素" else Color("dba14b")
''',
    '''	if kind == "fx_impact" and _primal_landing and str(data.get("source", "")) in [
			"土元素", "火元素", GameEngine.SURVEYOR_NAME]:
		var cell: Vector2i = data.cell
		var pi_src := str(data.source)
		var col := Color("dba14b")
		if pi_src == "火元素":
			col = Color("ff742a")
		elif pi_src == GameEngine.SURVEYOR_NAME:
			col = Color("f0c860")   # 计量金：比土元素的土黄更亮一档，一眼分得开
''',
    "落地飘字",
)

# ---------------- ⑤ 三个动作的播报 ----------------
rep(
    '''		"cannon_fire":
''',
    '''		"survey_beam":
			# R758 常数测量员（9253）：一发「分配 16 点」的计量。
			# 伤害本体的逐段投射由上面那套 `_primal_fx` 演（与土元素同一个队列、同一条时序），
			# 这里只播报 + 音效 + 轻微震屏 —— 不再另画一根光柱，否则会和分段投射叠成两层。
			var sb_total := int(data.get("total", 0))
			var sb_hits := int(data.get("hits", 0))
			var sb_spill := int(data.get("spilled", 0))
			var sb_stun := bool(data.get("stun", false))
			sfx.play("spell")
			_shake(1.6, 140)
			var sb_msg := "📏 常数测量员：分配 %d 点伤害" % sb_total
			if sb_hits > 0:
				sb_msg += "（%d 个目标）" % sb_hits
			if sb_spill > 0:
				sb_msg += "，溢出 %d 点打到 HP" % sb_spill
			else:
				sb_msg += "，全部被场上单位吃下"
			if sb_stun:
				sb_msg += " → 没打到 HP，自己眩晕一回合"
			_say(sb_msg)
			queue_redraw()
		"compute_cap":
			# R758 精密计算者（9254）：把刚入场的那个单位压到 15 血。
			# 飘字写「30 → 15」而不是「-15」，因为这不是一次伤害（不减护盾、不触发受击反应）。
			var cc_cell: Vector2i = data.get("cell", Vector2i(0, 0))
			var cc_from := int(data.get("from", 0))
			var cc_to := int(data.get("to", 0))
			var cc_name := "一个单位"
			if data.get("card") is CardData:
				cc_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": _cell_center(cc_cell) + Vector2(0, -32),
				"sc": _grid_scroll, "text": "%d → %d" % [cc_from, cc_to],
				"col": Color("7fd3ff"), "start": n, "dur": 1500})
			_say("🧮 精密计算者：%s 入场生命 %d → %d" % [cc_name, cc_from, cc_to])
			queue_redraw()
		"deck_gift":
			# R758 负载增量员（9255）：往**抽牌库**塞真卡（不是诅咒）。
			# 与 `curse_added` 的区别：那边有整屏卡面展示队列（诅咒值得看清楚），
			# 这里只写一句播报 + 牌库张数自己跳 —— 每回合两张，排队展示会把节奏拖烂。
			var dg_name := "一张卡"
			if data.get("card") is CardData:
				dg_name = (data["card"] as CardData).card_name
			var dg_deck := int(data.get("deck", -1))
			if dg_deck >= 0:
				_say("📦 负载增量员：一张「%s」塞进你的抽牌库（牌库 %d 张）" % [dg_name, dg_deck])
			else:
				_say("📦 负载增量员：往对方抽牌库塞了一张「%s」" % dg_name)
			sfx.play("place")
			queue_redraw()
		"cannon_fire":
''',
    "三个动作播报",
)

io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("written")
