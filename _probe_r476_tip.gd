extends SceneTree
## R476 只读探针：把 `Mention.draw_tip()` 的道具浮窗（惊奇盒子 6047）单独画进一个
## SubViewport 截图，核验「获得卡牌」那块在共享浮窗里也摆得正。
## 不碰存档、不改任何数据，产出 `_probe_mention_tip.png`（已 gitignore）。

const UiTheme = preload("res://scripts/ui_theme.gd")

var _vp: SubViewport
var _node: Control
var _frames := 0

func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(720, 620)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_node = Control.new()
	_node.size = Vector2(720, 620)
	_vp.add_child(_node)
	_node.draw.connect(_on_draw)
	_node.queue_redraw()
	process_frame.connect(_on_frame)

func _on_draw() -> void:
	var f: Font = UiTheme.font()
	var fb: Font = UiTheme.font_bold()
	_node.draw_rect(Rect2(Vector2.ZERO, Vector2(720, 620)), Color("20242c"), true)
	for pair in [[6047, Vector2(24, 24)], [6030, Vector2(400, 24)], [6032, Vector2(24, 340)]]:
		var ref := {"kind": "relic", "id": int(pair[0])}
		var sz := Mention.tip_size(f, ref)
		Mention.draw_tip(_node, f, fb, ref, pair[1] as Vector2)
		_node.draw_string(f, (pair[1] as Vector2) + Vector2(0, sz.y + 18),
				"%d  tip_size=%s" % [int(pair[0]), str(sz)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8fa0b8"))

func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	var img := _vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_probe_r476_tip.png"))
	print("P saved ", img.get_size())
	quit()
