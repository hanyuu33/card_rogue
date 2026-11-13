extends Control
## 卡牌图鉴 —— 浏览全部卡牌（cards.json + 新手/教程专属卡）。
##
## 布局（设计坐标 1280x720，canvas_items 拉伸自适应）：
##   顶栏：标题 + 数量 + 返回标题
##   左栏：筛选（种类 / 费用 / 关键词）
##   中间：卡牌网格（滚动），点选高亮
##   右栏：大卡详情（卡面 + 数值 + 效果文本）

const UiTheme = preload("res://scripts/ui_theme.gd")
const UiRoute = preload("res://scripts/ui_route.gd")

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

## R641：费用档选项表 —— **索引即选项顺序**，不再与「费用值」画等号。
## 原版第一档是「1 费」，0 费卡（哈气 9024 / 生命循环 9150 / 灵魂收割者 9077…）
## 在任何费用档里都查不到，玩家只能翻「费用不限」自己数。补一档「0 费」。
const COST_OPTIONS: Array[String] = ["费用不限", "0 费", "1 费", "2 费", "3 费", "4 费", "5 费+"]
const COST_FIRST := 1            # 第一个「具体费用」档 = 0 费 → 该档 cost == idx - COST_FIRST
const COST_OPEN := 6             # 最后一档 = 5 费以上

## R669：图鉴左栏说明最少行数（按权威文案实测，切换分组时面板不跳动）。
const HINT_MIN_LINES := {"ja": 5, "en": 6, "es": 8}
const HINT_FALLBACK_LINES := 8
const HINT_BOTTOM_PAD := 14.0
const HINT_LINE_H := 19.0            # 1280x720 窗口实测行距（像素）

var repo: CardRepo
var _all: Array[CardData] = []
var _shown: Array[CardData] = []
var _selected = null             # CardData or null

var _group := "player"           # 图鉴分组：player=玩家卡牌图鉴 / enemy=敌人图鉴
var _kind_filter := "全部"
var _cost_filter := 0            # 选中项索引（语义见 COST_OPTIONS / _cost_match）
var _search := ""
var _search_lc := ""             # R631：小写化后的搜索词（中文不变，`HP` / `hp` 要能互通）
var _search_pool: Dictionary = {}   # R631：id -> 可搜索文本（含空格版，见 _build_search_index）
var _search_flat: Dictionary = {}   # R631：id -> 去空白版（搜「聚能 炮击」也能中）
var _text_only_hits := 0         # R631：卡名不含、只在效果文 / 特性 / 字段里命中的张数
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
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
	UiTheme.bleed_child($BG)     # 底色整屏铺满（不跟着舞台缩，否则两侧露黑）
	UiTheme.stretch_topbar($TopBar)   # R519b：顶栏通屏宽，右侧按钮组贴窗口右缘
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
	_build_search_index()   # R631：搜索索引只在载入时建一次
	for t: String in COST_OPTIONS:
		cost_opt.add_item(GameI18n.source(t))
	_rebuild_classes()
	kind_opt.item_selected.connect(_on_kind_changed)
	cost_opt.item_selected.connect(_on_cost_changed)
	class_opt.item_selected.connect(_on_class_changed)
	search_edit.text_changed.connect(_on_search_changed)
	# R590：返回按钮文案跟着去向走（从百科进来就写「返回百科」）。
	back_btn.text = GameI18n.ui("map", "GALLERY_BACK_CODEX", "← 返回百科") if UiRoute.has_back() else GameI18n.ui("map", "GALLERY_BACK_TITLE", "← 返回标题")
	player_tab.text = GameI18n.ui("map", "GALLERY_TAB_PLAYER", "玩家卡牌图鉴")
	enemy_tab.text = GameI18n.ui("map", "GALLERY_TAB_ENEMY", "敌人图鉴")
	$LeftPanel/KindTitle.text = GameI18n.ui("map", "GALLERY_FILTER_KIND", "种类")
	$LeftPanel/CostTitle.text = GameI18n.ui("map", "GALLERY_FILTER_COST", "费用")
	$LeftPanel/ClassTitle.text = GameI18n.ui("map", "GALLERY_FILTER_CLASS", "职业")
	$LeftPanel/SearchTitle.text = GameI18n.ui("map", "GALLERY_SEARCH_TITLE", "搜索")
	search_edit.placeholder_text = GameI18n.ui("map", "GALLERY_SEARCH_PLACEHOLDER", "输入卡名 / 效果文…")
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
		# R631：`--search 词` 出图 / 探针前先填搜索框（验收「搜效果文能命中」用）。
		# ⚠️ 程序赋值 `text` 不保证发 `text_changed`（实测 4.3 里不发）→ 必须显式调一次，
		# 否则 `_search_lc` 还是空串、等于没搜（这个坑踩过，见 tools/probe_r631_search.gd）。
		if args[i] == "--search" and i + 1 < args.size():
			search_edit.text = str(args[i + 1])
			_on_search_changed(str(args[i + 1]))
		# R641：`--cost N` 出图 / 验收前先选费用档（N = 费用值：0..4 精确档，5 及以上 = 5 费+）。
		# 与 `--search` 同一条纪律：`OptionButton.select()` **不发** `item_selected`，必须显式调一次。
		if args[i] == "--cost" and i + 1 < args.size():
			var cv := clampi(int(args[i + 1]), 0, 5)
			var ci: int = COST_OPEN if cv >= 5 else COST_FIRST + cv
			cost_opt.select(ci)
			_on_cost_changed(ci)
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
		"back": GameI18n.ui("map", "GALLERY_MENU_BACK", "继续看图鉴"),
		"sub": "卡图鉴",
	})


