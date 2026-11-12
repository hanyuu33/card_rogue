extends SceneTree
## R604 片头动画验收：在若干时间点定格开场并各存一张，事后拼成对照图。
##
## 为什么不用「跑一遍再录」：opening_scene 到 4.7 秒就 change_scene 了，
## 录到的是一串连拍，挑帧全靠运气。这里禁掉它的 _process，手动拨 _t 再同步一次，
## 于是每个时间点都是确定的、可复现的。

const W := 640
const H := 400
const SHOTS := [0.42, 0.72, 1.05, 1.40, 1.85, 2.40]

var _node: Control


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var win := root as Window
	win.size = Vector2i(W, H)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var ps := load("res://scenes/opening.tscn") as PackedScene
	_node = ps.instantiate() as Control
	win.add_child(_node)
	await process_frame

	_node.set_process(false)
	_node.size = Vector2(W, H)

	var i := 0
	for t in SHOTS:
		_node.set("_t", float(t))
		_node.call("_sync_mark")
		_node.call("queue_redraw")
		await process_frame
		await process_frame
		var img := win.get_texture().get_image()
		img.save_png("res://_review/r604_f%d.png" % i)
		print("SHOT %d  t=%.2f" % [i, t])
		i += 1
	quit(0)
