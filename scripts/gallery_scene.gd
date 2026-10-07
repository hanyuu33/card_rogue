extends Control
## 卡牌图鉴 —— 浏览全部卡牌（cards.json + 新手/教程专属卡）。
##
## 布局（设计坐标 1280x720，canvas_items 拉伸自适应）：
##   顶栏：标题 + 数量 + 返回标题
##   左栏：筛选（种类 / 费用 / 关键词）
##   中间：卡牌网格（滚动），点选高亮
##   右栏：大卡详情（卡面 + 数值 + 效果文本）

const WINDOW_W := 1280.0
const WINDOW_H := 720.0

const GRID_X := 232.0
const GRID_Y := 52.0
const GRID_W := 756.0
const CELL_W := 86.0     # 卡 76x92 + 间隙
const CELL_H := 102.0
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

var _font: SystemFont
var _font_bold: SystemFont

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
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font.font_names
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
	$DetailPanel.draw.connect(_on_detail_draw)
	# 命令行 -- --group enemy：直接打开敌人图鉴（演示 / 截图用）
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--group" and i + 1 < args.size() and str(args[i + 1]) == "enemy":
			enemy_tab.button_pressed = true
	_rebuild_kinds()
	_apply_filters()
	# 命令行 -- --screenshot：打开后自动截图退出（视觉验证用）
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_gallery.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_selected = _shown[0] if not _shown.is_empty() else null
	_refresh_detail()
	grid.queue_redraw()


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
	if _group == "enemy":
		return ["全部", "盟友", "工事", "场地", "关卡效果"]
	return ["全部", "盟友", "技能", "效果", "工事", "场地"]


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


# ------------------------------------------------------------ 网格绘制

func _on_grid_draw() -> void:
	var cols := int(GRID_W / CELL_W)
	for i in _shown.size():
		var r := i / cols
		var col := i % cols
		var rect := Rect2(col * CELL_W + (CELL_W - CARD_W) / 2.0,
				r * CELL_H + 4, CARD_W, CARD_H)
		CardFace.draw(grid, _shown[i], rect, _shown[i].health,
				_shown[i] == _selected, false, _font, _font_bold)


func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position + Vector2(0, scroll.scroll_vertical)
		var cols := int(GRID_W / CELL_W)
		var col := int(pos.x / CELL_W)
		var r := int((pos.y - 4) / CELL_H)
		if col >= 0 and col < cols and r >= 0:
			var idx := r * cols + col
			if idx < _shown.size():
				_selected = _shown[idx]
				_refresh_detail()
				grid.queue_redraw()


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
	var cls_txt: String = c.card_class if c.card_class != "" else "无归属"
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
	get_tree().change_scene_to_file("res://scenes/title.tscn")


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