func _menu_items() -> Array:
	## 本界面的 Esc 菜单项（R148）。图鉴页**没有音效开关**（本场景没建 Sfx）→ 只给返回标题。
	return [
		# R590：文案跟着去向走，行为不变。
		{"text": func(): return GameI18n.ui("map", "GALLERY_MENU_RETURN_CODEX", "返回百科") if UiRoute.has_back() else GameI18n.ui("map", "GALLERY_MENU_RETURN_TITLE", "返回标题"),
					"fn": _on_back},
	]


func _unhandled_input(event: InputEvent) -> void:
	# R148：Esc = 主菜单（菜单开着时它自己关掉自己）
	if _menu != null and _menu.handle_esc(event):
		return


func _group_title() -> String:
	## 顶栏/计数用的分组名（敌人图鉴要显式带上「关卡效果」）。
	return GameI18n.ui("map", "GALLERY_GROUP_PLAYER", "玩家卡牌图鉴") if _group == "player" else GameI18n.ui("map", "GALLERY_GROUP_ENEMY", "敌人图鉴（含敌方关卡效果）")


func _hint_text() -> String:
	if _group == "enemy":
		return GameI18n.ui("map", "GALLERY_HINT_ENEMY", "敌方单位 + 敌方关卡效果（开局即挂在敌方效果区持续生效）。\n搜索匹配卡名 / 效果文 / 特性。\n左键点卡牌查看详情")
	return GameI18n.ui("map", "GALLERY_HINT_PLAYER", "玩家卡牌：初始卡组 / 奖励池 / 事件卡 / 衍生物。\n搜索匹配卡名 / 效果文 / 特性。\n左键点卡牌查看详情")


func _kind_options() -> Array:
	## 敌人图鉴把「效果」这类卡单独叫「关卡效果」（它们只作为关卡脚本挂在敌方效果区）。
	## R77：补上「场地」—— R74 把陷阱类卡改成了新卡种，图鉴里之前**根本选不到它们**。
	## R223：玩家图鉴补「诅咒」（难度 5 的「疲惫」9149 走这个新卡种）。
	if _group == "enemy":
		return [GameI18n.ui("map", "GALLERY_KIND_ALL", "全部"), GameI18n.ui("map", "GALLERY_KIND_ALLY", "盟友"), GameI18n.ui("map", "GALLERY_KIND_STRUCTURE", "工事"), GameI18n.ui("map", "GALLERY_KIND_FIELD", "场地"), GameI18n.ui("map", "GALLERY_KIND_LEVEL_EFFECT", "关卡效果")]
	return [GameI18n.ui("map", "GALLERY_KIND_ALL", "全部"), GameI18n.ui("map", "GALLERY_KIND_ALLY", "盟友"), GameI18n.ui("map", "GALLERY_KIND_SKILL", "技能"), GameI18n.ui("map", "GALLERY_KIND_EFFECT", "效果"), GameI18n.ui("map", "GALLERY_KIND_STRUCTURE", "工事"), GameI18n.ui("map", "GALLERY_KIND_FIELD", "场地"), GameI18n.ui("map", "GALLERY_KIND_CURSE", "诅咒")]


