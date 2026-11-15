class_name StoryUnlockToast
extends CanvasLayer
## R739：解锁新故事时**舞台右下角**弹出的提示卡 —— 跨界面常驻。
##
## 与 `UiToast` 的分工（别合并成一个）：
##   · `UiToast` = **屏幕底部居中**的通用一句话轻反馈（已保存 / 回放开始 / 已删除），
##                 1.6s、无标题、硬边胶囊；
##   · 本类      = **舞台右下角**的奖励事件卡（金边 + 星标 + 三段文字），
##                 约 4.8s、写着去哪看。
##   一个贴底中、一个贴右下，同屏不打架；语义也不同（一句话确认 vs 解锁了一个东西）。
##
## 触发口只有一处：`ProfileData.check_achievements()` 算出的「本次新解锁」。
## 战斗结算 / 地图 / 故事页 / 百科页四个调用点都从那个函数拿数据 ——
## 所以**「无论在哪个界面」是结构上成立的**，不用在每个界面各埋一个调用
## （那样早晚漏一个，而且以后新增界面还得记得补）。
##
## class_name + 懒实例（同 `UiToast` / `SceneFx`）：`--headless` 回归里没有 autoload，
## 懒实例自建；headless 下 `notify()` 直接丢弃 —— 没有窗口可弹，也不该往 root 里塞节点
## （`_verify.py` 八套全是 headless，塞进去只会给「resources still in use」添乱）。
##
## 结算面板那条副标题（battle_scene 的 `_over_hint`）照旧保留：面板是静止的一屏，
## 而右下角这张卡 4.8s 后就淡出了 —— 玩家回头截图时只剩面板，两边不重复承担同一件事。

const UiTheme = preload("res://scripts/ui_theme.gd")

const CARD_W := 356.0
const CARD_H := 88.0
const MARGIN := 18.0        # 距舞台右下角的边距
const ENTER_SEC := 0.24
const HOLD_SEC := 4.2
const EXIT_SEC := 0.34
const SLIDE_IN := 46.0      # 入场时从右侧滑进来多少像素

const COL_BG := Color("1b211c")
const COL_LINE := UiTheme.ADVENTURE_BRASS
const COL_TITLE := UiTheme.ADVENTURE_BRASS_LIT
const COL_TEXT := UiTheme.ADVENTURE_LIGHT
const COL_HINT := Color("9fa694")

static var _inst: StoryUnlockToast = null

var _root: Control = null
var _slide: Control = null      # 只让这一层动（`_root` 每帧贴舞台右下，不能被补间拖走）
var _star: Control = null
var _title_lb: Label = null
var _body_lb: Label = null
var _hint_lb: Label = null
var _tw: Tween = null


static func notify(body_text: String, count: int) -> void:
	## 唯一入口。`body_text` = 单段时的章节名（`count == 1` 才用得上）。
	## 没有场景树（纯逻辑测试）/ headless → 静默丢弃，不崩。
	if count <= 0:
		return
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if _inst == null:
		_inst = load("res://scripts/story_unlock_toast.gd").new()
		tree.root.add_child(_inst)
	_inst._play(body_text, count)


