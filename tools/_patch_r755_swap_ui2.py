# -*- coding: utf-8 -*-
"""R755 第二版微调：
1) `_round_box` 支持自定义描边宽度（悬停时用 2px 才看得出来）；
2) 换装卡加宽（132→148）、图标缩到 44、文字两行居中，卡面提亮对比；
3) 满栏时**不再画**右下角那个已禁用的「工具栏已满」按钮 —— 换装条已经说明了，
   两个一样的红字反而让人以为要点它；
4) 三处重复的「这条是不是待领工具 + 满栏」判据收成一个 `_tool_swap_active()`。
"""
import io

P = "E:/work/card_rogue/scripts/reward_panel.gd"
raw = io.open(P, "r", encoding="utf-8", newline="").read()


def rep(old, new, n=1):
    global raw
    assert raw.count(old) == n, "expect %d, got %d for %r" % (n, raw.count(old), old[:60])
    raw = raw.replace(old, new)


# ---- 1) _round_box 描边宽度可调
rep("""func _round_box(r: Rect2, radius: float, bg: Color, line: Color,
		shadow := true) -> void:
	## 圆角卡片底。StyleBoxFlat 走引擎自己的九宫格，圆角与投影都比手画多边形干净。
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	if line.a > 0.0:
		sb.set_border_width_all(1)
		sb.border_color = line""",
    """func _round_box(r: Rect2, radius: float, bg: Color, line: Color,
		shadow := true, bw := 1) -> void:
	## 圆角卡片底。StyleBoxFlat 走引擎自己的九宫格，圆角与投影都比手画多边形干净。
	## `bw`：描边宽度（R755 加，换装卡悬停时要 2px 才看得出来）。
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	if line.a > 0.0:
		sb.set_border_width_all(bw)
		sb.border_color = line""")

# ---- 2) 卡宽 / 图标尺度
rep("const TOOL_SWAP_W := 132.0\nconst TOOL_SWAP_GAP := 14.0",
    "const TOOL_SWAP_W := 148.0\nconst TOOL_SWAP_GAP := 12.0")

# ---- 3) 判据收敛 + 换装条重画
rep("""	var settled := _settled(e)
	# R695：工具栏 3/3 时这一条领不进去 → 正文要让出底部 TOOL_SWAP_H 给「换一个」栏位。
	var tool_full := (not settled) and str(e.get("kind", "")) == "tool" \\
			and RunState.trap_free_slots() <= 0""",
    """	var settled := _settled(e)
	# R695：工具栏 3/3 时这一条领不进去 → 正文要让出底部 TOOL_SWAP_H 给「换一个」栏位。
	var tool_full := _tool_swap_active(e)""")

rep("""	var claim := _btn_claim_rect()""",
    """	var claim := _btn_claim_rect()
	## R755：满栏时右下那个「工具栏已满」的灰按钮与换装条标题重复，而且看着像可以点
	## —— 干脆不画（点击也一并屏蔽，见 `_on_click`）。""")

rep("""	_draw_btn(claim, (GameI18n.ui("reward", "REWARD_TOOL_FULL_BTN", "工具栏已满") if tool_full
			else GameI18n.ui("reward", "REWARD_CLAIM", "领取")) if not settled
			else GameI18n.ui("reward", "REWARD_SETTLED_BUTTON", "已处理"),
			true, settled or tool_full)""",
    """	if not tool_full:
		_draw_btn(claim, (GameI18n.ui("reward", "REWARD_CLAIM", "领取")) if not settled
				else GameI18n.ui("reward", "REWARD_SETTLED_BUTTON", "已处理"),
				true, settled)""")

