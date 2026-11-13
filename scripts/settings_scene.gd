extends Control
## 设置页（R215）—— 音效 / 音乐 / 全屏。三项都**立刻生效并记住**（GameSettings）。
## R246：音效 / 音乐各加一行**音量**（− / + 或点条直接定位，10% 一档；同样即时生效并记住）。
##
## 入口：标题页「设置」按钮。之所以单开一页而不是塞进标题页：标题页是按钮栈
## （`Buttons` 容器），塞开关进去会把一屏一个主按钮的层次搞乱。
##
## R655：**第二个入口** = 各界面 ESC 菜单的「设置」。那条路**不切场景**，走 `open_overlay()`：
##   设置页作为浮层盖在当前界面之上、场景树暂停，关掉即原样回去。为什么不能切场景 ——
##   战斗的棋盘 / 手牌 / 引擎状态全在场景实例里，`SceneFx.goto(settings)` 一换场景，
##   回来就是重开一局；玩家按 Esc 只是想关小一点音乐，不该赔上一整场。
##
## R660c（店长口径）：**设置项按类分页** —— 音频 / 画面 / 语言 / 对局四个页签，
##   语言不再挂在页首右上角。为什么改：右上角那个下拉既挤标题行，又和「设置」标题
##   抢同一片留白；而语言本来就是一类设置，独立成页比塞在角落更像"设置项"。
##   分页后每页只留本类的东西，以后再加设置只需要往对应页里加一行。

const UiTheme = preload("res://scripts/ui_theme.gd")
const L10n = preload("res://scripts/l10n.gd")
const LanguageMenu = preload("res://scripts/language_menu.gd")

const TABS := ["audio", "display", "language", "run"]
const TAB_AUDIO := 0
const TAB_DISPLAY := 1
const TAB_LANGUAGE := 2
const TAB_RUN := 3

const TAB_Y := 126.0
const TAB_H := 40.0
## R660d：页签**贴紧等分**，整栏宽度 = 下方框体宽度（ROW_W）。原先按文字量各算宽度
## 再留 10px 间隙，看着是「四个小按钮」；现在是**一条页签栏**，格子之间零间隙。
const TAB_FONT_MIN := 11
const CONTENT_Y := 196.0
const ROW_W := 520.0
const ROW_H := 54.0
const ROW_GAP := 10.0
const SEED_H := 138.0     # R241：种子面板高度
const VOL_STEP := 0.1     # R246：音量一档 10%
const VOL_NUM := 20
const LANG_ROW_H := 48.0
const LANG_MAX_ROWS := 5

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _tab := TAB_AUDIO          # 当前页签（0 音频 / 1 画面 / 2 语言 / 3 对局）
var _tab_hover := -1
var _hover := -1               # 悬停的设置行序号
var _last_mp := Vector2.INF
var _seed_edit: LineEdit = null   # R241「下一局种子」输入框（唯一的原生控件）
var _seed_guard := false          # 防止 text_changed 里改 text 触发二次回调
var _seed_hover := false          # R325：「复制」按钮的悬停态（自绘按钮要自己记）
## R655：浮层模式（ESC 菜单进来的那条路）。`_overlay == true` 时「返回」= 关自己，
## **不切场景**；左上角文案跟着宿主改（战斗中 = 「← 返回战斗」）。
var _overlay := false
var _overlay_back := "返回战斗"
var _overlay_host: Node = null
var _overlay_layer: CanvasLayer = null
var _overlay_paused := false      # 暂停是浮层开的 → 由它还（不去解别人的暂停）
var _lang_list: Control = null    # R660c：语言页里的可滚动列表（内嵌，不再做下拉）


