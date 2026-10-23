extends Control
## 卡牌图鉴 —— 浏览全部卡牌（cards.json + 新手/教程专属卡）。
##
## 布局（设计坐标 1280x720，canvas_items 拉伸自适应）：
##   顶栏：标题 + 数量 + 返回标题
##   左栏：筛选（种类 / 费用 / 关键词）
##   中间：卡牌网格（滚动），点选高亮
##   右栏：大卡详情（卡面 + 数值 + 效果文本）

const UiTheme = preload("res://scripts/ui_theme.gd")

const WINDOW_W := 1280.0
const WINDOW_H := 720.0

const GRID_X := 232.0
const GRID_Y := 52.0
const GRID_W := 756.0
# 卡 76x92 + 间隙。R117：间隙必须装得下**骑在框上的数值**
# （UiTheme.CARD_BLEED × k = 9.2 × 1.314 ≈ 12.1 → 单元格至少 76+24.2 / 92+24.2）。
# 取 101/117：列数 `int(756/101) = 7`，仍是 7 列（与 R115 相同）。
const CELL_W := 101.0
const CELL_H := 117.0
const CARD_W := 76.0
const CARD_H := 92.0
const DETAIL_X := 1000.0

var repo: CardRepo
var _all: Array[CardData] = []
var _shown: Array[CardData] = []
var _selected = null             # CardData or null

var _group := "player"           # 图鉴分组：player=玩家卡牌图鉴 / enemy=敌人图鉴
var _kind_filter := "全部"
var _cost_filter := 0            # 0=全部，1..5=费用，6=5+
var _search := ""
var _class_filter := "全部"       # R77：按职业查找（"" = 无归属 / 通用）

var _menu: UiMenu = null      # Esc 主菜单（R148）
var _shot_scroll := 0         # R325：出图前先滚到这个位置（`--scroll N`，视觉验证用）

var _font: Font
var _font_bold: Font