func _kind_values() -> Array:
	if _group == "enemy":
		return ["全部", "盟友", "工事", "场地", "关卡效果"]
	return ["全部", "盟友", "技能", "效果", "工事", "场地", "诅咒"]


func _rebuild_classes() -> void:
	## R77：职业下拉。选项从**卡库实际出现过的 class 值**动态汇总（去重、排序），
	## 这样以后新增角色不用改这里；"无归属" 对应 class 为空的卡。
	## R642：发布版只汇总「见过」的卡（不然下拉框会先说漏有新职业）。
	var names: Array[String] = []
	for c in _all:
		if not _visible(c):
			continue
		var cn: String = c.card_class
		if cn == "" or names.has(cn):
			continue
		names.append(cn)
	names.sort()
	class_opt.clear()
	class_opt.add_item(GameI18n.ui("map", "GALLERY_CLASS_ALL", "全部"))
	class_opt.set_item_metadata(0, "全部")
	class_opt.add_item(GameI18n.ui("map", "GALLERY_CLASS_NONE", "无归属"))
	class_opt.set_item_metadata(1, "无归属")
	for cn2 in names:
		class_opt.add_item(GameI18n.class_name_of(cn2))
		class_opt.set_item_metadata(class_opt.item_count - 1, cn2)
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
	var values := _kind_values()
	var labels := _kind_options()
	for i in labels.size():
		kind_opt.add_item(str(labels[i]))
		kind_opt.set_item_metadata(i, values[i])
	kind_opt.select(0)
	_kind_filter = "全部"
	title_label.text = GameI18n.ui("map", "GALLERY_TITLE", "卡牌图鉴")
	UiTheme.autoshrink_label(title_label, title_label.text, 20, 12, Vector2(136.0, 26.0))
	hint_label.text = _hint_text()
	call_deferred("_fit_hint_panel")


func _fit_hint_panel() -> void:
	## R669：图鉴左栏说明按语言撑高，避免长译文落到羊皮纸框外。
	## 根因：gallery.tscn 里 Hint 的 rect 底边（相对面板 402）本来就比
	## LeftPanel 底边（412 - 52 = 360）低 42px；中文 4 行看不出来，
	## 英 / 西 6~8 行自动换行后整段画到框外。中文维持场景原值不动。
	if GameI18n.language() == "zh":
		return
	var lang := GameI18n.language()
	var lines := maxi(hint_label.get_line_count(), int(HINT_MIN_LINES.get(lang, HINT_FALLBACK_LINES)))
	var panel: Panel = $LeftPanel
	# minsize 由引擎按当前字体与 autowrap 算好；再用实测行数兜一层下限，
	# 避免 headless / 窗口字体度量差异或 enemy 页 minsize 尚未刷新时算小。
	var text_h := maxf(float(hint_label.get_minimum_size().y), float(lines) * HINT_LINE_H)
	var need := panel.offset_top + hint_label.offset_top + text_h + HINT_BOTTOM_PAD
	panel.offset_bottom = maxf(panel.offset_bottom, need)
	hint_label.offset_bottom = panel.offset_bottom - panel.offset_top - 8.0


func _match_kind(c: CardData) -> bool:
	if _kind_filter == "全部":
		return true
	if _kind_filter == "关卡效果":
		return c.is_level_effect()
	return c.kind == _kind_filter


func _kind_label(c: CardData) -> String:
	if c.is_level_effect():
		return GameI18n.ui("map", "GALLERY_DETAIL_KIND_LEVEL_EFFECT", "关卡效果")
	match c.kind:
		"盟友":
			return GameI18n.ui("map", "GALLERY_KIND_ALLY", "盟友")
		"技能":
			return GameI18n.ui("map", "GALLERY_KIND_SKILL", "技能")
		"效果":
			return GameI18n.ui("map", "GALLERY_KIND_EFFECT", "效果")
		"工事":
			return GameI18n.ui("map", "GALLERY_KIND_STRUCTURE", "工事")
		"场地":
			return GameI18n.ui("map", "GALLERY_KIND_FIELD", "场地")
		"诅咒":
			return GameI18n.ui("map", "GALLERY_KIND_CURSE", "诅咒")
	return c.kind


