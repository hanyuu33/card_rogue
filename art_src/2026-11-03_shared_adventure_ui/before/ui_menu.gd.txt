class_name UiMenu
extends CanvasLayer

const UiPop = preload("res://scripts/ui_pop.gd")
## 游戏中按 Esc 呼出的主菜单（R148）—— **可做的操作由当前界面决定**。
##
## 为什么做成组件：
##   * 战场顶栏原来挂着「记录 / 音效 / 标题 / 选关 / 地图」五个按钮 —— 顶栏碎成一片，
##     而且每加一个功能就得再挤一个格子。现在顶栏只剩「回合结束」+ **一个齿轮**，
##     设置类操作全部收进这里。
##   * 菜单**项由场景传入**：战斗中给「返回战斗 / 查看地图 / … / 返回标题」，
##     事件页给「返回事件 / 音效 / 返回标题」，选择页给「继续 / 音效 / 返回标题」——
##     同一个组件，不同界面长出不同的菜单。这就是「根据当前界面决定可做的操作」。
##
## 用法（场景 `_ready` 里挂一次，之后 Esc 交给它）：
##     _menu = UiMenu.attach(self, [
##         {"text": "查看地图", "fn": _toggle_map},
##         {"text": func(): return "音效：开" if sfx.enabled else "音效：关",
##          "fn": _toggle_sound, "keep_open": true},
##         {"text": "返回标题", "fn": _on_back_to_title},
##     ], {"back": "返回战斗", "sub": "战斗中"})
##
##     # 输入：场景在自己的 _unhandled_input / _unhandled_key_input 里问一句
##     if _menu != null and _menu.handle_esc(event):
##         return
##
## 项格式：`{ text: String | Callable, fn: Callable, keep_open?: bool, disabled?: bool }`
##   * `text` 传 Callable 时**每次重建都会调用** —— 「音效：开/关」这类随状态变的
##     文案必须这么写（传死的字符串在 attach 那一刻就求值了）。
##   * 默认「点完就关」；`keep_open` 的项点完保持打开并重建（就地切换类）。
##   * **首项「继续」由本组件自动补**（`opts.back`，primary）—— 一屏只有一个主按钮的
##     纪律因此不用每个界面各写一遍。
##
## 三条纪律：
##   ① **打开时暂停场景树**（`get_tree().paused = true`）—— 战斗里的 AI 计时器、动画、
##      回放推进全部停住，这才是「暂停菜单」。本层 `process_mode = ALWAYS`，所以暂停时
##     菜单自己的按钮照样能点，而**下层场景收不到任何输入**（连快捷键都自动屏蔽）。
##      ⚠️ 关闭 / 离开场景时一定要恢复暂停，否则整个游戏假死 → `_exit_tree` 兜底。
##   ② **自己不抢 Esc**：那样会和「Esc 先关地图总览」这类层级语义打架。
##      由场景显式调 `handle_esc()`，层级顺序由场景自己排。
##   ③ 满屏 + 接管鼠标 → 打开时在 UiGate 登记、关闭时撤销（下层悬停让位，R121 口径）。
##
## 命令行 `-- --menu`：战场演示（直接开着菜单出图；此时**不暂停**，否则 `_process`
## 停摆、截图永远不出）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const GATE_ID := "ui_menu"


const PANEL_PAD := 26.0      # 面板内距
const BTN_W := 286.0         # 菜单项宽度（**统一** —— 不让按钮随文字长短忽宽忽窄）
const BTN_H := 46.0
const SEP := 10.0            # 项间距
const BACKDROP := Color(0.03, 0.04, 0.07, 0.66)   # 全屏压暗遮罩

var _host: Node
var _items: Variant = []     # Array、或「返回 Array 的 Callable」（每次打开重新求值）
var _pause := true
var _back_text := "继续游戏"
var _sub_text := ""
var _sfx: Sfx = null
var _is_open := false
var _paused_by_me := false

var _root: Control
var _box: VBoxContainer
var _panel: PanelContainer


