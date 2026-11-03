extends Control
const UiTheme = preload("res://scripts/ui_theme.gd")

func label_at(text: String, pos: Vector2, fs := 18) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", UiTheme.PAGE_INK)
	add_child(l)

func button_at(text: String, pos: Vector2, primary := false, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 48)
	b.disabled = disabled
	UiTheme.apply_button(b, primary)
	add_child(b)
	return b

func _ready() -> void:
	RunState.run_active = true
	RunState.hp = 38
	RunState.max_hp = 50
	RunState.gold = 128
	label_at("冒险手记 · 通用界面", Vector2(64, 70), 30)
	label_at("操作按钮", Vector2(64, 128))
	var action := button_at("继续冒险", Vector2(64, 166), true)
	button_at("返回列表", Vector2(292, 166))
	button_at("已领取", Vector2(520, 166), false, true)
	var focused := button_at("查看卡组", Vector2(748, 166))
	focused.grab_focus()
	label_at("页签与工具栏", Vector2(64, 242))
	var x := 64.0
	for text in ["全部卡牌", "森林精魄", "暗影刺客", "机械之心"]:
		var b := Button.new()
		b.text = text
		b.toggle_mode = true
		b.position = Vector2(x, 278)
		b.size = Vector2(150, 34)
		UiTheme.apply_chip(b, false, true)
		b.button_pressed = text == "森林精魄"
		add_child(b)
		x += 170
	label_at("搜索与筛选", Vector2(64, 338))
	var input := LineEdit.new()
	input.placeholder_text = "搜索卡牌或关键词"
	input.position = Vector2(64, 374)
	input.size = Vector2(360, 42)
	add_child(input)
	var select := OptionButton.new()
	select.add_item("费用不限")
	select.add_item("1 费")
	select.add_item("2 费")
	select.position = Vector2(450, 374)
	select.size = Vector2(200, 42)
	add_child(select)
	var progress := ProgressBar.new()
	progress.position = Vector2(686, 382)
	progress.size = Vector2(260, 26)
	progress.value = 72
	add_child(progress)
	label_at("卡牌效果", Vector2(64, 460))
	label_at("每回合开始时恢复 2 点生命。自然之力将伴随你的旅程。", Vector2(88, 512), 16)
	var menu := UiMenu.attach(self, [{"text": "查看地图", "fn": func(): pass}], {"pause": true})
	# Verify the existing pause lifecycle still works under the new theme.
	menu.open()
	assert(get_tree().paused)
	menu.close()
	assert(not get_tree().paused)
	assert(action.get_theme_stylebox("normal") is StyleBoxTexture)
	assert(input.get_theme_stylebox("normal") is StyleBoxFlat)
	if "--screenshot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.6).timeout
		UiToast.toast("已保存 · 冒险手记", 3000)
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-03_shared_adventure_ui/shared_controls.png"))
		get_tree().quit()

func _draw() -> void:
	UiTheme.draw_page(self, Rect2(Vector2.ZERO, size))
	UiTheme.draw_panel_bg(self, Rect2(64, 492, 970, 80))