func _set_group(g: String) -> void:
	_group = g
	_rebuild_kinds()
	_apply_filters()
	_refresh_detail()


# ------------------------------------------------------------ 解锁（R642）
#
# 店长口径：**发布版**图鉴只列「见过」的卡 —— 没见过的连条目都没有、搜也搜不到；
# 全卡开（测试版）时全部位置都排出来，没见过的画成一张**通用未解锁图**。
# 「见过」的记账在 `CardFace.draw() / draw_pick()`（唯一口），见 `ProfileData`。

static func gallery_visible(c: CardData, release_mode: bool) -> bool:
	## R642：图鉴可见性的**唯一判据**。抽成静态是为了测试能直接调
	## （`preload("res://scripts/gallery_scene.gd").gallery_visible(card, true)`），
	## 不必把整个场景实例化起来才能验一条布尔。
	if release_mode and not ProfileData.is_card_seen(c.id):
		return false
	return true


func _visible(c: CardData) -> bool:
	## 这张卡在当前版本的图鉴里**存不存在**。
	return gallery_visible(c, GameBuild.is_release())


func _locked(c: CardData) -> bool:
	## 只有全卡开才可能为真：位置排出来了，但玩家还没见过 → 遮蔽成通用图。
	## 发布版里未见的卡在 `_visible()` 就被挡掉，走不到这里。
	return not ProfileData.is_card_seen(c.id)


func _has_active_filter() -> bool:
	## 有任何筛选 / 搜索在用 → 未解锁的占位卡全部退出结果。
	## 口径是「不能搜到」，筛选同理：一搜「机械」就把未知卡带出来，等于报答案。
	## 所以未知卡**只**在「什么都不筛」的默认视图里占位，告诉玩家还差多少。
	return (_search_lc != "" or _kind_filter != "全部"
			or _class_filter != "全部" or _cost_filter != 0)


func _group_counts() -> Array[int]:
	## [该分组总张数, 已见过张数] —— 顶栏「已收集 X / Y」用。
	var total := 0
	var seen := 0
	for c in _all:
		if c.group != _group:
			continue
		total += 1
		if ProfileData.is_card_seen(c.id):
			seen += 1
	return [total, seen]


# ------------------------------------------------------------ 搜索（R631）

func _build_search_index() -> void:
	## R631：搜索索引 —— 图鉴搜索从「只认卡名」扩成
	## 「卡名 + 效果正文 + 特性 / 字段 / 种类 / 职业」。
	## 为什么预建而不是每次按键现算：`CardText.parse` 自带缓存，但 316 张卡 × 每次
	## `text_changed` 都要重新拼串 + 归一，安卓输入法连续上屏时是实打实的卡顿；
	## 索引只在载入时建一次，之后每次按键只是 316 次 `contains`。
	_search_pool.clear()
	_search_flat.clear()
	for c in _all:
		if not _visible(c):
			continue   # R642：没见过的卡不进索引 —— 从源头上就搜不到
		var blob := _search_blob(c)
		_search_pool[c.id] = blob
		_search_flat[c.id] = blob.replace(" ", "")


func _search_blob(c: CardData) -> String:
	## 一张卡参与搜索的全部文本（小写）。
	## 正文收**两套口径**：
	##   · `CardText.naturalize()` = 玩家在图鉴右栏实际看到的字（去 `**`、剥括号补注、术语归一）；
	##   · `effect_text` 原文 = 括号补注与加粗里的字也能搜到（如「不分敌我」这类补注）；
	## 特性 / 字段也收：卡面正文里通常不写「机械」「嘲讽」这些词，
	## 但玩家搜种族、搜字段是再自然不过的用法。
	var parts := PackedStringArray()
	parts.append(c.card_name)
	parts.append(GameI18n.card_name(c.id, c.card_name))
	parts.append(CardText.naturalize(c.effect_text))
	parts.append(c.effect_text)
	parts.append(GameI18n.card_effect(c.id, c.effect_text))
	parts.append(c.kind)
	parts.append(_kind_label(c))
	parts.append(c.card_class)
	parts.append(GameI18n.class_name_of(c.card_class))
	for t in c.traits:
		parts.append(str(t))
		parts.append(GameI18n.source(str(t)))
	for a in c.affixes:
		parts.append(str(a))
		parts.append(CardData.affix_label(str(a)))
	return " ".join(parts).to_lower()