func _ready() -> void:
	# 98：在 `UiToast`(99) 与 `SceneFx`(100) 之下 —— 转场与通用提示都该压在它上面，
	# 但高于任何界面自己的覆盖层（那些最高到 90~95）。
	layer = 98
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(CARD_W, CARD_H)
	_root.visible = false
	add_child(_root)

	_slide = Control.new()
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.size = Vector2(CARD_W, CARD_H)
	_root.add_child(_slide)

	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = Vector2(CARD_W, CARD_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_LINE
	sb.set_border_width_all(1)
	sb.border_width_left = 3      # 左侧金条 = 奖励语义（金只给稀有 / 奖励）
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	sb.shadow_size = 6
	bg.add_theme_stylebox_override("panel", sb)
	_slide.add_child(bg)

	_star = Control.new()
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star.position = Vector2(16, 0)
	_star.size = Vector2(32, CARD_H)
	_star.draw.connect(_on_star_draw)
	_slide.add_child(_star)

	_title_lb = _make_label(14, COL_TITLE, true)
	_title_lb.position = Vector2(54, 13)
	_title_lb.size = Vector2(CARD_W - 68, 20)
	_body_lb = _make_label(17, COL_TEXT, true)
	_body_lb.position = Vector2(54, 33)
	_body_lb.size = Vector2(CARD_W - 68, 24)
	_hint_lb = _make_label(11, COL_HINT, false)
	_hint_lb.position = Vector2(54, 59)
	_hint_lb.size = Vector2(CARD_W - 68, 16)


func _make_label(px: int, col: Color, bold: bool) -> Label:
	## 三行都是定宽定高的短文本：章节名最长「第一章-鸭鸭王国的请托」，
	## 290px 装得下；真溢出就省略号截断（`clip_text` 必须有显式 size 配，
	## 否则会参与最小高计算、把行距顶歪 —— R729 的教训）。
	var lb := Label.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_theme_font_override("font", UiTheme.font_bold() if bold else UiTheme.font())
	lb.add_theme_font_size_override("font_size", px)
	lb.add_theme_color_override("font_color", col)
	lb.clip_text = true
	lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_slide.add_child(lb)
	return lb


func _on_star_draw() -> void:
	## 四角星程序画 —— 字体里的 `✦` 不保证有字形（`UiToast` 同款纪律）。
	var c := Vector2(_star.size.x * 0.5, CARD_H * 0.5)
	var pts := PackedVector2Array()
	for i in 8:
		var ang := -PI * 0.5 + float(i) * PI * 0.25
		var r := 10.5 if i % 2 == 0 else 3.6
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r))
	_star.draw_colored_polygon(pts, COL_TITLE)


func _play(body_text: String, count: int) -> void:
	if _root == null:
		return
	_title_lb.text = GameI18n.ui("shared", "STORY_UNLOCK_TOAST_TITLE", "新故事解锁")
	if count > 1:
		_body_lb.text = GameI18n.ui("shared", "STORY_UNLOCK_TOAST_MANY", "共 %d 段") % count
	else:
		_body_lb.text = body_text
	_hint_lb.text = GameI18n.ui("shared", "STORY_UNLOCK_TOAST_HINT", "在「故事」里查看")
	_root.position = _rest_pos()
	_root.visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()    # 连着解锁两次：重新播一遍，而不是排队攒一串
	_slide.position = Vector2(SLIDE_IN, 0)
	_slide.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tw = create_tween()
	_tw.tween_property(_slide, "position:x", 0.0, ENTER_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(_slide, "modulate:a", 1.0, ENTER_SEC)
	_tw.tween_interval(HOLD_SEC)
	_tw.tween_property(_slide, "modulate:a", 0.0, EXIT_SEC)
	_tw.parallel().tween_property(_slide, "position:x", 16.0, EXIT_SEC)
	_tw.tween_callback(_hide)


func _hide() -> void:
	if _root != null:
		_root.visible = false


func _rest_pos() -> Vector2:
	## 舞台右下角：`stage_origin` 处理宽屏 / 黑边居中，再兜一层「视口比舞台小」。
	var vp := get_viewport().get_visible_rect().size
	var o := UiTheme.stage_origin(vp)
	var x := o.x + UiTheme.STAGE_W - CARD_W - MARGIN
	var y := o.y + UiTheme.STAGE_H - CARD_H - MARGIN
	return Vector2(minf(x, vp.x - CARD_W - 8.0), minf(y, vp.y - CARD_H - 8.0))


func _process(_delta: float) -> void:
	# 只在露头时跟一次（隐藏时白算没意义）；窗口尺寸变了也靠这里贴回去。
	if _root == null or not _root.visible:
		return
	var p := _rest_pos()
	if _root.position != p:
		_root.position = p
