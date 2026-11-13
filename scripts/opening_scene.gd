extends Control
## R604 开场：厂牌卡（徽记勾线生长 → 名号逐字浮现 → 金线收束）→ 主界面主视觉淡入 → 交棒标题页。
##
## 为什么自己做而不是用引擎 splash：引擎 splash 只是一张静态图，换不掉「一开窗就跳进标题」
## 的观感。而 Godot 默认会在启动第一帧画自己的 logo（MIT 授权不要求显示，署名保留在鸣谢页），
## 所以 `project.godot` 的 splash 换成 `studio_mark.png`，底色与本文件的 BLACK **同色** ——
## 开机那一帧与这里的黑场接得住，不会闪。
##
## 徽记的「勾线生长」在 shaders/studio_reveal.gdshader 里，本文件只负责喂 progress。
##
## 调试：`--no-opening` 直接进标题页（截图工具用，免得每次多等四秒）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const MARK_SHADER := "res://shaders/studio_reveal.gdshader"

const BLACK := Color(0.06, 0.05, 0.04)
const GOLD := Color("e8c46a")
const INK_SOFT := Color(0.86, 0.80, 0.68)

# ---- 时间轴（秒）。调节奏只动这几个数，别把魔数散进 _draw。----
const M_IN_START := 0.30        # 徽记开始勾线
const M_IN_END := 1.30          # 勾线完成
const RING_AT := 1.04           # 金环自徽记外围扩散
const RING_DUR := 0.46
const NAME_AT := 1.24           # 名号开始浮现
const NAME_STEP := 0.045        # 相邻字母的延迟
const NAME_IN_DUR := 0.32       # 单个字母淡入时长
const RULE_AT := 1.76           # 名号下方金线自中心生长
const RULE_DUR := 0.38
const STUDIO_OUT := 2.30        # 厂牌整体退场
const STUDIO_OUT_END := 2.64
const A_IN_START := 2.70        # 主视觉开始淡入
const A_IN_END := 3.78
const A_OUT_START := 4.32
const A_OUT_END := 4.70
const ZOOM_FROM := 1.055        # 起始略放大，缓慢推回 1.0：只给呼吸，不晃眼
const INPUT_GUARD := 0.35       # 开机点窗口取焦点会送一次点击，这段时间内的输入不算「跳过」

const MARK_D := 176.0           # 徽记边长
const MARK_DROP := 0.055        # 徽记中心相对画面中心上移的比例（给名号留位置）
const MARK_SCALE_FROM := 0.92   # 勾线开始时略小，完成时长到 1.0

var _art: Texture2D
var _mark: Texture2D
var _mark_rect: TextureRect
var _mark_mat: ShaderMaterial
var _t := 0.0
var _leaving := false
var _handed := false


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(GameBrand.window_title())
	if "--no-opening" in OS.get_cmdline_user_args():
		_handoff()
		return
	_art = UiAssets.title_art()
	# 没有主视觉就别演四秒黑屏 —— 标题页那边有文字标题兜底
	if _art == null:
		_handoff()
		return
	_mark = UiAssets.studio_mark()
	if _mark != null:
		_build_mark_node()


func _build_mark_node() -> void:
	## 徽记是位图，要做「逐笔生长」只能过 shader —— 见 studio_reveal.gdshader 顶部说明。
	var sh := load(MARK_SHADER) as Shader
	_mark_mat = ShaderMaterial.new()
	if sh != null:
		_mark_mat.shader = sh
	_mark_rect = TextureRect.new()
	_mark_rect.texture = _mark
	_mark_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark_rect.material = _mark_mat
	add_child(_mark_rect)


func _process(delta: float) -> void:
	if _handed:
		return
	if _t >= A_OUT_END:
		_handoff()
		return
	_t += delta
	_sync_mark()
	queue_redraw()


func _sync_mark() -> void:
	## 徽记节点的位置 / 缩放 / 着色器进度 —— 只有这一处写，别在 _draw 里也画一遍。
	if _mark_rect == null:
		return
	var gone := _t >= STUDIO_OUT_END
	_mark_rect.visible = not gone
	if gone:
		return
	var k := clampf((_t - M_IN_START) / (M_IN_END - M_IN_START), 0.0, 1.0)
	if _mark_mat != null:
		_mark_mat.set_shader_parameter("progress", ease(k, 1.35))
	var s := lerpf(MARK_SCALE_FROM, 1.0, ease(k, 1.6))
	var d := MARK_D * s
	_mark_rect.size = Vector2(d, d)
	_mark_rect.position = Vector2(
			(size.x - d) * 0.5,
			size.y * (0.5 - MARK_DROP) - d * 0.5)
	var fade := 1.0
	if _t >= STUDIO_OUT:
		fade = 1.0 - clampf((_t - STUDIO_OUT) / (STUDIO_OUT_END - STUDIO_OUT), 0.0, 1.0)
	_mark_rect.modulate = Color(1.0, 1.0, 1.0, fade)


func _input(event: InputEvent) -> void:
	if _handed or _leaving or _t < INPUT_GUARD:
		return
	var hit := false
	if event is InputEventKey:
		var k := event as InputEventKey
		hit = k.pressed and not k.echo
	elif event is InputEventMouseButton:
		hit = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		hit = (event as InputEventScreenTouch).pressed
	elif event is InputEventJoypadButton:
		hit = (event as InputEventJoypadButton).pressed
	if not hit:
		return
	_leaving = true
	_t = maxf(_t, A_OUT_START)   # 跳过 = 直接进收尾，不硬切
	get_viewport().set_input_as_handled()