static func open_overlay(host: Node, back_text := "返回战斗") -> Control:
	## R655：ESC 菜单「设置」的**唯一入口** —— 设置页盖在 `host` 之上，不切场景。
	## ⚠️ 调用时机：在菜单项的按钮回调里直接调，会被紧接着的 `close()` 解冻
	##    （UiMenu 的 `_release_pause` 会把 `paused` 还回去），所以宿主要先
	##    `call_deferred` 一帧（`battle_scene._open_settings` 就是这么排的）。
	var ps := load("res://scenes/settings.tscn") as PackedScene
	if ps == null:
		return null
	var s: Variant = ps.instantiate()
	s._overlay = true
	s._overlay_back = back_text
	s._overlay_host = host
	var cl := CanvasLayer.new()
	cl.name = "SettingsOverlay"
	cl.layer = 28            # UiMenu 是 30：设置页盖住界面，宿主自己的 Esc 菜单仍在它上面
	host.add_child(cl)
	cl.add_child(s)          # 进树即 `_ready` —— 那边靠 `_overlay` 决定不动 BGM / 不挂菜单
	s._overlay_layer = cl
	if not host.get_tree().paused:
		host.get_tree().paused = true
		s._overlay_paused = true
	return s as Control


func _ready() -> void:
	# R655：浮层模式下场景树是**暂停**的 —— 本节点必须绕过暂停才收得到点击 / Esc。
	if _overlay:
		process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	GameSettings.ensure_loaded()
	sfx = Sfx.new()
	add_child(sfx)
	# R655：浮层**不动 BGM** —— 背后那一局还在，切成标题曲会让人以为已经回标题页了。
	if not _overlay:
		Bgm.play("title")
	# 出图探针：`--tab=语言页键`（audio / display / language / run），旧写法 `--lang-menu` 等同 language。
	_tab = _tab_from_args()
	# R655：浮层**不接**这个钩子 —— `--screenshot` 是「单独打开设置页出图」用的（0.6s 后
	# 直接 quit）。浮层是在战斗里出图的，宿主还没走到截图帧就被它掐掉，拍出来的是旧图。
	if not _overlay and "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_settings.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_build_seed_edit()
	_build_language_list()
	# R655：浮层不挂自己的 ESC 菜单（Esc 直接关浮层）—— 两层菜单叠着只会互相抢 Esc；
	# 浮层里也不需要「返回标题」（宿主菜单里本来就有那一条）。
	if not _overlay:
		_menu = UiMenu.attach(self, _menu_items, {
			"back": L10n.t("title.continue_short"),
			"sub": L10n.t("settings.title"),
		})


func _tab_from_args() -> int:
	if "--lang-menu" in OS.get_cmdline_user_args():
		return TAB_LANGUAGE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tab="):
			var k := a.substr(6).strip_edges().to_lower()
			var i := TABS.find(k)
			if i >= 0:
				return i
	return TAB_AUDIO


# ------------------------------------------------------------ 页签 / 布局

func _tab_key(i: int) -> String:
	match i:
		TAB_AUDIO:
			return "settings.tab_audio"
		TAB_DISPLAY:
			return "settings.tab_display"
		TAB_LANGUAGE:
			return "settings.tab_language"
	return "settings.tab_run"


func _tab_rects() -> Array[Rect2]:
	## R660d：页签**等分贴紧** —— 整栏宽度与下方框体一致（ROW_W，水平居中），
	## 格与格之间零间隙。这样读起来是一条页签栏，而不是一排按钮。
	## ⚠️ 等分后单格宽度固定，长文案（日文「オーディオ」）靠 `_draw_tabs` 里
	##    按可用宽自动缩字号兜底，不靠加宽格子。
	var n := TABS.size()
	var w := ROW_W / float(n)
	var x0 := (size.x - ROW_W) * 0.5
	var out: Array[Rect2] = []
	for i in n:
		out.append(Rect2(x0 + w * float(i), TAB_Y, w, TAB_H))
	return out


func _tab_at(pos: Vector2) -> int:
	var rects := _tab_rects()
	for i in rects.size():
		if rects[i].has_point(pos):
			return i
	return -1


func _set_tab(i: int) -> void:
	if i < 0 or i >= TABS.size() or i == _tab:
		return
	_tab = i
	_hover = -1
	_seed_hover = false
	_sync_seed_edit()
	_sync_language_list()
	queue_redraw()


func _row_rect(i: int) -> Rect2:
	## 内容从页签下方开始，**不垂直居中** —— 分页后每页行数不同，居中会让切换时整页跳。
	return Rect2((size.x - ROW_W) * 0.5, CONTENT_Y + float(i) * (ROW_H + ROW_GAP),
			ROW_W, ROW_H)


