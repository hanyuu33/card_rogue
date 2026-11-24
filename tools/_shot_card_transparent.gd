extends SceneTree
## 真实卡面 → 透明底高清 PNG（供商店页宣传图合成）。
## 用法：Godot --path . --script res://tools/_shot_card_transparent.gd -- --ids 9012,9040
## 输出：art_src/2026-11-21_store_realcard/cards/<id>.png（1280×1544，RGBA 透明底）
## 说明：SubViewport 开 transparent_bg，用真实 CardFace 铺满整卡；
##       卡面羊皮纸 + 职业外框覆盖整个矩形，透明只留在外框外，合成时无需再抠图。
##       record_seen=false，不污染玩家图鉴。

const UiTheme = preload("res://scripts/ui_theme.gd")
const OUT_DIR := "res://art_src/2026-11-21_store_realcard/cards"
const W := 1280
const H := 1544  # 640:772 卡面比例 ×2
const MARGIN := 90  # 透明边距：容纳压左上角、一半露框外的费用圆，避免被 viewport 裁掉


class CardDrawer extends Node2D:
	var card: CardData
	var face: Font
	var bold: Font
	var name_only := false

	func _draw() -> void:
		if card == null:
			return
		CardFace.draw(self, card, Rect2(Vector2(MARGIN, MARGIN), Vector2(W, H)), card.health,
				false, false, face, bold,
				-1, false, false, name_only, 0, -1, -1, false, false)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var ids: Array[int] = [9012, 9040, 9038, 8005, 8074, 9056]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids"):
			ids.clear()
			for s in arg.split("=")[1].split(","):
				ids.append(int(s.strip_edges()))

	var repo := CardRepo.load_json()
	var vp := SubViewport.new()
	vp.size = Vector2i(W + MARGIN * 2, H + MARGIN * 2)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var drawer := CardDrawer.new()
	drawer.face = UiTheme.font()
	drawer.bold = UiTheme.font_bold()
	vp.add_child(drawer)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for id in ids:
		var source: CardData = repo.get_card(id)
		if source == null:
			printerr("MISS card id=", id)
			continue
		drawer.card = CardData.from_dict(source.to_dict())
		drawer.queue_redraw()   # 换卡必须标记重绘，否则 _draw 不重跑、所有截图都画成第一张
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img == null:
			printerr("NO IMAGE id=", id, "（不能加 --headless）")
			quit(1)
			return
		var out: String = OUT_DIR + "/%d.png" % id
		var err := img.save_png(out)
		print("CARD OK ", ProjectSettings.globalize_path(out), " ", img.get_size(), " err=", err)
	quit()
