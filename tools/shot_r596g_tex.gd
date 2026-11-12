extends SceneTree
## R596g 卡图纹理质量验收（**不能加 --headless**：dummy 渲染器 get_image() 返回 null）。
##
## 左列 = 原始 PNG（Image.load_from_file 绕过导入系统），右列 = 导入后的纹理。
## 两列同样尺寸同样拉伸渲染，截图后由 `tools/_psnr_r596g.py` 逐像素比对。
## 下面再接两处 2× 放大，供人眼确认。
##
## 跑法：Godot --path . --script res://tools/shot_r596g_tex.gd -- <输出绝对路径>

const CardFaceScript = preload("res://scripts/card_face.gd")

const IDS := [9192, 9193, 1013]
const ZOOM_IDS := [9192, 9193]
const CARD_W := 448.0
const CARD_H := 403.0
const PAD := 24.0
const ROW := 423.0
const ZOOM := 2.0
const ZOOM_W := 400.0
const ZOOM_H := 300.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_path := "res://_review/r596g_tex.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	var zoom_top := PAD + ROW * float(IDS.size()) + 30.0
	root.size = Vector2i(1000, int(zoom_top + ZOOM_H * 2.0 + 12.0 + PAD))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08)
	bg.size = Vector2(1000, 2000)
	root.add_child(bg)

	for i in IDS.size():
		var cid: int = IDS[i]
		var raw_img := Image.load_from_file("res://assets/pics/%d.png" % cid)
		var tex: Texture2D = CardFaceScript.art_for(cid)
		if raw_img == null or tex == null:
			printerr("MISS ", cid, " raw=", raw_img != null, " tex=", tex != null)
			continue
		var y := PAD + ROW * float(i)
		_add(ImageTexture.create_from_image(raw_img), Vector2(PAD, y))
		_add(tex, Vector2(PAD + CARD_W + PAD, y))

	for i in ZOOM_IDS.size():
		var cid: int = ZOOM_IDS[i]
		var raw_img := Image.load_from_file("res://assets/pics/%d.png" % cid)
		var tex: Texture2D = CardFaceScript.art_for(cid)
		if raw_img == null or tex == null:
			continue
		var x := PAD + float(i) * (ZOOM_W + PAD)
		_add_zoom(ImageTexture.create_from_image(raw_img), Vector2(x, zoom_top))
		_add_zoom(tex, Vector2(x, zoom_top + ZOOM_H + 12.0))

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE")
		quit(1)
		return
	var err := img.save_png(out_path)
	print("TEXSHOT ", err, " ", ProjectSettings.globalize_path(out_path), " ", img.get_size())
	quit()


func _add(tex: Texture2D, pos: Vector2) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = pos
	tr.size = Vector2(CARD_W, CARD_H)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(tr)


func _add_zoom(tex: Texture2D, pos: Vector2) -> void:
	var clip := Control.new()
	clip.position = pos
	clip.size = Vector2(ZOOM_W, ZOOM_H)
	clip.clip_contents = true
	root.add_child(clip)
	var big := TextureRect.new()
	big.texture = tex
	big.size = Vector2(CARD_W * ZOOM, CARD_H * ZOOM)
	big.stretch_mode = TextureRect.STRETCH_SCALE
	clip.add_child(big)