func _vol_rects(r: Rect2) -> Array[Rect2]:
	## R246 音量行右侧的几何唯一口（画与点共用）：[−][条][+]。
	var cy := r.position.y + r.size.y / 2.0
	return [
		Rect2(r.position.x + r.size.x - 300.0, cy - 16.0, 32.0, 32.0),
		Rect2(r.position.x + r.size.x - 260.0, cy - 7.0, 118.0, 14.0),
		Rect2(r.position.x + r.size.x - 134.0, cy - 16.0, 32.0, 32.0),
	]


func _cycle_rect(r: Rect2) -> Rect2:
	## 循环档位（敌人速度）右侧的小按钮，几何唯一口。
	return Rect2(r.position.x + r.size.x - 104.0, r.get_center().y - 16.0, 84.0, 32.0)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


# ------------------------------------------------------------ 种子（R241）

func _seed_panel_rect() -> Rect2:
	## 对局页顶上一块 —— 本局种子（只读）+ 下一局种子（可填）。
	return Rect2((size.x - ROW_W) * 0.5, CONTENT_Y, ROW_W, SEED_H)


func _seed_copy_rect() -> Rect2:
	## R325：种子面板右上角的「复制」按钮（跟在「本局种子」一行的右端）。
	var p := _seed_panel_rect()
	return Rect2(p.position.x + p.size.x - 92.0, p.position.y + 30.0, 72.0, 26.0)


func _seed_copy_text() -> String:
	## 复制什么：优先**本局种子**（有进行中的对局时）；
	## 没有对局就退回「下一局种子」——那串码同样值得抄出去分享 / 复现。
	if RunState.run_active and RunState.run_seed != 0:
		return RunState.seed_text()
	return GameSettings.next_seed_code


func _copy_seed() -> void:
	## R325：种子写进**系统剪贴板**。`DisplayServer.clipboard_set` 在桌面与安卓是同一口
	## （安卓走 JNI 的 ClipboardManager），所以手机上复制完直接长按粘贴就行。
	var code := _seed_copy_text()
	if code == "":
		UiToast.toast(L10n.t("settings.no_seed"))
		return
	DisplayServer.clipboard_set(code)
	UiToast.toast(L10n.tf("settings.copied", [code]))


func _seed_edit_rect() -> Rect2:
	var p := _seed_panel_rect()
	return Rect2(p.position.x + 132.0, p.position.y + 62.0, 214.0, 34.0)


func _build_seed_edit() -> void:
	## 原生 LineEdit（手机上点它才会弹软键盘 —— 纯 _draw 的输入框做不到这件事）。
	GameSettings.ensure_loaded()
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = L10n.t("settings.seed_placeholder")
	_seed_edit.max_length = RunState.SEED_LEN
	_seed_edit.text = GameSettings.next_seed_code
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAGE_PAPER
	sb.border_color = UiTheme.ADVENTURE_BRASS
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	_seed_edit.add_theme_stylebox_override("normal", sb)
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = Color("23262f")
	sbf.border_color = UiTheme.ADVENTURE_BRASS
	sbf.set_border_width_all(1)
	sbf.set_corner_radius_all(4)
	sbf.content_margin_left = 8.0
	sbf.content_margin_right = 8.0
	_seed_edit.add_theme_stylebox_override("focus", sbf)
	_seed_edit.add_theme_font_override("font", _font)
	_seed_edit.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	_seed_edit.add_theme_color_override("font_color", UiTheme.PAGE_INK)
	_seed_edit.add_theme_color_override("caret_color", UiTheme.PAGE_INK)
	_seed_edit.add_theme_color_override("placeholder_color", UiTheme.PAGE_MUTED)
	_seed_edit.text_changed.connect(_on_seed_changed)
	add_child(_seed_edit)
	_sync_seed_edit()
	resized.connect(_sync_seed_edit)


func _sync_seed_edit() -> void:
	if _seed_edit == null:
		return
	# R660c：输入框只在「对局」页存在 —— 别的页留着它会浮在行卡上面。
	_seed_edit.visible = _tab == TAB_RUN
	if not _seed_edit.visible:
		_seed_edit.release_focus()
	var r := _seed_edit_rect()
	_seed_edit.position = r.position
	_seed_edit.size = r.size