# ---- 4) 卡片绘制：图标 44 + 两行文字垂直居中 + 悬停 2px 红边
rep("""		var hot := _mouse_over(sr)
		_round_box(sr, 10.0, Color(1.0, 0.99, 0.95, 0.96) if hot else Color(0.98, 0.96, 0.89, 0.80),
				Color("b03a2e") if hot else Color("d4cbb8"), hot)
		var icon_box := sr.size.y - 12.0
		var tex: Texture2D = UiAssets.trap_icon(old)
		if tex != null:
			_root.draw_texture_rect(tex, Rect2(sr.position + Vector2(6.0, 6.0),
					Vector2(icon_box, icon_box)), false)
		var td: TrapData = TrapRepo.load_json().get_trap(old)
		var nm := td.trap_name if td != null else "工具"
		var nx := sr.position.x + icon_box + 4.0
		var nw := sr.end.x - nx - 8.0
		_root.draw_string(_font_bold, Vector2(nx, sr.position.y + 28.0), nm,
				HORIZONTAL_ALIGNMENT_LEFT, nw, UiTheme.FS_CAPTION, Color("4a3f2e"))
		_root.draw_string(_font, Vector2(nx, sr.position.y + 50.0),
				GameI18n.ui("reward", "REWARD_TOOL_SWAP_TAG", "丢掉它"),
				HORIZONTAL_ALIGNMENT_LEFT, nw, UiTheme.FS_CAPTION,
				Color("b03a2e") if hot else Color(0.55, 0.42, 0.30, 0.80))""",
    """		var hot := _mouse_over(sr)
		_round_box(sr, 10.0, Color(1.0, 0.99, 0.95, 1.0) if hot else Color(0.97, 0.95, 0.88, 0.92),
				Color("b03a2e") if hot else Color("d0bf9c"), hot, 2 if hot else 1)
		var icon_box := 44.0
		var tex: Texture2D = UiAssets.trap_icon(old)
		if tex != null:
			_root.draw_texture_rect(tex, Rect2(sr.position + Vector2(8.0,
					(sr.size.y - icon_box) * 0.5), Vector2(icon_box, icon_box)), false)
		else:
			icon_box = 0.0
		var td: TrapData = TrapRepo.load_json().get_trap(old)
		var nm := td.trap_name if td != null else "工具"
		var nx := sr.position.x + icon_box + 14.0
		var nw := sr.end.x - nx - 8.0
		_root.draw_string(_font_bold, Vector2(nx, sr.position.y + 30.0), nm,
				HORIZONTAL_ALIGNMENT_LEFT, nw, UiTheme.FS_CAPTION, Color("4a3f2e"))
		_root.draw_string(_font, Vector2(nx, sr.position.y + 50.0),
				GameI18n.ui("reward", "REWARD_TOOL_SWAP_TAG", "丢掉它"),
				HORIZONTAL_ALIGNMENT_LEFT, nw, UiTheme.FS_CAPTION,
				Color("b03a2e") if hot else Color(0.55, 0.42, 0.30, 0.85))""")

# ---- 5) 判据唯一口 + 点击屏蔽
rep("""func _tool_swap_block_rect() -> Rect2:""",
    """func _tool_swap_active(e: Dictionary) -> bool:
	## R755：这条是「待领的工具」且工具栏已满 → 详情页走换装条（点旧槽换下 / 取消）。
	## 绘制、绘制闸门、命中三处都读它，别各写一份判据。
	return str(e.get("kind", "")) == "tool" and not _settled(e) \\
			and RunState.trap_free_slots() <= 0


func _tool_swap_block_rect() -> Rect2:""")

rep("""			if _btn_claim_rect().has_point(pos):
				_claim_entry(_sel)
				return
			# R695：工具栏满 → 点旧槽 = 丢掉它并把这条工具领进来（其余情况没有这排栏位）。
			if _sel < RunState.pending_rewards.size():
				var et: Dictionary = RunState.pending_rewards[_sel]
				if str(et.get("kind", "")) == "tool" and not _settled(et) \\
						and RunState.trap_free_slots() <= 0:""",
    """			# R755：满栏时右下角没有「领取」按钮（换了换装条），这一点不做事。
			if _sel < RunState.pending_rewards.size() \\
					and _tool_swap_active(RunState.pending_rewards[_sel]):
				pass
			elif _btn_claim_rect().has_point(pos):
				_claim_entry(_sel)
				return
			# R695：工具栏满 → 点旧槽 = 丢掉它并把这条工具领进来（其余情况没有这排栏位）。
			if _sel < RunState.pending_rewards.size():
				var et: Dictionary = RunState.pending_rewards[_sel]
				if _tool_swap_active(et):""")

io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("ok, crlf=%d lf=%d" % (raw.count("\r\n"), raw.count("\n")))