@onready var title_label: Label = $TopBar/TitleLabel
@onready var player_tab: Button = $TopBar/PlayerTab
@onready var enemy_tab: Button = $TopBar/EnemyTab
@onready var hint_label: Label = $LeftPanel/Hint
@onready var kind_opt: OptionButton = $LeftPanel/KindOpt
@onready var cost_opt: OptionButton = $LeftPanel/CostOpt
@onready var class_opt: OptionButton = $LeftPanel/ClassOpt
@onready var search_edit: LineEdit = $LeftPanel/SearchEdit
@onready var count_label: Label = $TopBar/CountLabel
@onready var back_btn: Button = $TopBar/BackBtn
@onready var scroll: ScrollContainer = $Scroll
@onready var grid: Control = $Scroll/Grid
@onready var detail_name: Label = $DetailPanel/NameLabel
@onready var detail_kind: Label = $DetailPanel/KindLabel
@onready var detail_stats: Label = $DetailPanel/StatsLabel
@onready var detail_traits: Label = $DetailPanel/TraitsLabel
@onready var detail_text: Label = $DetailPanel/TextLabel
@onready var detail_badge: Label = $DetailPanel/TargetBadge


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	# R325：**字体统一换成工程内嵌的思源黑体**。
	# 场景里那套 `SystemFont("Microsoft YaHei UI" / "SimHei")` 是给 Windows 用的，
	# 安卓上这几个字体名**一个都不存在** —— 手机上不是豆腐块就是取不到字形
	# （进图鉴黑屏的嫌疑之一，另一个是一次画 258 张卡的绘制 / 字形压力，见 _on_grid_draw）。
	_apply_project_fonts(self)
	# R113：图鉴页底色 #E9E7E2 = 亮底 → 浅底 chip；两个 tab 是 toggle，选中态由 button_pressed 驱动
	for _b: Button in [player_tab, enemy_tab, back_btn]:
		UiTheme.apply_chip(_b, false)
	# R154：左 / 右栏默认冷灰 Panel → 羊皮纸面板（清单 §2.5；顶栏保持默认，压住页面即可）
	UiTheme.apply_paper_panel($LeftPanel)
	UiTheme.apply_paper_panel($DetailPanel)
	# ⚠️ 面板里的 Label 默认是**白字**（给默认深灰 Panel 配的）→ 纸面上必须改墨色
	for lb: Label in [$LeftPanel/KindTitle, $LeftPanel/CostTitle, $LeftPanel/ClassTitle,
			$LeftPanel/SearchTitle, $LeftPanel/Hint]:
		lb.add_theme_color_override("font_color", UiTheme.INK_600)
	detail_name.add_theme_color_override("font_color", UiTheme.INK_900)
	detail_kind.add_theme_color_override("font_color", UiTheme.INK_600)
	detail_stats.add_theme_color_override("font_color", UiTheme.INK_800)
	detail_traits.add_theme_color_override("font_color", UiTheme.INK_600)
	detail_text.add_theme_color_override("font_color", UiTheme.INK_800)
	repo = CardRepo.load_json()
	_all = repo.all_cards()
	for t: String in ["费用不限", "1 费", "2 费", "3 费", "4 费", "5 费+"]:
		cost_opt.add_item(t)
	_rebuild_classes()
	kind_opt.item_selected.connect(_on_kind_changed)
	cost_opt.item_selected.connect(_on_cost_changed)
	class_opt.item_selected.connect(_on_class_changed)
	search_edit.text_changed.connect(_on_search_changed)
	back_btn.pressed.connect(_on_back)
	player_tab.toggled.connect(_on_group_toggled.bind("player"))
	enemy_tab.toggled.connect(_on_group_toggled.bind("enemy"))
	grid.draw.connect(_on_grid_draw)
	grid.gui_input.connect(_on_grid_input)
	# R325：`_on_grid_draw` 现在**只画可见行** —— 滚动后必须重画，否则新露出来的那几行
	# 是空白（绘制的坐标变换会跟着滚动走，但 `_draw` 不会自动重跑）。
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float): grid.queue_redraw())
	$DetailPanel.draw.connect(_on_detail_draw)
	# 命令行 -- --group enemy：直接打开敌人图鉴（演示 / 截图用）
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--group" and i + 1 < args.size() and str(args[i + 1]) == "enemy":
			enemy_tab.button_pressed = true
		# R325：`--scroll N` 出图前先滚到 N —— 可见行裁剪之后要证明「滚下去照样画」。
		if args[i] == "--scroll" and i + 1 < args.size():
			_shot_scroll = int(args[i + 1])
	_rebuild_kinds()
	_apply_filters()
	# 命令行 -- --screenshot：打开后自动截图退出（视觉验证用）
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			if _shot_scroll > 0:
				scroll.scroll_vertical = _shot_scroll
				await get_tree().process_frame
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_gallery.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_selected = _shown[0] if not _shown.is_empty() else null
	# 命令行 -- --card <id>：详情直接选中指定卡（出图核验卡面 / 字段行用，与 battle 的
	# `--r119card <id>` 同类）。R211 加：填充 9146 挂「次元」后靠它核对卡面确实写了字段。
	for ai in args.size():
		if args[ai] == "--card" and ai + 1 < args.size():
			var want_id := int(args[ai + 1])
			for gi in _shown.size():
				if (_shown[gi] as CardData).id == want_id:
					_selected = _shown[gi]
					break
	_refresh_detail()
	grid.queue_redraw()
	# R148：Esc 主菜单（图鉴页没有 sfx → 菜单里不给音效项）
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续看图鉴",
		"sub": "卡图鉴 · 按 Esc 返回",
	})


func _menu_items() -> Array:
	## 本界面的 Esc 菜单项（R148）。图鉴页**没有音效开关**（本场景没建 Sfx）→ 只给返回标题。
	return [
		{"text": "返回标题", "fn": _on_back},
	]


func _unhandled_input(event: InputEvent) -> void:
	# R148：Esc = 主菜单（菜单开着时它自己关掉自己）
	if _menu != null and _menu.handle_esc(event):
		return


func _group_title() -> String:
	## 顶栏/计数用的分组名（敌人图鉴要显式带上「关卡效果」）。
	return "玩家卡牌图鉴" if _group == "player" else "敌人图鉴（含敌方关卡效果）"


func _hint_text() -> String:
	if _group == "enemy":
		return "敌方单位 + 敌方关卡效果（开局即挂在敌方效果区持续生效）。\n左键点卡牌查看详情"
	return "玩家卡牌：初始卡组 / 奖励池 / 事件卡 / 衍生物。\n左键点卡牌查看详情"


func _kind_options() -> Array:
	## 敌人图鉴把「效果」这类卡单独叫「关卡效果」（它们只作为关卡脚本挂在敌方效果区）。
	## R77：补上「场地」—— R74 把陷阱类卡改成了新卡种，图鉴里之前**根本选不到它们**。
	## R223：玩家图鉴补「诅咒」（难度 5 的「疲惫」9149 走这个新卡种）。
	if _group == "enemy":
		return ["全部", "盟友", "工事", "场地", "关卡效果"]
	return ["全部", "盟友", "技能", "效果", "工事", "场地", "诅咒"]