func _handoff() -> void:
	if _handed:
		return
	_handed = true
	get_tree().change_scene_to_file.call_deferred(after_opening_scene())


static func after_opening_scene() -> String:
	## R660：正式版**第一次**打开时，片头之后先选语言，再进首页。
	## 判定在 GameSettings 里（测试版不弹 / 老玩家不打断 / `--force-language-pick` 可出图）。
	if GameSettings.needs_language_pick():
		return "res://scenes/language_pick.tscn"
	return "res://scenes/title.tscn"


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, BLACK)
	# 第二拍：主视觉淡入 + 极缓推近
	if _art != null and _t >= A_IN_START:
		var k := clampf((_t - A_IN_START) / (A_IN_END - A_IN_START), 0.0, 1.0)
		var z := lerpf(ZOOM_FROM, 1.0, ease(k, 0.55))
		var w := size.x * z
		var h := size.y * z
		var r := Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5), Vector2(w, h))
		draw_texture_rect(_art, r, false, Color(1.0, 1.0, 1.0, clampf(k * 1.6, 0.0, 1.0)))
	# 第一拍：厂牌（徽记由子节点画，这里只补金环、名号、金线）
	if _t < STUDIO_OUT_END:
		_draw_studio()
	# 收尾：压回黑场后交接（不叠 SceneFx 的 wipe，免得两段转场打架）
	if _t >= A_OUT_START:
		var a := clampf((_t - A_OUT_START) / (A_OUT_END - A_OUT_START), 0.0, 1.0)
		draw_rect(full, Color(BLACK, a))
	if _t > 1.0 and not _leaving:
		_draw_hint()


func _studio_alpha() -> float:
	var a := 1.0
	if _t >= STUDIO_OUT:
		a = 1.0 - clampf((_t - STUDIO_OUT) / (STUDIO_OUT_END - STUDIO_OUT), 0.0, 1.0)
	return ease(a, 1.8)


func _draw_studio() -> void:
	var a := _studio_alpha()
	if a <= 0.002:
		return
	var cx := size.x * 0.5
	var cy := size.y * (0.5 - MARK_DROP)
	_draw_ring(cx, cy, a)
	_draw_name(cx, cy, a)


func _draw_ring(cx: float, cy: float, a: float) -> void:
	## 勾线完成时，一圈细金环从徽记外缘扩出去后淡掉 —— 给「封缄」感，别做成冲击波。
	if _t < RING_AT:
		return
	var k := clampf((_t - RING_AT) / RING_DUR, 0.0, 1.0)
	var r0 := MARK_D * 0.5
	var r := lerpf(r0, r0 * 1.42, ease(k, 0.7))
	var w := lerpf(1.8, 0.6, k)
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 128, Color(GOLD, a * (1.0 - k) * 0.55), w, true)


func _draw_name(cx: float, cy: float, a: float) -> void:
	## 名号逐字浮现 + 下方金线自中心向两边生长。字距温和拉开，不是双空格那种散。
	if _t < NAME_AT:
		return
	var en := GameBrand.STUDIO_EN
	var cn := GameBrand.STUDIO_CN
	if en == "" and cn == "":
		return
	var f := UiTheme.font()
	var fs := 27
	var track := 2.2
	var text := en if en != "" else cn
	var base_y := cy + MARK_D * 0.5 + 46.0

	var widths: Array[float] = []
	var total := 0.0
	for i in text.length():
		var w := f.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w
	total += track * float(maxi(0, text.length() - 1))

	var x := cx - total * 0.5
	for i in text.length():
		var k := clampf((_t - (NAME_AT + NAME_STEP * float(i))) / NAME_IN_DUR, 0.0, 1.0)
		if k > 0.0:
			var lift := (1.0 - k) * 5.0
			draw_string(f, Vector2(x, base_y - lift), text.substr(i, 1),
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GOLD, a * ease(k, 1.6)))
		x += widths[i] + track

	# 金线：从中心往两侧长，长度跟最后一个字母同步
	if _t >= RULE_AT and total > 1.0:
		var kr := clampf((_t - RULE_AT) / RULE_DUR, 0.0, 1.0)
		var half := (total * 0.5 + 26.0) * ease(kr, 0.65)
		var y := base_y + 13.0
		var c := Color(GOLD, a * 0.42 * kr)
		draw_line(Vector2(cx - half, y), Vector2(cx + half, y), c, 1.0, true)
		# 两端各一个小菱形：纹章味，比圆点更稳
		for side in [-1.0, 1.0]:
			var px: float = cx + side * half
			draw_colored_polygon(PackedVector2Array([
					Vector2(px, y - 3.0), Vector2(px + 3.0, y),
					Vector2(px, y + 3.0), Vector2(px - 3.0, y)]), Color(GOLD, a * 0.62 * kr))


func _draw_hint() -> void:
	var fs := UiTheme.FS_CAPTION
	var f := UiTheme.font()
	var hint := GameI18n.ui("shell", "OPENING_CONTINUE_HINT", "按任意键继续")
	var tw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a := clampf((_t - 1.0) / 0.4, 0.0, 1.0) * 0.42
	draw_string(f, Vector2(size.x - tw - 24.0, size.y - 20.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.96, 0.88, a))