func _on_seed_changed(txt: String) -> void:
	## R261：只收 **A-Z / 0-9**（小写自动转大写）—— 粘贴 / 输入法带进来的其它字符当场剃掉。
	## 半截串（不足 10 位）先留在框里让人继续打，落盘只会是合法码或空（见 set_next_seed_code）。
	if _seed_guard:
		return
	var code := ""
	for i in txt.length():
		var ch := txt[i].to_upper()
		if RunState.SEED_ALPHABET.find(ch) >= 0:
			code += ch
	if code != txt:
		_seed_guard = true
		_seed_edit.text = code
		_seed_edit.caret_column = code.length()
		_seed_guard = false
	GameSettings.set_next_seed_code(code)
	queue_redraw()


# ------------------------------------------------------------ 语言列表（R660c）

func _lang_list_rect() -> Rect2:
	var rows := mini(L10n.LANGUAGES.size(), LANG_MAX_ROWS)
	var h := float(rows) * LANG_ROW_H + 16.0
	return Rect2((size.x - ROW_W) * 0.5, CONTENT_Y, ROW_W, h)


func _build_language_list() -> void:
	## 列表只建一次：切页只改 visible / 几何 / 数据，不反复 new。
	_lang_list = LanguageMenu.new()
	_lang_list.visible = false
	_lang_list.picked.connect(_on_language_picked)
	_lang_list.activated.connect(_on_language_picked)
	_lang_list.highlighted.connect(_on_language_picked)   # 设置页是即时生效：↑↓ 也算选定
	add_child(_lang_list)
	_sync_language_list()
	resized.connect(_sync_language_list)


func _sync_language_list() -> void:
	if _lang_list == null:
		return
	_lang_list.visible = _tab == TAB_LANGUAGE
	if not _lang_list.visible:
		_lang_list.release_focus()
		return
	var r := _lang_list_rect()
	_lang_list.position = r.position
	_lang_list.size = r.size
	_lang_list.setup(L10n.LANGUAGES, GameSettings.language, LANG_ROW_H)


func _on_language_picked(code: String) -> void:
	## 设置页是**选完立刻生效**：整页重绘、Esc 菜单文案也跟着换。
	if code == GameSettings.language:
		return
	GameSettings.set_language(code, true)
	if _seed_edit != null:
		_seed_edit.placeholder_text = L10n.t("settings.seed_placeholder")
	_rebuild_menu()
	UiToast.toast(L10n.t("settings.language_changed"))
	if _lang_list != null:
		_lang_list.setup(L10n.LANGUAGES, GameSettings.language, LANG_ROW_H)
	_sync_seed_edit()
	queue_redraw()


func _rebuild_menu() -> void:
	## UiMenu 的文案在 attach 时定死；换语言后重挂一份，免得 Esc 菜单还是旧语言。
	if _overlay or _menu == null:
		return
	_menu.queue_free()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": L10n.t("title.continue_short"),
		"sub": L10n.t("settings.title"),
	})


# ------------------------------------------------------------ 输入

func _menu_items() -> Array:
	return [
		{"text": L10n.t("settings.back_title"), "fn": _back_to_title},
	]