static func attach(host: Node, items: Variant, opts := {}) -> UiMenu:
	## 挂到任意界面：返回新建的菜单层。`opts`：
	##   `pause`（默认 true）打开菜单时是否暂停场景树 —— 只有「开着菜单也要出图」的
	##     演示场景才该传 false；
	##   `back`  首项「继续」的文案（战斗中「返回战斗」/ 事件页「返回事件」）；
	##   `sub`   标题下那行小字（说明当前界面，如「战斗中」）。
	##
	## ⚠️ `items` 最好传**函数引用**（`attach(self, _menu_items, …)`）：每次打开菜单都会
	##    重新调用它 → 文案与 `disabled` 拿到的一定是当下状态（地图开不开、音效开关、
	##    是不是联机局）。传死的数组只在 attach 那一刻求值一次，很容易过期。
	var m := UiMenu.new()
	m._host = host
	m._items = items
	m._pause = bool(opts.get("pause", true))
	m._back_text = str(opts.get("back", "继续游戏"))
	m._sub_text = str(opts.get("sub", ""))
	host.add_child(m)
	return m


func _init() -> void:
	layer = 30   # 最高层：RewardPanel(18) / 道具速览(15) 都在它下面


func _ready() -> void:
	# 暂停时仍要能点按钮 → 本层必须绕过 paused（否则菜单一点就「卡住」）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 音效开关操作的是**当前场景**的 sfx（音效本来就是各场景一份）——
	# 用 duck typing 取，取不到（如图鉴页）菜单里对应的项自行禁用即可。
	if "sfx" in _host and _host.get("sfx") is Sfx:
		_sfx = _host.get("sfx")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉落在遮罩上的点击（别穿到棋盘）
	_root.draw.connect(_draw_backdrop)
	_root.visible = false
	add_child(_root)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cc)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	cc.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", int(SEP))
	_panel.add_child(_box)
	_rebuild()
	# 命令行 -- --menu：演示（直接开着菜单出图）。
	# ⚠️ 这一支**强制不暂停** —— 暂停了场景自己的 `_process` 就停摆，截图永远出不来
	#    （`--menu` 只服务出图核验，不是给玩家用的）。
	if "--menu" in OS.get_cmdline_user_args():
		_pause = false
		open.call_deferred()


func _input(event: InputEvent) -> void:
	## Esc 的**关闭**由本类自己接（Esc 的**打开**留给场景 —— 见 `handle_esc`）。
	##
	## 为什么必须由本类接（**R148 用探针实测抓到的 bug**）：
	##   菜单一打开就暂停场景树，而场景自己是 PAUSABLE → 它的 `_unhandled_key_input`
	##   根本收不到第二次 Esc，于是「按 Esc 打开菜单后再按 Esc 关不掉」，只能去点
	##   「返回战斗」。本层是 `PROCESS_MODE_ALWAYS`，暂停照收输入，所以只有它能关。
	##
	## 为什么是 `_input` 而不是 `_unhandled_input`（**同一轮实测抓到的第二个坑**）：
	##   事件派发是「`_input` → GUI → 未处理输入」一条链、**同一个事件**走完。
	##   若用 `_unhandled_input`：场景在它之前把菜单**打开**（`_is_open` 变真），紧接着本函数
	##   收到**同一个事件**，看到「开着」便当场关掉 → 表现是「按 Esc 闪一下又没了」。
	##   放到 `_input` 阶段，本类是这个事件最早的接收者之一，此刻 `_is_open` 还是打开前的
	##   真实状态 —— 关着就放行给场景去开，开着才关。
	##
	## ⚠️ 关闭时**必须消费事件**：否则场景随后又收到同一个 Esc 把菜单开回来。
	if not _is_open:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE and k.pressed and not k.echo:
			close()
			get_viewport().set_input_as_handled()