func _match_search(c: CardData) -> bool:
	## 搜索命中（R631）。空词放行。
	if _search_lc == "":
		return true
	var blob := str(_search_pool.get(c.id, ""))
	if blob == "":
		# 索引里没有（理论上不会发生）→ 退化成老口径「只认卡名」，绝不放行全部
		return c.card_name.to_lower().contains(_search_lc)
	if blob.contains(_search_lc):
		return true
	var q_flat := _search_lc.replace(" ", "")
	if q_flat != _search_lc:
		return str(_search_flat.get(c.id, "")).contains(q_flat)
	return false


func _match_name(c: CardData) -> bool:
	## 卡名是否直接含搜索词 —— 只用来计数，区分「名字里有」和「只在效果文里有」。
	if _search_lc == "":
		return true
	var n := (c.card_name + " " + GameI18n.card_name(c.id, c.card_name)).to_lower()
	return n.contains(_search_lc) or n.contains(_search_lc.replace(" ", ""))


func _cost_match(c: CardData, idx: int) -> bool:
	## 费用档的**唯一判据**（R641）。`idx` 是下拉框索引，**不是**费用值 ——
	## 加了「0 费」这一档后索引整体右移一位，再按「idx == cost」写会整列错一行。
	## 口径（与卡面 / R521 一致）：
	##   * 0 = 不限 → 全收（X 费卡只在这里出现）；
	##   * 1..5 = 0..4 费 → 精确匹配；
	##   * 6 = 5 费+ → cost >= 5。
	if idx <= 0:
		return true
	# R521：X 费卡没有固定费用 → 任何费用档都不命中
	if c.x_cost:
		return false
	if idx >= COST_OPEN:
		return c.cost >= 5
	return c.cost == idx - COST_FIRST


func _apply_filters() -> void:
	_shown.clear()
	_text_only_hits = 0
	for c in _all:
		if c.group != _group:
			continue
		# R642：发布版没见过的卡**不存在**于图鉴（因此也搜不到）。
		if not _visible(c):
			continue
		# 全卡开才有的一层：未解锁的只在默认视图占位，一旦筛选 / 搜索就退出。
		if _locked(c) and _has_active_filter():
			continue
		if not _match_kind(c):
			continue
		if not _match_class(c):
			continue
		if not _cost_match(c, _cost_filter):
			continue
		if not _match_search(c):
			continue
		if _search_lc != "" and not _match_name(c):
			_text_only_hits += 1
		_shown.append(c)
	var summary := ""
	if GameBuild.is_release():
		# 发布版：说「收集进度」而不是「卡池总量」—— 玩家看不到没见过的部分，
		# 报总数等于直接告诉他「还有多少张没解锁」，那是另一件事（全卡开才给）。
		var gc := _group_counts()
		summary = GameI18n.ui("map", "GALLERY_SUMMARY_RELEASE", "%s · 已收集 %d / %d") % [_group_title(), int(gc[1]), int(gc[0])]
		if _shown.size() != int(gc[1]):
			summary += GameI18n.ui("map", "GALLERY_SUMMARY_SHOWN", "（显示 %d 张）") % _shown.size()
	else:
		summary = GameI18n.ui("map", "GALLERY_SUMMARY_TEST", "%s · 共 %d 种卡牌") % [_group_title(), _shown.size()]
		var gc2 := _group_counts()
		var unknown_n := int(gc2[0]) - int(gc2[1])
		if unknown_n > 0 and not _has_active_filter():
			summary += GameI18n.ui("map", "GALLERY_SUMMARY_LOCKED", "（其中 %d 张未解锁）") % unknown_n
	# R631：命中的卡里有相当一部分「卡名里没有这个词」——它可能来自效果文，也可能是
	# 特性 / 字段 / 职业（搜「机械」会命中整个机械之心）。文案只说「卡名不含」这个**事实**，
	# 不承诺命中的是哪一处（详情右栏能看到来源），免得玩家以为搜索串了。
	if _search_lc != "" and _text_only_hits > 0:
		summary += "（其中 %d 张卡名不含）" % _text_only_hits
	UiTheme.autoshrink_label(count_label, summary, 14, 11, Vector2(470.0, 24.0))
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
		# R642：全卡开时未解锁的位置画**通用未解锁图**，不泄露卡名 / 数值 / 卡图。
		if _locked(_shown[i]):
			CardFace.draw_locked(grid, rect, _font_bold)
			continue
		# 图鉴自己画卡面**不记**「见过」（`draw_no_record`）——
		# 否则一开图鉴就把全部卡标成见过，这套解锁等于没有。
		CardFace.draw_no_record(grid, _shown[i], rect, _shown[i].health,
				_shown[i] == _selected, _font, _font_bold)


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
	var r := Rect2(70, 445, 132, 160)
	# R642：未解锁的详情也不给看卡面（卡图本身就是最大的剧透）。
	if _locked(_selected):
		CardFace.draw_locked($DetailPanel, r, _font_bold)
		return
	CardFace.draw_no_record($DetailPanel, _selected, r,
			_selected.health, false, _font, _font_bold)