func _rebuild_classes() -> void:
	## R77：职业下拉。选项从**卡库实际出现过的 class 值**动态汇总（去重、排序），
	## 这样以后新增角色不用改这里；"无归属" 对应 class 为空的卡。
	var names: Array[String] = []
	for c in _all:
		var cn: String = c.card_class
		if cn == "" or names.has(cn):
			continue
		names.append(cn)
	names.sort()
	class_opt.clear()
	class_opt.add_item("全部")
	class_opt.add_item("无归属")
	for cn2 in names:
		class_opt.add_item(cn2)
	class_opt.select(0)
	_class_filter = "全部"


func _match_class(c: CardData) -> bool:
	## 职业筛选（R77）。"全部" 放行；"无归属" 只放行 class 为空的卡。
	if _class_filter == "全部":
		return true
	if _class_filter == "无归属":
		return c.card_class == ""
	return c.card_class == _class_filter


func _rebuild_kinds() -> void:
	kind_opt.clear()
	for t in _kind_options():
		kind_opt.add_item(str(t))
	kind_opt.select(0)
	_kind_filter = "全部"
	title_label.text = "卡牌图鉴"
	hint_label.text = _hint_text()


func _match_kind(c: CardData) -> bool:
	if _kind_filter == "全部":
		return true
	if _kind_filter == "关卡效果":
		return c.is_level_effect()
	return c.kind == _kind_filter


func _kind_label(c: CardData) -> String:
	return "关卡效果" if c.is_level_effect() else c.kind


func _set_group(g: String) -> void:
	_group = g
	_rebuild_kinds()
	_apply_filters()
	_refresh_detail()


func _apply_filters() -> void:
	_shown.clear()
	for c in _all:
		if c.group != _group:
			continue
		if not _match_kind(c):
			continue
		if not _match_class(c):
			continue
		if _cost_filter > 0:
			if _cost_filter < 5 and c.cost != _cost_filter:
				continue
			if _cost_filter == 5 and c.cost < 5:   # 5 费+
				continue
		if _search != "" and not c.card_name.contains(_search):
			continue
		_shown.append(c)
	count_label.text = "%s · 共 %d 种卡牌" % [_group_title(), _shown.size()]
	# 网格内容尺寸随结果数量变化（滚动）
	var cols := int(GRID_W / CELL_W)
	var rows := int(ceil(_shown.size() / float(cols)))
	grid.custom_minimum_size = Vector2(GRID_W, maxf(rows * CELL_H, WINDOW_H - GRID_Y - 8))
	grid.queue_redraw()
	if not _shown.is_empty() and (_selected == null or not _shown.has(_selected)):
		_selected = _shown[0]
		_refresh_detail()


func _apply_project_fonts(n: Node) -> void:
	## 递归把控件上的**字体 override** 换成工程字体。
	## 只动「字体」这一项，字号 / 颜色 / 对齐等 override 原样保留 ——
	## 场景文件里写死的 SystemFont 会被 `add_theme_font_override` 顶掉。
	if n is Control:
		var c := n as Control
		for key: StringName in [&"font", &"normal_font", &"bold_font"]:
			if c.has_theme_font_override(key):
				c.add_theme_font_override(key, _font)
	for ch in n.get_children():
		_apply_project_fonts(ch)


func _cell_rect(i: int) -> Rect2:
	## 第 i 张卡在**网格自身坐标系**里的矩形 —— 绘制与点击共用这一口。
	## ⚠️ R325：以前两处各算一遍，命中那边还多加了一次 `scroll.scroll_vertical`
	## （ScrollContainer 是靠移动子节点位置的，`gui_input` 的坐标里已经含滚动量），
	## 于是往下滚之后点到的永远是上面几行的卡。共用函数 + 不加偏移是唯一的解。
	var cols := int(GRID_W / CELL_W)
	return Rect2((i % cols) * CELL_W + (CELL_W - CARD_W) / 2.0,
			(i / cols) * CELL_H + (CELL_H - CARD_H) / 2.0, CARD_W, CARD_H)


# ------------------------------------------------------------ 网格绘制

