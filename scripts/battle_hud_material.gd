extends RefCounted
## Shared nine-slice material for battle instruments; preserves the painted corners.
const UiAssets = preload("res://scripts/ui_assets.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
static var _style: StyleBoxTexture
static var _frame: StyleBoxTexture
static var _small_frame: StyleBoxTexture

static func draw_frame(canvas: CanvasItem, rect: Rect2, small := false) -> void:
	var style := _small_frame if small else _frame
	if style == null:
		style = StyleBoxTexture.new()
		style.texture = UiAssets.get_tex("adventure_shared/battle_card_trim" if small else "adventure_shared/battle_instrument_panel")
		style.draw_center = false
		style.set_texture_margin_all(5 if small else 12)
		if small:
			_small_frame = style
		else:
			_frame = style
	canvas.draw_style_box(style, rect)

static func draw(canvas: CanvasItem, rect: Rect2) -> void:
	if _style == null:
		var texture := UiAssets.get_tex("adventure_shared/battle_instrument_panel")
		if texture == null:
			UiTheme.draw_info_card(canvas, rect)
			return
		_style = StyleBoxTexture.new()
		_style.texture = texture
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_style.set_texture_margin(side, 12)
			_style.set_expand_margin(side, 0)
		_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		_style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	# Prepared 128 px source keeps the corners at 12 screen pixels.
	canvas.draw_style_box(_style, rect)
