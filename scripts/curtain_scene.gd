extends Control
## R310「卷卷」事件 —— **每层起点**的那位豚鼠吟游诗人（用户口径）。
##
## 流程（`_stage`）：
##   0 · 台词流式输出中（可点屏幕 / 空格跳过打字）
##   1 · 三个选项 = `RunState.relic_choice` 里那三件起始道具（按钮文字就是**道具名**）；
##       鼠标悬停 → 右侧浮窗显示道具具体效果；触屏（安卓）点第一下 = 显示效果，
##       再点同一项 = 收下（桌面悬停即预览，单击直接收下）。
##   2 · 第二层起：玩家收下道具 → **角色立绘出场**，回一句（CurtainLines.reply）。
##   3 · 收尾：只留一个「离开」。
##       R320（用户口径）：收尾态**任意键 / 点屏幕任意处**都等于「离开」——
##       右上角那颗按钮从此只是「看得见」的提示，不再是唯一出口。
##
## 素材（缺失都不空白、不报错）：
##   assets/ui/bg_curtain.png          整屏背景（卷卷的森林 CG）
##   assets/ui/curtain_box.png         羊皮纸对话框（九宫格，中心留白写字）
##   assets/ui/curtain_plate.png       名称牌
## ⚠️ R310 修订（用户口径）：**不再使用角色立绘** —— 二层回答改成只换名称牌 + 台词，
##    立绘素材（curtain_hero_*）已从 assets/ui 撤掉，源图留在 art_src 备查。
##
## 文案唯一口 = `CurtainLines`（本文件只负责排版与状态机）。
##
## 进程纪律：起点三选一的候选仍由 `RunState.relic_choice` 生成（start_run /
## advance_layer 各摇一次）；收下或跳过都要把它清空，否则地图会把人再送回来。

const UiTheme = preload("res://scripts/ui_theme.gd")
const TextWrap = preload("res://scripts/text_wrap.gd")

# ---- 几何（按窗口尺寸算，1280×720 下的取值写在注释里）----
const BOX_PAD_X := 58.0          # 对话框左右外边距
const BOX_H := 256.0             # 对话框高度
const BOX_BOTTOM := 20.0         # 对话框距屏幕下沿
const OPT_W := 292.0             # 选项胶囊宽
const OPT_H := 52.0
const OPT_GAP := 28.0
const OPT_BOTTOM_PAD := 20.0     # 选项行距对话框下沿
const TIP_W := 470.0
const TYPE_CPS := 26.0           # 流式输出速度（字 / 秒）

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null

var _layer := 1
var _cls := ""
var _stage := 0
var _typing := false
var _typed := 0.0
var _full := ""
var _hover := -1
var _tap := -1                   # 触屏：已经点开过效果的那一项（-1 = 没有）
var _picked := -1
var _instant := false            # 打字瞬完（出图 / 测试）
var _tip_demo := -1              # 演示参数 --curtaintip N：锁住第 N 项的效果浮窗（出图核验）

var _bg: TextureRect = null
var _box: Panel = null
var _plate: TextureRect = null
var _title: Label = null
var _desc: Label = null
var _opts: Array[Button] = []
var _skip: Button = null
var _tip: Control = null


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	_layer = RunState.current_layer if RunState.current_layer > 0 else GameLayers.LAYER_DEFAULT
	_cls = RunState.player_class
	if _cls == "":
		_cls = PlayerClass.default_id()
	_apply_demo_args()
	_build_nodes()
	# 候选兜底：直接打开场景（调试 / 出图）时给一组（本层起始道具池前 3 个）
	if RunState.relic_choice.is_empty():
		var pool: Array[int] = RelicRepo.load_json().start_ids_for_layer(_layer)
		RunState.relic_choice = pool.slice(0, mini(3, pool.size()))
	_fill_options()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	_say(CurtainLines.greeting(_layer, _cls))
	if _tip_demo >= 0:
		_hover = _tip_demo
		_tip.queue_redraw.call_deferred()
	if _picked >= 0:
		# 出图 / 排错：直接跳到「收下之后」那一态
		var pi: int = _picked
		_picked = -1
		_pick(pi)
	if "--screenshot" in OS.get_cmdline_user_args():
		_instant = true
		_desc.visible_characters = -1
		var t := Timer.new()
		t.wait_time = 0.9
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_curtain.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	# R323：开局（选完角色）/ 换层之后，这里就是「本层起点」—— 立刻存一份，
	# 否则玩家在卷卷这段对话里点「返回标题」，标题页连「继续游戏」都没有
	# （地图检查点还没机会写）。存档带着 relic_choice，继续游戏会把人送回这段对话。
	if RunState.run_active and DisplayServer.get_name() != "headless" \
			and "--screenshot" not in OS.get_cmdline_user_args():
		RunSave.save_run()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续这段对话",
		"sub": "起点",
	})