func _unhandled_input(event: InputEvent) -> void:
	# R655：浮层里 Esc = 关掉浮层回原界面（宿主是暂停的，只有本节点收得到这个事件）
	if _overlay:
		if event is InputEventKey and event.pressed and not event.echo \
				and (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_overlay()
		return
	if _menu != null and _menu.handle_esc(event):
		return
	# R660c：← → 翻页（列表有焦点时方向键归列表，这里只收左右）
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_LEFT:
			_set_tab(maxi(0, _tab - 1))
			get_viewport().set_input_as_handled()
		elif k == KEY_RIGHT:
			_set_tab(mini(TABS.size() - 1, _tab + 1))
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		queue_redraw()


func _row_at(pos: Vector2) -> int:
	var rows := _rows()
	for i in rows.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var th := _tab_at(event.position)
		var h := _row_at(event.position)
		var sh := _tab == TAB_RUN and _seed_copy_rect().has_point(event.position)
		if th != _tab_hover or h != _hover or sh != _seed_hover:
			_tab_hover = th
			_hover = h
			_seed_hover = sh
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var ti := _tab_at(event.position)
		if ti >= 0:
			if ti != _tab:
				sfx.play("click")
			_set_tab(ti)
			return
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back_to_title()
			return
		if _tab == TAB_RUN and _seed_copy_rect().has_point(event.position):
			if _seed_copy_text() != "":
				sfx.play("click")
			_copy_seed()
			queue_redraw()
			return
		var i := _row_at(event.position)
		if i >= 0:
			var d: Dictionary = _rows()[i]
			if str(d.get("kind", "toggle")) == "volume":
				var vr := _vol_rects(_row_rect(i))
				if vr[0].has_point(event.position):
					sfx.play("click")
					_nudge_volume(str(d["id"]), -VOL_STEP)
					return
				if vr[2].has_point(event.position):
					sfx.play("click")
					_nudge_volume(str(d["id"]), VOL_STEP)
					return
				if vr[1].grow(8.0).has_point(event.position):
					# 点条上任意位置直接定位（条本身就是滑块）
					sfx.play("click")
					_set_volume(str(d["id"]),
							(event.position.x - vr[1].position.x) / vr[1].size.x)
					return
				return   # 点行进空白处：不动作（别把音量行当成开关翻掉）
			sfx.play("click")
			_activate_row(d)
			return
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _activate_row(d: Dictionary) -> void:
	## 点行 = 切换（开关翻面 / 档位循环）。唯一落地点都在这一个函数里。
	GameSettings.ensure_loaded()
	match str(d.get("id", "")):
		"sfx":
			GameSettings.set_sfx_on(not GameSettings.sfx_on)
			sfx.enabled = GameSettings.sfx_on
			if sfx.enabled:
				sfx.play("click")
		"music":
			GameSettings.set_music_on(not GameSettings.music_on)
			Bgm.set_enabled(GameSettings.music_on)
			if GameSettings.music_on:
				Bgm.play("title")   # 当场就有反馈（否则要等下一次切场景才响）
		"fullscreen":
			GameSettings.set_fullscreen(not GameSettings.fullscreen)
		"foe_speed":
			GameSettings.set_foe_speed(GameSettings.next_foe_speed(GameSettings.foe_speed))
	queue_redraw()


func _nudge_volume(id: String, delta: float) -> void:
	## R246：− / + 按一档（10%）步进，并对齐到整档（避免 10% 累积出 0.30000001）。
	var cur := _volume_of(id)
	var steps := roundf((cur + delta) * float(VOL_NUM))
	_set_volume(id, steps / float(VOL_NUM))


func _volume_of(id: String) -> float:
	GameSettings.ensure_loaded()
	return GameSettings.sfx_volume if id == "sfx_vol" else GameSettings.music_volume


func _set_volume(id: String, v: float) -> void:
	## 唯一落地点：写设置 + 落到正在播的实例 + 重绘（两档音量共用）。
	var nv := clampf(v, 0.0, 1.0)
	nv = roundf(nv * float(VOL_NUM)) / float(VOL_NUM)   # 吸附到 5% 网格（点条也整齐）
	if id == "sfx_vol":
		GameSettings.set_sfx_volume(nv)
		sfx.volume = nv
		if nv > 0.0:
			sfx.play("click")   # 当场听到新音量
	else:
		GameSettings.set_music_volume(nv)
		Bgm.set_volume(nv)
	queue_redraw()


func _back_to_title() -> void:
	## R655：浮层模式下「返回」回的是**宿主界面**（战斗），标题页是另一条路。
	if _overlay:
		_close_overlay()
		return
	SceneFx.goto("res://scenes/title.tscn")


func _close_overlay() -> void:
	## R655：关掉浮层 —— 连包着它的 CanvasLayer 一起 free（自己随之释放）。
	## 暂停在 `_restore_overlay_pause()` 里还；`_exit_tree` 再兜一次底。
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	_overlay_layer = null
	_restore_overlay_pause()


func _restore_overlay_pause() -> void:
	if not _overlay_paused:
		return
	_overlay_paused = false
	var t := get_tree()
	if t != null:
		t.paused = false


func _exit_tree() -> void:
	## 兜底：浮层被强拆（宿主切场景 / 被 free / 关卡结束）时也必须把暂停还回去，
	## 否则回到任何界面都是假死 —— 与 UiMenu 的 `_exit_tree` 同一条纪律。
	_restore_overlay_pause()


# ------------------------------------------------------------ 内容

func _rows() -> Array:
	## 当前页的行描述。`id` 是行为唯一键（画、点、落盘都靠它，不再用序号下标）。
	GameSettings.ensure_loaded()
	match _tab:
		TAB_AUDIO:
			return [
				{"id": "sfx", "kind": "toggle", "on": GameSettings.sfx_on,
						"title": L10n.t("settings.sfx"),
						"desc": L10n.t("settings.sfx_desc")},
				{"id": "sfx_vol", "kind": "volume", "val": GameSettings.sfx_volume,
						"title": L10n.t("settings.sfx_vol"),
						"desc": L10n.t("settings.sfx_vol_desc")},
				{"id": "music", "kind": "toggle", "on": GameSettings.music_on,
						"title": L10n.t("settings.music"),
						"desc": L10n.t("settings.music_desc")},
				{"id": "music_vol", "kind": "volume", "val": GameSettings.music_volume,
						"title": L10n.t("settings.music_vol"),
						"desc": L10n.t("settings.music_vol_desc")},
			]
		TAB_DISPLAY:
			return [
				{"id": "fullscreen", "kind": "toggle", "on": GameSettings.fullscreen,
						"title": L10n.t("settings.fullscreen"),
						"desc": L10n.t("settings.fullscreen_desc")},
				{"id": "foe_speed", "kind": "cycle", "on": true,
						"value": GameSettings.foe_speed,
						"title": L10n.t("settings.foe_speed"),
						"desc": L10n.t("settings.foe_speed_desc")},
			]
	return []


func _draw() -> void:
	UiTheme.draw_page(self, UiTheme.bleed_rect(self))   # R519：铺满窗口
	draw_string(_font_bold, Vector2(0, 78), L10n.t("settings.title"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(0, 110), L10n.t("settings.autosave"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	_draw_tabs()
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	UiTheme.draw_action(self, back, false, false, hov_back)
	# R655：浮层里回的是宿主界面（战斗中 = 「← 返回战斗」）
	var back_name := _overlay_back
	if _overlay_back == "返回战斗":
		back_name = L10n.t("settings.back_battle")
	var back_label := "← %s" % back_name if _overlay else "← %s" % L10n.t("settings.back_title")
	draw_string(_font_bold, back.position + Vector2(0, 22), back_label,
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var rows := _rows()
	for i in rows.size():
		_draw_row(i, rows[i])
	if _tab == TAB_LANGUAGE:
		_draw_language_note()
	elif _tab == TAB_RUN:
		_draw_seed_panel()


func _draw_tabs() -> void:
	## R660d：**一条页签栏**，不是四颗按钮 —— 整条只画一圈外框，内部只画竖向分隔线。
	## 每格各画自己的边框时，贴紧后中缝会叠成 2px 粗线，一眼又变回「按钮排」。
	var rects := _tab_rects()
	var bar := Rect2(rects[0].position, Vector2(ROW_W, TAB_H))
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.34), true)
	for i in rects.size():
		if i != _tab and i != _tab_hover:
			continue
		draw_rect(rects[i], UiTheme.ADVENTURE_FOREST if i == _tab
				else Color(1.0, 0.98, 0.90, 0.72), true)
	# 竖向分隔：跳过选中格两侧 —— 深绿底上留一道金线会显脏。
	for i in range(1, rects.size()):
		if i == _tab or i - 1 == _tab:
			continue
		var x: float = rects[i].position.x
		draw_line(Vector2(x, TAB_Y + 9.0), Vector2(x, TAB_Y + TAB_H - 9.0),
				Color(UiTheme.ADVENTURE_BRASS, 0.45), 1.0)
	draw_rect(bar, UiTheme.ADVENTURE_BRASS, false, 1.4)
	# 选中格顶上一道亮金：像被拎起来的那一格，和未选中的平压状态区分开。
	var sel: Rect2 = rects[_tab]
	draw_line(sel.position, Vector2(sel.end.x, sel.position.y),
			UiTheme.ADVENTURE_BRASS_LIT, 2.0)
	for i in rects.size():
		var r: Rect2 = rects[i]
		var active := i == _tab
		var label := L10n.t(_tab_key(i))
		var avail := r.size.x - 16.0
		var fs := UiTheme.FS_LABEL
		var tw := _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# 等分后单格宽度固定，长文案按可用宽逐档缩字号（日文「オーディオ」最先触线）。
		while tw > avail and fs > TAB_FONT_MIN:
			fs -= 1
			tw = _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font_bold, Vector2(r.position.x, r.position.y + 27.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs,
				UiTheme.ADVENTURE_LIGHT if active else UiTheme.PAGE_INK)


func _draw_language_note() -> void:
	var r := _lang_list_rect()
	draw_string(_font, Vector2(r.position.x, r.end.y + 26.0),
			L10n.t("settings.language_note"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x,
			UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)


func _draw_seed_panel() -> void:
	## R241：种子面板 —— ① 本局种子（只读，继续游戏会沿用它）② 下一局种子（可填）。
	var p := _seed_panel_rect()
	UiTheme.draw_panel_bg(self, p)
	draw_rect(p, UiTheme.ADVENTURE_BRASS, false, 1.6)
	draw_string(_font_bold, p.position + Vector2(20, 26), L10n.t("settings.seed_title"),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var cur := L10n.tf("settings.seed_current", [RunState.seed_text()])
	if not RunState.run_active:
		cur = L10n.t("settings.seed_none")
	draw_string(_font, p.position + Vector2(20, 50), cur,
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 40.0, UiTheme.FS_LABEL,
			UiTheme.PAGE_GREEN if RunState.run_active else UiTheme.PAGE_MUTED)
	draw_string(_font_bold, p.position + Vector2(20, 84), L10n.t("settings.seed_next"),
			HORIZONTAL_ALIGNMENT_LEFT, 150, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var next_code := GameSettings.next_seed_code
	var tail := L10n.t("settings.seed_current_random")
	if next_code != "":
		tail = L10n.tf("settings.seed_current_code", [next_code])
	draw_string(_font, p.position + Vector2(356, 84), tail,
			HORIZONTAL_ALIGNMENT_LEFT, 150, UiTheme.FS_CAPTION,
			UiTheme.PAGE_MUTED if next_code == "" else UiTheme.PAGE_INK)
	draw_string(_font, p.position + Vector2(20, 120), L10n.t("settings.seed_tip"),
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 40.0, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	# R325：一键复制 —— 10 位码手抄太容易错一位（抄错 = 复现不出同一局）。
	# 按钮紧跟「本局种子」一行右端；没有可复制的码时置灰并吞掉点击。
	var cr := _seed_copy_rect()
	var can_copy := _seed_copy_text() != ""
	var hov := _seed_hover and can_copy
	draw_rect(cr, UiTheme.PAGE_PAPER if hov else UiTheme.ADVENTURE_INPUT, true)
	draw_rect(cr, UiTheme.ADVENTURE_BRASS, false, 1.4)
	draw_string(_font_bold, cr.position + Vector2(0, 18), L10n.t("settings.copy"),
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, UiTheme.FS_CAPTION,
			UiTheme.PAGE_INK if can_copy else Color("63687a"))
	# 页脚提示挂在种子面板下面（它讲的就是种子，跟着本页走）
	draw_string(_font, Vector2(0, p.end.y + 30.0), L10n.t("settings.seed_footer"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
			UiTheme.PAGE_MUTED)


func _draw_row(i: int, d: Dictionary) -> void:
	var r := _row_rect(i)
	var hov := i == _hover
	UiTheme.draw_info_card(self, r, hov)
	draw_string(_font_bold, r.position + Vector2(20, 24), str(d["title"]),
			HORIZONTAL_ALIGNMENT_LEFT, 200, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var kind := str(d.get("kind", "toggle"))
	var is_vol := kind == "volume"
	# 档位行右侧只剩一颗小铜牌（-104 起），描述可以铺到 386；开关行要给开关让位。
	draw_string(_font, r.position + Vector2(20, 43), str(d["desc"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			190.0 if is_vol else (386.0 if kind == "cycle" else 360),
			UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	if is_vol:
		_draw_volume_row(r, float(d.get("val", 1.0)))
		return
	if kind == "cycle":
		_draw_cycle_chip(r, float(d.get("value", 1.0)), hov)
		return
	var on := bool(d["on"])
	# 右侧开关：药丸底 + 圆点（开 = 绿 / 关 = 灰），文字跟着走
	var sw := Rect2(r.position.x + r.size.x - 96.0, r.position.y + r.size.y / 2.0 - 15.0,
			76.0, 30.0)
	var track := StyleBoxFlat.new()
	track.bg_color = UiTheme.ADVENTURE_FOREST if on else UiTheme.ADVENTURE_INPUT
	track.border_color = UiTheme.ADVENTURE_BRASS
	track.set_border_width_all(1)
	track.set_corner_radius_all(15)
	track.corner_detail = 12
	track.anti_aliasing = true
	draw_style_box(track, sw)
	var knob := StyleBoxFlat.new()
	knob.bg_color = UiTheme.PAGE_PAPER
	knob.border_color = UiTheme.ADVENTURE_BRASS
	knob.set_border_width_all(1)
	knob.set_corner_radius_all(11)
	knob.corner_detail = 12
	knob.anti_aliasing = true
	var knob_x := sw.position.x + (sw.size.x - 26.0 if on else 4.0)
	draw_style_box(knob, Rect2(knob_x, sw.position.y + 4, 22, 22))
	draw_string(_font_bold, Vector2(sw.position.x - 46.0, sw.position.y + 21.0),
			L10n.t("settings.on") if on else L10n.t("settings.off"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_LABEL,
			UiTheme.PAGE_GREEN if on else UiTheme.PAGE_MUTED)


func _draw_cycle_chip(r: Rect2, value: float, hov: bool) -> void:
	## 循环档位（敌人速度）：一颗小铜牌，写着 ×1.0 / ×1.5 / ×2.0，点它翻下一档。
	var c := _cycle_rect(r)
	draw_rect(c, UiTheme.PAGE_PAPER if hov else UiTheme.ADVENTURE_INPUT, true)
	draw_rect(c, UiTheme.ADVENTURE_BRASS_LIT if hov else UiTheme.ADVENTURE_BRASS,
			false, 1.4)
	draw_string(_font_bold, c.position + Vector2(0, 21), "×%.1f" % value,
			HORIZONTAL_ALIGNMENT_CENTER, c.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)


func _draw_volume_row(r: Rect2, val: float) -> void:
	## R246：音量行右侧 = [−][滑条][+][ 80% ]。三块几何走 `_vol_rects`（与点击同一份）。
	var vr := _vol_rects(r)
	var mp := get_local_mouse_position()
	for k in [0, 2]:
		var b: Rect2 = vr[k]
		var hb := b.has_point(mp)
		draw_rect(b, UiTheme.PAGE_PAPER, true)
		draw_rect(b, Color("7d8aa4") if hb else UiTheme.ADVENTURE_BRASS, false, 1.4)
		draw_string(_font_bold, b.position + Vector2(0, 22), "−" if k == 0 else "+",
				HORIZONTAL_ALIGNMENT_CENTER, b.size.x, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var bar: Rect2 = vr[1]
	UiTheme.draw_panel_bg(self, bar)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(val, 0.0, 1.0), bar.size.y)),
			UiTheme.PAGE_INK, true)
	draw_rect(bar, UiTheme.ADVENTURE_BRASS, false, 1.2)
	draw_string(_font_bold, Vector2(r.position.x + r.size.x - 92.0, bar.position.y + 13.0),
			"%d%%" % int(roundf(val * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, 76,
			UiTheme.FS_LABEL, UiTheme.PAGE_INK if val > 0.0 else Color("8b8f98"))
