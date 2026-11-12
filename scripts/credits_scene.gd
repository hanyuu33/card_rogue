extends Control
## 鸣谢页（R576）—— 纯黑底滚动字（电影式结尾字幕）。
## 入口：标题页「鸣谢」按钮。点击 / 任意键跳过，滚完自动回标题。
##
## 音乐署名来自 `assets/audio/credits.md`（PeriTune · CC BY 4.0，**必须署名**，
## 这里就是游戏内的署名载体）。新增 BGM 后记得同步更新 CREDITS_TEXT 的曲目列表。
##
## R605「素材说明」：Steam **不要求**在游戏内标注 AI 生成内容，平台只强制 Steamworks
## 后台的内容调查表（生成式 AI 部分），再由 Valve 展示到商店页。这里主动写明属于加分项：
## 被截图质疑时不必临时补解释，也不需要玩家去商店页翻。措辞保持「部分素材 / 辅助生成」，
## 与实际情况一致（AI 出图 + 人工筛选、切图、排版），不要改成「全部由 AI 生成」。

const UiTheme = preload("res://scripts/ui_theme.gd")

## 每秒上移像素（电影式字幕的舒缓节奏）。
const SCROLL_SPEED := 44.0

## 鸣谢正文（BBCode）。[center] 居中，[font_size] / [color] 分层级。
## R578：抬头用 `{name}` 占位，由 `credits_text()` 从 GameBrand 注入 —— 改名不用改这里。
const CREDITS_TEXT := """[center]
[font_size=58][color=#ffffff]{name}[/color][/font_size]


[font_size=26][color=#9a9a9a]开发[/color][/font_size]
[font_size=32][color=#ffffff]栗鼠大怪兽[/color][/font_size]


[font_size=26][color=#9a9a9a]引擎[/color][/font_size]
[font_size=32][color=#ffffff]Godot 4.3[/color][/font_size]


[font_size=26][color=#9a9a9a]音乐 · PeriTune（CC BY 4.0）[/color][/font_size]
[font_size=24][color=#c8c8c8]Holy_Place
Piano_Refreshing
Poema
Strategy4
Dramatic
EpicBattle
Raid_FolkMetal
Firmament3
Soaring
Rapid4
Havoc[/color][/font_size]

[font_size=20][color=#888888]https://peritune.com/
License: Creative Commons CC BY 4.0
https://creativecommons.org/licenses/by/4.0[/color][/font_size]


[font_size=26][color=#9a9a9a]素材说明[/color][/font_size]
[font_size=22][color=#c8c8c8]本作部分美术素材使用 AI 工具辅助生成[/color][/font_size]


[font_size=26][color=#9a9a9a]特别鸣谢[/color][/font_size]
[font_size=24][color=#c8c8c8]每一位测试与反馈的伙伴[/color][/font_size]


[font_size=32][color=#ffffff]感谢游玩[/color][/font_size]
[/center]"""


static func credits_text() -> String:
	## 把 `{name}` 换成当前游戏名（唯一来源 = GameBrand）。
	return CREDITS_TEXT.replace("{name}", GameBrand.display_name())


var _label: RichTextLabel
var _done := false


func _ready() -> void:
	# 纯黑底：背景在 _draw 里铺满，不挂 UiTheme.attach_stage（那套是羊皮纸舞台风格）。
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.text = credits_text()
	_label.fit_content = true
	_label.scroll_active = false
	_label.add_theme_font_override("normal_font", UiTheme.font())
	_label.add_theme_font_override("bold_font", UiTheme.font())
	_label.add_theme_font_override("italics_font", UiTheme.font())
	_label.add_theme_font_override("bold_italics_font", UiTheme.font())
	_label.custom_minimum_size = Vector2(size.x, 0)
	add_child(_label)
	# 初始停在屏幕底边之外；等一帧让 fit_content 算出真实高度再定位。
	_label.position = Vector2(0, size.y)
	await get_tree().process_frame
	_label.position = Vector2(0, size.y)
	Bgm.play("title")
	# 命令行 -- --screenshot：出图验收用（滚到中段再截，能看到正文）。
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 2.0
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_credits.png"))
			get_tree().quit())
		add_child(t)
		t.start()


func _process(delta: float) -> void:
	if _done:
		return
	_label.position.y -= SCROLL_SPEED * delta
	# 整块文本滚出屏幕顶部 → 自动回标题。
	if _label.position.y + _label.size.y < -24.0:
		_back()


func _input(event: InputEvent) -> void:
	# 点击 / 任意键跳过（echo 不算，避免按住连发）。
	if _done:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_back()
	elif event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		_back()


func _back() -> void:
	if _done:
		return
	_done = true
	SceneFx.goto("res://scenes/title.tscn")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