func _apply_demo_args() -> void:
	## 出图 / 冒烟参数：--curtain1 / --curtain2 / --curtaincls forest|rogue|mech /
	## --curtainpick N（直接进回答态）/ --typedone（打字瞬完）。
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match str(args[i]):
			"--curtain1":
				_layer = GameLayers.LAYER_DEFAULT
			"--curtain2":
				_layer = GameLayers.LAYER_TWO
			"--typedone":
				_instant = true
			"--screenshot":
				_instant = true   # 出图要完整台词，不能截到半句话
			"--curtaincls":
				if i + 1 < args.size():
					match str(args[i + 1]):
						"forest":
							_cls = PlayerClass.DRUID
						"rogue":
							_cls = PlayerClass.ROGUE
						"mech":
							_cls = PlayerClass.MECH
			"--curtainpick":
				if i + 1 < args.size():
					_picked = clampi(int(args[i + 1]), 0, 2)
			"--curtaintip":
				if i + 1 < args.size():
					_tip_demo = clampi(int(args[i + 1]), 0, 2)


func _build_nodes() -> void:
	# ① 背景（缺图 → 退 v 内置暗底 ColorRect）
	_bg = TextureRect.new()
	_bg.texture = UiAssets.get_tex("bg_curtain")
	# 用户口径：**背景图不拉伸** —— 等比完整显示、居中；
	# 窗口不是 16:9 时宁可两侧/上下留暗边，也不裁掉画面、更不拉变形。
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	move_child(_bg, 0)
	_bg.visible = _bg.texture != null
	# R320：缺背景图时露出来的就是这层暗底 —— 它是 Control，**默认会把点击全吃掉**，
	# `_gui_input` 于是收不到「点了屏幕一下」（有背景图时才正常）。统一设成不吃鼠标，
	# 让「点任意处」在两种情况下都成立。
	($BG as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _bg.visible:
		($BG as ColorRect).visible = false      # 让位给自定义背景（否则暗底会压在上面）
	# ② 对话框（羊皮纸，九宫格：左右边角不拉伸、中间拉宽）
	_box = Panel.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxTexture.new()
	sb.texture = UiAssets.get_tex("curtain_box")
	if sb.texture != null:
		var tw := float(sb.texture.get_width())
		sb.texture_margin_left = tw * 0.20
		sb.texture_margin_right = tw * 0.20
		sb.texture_margin_top = 26.0
		sb.texture_margin_bottom = 26.0
		_box.add_theme_stylebox_override("panel", sb)
	else:
		var fb := StyleBoxFlat.new()
		fb.bg_color = UiTheme.PANEL_PAPER_BG
		fb.set_corner_radius_all(14)
		fb.set_border_width_all(2)
		fb.border_color = UiTheme.PANEL_PAPER_LINE
		_box.add_theme_stylebox_override("panel", fb)
	add_child(_box)
	# ④ 名称牌
	_plate = TextureRect.new()
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.texture = UiAssets.get_tex("curtain_plate")
	add_child(_plate)
	_title = Label.new()
	_title.text = CurtainLines.SPEAKER
	_title.add_theme_font_override("font", _font_bold)
	_title.add_theme_font_size_override("font_size", UiTheme.FS_SUBHEAD)
	_title.add_theme_color_override("font_color", Color("5b3f1c"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	# ⑤ 台词
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_override("font", _font)
	_desc.add_theme_font_size_override("font_size", 22)
	_desc.add_theme_color_override("font_color", Color("2a2118"))
	_desc.add_theme_constant_override("line_spacing", 10)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc)
	# ⑥ 三个道具选项
	for i in 3:
		var b := Button.new()
		b.visible = false
		UiTheme.apply_button(b, false, false)
		b.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
		b.add_theme_color_override("font_color", Color("33291c"))
		b.add_theme_color_override("font_hover_color", Color("1f1810"))
		b.pressed.connect(_on_opt.bind(i))
		b.mouse_entered.connect(_on_opt_hover.bind(i))
		b.mouse_exited.connect(_on_opt_hover.bind(-1))
		add_child(b)
		_opts.append(b)
	# ⑦ 跳过 / 离开
	_skip = Button.new()
	_skip.text = CurtainLines.skip_label(_layer)
	UiTheme.apply_chip(_skip, true, true)
	_skip.pressed.connect(_on_skip)
	add_child(_skip)
	# ⑧ 效果浮窗（顶层自绘，不吃点击）
	_tip = Control.new()
	_tip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.draw.connect(_draw_tip)
	add_child(_tip)


# ──────────────────────────────────────────────────────── 布局

func _box_rect() -> Rect2:
	var w: float = size.x
	var h: float = size.y
	return Rect2(BOX_PAD_X, h - BOX_BOTTOM - BOX_H, w - BOX_PAD_X * 2.0, BOX_H)


func _relayout() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		size = get_viewport_rect().size
	var r := _box_rect()
	_box.position = r.position
	_box.size = r.size
	# 名称牌骑在对话框左上沿
	var pw := clampf(r.size.x * 0.22, 210.0, 290.0)
	var ph := pw * 0.26
	_plate.position = Vector2(r.position.x + 34.0, r.position.y - ph * 0.62)
	_plate.size = Vector2(pw, ph)
	_title.position = Vector2(_plate.position.x + pw * 0.20, _plate.position.y + ph * 0.10)
	_title.size = Vector2(pw * 0.74, ph * 0.80)
	# 台词区
	# 左右各留 108：避开对话框两端那丛藤蔓 / 雏菊角饰（文字压上去会读不清）
	_desc.position = Vector2(r.position.x + 108.0, r.position.y + 58.0)
	_desc.size = Vector2(r.size.x - 216.0, 116.0)
	# 选项行（三个胶囊居中于对话框）
	var total: float = OPT_W * 3.0 + OPT_GAP * 2.0
	var x0: float = r.position.x + (r.size.x - total) * 0.5
	var oy: float = r.get_center().y + r.size.y * 0.5 - OPT_BOTTOM_PAD - OPT_H
	for i in _opts.size():
		var b: Button = _opts[i]
		b.position = Vector2(x0 + i * (OPT_W + OPT_GAP), oy)
		b.size = Vector2(OPT_W, OPT_H)
	# 跳过 / 离开（屏幕右上角，不压对话框的藤蔓角饰）
	_skip.size = Vector2(150.0, 34.0)
	_skip.position = Vector2(size.x - _skip.size.x - 22.0, 18.0)


# ──────────────────────────────────────────────────────── 台词 / 状态机

func _say(text: String, speaker := "") -> void:
	_full = text
	_typing = true
	_typed = 0.0
	_desc.text = text
	_desc.visible_characters = 0 if not _instant else -1
	if speaker != "":
		_title.text = speaker
	if _instant:
		_typing = false
		_desc.visible_characters = -1
		_on_type_done()


func _process(delta: float) -> void:
	if not _typing:
		return
	_typed += delta * TYPE_CPS
	var n: int = int(_typed)
	if n >= _full.length():
		_typing = false
		_desc.visible_characters = -1
		_on_type_done()
	else:
		_desc.visible_characters = n


func _finish_typing() -> void:
	if not _typing:
		return
	_typing = false
	_desc.visible_characters = -1
	_on_type_done()


func _on_type_done() -> void:
	if _stage == 0:
		_stage = 1
		_show_options(true)


func _can_walk_away() -> bool:
	## R320（用户口径）：「对话收尾」这一态 —— 台词出完了，也没有别的东西等着玩家点。
	##
	## ⚠️ **不能**写成 `_stage == 3`：`_on_type_done()` 只把 **stage 0** 推到 1，
	##    所以「收下道具之后那句回答念完」的终点状态**仍然是 2**（3 只有点跳过按钮才会到）。
	##    用户说的「最后一句只能点右上角离开」，卡住的就是这个 stage 2。
	## ⚠️ stage 1 **不算**：那时三个起始道具还挂着等玩家挑，误触一次（随便按个键 /
	##    点一下空白）就白丢一件道具 —— 这个「任意键离开」只给收尾态开。
	return not _typing and _stage >= 2


func _show_options(on: bool) -> void:
	for b: Button in _opts:
		b.visible = on
	if not on:
		_hover = -1
		_tap = -1
	_tip.queue_redraw()


func _fill_options() -> void:
	var repo := RelicRepo.load_json()
	for i in _opts.size():
		var b: Button = _opts[i]
		if i >= RunState.relic_choice.size():
			b.disabled = true
			b.text = "（空缺）"
			continue
		var rel: RelicData = repo.get_relic(RunState.relic_choice[i])
		if rel == null:
			b.text = "（未知道具 %d）" % RunState.relic_choice[i]
			b.disabled = true
			continue
		# 带「」的名字 = `Mention` 认得的「可查看」标记（与其它界面同一套口径）
		b.text = "「%s」" % rel.relic_name
		b.disabled = false


func _on_opt_hover(i: int) -> void:
	if _hover == i:
		return
	_hover = i
	_tip.queue_redraw()


func _on_opt(i: int) -> void:
	if _stage != 1:
		return
	sfx.play("click")
	# 触屏：第一下只摊开效果，第二下才收下（用户口径：安卓点道具名看效果）
	if DisplayServer.is_touchscreen_available() and _tap != i:
		_tap = i
		_hover = i
		_tip.queue_redraw()
		return
	if i < 0 or i >= RunState.relic_choice.size():
		return
	_pick(i)


func _pick(i: int) -> void:
	var id: int = RunState.relic_choice[i]
	_picked = i
	_stage = 2
	_show_options(false)
	RunState.choose_start_relic(id)
	var name: String = RunState.relic_display_name(id)
	if CurtainLines.has_reply(_layer):
		# 二层起：角色回一句（R310 修订：只换名称牌，不再出立绘 —— 用户口径）
		_say(CurtainLines.reply(_layer, _cls), CurtainLines.reply_speaker(_layer, _cls))
		_skip.text = "离开"
	elif name != "":
		_say("「%s」收下了——路上小心哦。" % name, CurtainLines.SPEAKER)
		_skip.text = "离开"
	else:
		_end_stage()


func _end_stage() -> void:
	_stage = 3
	_typing = false
	_desc.visible_characters = -1
	_show_options(false)
	_skip.text = "离开"
	_skip.visible = true


func _on_skip() -> void:
	## 跳过 / 离开：两条路都算「本层起点已经过完了」，必须清空候选。
	sfx.play("click")
	if _stage == 3:
		_leave()
		return
	if _stage == 1 and _picked < 0:
		RunState.relic_choice = []
	_end_stage()
	_leave()


func _leave() -> void:
	if not RunState.run_active:
		SceneFx.goto("res://scenes/title.tscn")
		return
	if RunState.pending_relic > 0:
		# 即时道具要再选一张卡（源数之力 / 失忆药水）→ 与旧版 relic_pick 同一出口
		SceneFx.goto("res://scenes/deck_edit.tscn")
		return
	SceneFx.goto("res://scenes/map.tscn")


# ──────────────────────────────────────────────────────── 输入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			_finish_typing()
			return
		# R320（用户口径）：收尾态 → **点屏幕任意位置**就是「离开」，
		# 不用去够右上角那颗小按钮（触屏上尤其难按）。
		# 到不了这里的两种情况都是对的：
		#   · 右上角「离开」/ 三个道具都是 Button，落在它们身上的点击被按钮自己吃掉；
		#   · 菜单开着时 UiMenu 那层全屏遮罩（MOUSE_FILTER_STOP）先吃掉，不会穿过来。
		if _can_walk_away():
			_on_skip()
			return
		# 点到空白处 → 收起触屏摊开的效果
		if _tap >= 0:
			_tap = -1
			_tip.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return
	# R320：菜单开着时一律不响应 —— 别让「任意键」顺手把菜单连同本场景一起关掉
	# （菜单自己跑在暂停里，`_unhandled_input` 理论上收不到，这里是显式兜一道）。
	if _menu != null and _menu.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# R320（用户口径）：原来只认空格 / 回车，现在**任何键**都算：
		#   台词没打完 → 直接补完（省一次点击）；已经收尾 → 走人。
		# ⚠️ Esc 不在此列 —— 它在上两行被 `handle_esc()` 吃成「打开菜单」，这是全局约定，
		#    「离开」不该抢它的活。
		if _typing:
			_finish_typing()
			return
		if _can_walk_away():
			_on_skip()


# ──────────────────────────────────────────────────────── 效果浮窗

func _tip_relic() -> RelicData:
	var idx: int = _tap if _tap >= 0 else _hover
	if _tip_demo >= 0:
		idx = _tip_demo
	if idx < 0 or idx >= RunState.relic_choice.size():
		return null
	return RelicRepo.load_json().get_relic(RunState.relic_choice[idx])


func _tip_metrics() -> Dictionary:
	## 浮窗几何：宽度固定，高度按正文折行数算（测量与绘制共用这一处）。
	var rel := _tip_relic()
	if rel == null:
		return {}
	var lines: Array[String] = TextWrap.wrap_plain(_font, rel.desc, TIP_W - 32.0,
			UiTheme.FS_LABEL)
	var h: float = 30.0 + 22.0 + 12.0 + lines.size() * 23.0 + 16.0
	var r := _box_rect()
	# 靠左摆：中间偏右是卷卷的脸，浮窗压上去会让人看不清她（用户口径：悬停只看道具效果）
	var x: float = r.position.x + 30.0
	# 再往上让 34：名称牌骑在对话框上沿，浮窗压上去会把说话人盖掉
	var y: float = r.position.y - h - 48.0
	if y < 60.0:
		y = 60.0
	return {"rect": Rect2(x, y, TIP_W, h), "lines": lines, "relic": rel}


func _draw_tip() -> void:
	var m := _tip_metrics()
	if m.is_empty():
		return
	var rect: Rect2 = m["rect"]
	var lines: Array = m["lines"]
	var rel: RelicData = m["relic"]
	_tip.draw_rect(rect, Color(0.10, 0.11, 0.15, 0.96), true)
	_tip.draw_rect(rect, rel.badge_color(), false, 2.0)
	# R343：传奇道具名走亮金（提示框是深底）。
	_tip.draw_string(_font_bold, rect.position + Vector2(16, 28), rel.relic_name,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, UiTheme.FS_SUBHEAD,
			rel.name_color(Color("f2e6c8")))
	_tip.draw_string(_font, rect.position + Vector2(16, 50), "道具 · %s" % rel.kind,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, UiTheme.FS_CAPTION,
			rel.badge_color())
	var y: float = 50.0 + 30.0
	for ln: String in lines:
		_tip.draw_string(_font, rect.position + Vector2(16, y), ln,
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, UiTheme.FS_LABEL,
				Color("cfcabb"))
		y += 23.0


# ──────────────────────────────────────────────────────── 菜单

func _menu_items() -> Array:
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _on_back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _on_back_to_title() -> void:
	if RunState.run_active:
		RunState.end_run(false)
	SceneFx.goto("res://scenes/title.tscn")