func _refresh_detail() -> void:
	if _selected == null:
		# R642：发布版第一次进图鉴可能是**全空**（一局都没打过 = 一张都没见过）。
		# 这时候必须说清楚「为什么空」，否则玩家会以为图鉴坏了。
		# 文案压在 11 字以内（236px 宽、20 号字），超了会被 Label 撑出框线。
		detail_name.text = GameI18n.ui("map", "GALLERY_EMPTY", "（无卡牌）")
		if GameBuild.is_release():
			detail_name.text = (GameI18n.ui("map", "GALLERY_EMPTY_UNSEEN", "还没见过任何卡牌") if ProfileData.seen_count() == 0
					else GameI18n.ui("map", "GALLERY_EMPTY_FILTERED", "（没有符合条件的卡牌）"))
		for l: Label in [detail_kind, detail_stats, detail_traits, detail_text]:
			l.text = ""
		detail_badge.visible = false
		return
	var c: CardData = _selected
	# R602：**先量框再写字**。这一页的 Label 宽度是场景里写死的（18→254 = 236），
	# 而 Label 的 minimum size 会跟着文本变长 → 长卡名（「量产型阿斯克勒庇厄斯（#9207）」
	# 实测 330px）会把 Label 自己撑宽、直接画到右侧面板的框线外。
	# 现在统一走 `UiTheme.autoshrink_label`：放不下就缩字号（20→13），缩到底才裁。
	# 框尺寸与 `scenes/gallery.tscn` 的 offset 一一对应，改场景时必须同步这里。
	const BX := 236.0
	const B_TITLE := Vector2(BX, 30.0)
	const B_LINE := Vector2(BX, 24.0)
	const B_BODY := Vector2(BX, 230.0)
	# R642：未解锁的卡只报「还没解锁」，卡名 / 种类 / 数值 / 正文一律不写 ——
	# 图鉴的解锁乐趣全在「第一次见到它」那一刻，详情面板不能提前把答案给出来。
	# 只留一句**怎么解锁**，否则玩家会以为这是 Bug。
	if _locked(c):
		UiTheme.autoshrink_label(detail_name, GameI18n.ui("map", "GALLERY_LOCKED_NAME", "？？？"), 20, 13, B_TITLE)
		UiTheme.autoshrink_label(detail_kind, GameI18n.ui("map", "GALLERY_LOCKED_KIND", "未解锁"), 14, 10, B_LINE)
		UiTheme.autoshrink_label(detail_stats, "", 14, 10, B_LINE)
		UiTheme.autoshrink_label(detail_traits, "", 14, 10, B_LINE)
		UiTheme.autoshrink_label(detail_text,
				GameI18n.ui("map", "GALLERY_LOCKED_DESCRIPTION", "在游戏里见过这张卡后，才会收录进图鉴。"), 16, 11, B_BODY)
		detail_badge.visible = false
		$DetailPanel.queue_redraw()
		return
	# R77：详情里带上职业（图鉴现在支持按职业查了，写出来才看得到筛选是否对）
	# R328：class 留空的卡分两种 —— 公用初始卡（木栅栏/攻击，三职业共用）写「公用初始」，
	# 其余（事件产出 / 诅咒）仍写「无归属」，别让这两类在详情里混成同一个标签。
	var cls_txt: String = GameI18n.class_name_of(c.card_class)
	if cls_txt == "":
		cls_txt = GameI18n.ui("map", "GALLERY_CLASS_BASE_COMMON", "公用初始") if PlayerClass.is_base_common(c.id) else GameI18n.ui("map", "GALLERY_DETAIL_CLASS_NONE", "无归属")
	# R600：颜色是内部元数据，玩家不需要在详情里看到；只留阵营 / 种类 / 费用 / 归属。
	UiTheme.autoshrink_label(detail_kind, GameI18n.ui("map", "GALLERY_DETAIL_META", "%s · %s · %d 费 · %s") % [
			GameI18n.ui("map", "GALLERY_DETAIL_PLAYER", "玩家") if _group == "player" else GameI18n.ui("map", "GALLERY_DETAIL_ENEMY", "敌方"), _kind_label(c), c.cost, cls_txt],
			14, 10, B_LINE)
	UiTheme.autoshrink_label(detail_stats, CardFace.stats_line(c), 14, 10, B_LINE)
	var trait_labels := PackedStringArray()
	for trait_name in c.traits:
		trait_labels.append(GameI18n.source(str(trait_name)))
	var trait_separator := "、" if GameI18n.language() in ["zh", "ja"] else ", "
	UiTheme.autoshrink_label(detail_traits,
			GameI18n.ui("map", "GALLERY_DETAIL_TRAITS_PREFIX", "特性：") + (trait_separator.join(trait_labels) if not trait_labels.is_empty() else GameI18n.ui("map", "GALLERY_DETAIL_TRAITS_NONE", "无")),
			14, 10, B_LINE)
	# R106：图鉴正文同样是「纯文本降级」—— 隐藏「（…）」补注、去掉 `**加粗**` 标记，
	# 免得 Label 里出现裸星号（这里是 Label 不是 RichTextLabel，用 naturalize 而非 bbcode）。
	# R602：正文框 236×230 固定 → 长效果文先折行、再缩字号，缩到底才裁。
	UiTheme.autoshrink_label(detail_text, CardText.naturalize(c.effect_text),
			16, 11, B_BODY)
	# 编号附在名字后
	# R632：玩家不需要看到卡牌编号（内部 id）—— 只写卡名。
	UiTheme.autoshrink_label(detail_name, GameI18n.card_name(c.id, c.card_name), 20, 13, B_TITLE)
	detail_badge.visible = c.needs_target()
	UiTheme.autoshrink_label(detail_badge, GameI18n.ui("map", "GALLERY_TARGET_REQUIRED", "需要选择目标"), 14, 10, Vector2(BX, 30.0))
	$DetailPanel.queue_redraw()


# ------------------------------------------------------------ 信号

func _on_back() -> void:
	## R590：从百科进来的 → 退回百科（见 `ui_route.gd` 的说明）。
	var back := UiRoute.take_back()
	SceneFx.goto(back if back != "" else "res://scenes/title.tscn")


func _on_group_toggled(on: bool, g: String) -> void:
	## 顶部两个页签互斥（ButtonGroup），只处理「被按下」的那次。
	if on:
		_set_group(g)


func _on_kind_changed(idx: int) -> void:
	var value: Variant = kind_opt.get_item_metadata(idx)
	_kind_filter = str(value) if value != null else kind_opt.get_item_text(idx)
	_apply_filters()


func _on_cost_changed(idx: int) -> void:
	_cost_filter = idx  # 下拉框索引（语义见 COST_OPTIONS / _cost_match）
	_apply_filters()


func _on_class_changed(idx: int) -> void:
	## R77：按职业查找。
	var value: Variant = class_opt.get_item_metadata(idx)
	_class_filter = str(value) if value != null else class_opt.get_item_text(idx)
	_apply_filters()


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges()
	_search_lc = _search.to_lower()   # R631
	_apply_filters()
