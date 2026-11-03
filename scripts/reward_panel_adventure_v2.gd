extends "res://scripts/reward_panel.gd"
## Additive adventure variant. Original RewardPanel and layered assets remain intact.

func _layer_image(key: String, rect: Rect2) -> void:
	var name := "reward_adventure_v2/" + key
	var tex := UiAssets.get_tex(name)
	if tex == null:
		tex = UiAssets.get_tex("reward_layered/" + key)
	if tex == null:
		return
	_root.draw_texture_rect(tex, rect, false)


func _draw_reward_heading(pr: Rect2) -> void:
	# The generated plaque includes transparent margins; center against its visible body.
	var rr := Rect2(pr.position.x - 18, pr.position.y - 54, 340, 104)
	_layer_image("01", rr)
	var fs := 30
	var body := Rect2(rr.position + Vector2(rr.size.x * 0.34, rr.size.y * 0.24), Vector2(rr.size.x * 0.60, rr.size.y * 0.47))
	var baseline := body.get_center().y + (_font_bold.get_ascent(fs) - _font_bold.get_descent(fs)) * 0.5
	_root.draw_string(_font_bold, Vector2(body.position.x, baseline), "卡牌奖励", HORIZONTAL_ALIGNMENT_CENTER, body.size.x, fs, Color("f1ddb1"))


func _draw_card_detail(cands: Array) -> void:
	## R502：按店长的 GPT 参考稿重排 —— 奶油圆角详情盒、左侧棕色卡名题签、
	## 右侧青色「效果」胶囊。信息口径不变：编号 / 种类 / 费用 / 稀有度 / 数值 /
	## 完整效果与提及命中全部保留；悬停优先，触屏读已点选。
	var idx := _hover_card if _hover_card >= 0 else _pick_sel
	if idx < 0 or idx >= cands.size():
		return
	var card: CardData = _repo_cards.get_card(int(cands[idx]))
	if card == null:
		return
	var pr2 := _cards_panel_rect()
	var bw := minf(880.0, pr2.size.x - 120.0)
	var bx := pr2.get_center().x - bw / 2.0
	var top := _cards_y() + CARD_H + 40.0       # 让开卡下的稀有度胶囊
	var pad := 12.0
	var col_w := 194.0
	var ex := bx + pad + col_w + 28.0
	var ew := bx + bw - pad - ex
	var bg := REWARD_DETAIL
	var ink := Color("465a54")
	var stats := CardFace.stats_line(card)
	var segs := CardText.parse(card.effect_text)
	var stat_lines := 0
	if stats != "":
		stat_lines = CardFace.wrap_text(_font, stats, col_w, UiTheme.FS_CAPTION).size()
	var eff_lines: int = CardText.wrap_segments(_font, _font_bold, segs, ew, 13).size()
	var right_h := 48.0 + float(eff_lines) * 19.0
	var left_h := 64.0 + float(stat_lines) * 17.0
	var avail := _btn_confirm_rect().position.y - top - 16.0         # 下方胶囊按钮与留白
	var box_h := clampf(maxf(left_h, right_h) + pad, minf(128.0, avail), minf(DETAIL_STRIP_H, avail))
	var box := Rect2(bx, top, bw, box_h)
	_layer_image("08", box)
	var sx := bx + pad + col_w + 12.0
	_root.draw_line(Vector2(sx, box.position.y + 14.0),
			Vector2(sx, box.end.y - 14.0), Color(0.35, 0.30, 0.20, 0.22), 1.0, true)
	# 左栏：棕色斜切题签 + 元信息 + 数值。
	var lx := bx + pad
	var name_w := clampf(_font_bold.get_string_size(card.card_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_SUBHEAD).x + 42.0, 126.0, col_w)
	var ny := box.position.y + 10.0
	_root.draw_string(_font_bold, Vector2(lx, ny + 22.0), card.card_name,
			HORIZONTAL_ALIGNMENT_CENTER, name_w - 12.0, UiTheme.FS_SUBHEAD, REWARD_TEXT)
	var ly := ny + 44.0
	_root.draw_string(_font, Vector2(lx, ly),
			"#%d  %s · %d 费 · %s" % [card.id, card.kind, card.cost, card.rarity_name()],
			HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_CAPTION, UiTheme.INK_600)
	ly += 19.0
	if stats != "":
		for t: String in CardFace.wrap_text(_font, stats, col_w, UiTheme.FS_CAPTION):
			_root.draw_string(_font, Vector2(lx, ly), t,
					HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_CAPTION, UiTheme.INK_600)
			ly += 17.0
	# 右栏：青色标签 + 效果全文（提及仍由 CardText 统一上色与命中）。
	_round_box(Rect2(ex, box.position.y + 11.0, 64.0, 22.0), 11.0,
			Color("4a5672"), Color(0, 0, 0, 0), false)
	_root.draw_string(_font_bold, Vector2(ex, box.position.y + 27.0), "效果",
			HORIZONTAL_ALIGNMENT_CENTER, 64.0, UiTheme.FS_CAPTION, Color("ffffff"))
	var res := CardText.draw_wrapped_hits(_root, _font, _font_bold, segs, ex,
			box.position.y + 51.0, ew, 13, 19.0, ink, box.end.y - pad, -1.0, bg)
	_mention_hits = res["hits"]