func has_sound() -> bool:
	## 当前界面有没有可控的音效开关（图鉴页没有 sfx → 菜单里那一项应禁用）。
	return _sfx != null


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_rebuild()
	_root.visible = true
	UiPop.play(_panel)   # R151 P1-9：入场 scale 0.92→1.0 + 淡入 160ms
	UiGate.push(GATE_ID)
	if _pause and not get_tree().paused:
		_paused_by_me = true
		get_tree().paused = true
	_click()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_root.visible = false
	UiGate.pop(GATE_ID)
	_release_pause()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func handle_esc(event: InputEvent) -> bool:
	## 场景的 Esc 入口：**打开**菜单（返回 true = 事件已被吃掉）。
	## ⚠️ 场景要在调用它**之前**处理「更靠上层」的浮层（如地图总览），层级由场景排。
	## ⚠️ 「关闭」不归这里 —— 菜单开着时场景是收不到输入的（暂停），关闭由本类的
	##    `_unhandled_input` 负责（PROCESS_MODE_ALWAYS，暂停也照收）。
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE and k.pressed and not k.echo:
			toggle()
			return true
	return false


func _exit_tree() -> void:
	## 兜底：切场景 / 释放时**一定**要把暂停恢复 —— 否则新场景一进去就假死。
	UiGate.pop(GATE_ID)
	_release_pause()


func _release_pause() -> void:
	if not _paused_by_me:
		return
	_paused_by_me = false
	var t := get_tree()
	if t != null:
		t.paused = false


func _click() -> void:
	if _sfx != null:
		_sfx.play("click")


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	sb.border_color = UiTheme.ACCENT_GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(UiTheme.RADIUS_LG)
	sb.set_content_margin_all(PANEL_PAD)
	return sb


func _draw_backdrop() -> void:
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), BACKDROP)


func _menu_list() -> Array:
	## 首项「继续」自动补在最上面（它是这一屏**唯一**的主按钮）。
	## `_items` 是函数引用时当场求值 —— 每次打开菜单的项与禁用态都是最新的。
	## 文案也**在这里就求值**（`text` 传 Callable 的项）：这样列表本身拿到的就是最终
	## 字符串，断言 / 排查时不会再看到一串 `<anonymous lambda>`。
	var src: Array = _items.call() if _items is Callable else _items
	var list: Array = [{"text": _back_text, "fn": close, "primary": true}]
	for it: Dictionary in src:
		var copy := it.duplicate()
		var raw: Variant = copy.get("text", "")
		if raw is Callable:
			copy["text"] = str(raw.call())
		list.append(copy)
	return list


func _rebuild() -> void:
	## 每次打开 / keep_open 项触发后重建 —— 项的文案与禁用态因此总是最新的。
	## ⚠️ 旧节点必须 `remove_child` 再 `queue_free`：单靠 queue_free 它们要到帧末才
	##    离开容器，本帧的布局会按「新旧都在」排，重复重建时面板会越撑越高。
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_box.add_child(_mk_label("菜单", UiTheme.FS_HEADING, Color("f2e7cd"), true))
	if _sub_text != "":
		_box.add_child(_mk_label(_sub_text, UiTheme.FS_CAPTION, Color("9a958a"), false))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_box.add_child(gap)
	for it: Dictionary in _menu_list():
		var b := Button.new()
		b.text = str(it.get("text", ""))
		b.custom_minimum_size = Vector2(BTN_W, BTN_H)
		b.disabled = bool(it.get("disabled", false))
		var fn: Callable = it.get("fn", Callable())
		var keep := bool(it.get("keep_open", false))
		b.pressed.connect(func():
			_click()
			if fn.is_valid():
				fn.call()
			if keep:
				_rebuild()
			else:
				close())
		# 暗底界面一律 on_dark（本菜单面板就是暗底）
		UiTheme.apply_button(b, bool(it.get("primary", false)), true)
		_box.add_child(b)
	# R261：菜单底部**显示本局种子** —— 玩家随时按 Esc 抄下 10 位码，
	# 下次在角色选择页填进去就能复现这一局。只在进行中的对局里显示。
	if RunState.run_active:
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 4)
		_box.add_child(sp)
		_box.add_child(_mk_label("种子：%s" % RunState.seed_text(),
				UiTheme.FS_CAPTION, Color("a89a6e"), false))


func _mk_label(text: String, fs: int, col: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.font_bold() if bold else UiTheme.font())
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l