func _on_grid_draw() -> void:
	## ⚠️ R325：**只画看得见的那几行**。
	## 图鉴最多 258 张卡（7 列 = 37 行）：以前一次全画，每帧上千条绘制命令，
	## 几百个卡名 / 效果文的字形都要进动态字体图集 —— 安卓上直接把纹理内存撑爆
	## （用户实测「进图鉴直接黑屏」），PC 上滚起来也发卡。
	## 卡面尺寸 76×92，每行 CELL_H = 117，所以只留上下各一行余量就够。
	var top := float(scroll.scroll_vertical) - CELL_H
	var bottom := float(scroll.scroll_vertical) + scroll.size.y + CELL_H
	for i in _shown.size():
		var rect := _cell_rect(i)
		if rect.end.y < top or rect.position.y > bottom:
			continue
		CardFace.draw(grid, _shown[i], rect, _shown[i].health,
				_shown[i] == _selected, false, _font, _font_bold)


func _on_grid_input(event: InputEvent) -> void:
	## R325：命中判定改成**逐张卡的矩形**，与绘制共用 `_cell_rect()`。
	## ⚠️ 之前那句「event.position 再加一次竖向滚动量」是**重复补偿**：
	## ScrollContainer 靠移动子节点位置实现滚动，`gui_input` 收到的局部坐标已经含滚动量，
	## 于是往下滚多少、就点错多少行（用户报「点不中 / 选中了别的卡」）。
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# 用**事件自带**的坐标：`gui_input` 收到的 position 已经是网格自身坐标系
		# （ScrollContainer 靠移动子节点滚动，坐标里天然含滚动量），
		# 而且触摸 / 笔 / 鼠标三种来源走的是同一条通道。
		var pos: Vector2 = (event as InputEventMouseButton).position
		for i in _shown.size():
			# grow(5)：卡与卡之间有一条 25×25 的缝（CELL 101/117 减卡 76/92），
			# 点在缝里也该算中这一张，不然看着点准了却没反应。
			if _cell_rect(i).grow(5.0).has_point(pos):
				_selected = _shown[i]
				_refresh_detail()
				grid.queue_redraw()
				return


# ------------------------------------------------------------ 详情面板

func _on_detail_draw() -> void:
	## 详情面板底部的大卡面（放大 132x160，走共享 CardFace 绘制）
	if _selected == null:
		return
	CardFace.draw($DetailPanel, _selected, Rect2(70, 445, 132, 160),
			_selected.health, false, false, _font, _font_bold)


func _refresh_detail() -> void:
	if _selected == null:
		detail_name.text = "（无卡牌）"
		for l: Label in [detail_kind, detail_stats, detail_traits, detail_text]:
			l.text = ""
		detail_badge.visible = false
		return
	var c: CardData = _selected
	detail_name.text = c.card_name
	# R77：详情里带上职业（图鉴现在支持按职业查了，写出来才看得到筛选是否对）
	# R328：class 留空的卡分两种 —— 公用初始卡（木栅栏/攻击，三职业共用）写「公用初始」，
	# 其余（事件产出 / 诅咒）仍写「无归属」，别让这两类在详情里混成同一个标签。
	var cls_txt: String = c.card_class
	if cls_txt == "":
		cls_txt = "公用初始" if PlayerClass.is_base_common(c.id) else "无归属"
	detail_kind.text = "%s · %s · %d 费 · %s · %s" % [
			"玩家" if _group == "player" else "敌方", _kind_label(c), c.cost,
			c.color, cls_txt]
	detail_stats.text = CardFace.stats_line(c)
	detail_traits.text = "特性：" + ("、".join(PackedStringArray(c.traits)) if not c.traits.is_empty() else "无")
	# R106：图鉴正文同样是「纯文本降级」—— 隐藏「（…）」补注、去掉 `**加粗**` 标记，
	# 免得 Label 里出现裸星号（这里是 Label 不是 RichTextLabel，用 naturalize 而非 bbcode）。
	detail_text.text = CardText.naturalize(c.effect_text)
	# 编号附在名字后
	detail_name.text = "%s（#%d）" % [c.card_name, c.id]
	detail_badge.visible = c.needs_target()
	detail_badge.text = "需要选择目标"
	$DetailPanel.queue_redraw()


# ------------------------------------------------------------ 信号

func _on_back() -> void:
	SceneFx.goto("res://scenes/title.tscn")


func _on_group_toggled(on: bool, g: String) -> void:
	## 顶部两个页签互斥（ButtonGroup），只处理「被按下」的那次。
	if on:
		_set_group(g)


func _on_kind_changed(idx: int) -> void:
	_kind_filter = kind_opt.get_item_text(idx)
	_apply_filters()


func _on_cost_changed(idx: int) -> void:
	_cost_filter = idx  # 0=全部 1..4, 5=5费+
	_apply_filters()


func _on_class_changed(idx: int) -> void:
	## R77：按职业查找。
	_class_filter = class_opt.get_item_text(idx)
	_apply_filters()


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges()
	_apply_filters()
