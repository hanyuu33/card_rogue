extends SceneTree
## R605 鸣谢页验收：定格「素材说明」那一段并截图。
##
## 为什么不能直接跑 scenes/credits.tscn 的 --screenshot：那套是等 2 秒截屏，
## 44px/s 只滚到 88px，看到的永远是开头几行。这里把 _done 置真停掉滚动，
## 再按 RichTextLabel 的行偏移把目标行顶到画面 1/5 处。

const W := 1280
const H := 800
const KEY := "素材说明"

var _node: Control


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var win := root as Window
	win.size = Vector2i(W, H)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var ps := load("res://scenes/credits.tscn") as PackedScene
	_node = ps.instantiate() as Control
	win.add_child(_node)
	await process_frame
	await process_frame

	_node.size = Vector2(W, H)
	var label := _node.get("_label") as RichTextLabel
	if label == null:
		print("ERR 找不到 _label")
		quit(1)
		return

	# 停掉滚动：_process 看到 _done 直接返回。
	_node.set("_done", true)

	var line_y := _find_line_y(label, KEY)
	print("lines=%d  content=%.1f  %s 行顶=%.1f"
			% [label.get_line_count(), label.get_content_height(), KEY, line_y])

	# 目标行落在画面 20% 处，下面正好露出特别鸣谢与「感谢游玩」。
	label.position = Vector2(0, H * 0.20 - line_y)
	await process_frame
	await process_frame

	var img := win.get_texture().get_image()
	img.save_png("res://_review/r605_credits_ai.png")
	print("SHOT ok")
	quit(0)


## 关键词所在段落的纵坐标（相对文本顶部）。
## RichTextLabel 没有 get_line_text，但给了 get_parsed_text + get_character_paragraph。
func _find_line_y(label: RichTextLabel, key: String) -> float:
	var plain := label.get_parsed_text()
	var idx := plain.find(key)
	if idx < 0:
		print("WARN 没找到关键词，退回 0")
		return 0.0
	var p := label.get_character_paragraph(idx)
	return float(label.get_paragraph_offset(p))
