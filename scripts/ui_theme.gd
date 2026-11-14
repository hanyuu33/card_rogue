extends RefCounted
## card_rogue 界面规范（R113）—— 界面**颜色 / 字号 / 字体 / 间距**的唯一来源。
##
## ## ⚠️ 为什么这个文件**故意不写 `class_name`**
## 全工程其它类（CardData / CardFace / RunState …）都用 `class_name`，这个文件是**例外**，
## 原因是 R113 实测出来的：新增 `class_name` 后，headless 的 `--script` / `_verify.py`
## 会报 `Identifier "UiTheme" not declared in the current scope` —— 因为全局类名存在
## `.godot/global_script_class_cache.cfg` 里，而那份缓存**只能由编辑器扫描重建**：
##   · `--headless --editor --quit-after 40` → 输出 `WARNING: Scan thread aborted...`，
##     即退出得比扫描线程早，缓存根本没更新（这也是「别用 `--quit`」那条老坑的成因）；
##   · 手工改 `.godot/` 又是机器本地、不可随 git 传递。
## 所以本文件改用 **`preload`**：消费方写一行
##     `const UiTheme = preload("res://scripts/ui_theme.gd")`
## 就完全不依赖类缓存，`git pull` 到另一台机器也能立刻跑门禁。
##
## 代价：不能写 `var t: UiTheme` 这类类型标注（本文件只提供静态方法与常量，用不到）。
##
## ## 为什么要有这个文件
## R112 界面体检实测：界面层有 **590 处 `Color()` 字面量**（去重 280 种，其中 111 种属 44 个
## 「近重复簇」）、**19 档字号**（215 处设置点，20% 小于 11px）、字体族声明**复制了 14 份**、
## 而 `_font_bold` 其实是**伪粗体**（从未设 `font_weight`，与 `_font` 完全同款）。
## 这些不是「不好看」，是**没有系统** —— 后果是层级失效、改一处要翻几十处、必然漏。
##
## ## 规矩（新增或修改界面代码时必须遵守）
## 1. **字体**：一律 `UiTheme.font()` / `UiTheme.font_bold()`。
##    **不准**再出现 `SystemFont.new()`。
## 2. **颜色**：界面里**不准**再写裸 `Color("xxxxxx")` / `Color(r,g,b)`。
##    需要新颜色 → **先在这里加令牌**，再引用。（白/黑/`Color(1,1,1,0.5)` 这类
##    纯中性色与一次性调试色除外。）
## 3. **字号**：只用下面 7 档 `FS_*`。想要别的尺寸 → 先归到最近的档；
##    确实需要新档，就在本文件加一行并注明用途，别在调用点写数字。
##    **卡面例外**：卡面字号随卡牌尺寸缩放（战场 k=1 / 手牌 k=1.7 / 图鉴更大），
##    用 `CARD_FS_*` 子阶 + `roundi()`，**不要用 `int()`**（`int(7.5*k)` 在 k=1 会被截成 7）。
## 4. **间距**：用 `SP_*`（4px 基准）。
## 5. **语义唯一**：一个颜色只表达一件事。
##    · 「生命/伤害」= `STAT_HEALTH`；「敌方标记」= `SIDE_FOE`；「胜利」= `SIDE_SELF_TEXT`。
##    · **选中态不准占用边框颜色** —— 边框色是稀有度的通道，选中用描边/外发光表达。
##    · 同一色相允许多个**角色档**（文字档 / 标记档），但必须在注释里写清角色，例如
##      `SIDE_SELF`（框/标记）与 `SIDE_SELF_TEXT`（文字，对比度更高）。
##
## ## 迁移状态（存量分批收口，别一次性重写）
## * ✅ 字体：13 个场景已全部改走 `font()` / `font_bold()`。
## * ✅ `card_face.gd`：已全部令牌化。
## * ⏳ `battle_scene.gd`（356 处字面量）/ `map_scene.gd`（83 处）：**批 3 迁移**。
##   在此之前它们保留各自的 `COL_*`，**不要**顺手改（会污染 diff 与回归）。
##
## * 卡面的**效果文字**只在排得下完整一行时才画，所以小卡（58×70）上只有卡名与种类。
##   要让它在小卡上也出现，只能改「字号不随卡片线性缩放」这条 —— 属于玩法信息密度问题，
##   不是排版问题，先记在这里。
##
## ## 未决
## * ~~`font_bold()` 依赖系统提供 Bold 字面~~ **R180 已解决**：内嵌思源黑体
##   （`assets/fonts/SourceHanSansCN-Regular/Bold.otf`，OFL 授权可商用），`font()` /
##   `font_bold()` 改走 `FontFile` —— 同时根治安卓乱码（微软雅黑是 Windows 字体，
##   安卓上 SystemFont 回退默认字体 → 中文豆腐块），跨平台字形/字宽一致，粗体是真 Bold。

# ══════════════════════════════════════════════════════════════════════
# 字体
# ══════════════════════════════════════════════════════════════════════

## ⚠️ 必须是**数组字面量**：`const X := PackedStringArray([...])` 不是常量表达式，会解析失败。
## R180：字体从 `SystemFont`（微软雅黑系列）改为**内嵌思源黑体 FontFile** —— 微软雅黑是
## Windows 专属字体，安卓上 `SystemFont` 找不到会回退到不含中文的默认字体 → 中文全变豆腐块。
## 内嵌后跨平台字形一致、安卓不再乱码（含生僻字）。`FONT_NAMES` 降级为 `FontFile` 加载失败时
## 的 SystemFont 兜底族名（几乎不会走到）。
const FONT_NAMES := ["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"]

## 内嵌思源黑体（Source Han Sans CN，OFL 授权可商用）—— Regular 正文 / Bold 强调。
const FONT_PATH_REGULAR := "res://assets/fonts/SourceHanSansCN-Regular.otf"
const FONT_PATH_BOLD := "res://assets/fonts/SourceHanSansCN-Bold.otf"

static var _font: FontFile = null
static var _font_bold: FontFile = null


static func font() -> FontFile:
	## 正文/常规字体。全工程共用一个实例。
	if _font == null:
		_font = _load_font_file(FONT_PATH_REGULAR)
	return _font


static func font_bold() -> FontFile:
	## 强调字体。R180 起直接用**真粗体字面**（思源黑体 Bold），不再是 SystemFont 伪粗体。
	if _font_bold == null:
		_font_bold = _load_font_file(FONT_PATH_BOLD)
	return _font_bold


static func _load_font_file(path: String) -> FontFile:
	## 加载内嵌 OTF；失败则回退到 SystemFont（微软雅黑系列）。FontFile 覆盖全部中文字形
	## （含生僻字），安卓不再乱码。返回 FontFile 但内部兜底，调用方无需感知。
	## ⚠️ 必须先走 `load()`：导出包（pck）里原始 .otf 被 import 成 `.fontdata` 并写进
	## `.remap`，`load_dynamic_font()` 是**直读磁盘原文**，在发布包里必然失败 →
	## 静默回落到 SystemFont（微软雅黑），字形与字宽都和开发时看到的不一样。
	## `load()` 认 remap，编辑器与导出包拿到的是同一份导入产物。
	var res: Resource = load(path)
	if res is FontFile:
		return res as FontFile
	# 万不得已（资源未导入 / 路径写错）仍按原文直读一次。
	var ff := FontFile.new()
	if ff.load_dynamic_font(path) == OK:
		return ff
	# 加载失败（资源缺失等）→ 兜底 SystemFont，保证永不空字。
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(FONT_NAMES)
	# 把 SystemFont 挂到空 FontFile 的 fallback，仍返回 FontFile 类型（调用方类型不破）。
	var fb := FontFile.new()
	fb.fallbacks = [sf]
	return fb


# ══════════════════════════════════════════════════════════════════════
# 字号阶（9 档）
# ══════════════════════════════════════════════════════════════════════
#
# 体检时是 19 档（8~64px）：17/18/19/22/26/30/34 全是只出现一两次的孤值，
# 15 与 16、17 与 18 肉眼几乎分不出 —— 它们只把层级搅浑。
#
# ⚠️ 为什么是 **9 档而不是 7 档**：R113 实测全工程 213 处设置点，其中 8~14px 段占了
#   绝大多数（8/9/10/11/12/13/14 共 149 处）。这是一块 1280×720 的**信息密集**策略界面，
#   底部确实需要一档「微型字」（棋盘表头、费用、卡组计数…）。若硬压成 7 档，
#   这些 9px 文字会被顶到 12px（+33%），在紧凑区块里直接溢出。
#   所以补 `FS_MICRO`（微型）与 `FS_HERO`（游戏主标题）—— 最大变动幅度因此从 +50% 降到 +25%。

const FS_MICRO := 10    ## 微型：棋盘表头、计数徽章、悬停面板脚注（信息密集区专用）
const FS_CAPTION := 12  ## 说明文字、次要信息
const FS_LABEL := 14    ## 标签、次要正文
const FS_BODY := 16     ## 正文、按钮
const FS_SUBHEAD := 20  ## 小标题、重要数字
const FS_HEADING := 24  ## 区块标题、主按钮
const FS_TITLE := 32    ## 大面板标题、结算大字
const FS_DISPLAY := 48  ## 分层/结算的大号标题
const FS_HERO := 64     ## 仅用于标题页游戏名

## 全部合法字号。新增界面字号**必须**落在这 9 个值上。
## ⚠️ 用**数组字面量**（`Array[int]` 类型标注的常量不可靠）。
const FS_STEPS := [FS_MICRO, FS_CAPTION, FS_LABEL, FS_BODY, FS_SUBHEAD,
		FS_HEADING, FS_TITLE, FS_DISPLAY, FS_HERO]

## 旧值 → 新档的**吸附表**（迁移用；已全部落地的对照见 UI设计规范.md）。
## 19 档 → 9 档，最大变动 ±25%（仅 8→10 与 64 保留）。
const FS_SNAP_MAP := {
	8: FS_MICRO, 9: FS_MICRO, 10: FS_MICRO,
	11: FS_CAPTION, 12: FS_CAPTION, 13: FS_LABEL, 14: FS_LABEL,
	15: FS_BODY, 16: FS_BODY, 17: FS_BODY,
	18: FS_SUBHEAD, 19: FS_SUBHEAD, 20: FS_SUBHEAD,
	22: FS_HEADING, 24: FS_HEADING, 26: FS_HEADING,
	30: FS_TITLE, 34: FS_TITLE,
	64: FS_HERO,
}


static func nearest_font(px: int) -> int:
	## 把任意字号吸附到最近的合法档位（迁移存量用；**不要**用在卡面尺寸上）。
	if FS_SNAP_MAP.has(px):
		return FS_SNAP_MAP[px]
	var best: int = FS_STEPS[0]
	var best_d: int = absi(px - best)
	for s in FS_STEPS:
		var d: int = absi(px - int(s))
		if d < best_d:
			best_d = d
			best = int(s)
	return best


# ══════════════════════════════════════════════════════════════════════
# 卡面字号子阶（随缩放比 k 派生，保持比例）
# ══════════════════════════════════════════════════════════════════════
#
# 基阶从 6 档（7 / 7.5 / 8 / 9 / 10 / 12）收到 **2 档**。原计划 3 档，实现时发现
# 「卡名」与「附属信息」都落在 9.0 —— 两个同值令牌是纯冗余，合并为 `CARD_FS_TEXT`。
#
# 卡面从 58×70（战场）缩到手上也就 119×143，塞不下字号层级；所以**卡面靠字重与颜色
# 拉层级**（卡名=粗+墨色、种类=卡种色、力量=金、生命=红），不靠字号。
#
# 取值用 float 保留比例，调用点必须 `roundi(CARD_FS_* * k)`，**不要 `int()`** ——
# `int(7.5 * k)` 在 k=1 会被截成 7，比低一档还小。

const CARD_FS_TEXT := 9.0    ## 卡名 / 种类 / 字段 / 效果文字
## 数值徽章上的数字。R117 从 9 提到 12（用户口径「战场上的数字太小，加大占比」）。
## 战场卡 k ≈ 76/70 ≈ 1.086 → 实到 `roundi(12 × 1.086) = 13px`，占 20px 圆盘的 65%
## （R116 是 9px / 17px ≈ 53%）。两位数是这套参数的上限：sz=13 时量宽「30」= 17px
## ≤ 自动缩号阈值 r×1.75 ≈ 17.5，所以**两位数的力量/生命不会再被悄悄缩小**。
const CARD_FS_BADGE := 12.0


# ══════════════════════════════════════════════════════════════════════
# ══════════════════════════════════════════════════════════════════════
# 卡面版式（R115）：上半卡图 / 下半文字 / 数值「挂在框上」
# ══════════════════════════════════════════════════════════════════════
#
#    ┌───────────────────────┐  ① 费用     = 卡框**左上角**
#    │ ①      ← 卡图 →       │  ② 力量     = 卡框**左下角**（与 ① 同一条竖线）
#    ├───────────────────────┤  ③ 攻击距离 = ② 右侧
#    │         卡名           │  ④ 移动距离 = ⑤ 左侧
#    │       种类 · 字段       │  ⑤ 生命     = 卡框**右下角**（与 ① 左右反向）
#    │    效果文字（可折行）…  │
#    └───────────────────────┘
#     ②力 ③程         ④速 ⑤
#
# ⚠️ 力量与生命因此**分别向左右探出卡框**（R115 用户口径「攻击力和生命都可以
#   左右方向超出卡片范围」）。这不是装饰偏好：它把「四个数值都得挤进卡宽」
#   松成「只有中间两个受卡宽限制」，图标于是能画得更大（R 7 → 8.5），
#   同时卡片内部依然完整让给卡图与文字。代价是容器必须让出 `CARD_BLEED`。
#
# 所有尺寸都是**基准值 × 卡片缩放比 k**（k = 卡高 / 70；战场小卡 k=1、手牌 1.7、
# 奖励大卡 3.7）。数值图标走 `assets/ui/icon_*.png`（剑/弓/鞋/血/水晶），
# **缺图回退语义色圆盘**，所以这份版式在零素材时也成立。


## 卡图占卡片高度的比例 —— **上半卡图 / 下半文字，对半分**（就是需求原话）。
## ⚠️ 这个值不是「好看就行」：下半要同时装下**卡名 + 种类·字段 + 效果文字**三样。
## 数值不占内部空间（它们骑在卡框上，见 `CARD_BLEED`），所以 0.50 是安全的；
## 但 R114 实测 0.52 时 k=1.7 的手牌上「种类」会被挤掉 —— 想调大先按最坏情况算一遍。
const CARD_ART_RATIO := 0.662  ## R193：对齐 card_paper.png v4 底图的卡图/姓名牌分隔金条
const CARD_NAMEPLATE_TOP := 0.745    ## 姓名牌内框上沿（归一化）
const CARD_NAMEPLATE_BOTTOM := 0.94  ## 姓名牌内框下沿
const CARD_NAMEPLATE_X0 := 0.06      ## 姓名牌内框左沿
const CARD_NAMEPLATE_X1 := 0.94      ## 姓名牌内框右沿
const CARD_PAD := 3.0             ## 卡面内距（基准）
## 数值图标半径（基准）。R117 从 8.5 提到 9.2 —— 战场卡 k ≈ 1.086
## → 实到 10.0（**直径 20**，正是用户口径「徽章直径 17 → 约 20」）。
## ⚠️ 上限仍由**底部一排**决定：力量/生命挪到卡框左右两角之后，约束是
## 「中间两张 + 左右各一个半径 = 6R + 2×GAP ≤ 卡宽」。R117 卡宽 58 → 63，
## 于是上限从 `58/6 ≈ 9.67` 松到 `63/6 = 10.5`，9.2 仍有 7.8px 余量。
const CARD_BADGE_R := 9.2
## 同排两个数值的间距（基准）。**0 = 相邻两个直接相接**（用户明确接受）。
const CARD_BADGE_GAP := 0.0
## **卡片四周至少要留出的「外溢边」**（基准单位，实际尺寸 = 本值 × 卡片缩放比 k）。
## 数值的**圆心落在卡框上** → 一半露在框外（炉石那种「挂在框上」），而且 R115 起
## 力量/生命分别向左右探出，所以**上下左右四条边都要让**。容器必须留出来，
## 否则会骑到邻卡身上：
##   · 网格类（卡尺寸固定）：单元格 ≥ 卡尺寸 + 2 × `CARD_BLEED` × k
##     （例：图鉴 CELL 101×117 @ k=1.314、牌库间距 24）
##   · 列表类：行距 ≥ 卡高 + 2 × `CARD_BLEED` × k（例：卡组行 89 = 70 + 2×9.2）
##   · ⚠️ 卡高**可变**的网格（卡组编辑）：间距要由卡高反算，写死常数两头都错
## ⚠️ R117 订正：此前这里写着「棋盘 `CELL` / `GRID_X` / `GRID_Y` 是引擎约束、
##   不许改」——**实测不成立**：全工程只有 `battle_scene.gd` 与 `test_smoke.gd`
##   引用这三个常量，引擎 / 回放 / 录像一律以**格坐标** `Vector2i` 为准。
##   R117 正是据此把棋盘放大（并拆出 `CELL_W`）——棋盘那一格现在**也装得下**了，
##   R115 写的「只保证贴边不重叠」不再适用。
## ⚠️ 唯一的例外是牌库面板：它的间距被**列数**反卡住（`int(1080/(76+GAP))`），
##   GAP 从 22 抬到 24 会让列数从 11 掉到 10 —— 所以那里靠**加宽面板**
##   （1120 → 1150）把这一格吃回来，而不是压缩间距。
const CARD_BLEED := 9.2

## ⚠️ **两个不同的缩放上限**（R114 实测的结论，别合并成一个）：
##   · 徽章用 `CARD_BADGE_SCALE_CAP` —— 大卡上徽章若跟着 k 线性长，会变成几个巨球抢戏。
##   · 文字用 `CARD_TEXT_SCALE_CAP` —— 卡片越大，每个字应当**更小**才装得下更多字：
##     能排的字数 ≈ 区域面积 / 字号²，而面积 ∝ k²、字号 ∝ min(k,cap)²，
##     所以 cap 越小能装的字越多。奖励卡（216×260）实测：cap=2.0 只排得下约 30 字，
##     cap=1.6 排得下约 70 字 —— 而卡面存在的意义就是让玩家读得到说明。
const CARD_BADGE_SCALE_CAP := 2.2
const CARD_TEXT_SCALE_CAP := 1.6

## R170 卡面底部框线：**中性深胡桃木色**。此前框线涂稀有度色（「颜色条」），
## 稀有度的主通道已改为右上角的**缎带素材**（`UiAssets.rarity_ribbon`）——
## 用户口径「稀有度不要粗暴的颜色块/颜色条，做成 banner 图片素材」。
const CARD_FRAME := Color("574433")

## 徽章圆盘色：**缺图标素材时的回退底衬**，同时充当图例（一个通道一个含义）。
const BADGE_COST := Color("2255aa")    ## 费用（水晶）
const BADGE_POWER := Color("8a5f00")   ## 力量（剑）
const BADGE_RANGE := Color("1f6b6b")   ## 攻击距离（弓）
const BADGE_HEALTH := Color("c1121f")  ## 生命（血）
const BADGE_SPEED := Color("4f4a8a")   ## 移动距离（鞋）
const BADGE_OUTLINE := Color(0.05, 0.05, 0.07, 0.94)  ## 压在图标上的数字描边
const BADGE_VALUE := Color("ffffff")   ## 徽章数字
## R301：卡面数值相对**卡库原型**的涨跌染色（高 = 绿 / 低 = 红）。
## 只染**数字**、不动图标底色 —— 图标是「这是哪种数值」的语义色，数字是「变没变」。
## 手卡 / 场上 / 弃牌区 / 图鉴全部共用（染色在 `CardFace.draw()` 里，调用方不用管）。
const BADGE_UP := Color("2fd968")     ## 比原型高（改造 / 附魔加成）
const BADGE_DOWN := Color("ff5757")   ## 比原型低（被削弱 / 减益）
## R301：生命徽章的两条专用态（用户口径 —— 生命不能只按「比原本高/低」一个维度染）
##   · BADGE_HURT  当前生命 < 最大生命 → 受伤（**优先级最高**，压过涨跌）
##   · BADGE_WARN  满血但最大生命 < 原本 → 上限被削（是警示，不是损失）
## 受伤红比 BADGE_DOWN 略亮一档：它要压在**深红酒滴图标**上（icon_health），
## 纯正红 #ff5757 在那上面只有 4.5:1，提亮后到 5.0:1，小号数字更扎实。
const BADGE_HURT := Color("ff6b6b")   ## 受伤（当前生命低于最大生命）
const BADGE_WARN := Color("ffd23f")   ## 满血但生命上限被削


# ══════════════════════════════════════════════════════════════════════
# 间距（4px 基准）
# ══════════════════════════════════════════════════════════════════════

const SP_1 := 4
const SP_2 := 8
const SP_3 := 12
const SP_4 := 16
const SP_5 := 24
const SP_6 := 32


# ══════════════════════════════════════════════════════════════════════
# 色彩令牌
# ══════════════════════════════════════════════════════════════════════

# ── 中性 / 文字 ──
const INK_900 := Color("1a1c22")      ## 主文字
const INK_800 := Color("333333")      ## 次强文字（弹窗标题、亮底上的正文）
const INK_600 := Color("555555")      ## 次要文字（替代散落的 #444444 / #666666）
const INK_500 := Color("6b6b6b")      ## 弱化文字（5.33:1；原 #777777 只有 4.48:1，未过 AA）
const INK_ON_DARK := Color("8a867c")  ## 暗底上的提示文字
const INK_300 := Color("b8b4aa")      ## 分割线 / 描边

# ── 底 ──
const SURFACE := Color("ffffff")      ## 卡面 / 面板底
const PAPER := Color("f7f5f0")        ## 纸面底
const SAND := Color("e8e4da")         ## 卡片槽底
const BOARD_BG := Color("e9e7e2")     ## 棋盘底
## R154 暗底锚点（清单 §2.6）：全屏界面的暗底**只许读这两个**，别再散落 Color("252a35")。
## 冷灰（252a35）与羊皮纸/墨蓝的美术方向不一致 → 统一锚到墨蓝夜色。
const SCREEN_BG := Color("1a1c22")      ## 全屏界面暗底（选角 / 道具 / 卡组编辑 / 事件）
const PANEL_DARK := Color("222630")      ## 暗底上的卡片 / 面板底（略亮于 SCREEN_BG 一档）
## R154 羊皮纸面板（清单 §2.5）：图鉴左右栏这类「纸面上的面板」。
const PANEL_PAPER_BG := Color("f1e9d5")  ## 羊皮纸奶油底
const PANEL_PAPER_LINE := Color(0.78, 0.68, 0.45, 0.60)   ## 纸面细金边
## 棋盘格线。原为 `#9a9a9a`，在 `BOARD_BG` 上只有 **2.28:1** —— 对非文字元素低于 WCAG 的 3:1，
## 玩家分不清格子边界。`#7d7b74` 是 **3.43:1**，既能看清又不抢单位的视觉重量。
const BOARD_GRID_LINE := Color("7d7b74")

# ── 阵营 ──
const SIDE_SELF := Color("2e7d32")       ## 我方：框 / 标记
const SIDE_SELF_TEXT := Color("1b5e20")  ## 我方：文字（对比度 7.85:1）
const SIDE_FOE := Color("c62828")        ## 敌方：框 / 标记

# ── 数值 / 危险 ──
const STAT_POWER := Color("8a5f00")   ## 力量（5.64:1；原 #b8860b 只有 3.25:1，未过 AA）
const STAT_HEALTH := Color("c1121f")  ## 生命 / 伤害（6.22:1）

## R711（店长口径）：详细面板里「和卡库原型不同」的数值 —— **高了绿、低了红**。
## ⚠️ 不能直接复用卡面徽章的 `BADGE_UP`(#2fd968) / `BADGE_DOWN`(#ff5757)：那套是配
##    **深底徽章**写的，压在羊皮纸 `PANEL_PAPER_BG`(#f1e9d5) 上只有 1.54:1 / 2.57:1，
##    左栏 10~13px 的正文会糊成一片。这里给**浅底可读**的两级（5.41:1 / 5.14:1）。
const STAT_UP := Color("1f6b34")      ## 高于原型（绿；5.41:1）
const STAT_DOWN := Color("c1121f")    ## 低于原型（红；与 DMG_NOW / STAT_HEALTH 同值）

## R349（用户口径）：伤害数**内联在效果正文里**染色，不再单开一行「现在打出」。
## 两个色各管一件事 —— 总值要最跳，算式要能读但不抢。
const DMG_NOW := Color("c1121f")       ## 当前总伤害（与生命同色系，浅底上最醒目）
const DMG_CALC := Color("8a6a45")      ## 算式（10＋8）：暖褐，和红色明显分开

# ── 卡种（`card_face.gd` 的种类着色）──
const KIND_ALLY := Color("2a7a2a")    ## 盟友
const KIND_SKILL := Color("7a2a7a")   ## 技能
const KIND_EFFECT := Color("1d7a4f")  ## 效果
const KIND_FORT := Color("7a5a2a")    ## 工事
const KIND_CURSE := Color("4e4560")   ## 诅咒（R223「疲惫」）
const KIND_FALLBACK := Color("808080")  ## 未知种类

## R165 卡面横幅：无图回退 / 卡名条用**卡种（或职业）色的淡彩渐变**代替「粗暴纯色块」。
## 两个值是「向白混合」的比例（越大越淡越自然）：上端更淡、下端略深形成渐变。
const KIND_BANNER_TOP := 0.80   ## 横幅渐变上端混合比（更淡）
const KIND_BANNER_BOT := 0.50   ## 横幅渐变下端混合比（略深，仍有彩）

## 卡面说明文字里的「关键字」高亮（如数值、费用）。4.74:1。
const CODE_TEXT := Color("a8621f")

## 「文本里提到的卡牌 / 道具名」（R168 · 规范 §4.38）：**可悬浮看详情**，
## 所以要用与正文不同的强调色。浅底 / 暗底各一枚，由 `Mention.text_color(底色)` 二选一 ——
## 保证两种底色上都比正文醒目、而且读得清（用户口径：这些名字本身要有颜色）。
const MENTION_ON_LIGHT := Color("8a5f00")   ## 浅底（羊皮纸 / 卡面）：琥珀棕
const MENTION_ON_DARK := Color("f2c14e")    ## 暗底（悬浮面板）：亮金（= ACCENT_LIT）

# ── 卡面 ──
const COST_BG := Color("2255aa")     ## 费用圆底色
const SELECT_RING := Color("c1121f") ## 选中描边色（批 2 会改成「外发光」，令牌保留）

# ── 标题页背景 ──
const OVERLAY_TITLE := Color(1, 1, 1, 0.30)  ## 标题页白罩（原 0.55）

## 标题页的「幽灵卡」母題（R113）：不用 cardback.png 贴图。
## 原因：卡背是**深海军蓝**，而标题页底色是**浅米黄** —— 任何低透明度都会把深蓝
## 兑成中灰，菱形花纹的对比度被同比例压缩，最后只剩一个「灰色占位块」。
## 改成「浅色卡 + 描边」的幽灵卡，才是这块纸面上的合理存在。
const GHOST_CARD_FILL := Color(0.91, 0.89, 0.84, 0.62)   ## 卡面
const GHOST_CARD_LINE := Color(0.72, 0.71, 0.67, 0.55)   ## 外描边
const GHOST_CARD_INNER := Color(0.78, 0.76, 0.70, 0.30)  ## 内嵌描边（卡面的一圈留白）
## 幽灵卡的横向活动区间（占窗口宽度比例）：只出现在左右留白区，**永不压住标题与按钮**。
const GHOST_CARD_MARGIN := 0.23

# ── 稀有度（对映 CardData.RARITY_COLORS / RARITY_NAMES 的下标）──
const RARITY_COMMON := Color("2c2c2a")   ## 0 普通
const RARITY_RARE := Color("1f5fbf")     ## 1 稀有
const RARITY_EPIC := Color("8a30b8")     ## 2 史诗
const RARITY_STARTER := Color("1d7a4f")  ## 3 初始
const RARITY_MONSTER := Color("7a1f1f")  ## 4 怪物
const RARITY_EVENT := Color("a44ad0")    ## 5 事件
const RARITY_CURSE := Color("4e4560")    ## 6 诅咒（R223「疲惫」）

# ── 职业色（CardData.card_class → 卡面左侧竖条，R153）──
const CLASS_DRUID := Color("3a7d44")   ## 森林精魄 自然绿
const CLASS_ROGUE := Color("5b3a8e")   ## 暗影刺客 幽紫
const CLASS_MECH := Color("b8860b")    ## 机械之心 黄铜
const CLASS_ENEMY := Color("7a1f1f")   ## 敌人 暗红
## R277：**公用卡**（cards.json 里 class 留空 = 不属于任何职业的事件 / 道具产出卡）
## 的中性灰 —— 与「无归属」的语义一致：不站任何一边，但也确实是卡库里的正式成员。
const CLASS_NONE := Color("6f6f6f")    ## 公用卡 中性灰

# ── 强调 / 状态 ──
const ACCENT_GOLD := Color("c8951c")  ## 装饰 / 描边
const ACCENT_LIT := Color("f2c14e")   ## 高亮 / 奖励
const STATE_GUARD := Color("1d9e4f")  ## 护盾
const STATE_TAUNT := Color("ff8f00")  ## 嘲讽
const STATE_FROZEN := Color("6ec6ff") ## 冰冻
const STATE_SLEEP := Color("b07bff")  ## 沉睡
const STATE_FUSE := Color("ff7043")  ## 铸造倒计时（R149）：橙红，刻意与嘲讽的 ff8f00 拉开
const STATE_STUN := Color("ffd54f")  ## 眩晕（R654）：亮金，靠「虚线环 + 绕头星点」与其余环形成对区分

# ── 滚动提示（R126）──
## 地图「还能上下滚」的半透明双箭头。第一枚亮、第二枚更淡 → 形成层次，
## 读起来就是「双箭头」（= 还有更多），而不是两个孤立的三角。
## ⚠️ 地图上会与节点重叠（地图节点是亮橙/亮绿）→ 箭头的**下沿再垫一道更粗的暗色折线**
## （与卡面数字描边同一手法），否则浅色箭头会被亮节点淹没。
## R147：原来是**白色**（0.52 / 0.26）—— 压在棋盘石色 / 地图彩绘底上「太浅了」，
##   用户口径改成**更明显的浅蓝**并提高不透明度；垫底描边同时加深，压在亮色块上仍可辨。
const HINT_CHEVRON := Color(0.55, 0.88, 1.0, 0.95)      ## 第一枚（离内容更近的那枚）
const HINT_CHEVRON_DIM := Color(0.45, 0.78, 1.0, 0.62)  ## 第二枚（更淡，但仍读得出是同一组）
const HINT_CHEVRON_HALO := Color(0.03, 0.07, 0.14, 0.78)  ## 垫底的暗色描边

# ── 地图通路（R130）──
## 唯一消费方：scripts/map_bridge.gd（冒险地图页与战斗内地图总览共用）。
## 通路 = 两格之间的墙上盖一枚**小桥图标**；这三个是**染色**（modulate，会与原图相乘）。
## ⚠️ 桥素材必须画成**浅色**：deep 色的图乘上冷色会变成一团脏色。
## ⚠️ 别再改回「画一块色块 / 门洞」—— R130 第一版那样做过，量感过重且彼此不相连，
##    鹰哨全揭示时像散落的按钮。通路要是「一个能被认出来的物件」。
const MAP_BRIDGE_DARK := Color(0.03, 0.04, 0.06, 0.72)   ## 缺图兜底横条的暗描边
const MAP_BRIDGE_DONE := Color(1.0, 0.90, 0.68)          ## 走过的房 → 已确认的相邻房（暖白）
const MAP_BRIDGE_LIT := Color(0.40, 0.86, 1.0)           ## 当前房 → 可走的相邻房（亮青，会呼吸）
## ⚠️ 这档要**够饱和**：桥素材本身是浅米色，染色是相乘 —— 太淡的青色乘出来
##    和「暖白」几乎分不开（出图验证过）。
const MAP_BRIDGE_UNSEEN := Color(0.68, 0.73, 0.82, 0.90) ## 鹰哨揭示、还没走过（灰蓝、更小）
## ⚠️ 这档别压太暗：出图验证过，alpha 0.8 + 更深的灰在深色背景上几乎看不见 ——
##    而「鹰哨全揭示」恰恰是最需要看清通路的时候。


## R148：齿轮图标（「设置 / 菜单」按钮用）。
## ⚠️ 必须**程序绘制**：字体里的 ⚙（U+2699）在微软雅黑 / SimHei 上不保证有，
##    缺字时按钮上会变成一个方框。齿形用「内圈-外圈-外圈-内圈」四点一齿拼成多边形，
##    中心再挖一个底色圆当轴孔（`hole` 传按钮底色 —— hover 时底色变了要跟着传新的）。
static func draw_gear(cv: CanvasItem, center: Vector2, r_out: float,
		col: Color, hole: Color, teeth := 8) -> void:
	var n := maxi(teeth, 3)
	var r_in := r_out * 0.74
	var step := TAU / float(n)
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) * step
		pts.append(center + Vector2.from_angle(a - step * 0.36) * r_in)
		pts.append(center + Vector2.from_angle(a - step * 0.22) * r_out)
		pts.append(center + Vector2.from_angle(a + step * 0.22) * r_out)
		pts.append(center + Vector2.from_angle(a + step * 0.36) * r_in)
	cv.draw_colored_polygon(pts, col)
	cv.draw_circle(center, r_out * 0.36, hole)


static func class_color(card_class: String) -> Color:
	## 卡牌**归属** → 颜色。**唯一口**（R153）：左侧竖条与卡底面填色（`CardFace.paper_tint`）
	## 都读这里，别在别处再写一份字典。
	## R277 用户口径：颜色绑的是「这张卡属于谁」，不是「哪个角色能用它」——
	##   森林精魄 = 自然绿 / 暗影刺客 = 幽紫 / 机械之心 = 黄铜 / 敌人 = 暗红 /
	##   **class 留空 = 公用卡 → 中性灰**（此前留空返回透明，卡面与竖条都当作“没有归属”）。
	## 返回 alpha 0 仍然表示「不需要上色」（目前只有 card == null 这类兜底会走到）。
	if card_class == "":
		return CLASS_NONE
	match card_class:
		"森林精魄":
			return CLASS_DRUID
		"暗影刺客":
			return CLASS_ROGUE
		"机械之心":
			return CLASS_MECH
		"敌人":
			return CLASS_ENEMY
	return Color(0, 0, 0, 0)


static func kind_color(kind: String) -> Color:
	## 卡种 → 颜色。**唯一口**：卡面与悬停面板都读这里，避免两处各写一份字典。
	match kind:
		"盟友":
			return KIND_ALLY
		"技能":
			return KIND_SKILL
		"效果":
			return KIND_EFFECT
		"工事":
			return KIND_FORT
		"诅咒":
			return KIND_CURSE
	return KIND_FALLBACK


## 地图节点配色（**唯一出处**）。此前 `battle_scene.gd` 的 `MAPVIEW_TYPE_COLORS` 与
## `map_scene.gd` 的 `TYPE_COLORS` 各存一份一模一样的表，两边的注释里都写着「改这里时
## 两边要一起改」—— 那就说明它本来就该只有一份。
##
## ⚠️ 必须是 `static var` 而不是 `const`：**const 字典里不能放 `Color()`**（也不是
## `UiTheme.X` 这种跨脚本常量引用），否则整份文件 `Parse Error`。
## ⚠️ 只读使用；不要往这个字典里写（static 是共享对象）。
static var MAP_NODE_COLORS := {
	"start": Color("7a94b8"),   # 起点 蓝灰
	"battle": Color("c6503c"),  # 普通战斗 红
	"elite": RARITY_EPIC,       # 精英 紫
	"rest": Color("3f9b5f"),    # 休息 绿
	"event": Color("d1a12a"),   # 事件 金
	"chest": Color("e0912a"),   # 宝箱 橙金（与事件金区分）
	"bigchest": Color("f5c84c"),  # 大宝箱（R128）：更亮的金 —— 全图只有两格，要跳出来
	"unknown": Color("6f7a8c"),   # 「?」房（R128）：灰蓝，走进才揭晓
	"boss": Color("33323b"),    # Boss 黑
}


# ══════════════════════════════════════════════════════════════════════
# 圆角与组件规格
# ══════════════════════════════════════════════════════════════════════
#
# ⚠️ 这一节是给「以后会有许多其他界面」准备的：**任何新界面都不该自己画按钮**，
#    一律 `UiTheme.apply_button(btn, primary)`。这样主次、圆角、内距、焦点环
#    永远只有一处定义，新界面不可能跟旧界面长得不一样。

const RADIUS_SM := 6
const RADIUS_MD := 8
const RADIUS_LG := 12

const BTN_PAD_X := 18   ## 按钮左右内距
const BTN_PAD_Y := 9    ## 按钮上下内距

# ── 主按钮（一屏**最多**一个；选择类界面可以全是次按钮）──
const BTN_PRIMARY_BG := Color("283c2d")        ## 深墨蓝（日式西幻的夜色）
const BTN_PRIMARY_BG_HOVER := Color("3b543c")
const BTN_PRIMARY_BG_PRESS := Color("1f3025")
const BTN_PRIMARY_LINE := Color("a58c58")      ## 金线
const BTN_PRIMARY_LINE_FOCUS := Color("dbc58d") ## 焦点环（更亮，键盘可达性）
const BTN_PRIMARY_TEXT := Color("f5efe0")

## 暗底上的主按钮：深墨蓝在暗底上会「沉下去」，所以换金底 + 墨色字。
const BTN_PRIMARY_DARK_BG := Color("c8951c")
const BTN_PRIMARY_DARK_BG_HOVER := Color("d9a52c")
const BTN_PRIMARY_DARK_BG_PRESS := Color("a87a12")
const BTN_PRIMARY_DARK_LINE := Color("f2c14e")
const BTN_PRIMARY_DARK_TEXT := Color("1a1c22")

# ── 次按钮 ──
const BTN_SECONDARY_BG := Color(1, 1, 1, 0.42)
const BTN_SECONDARY_BG_HOVER := Color(1, 1, 1, 0.72)
const BTN_SECONDARY_BG_PRESS := Color(1, 1, 1, 0.28)
const BTN_SECONDARY_LINE := Color("b8b4aa")
const BTN_SECONDARY_LINE_FOCUS := Color("8a5f00")
const BTN_SECONDARY_TEXT := Color("514735")

## 暗底上的次按钮：半透明白 + 亮字（亮底那套的深字在暗底上根本读不出来）。
const BTN_SECONDARY_DARK_BG := Color(1, 1, 1, 0.10)
const BTN_SECONDARY_DARK_BG_HOVER := Color(1, 1, 1, 0.22)
const BTN_SECONDARY_DARK_BG_PRESS := Color(1, 1, 1, 0.06)
const BTN_SECONDARY_DARK_LINE := Color(1, 1, 1, 0.30)
const BTN_SECONDARY_DARK_TEXT := Color("e6e2d8")

const BTN_DISABLED_LINE := Color("b8b4aa")
const BTN_DISABLED_TEXT := Color("7a7a78")

# ── 小按钮（chip）：顶部工具条 / HUD、难度档位、筛选、多选标签 ──
## 浅底档（默认）：半透明白 + 深字 —— 成组出现于**亮底**（如标题页的难度档位）。
const CHIP_BG := Color(1, 1, 1, 0.34)
const CHIP_BG_HOVER := Color(1, 1, 1, 0.62)
const CHIP_LINE := Color("b8b4aa")
const CHIP_TEXT := Color("514735")
const CHIP_PAD_X := 12
const CHIP_PAD_Y := 5

## 实心档（solid）：实心暗蓝灰 + 亮字 —— 顶部工具条 / HUD，要从背景里跳出来。
## 取值沿用 `map_scene` 原本手写的样式，所以地图页观感**不变**，只是收进唯一口、并补回焦点环
## （原来那里把 focus 设成了 `StyleBoxEmpty`，键盘可达性直接没了）。
const CHIP_SOLID_BG := Color("2d3c30")
const CHIP_SOLID_BG_HOVER := Color("40503b")
const CHIP_SOLID_BG_PRESS := Color("233025")
const CHIP_SOLID_LINE := Color(0, 0, 0, 0.35)
const CHIP_SOLID_TEXT := Color("f3ead8")
const CHIP_SOLID_TEXT_HOVER := Color("ffffff")
const CHIP_SOLID_TEXT_PRESS := Color("cfcabb")
## compact：更小的内距，给**固定高度**的工具条用（battle 顶栏按钮只有 28px 高）。
const CHIP_COMPACT_PAD_X := 10
const CHIP_COMPACT_PAD_Y := 3


static func _btn_box(bg: Color, line: Color, width: int, radius: int,
		px := BTN_PAD_X, py := BTN_PAD_Y) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = px
	sb.content_margin_right = px
	sb.content_margin_top = py
	sb.content_margin_bottom = py
	return sb


static func _btn_tex_box(tex: Texture2D, px := BTN_PAD_X, py := BTN_PAD_Y) -> StyleBoxTexture:
	## R154：素材按钮底（btn_primary / btn_plain）。胶囊两端 40px 不拉伸（保金线圆弧），
	## 纵向上下各留 6px、中段自由拉伸 —— 按钮比素材矮时圆弧略扁，可接受。
	## hover / pressed 的反馈由**字色变化 + UiPressFx 缩放**承担（素材只有常态一张）。
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 40.0
	sb.texture_margin_right = 40.0
	sb.texture_margin_top = 6.0
	sb.texture_margin_bottom = 6.0
	sb.content_margin_left = px
	sb.content_margin_right = px
	sb.content_margin_top = py
	sb.content_margin_bottom = py
	return sb


static func _chip_box(bg: Color, line: Color, width: int, px: int, py: int,
		bottom_only := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	if bottom_only:
		sb.border_width_bottom = width      # 只留底边 → 胶囊的「落地感」
	else:
		sb.set_border_width_all(width)
	sb.set_corner_radius_all(RADIUS_SM)
	sb.content_margin_left = px
	sb.content_margin_right = px
	sb.content_margin_top = py
	sb.content_margin_bottom = py
	return sb


const UiPressFx = preload("res://scripts/ui_press_fx.gd")


static func _night_group_font_size(btn: Button) -> int:
	## R517：同一页的 night 按钮**共用同一个字号**。
	##
	## 原先每个按钮各自缩字 —— 文案短的那行保持 FS_SUBHEAD、长的那行掉到 FS_LABEL，
	## 一页里两个按钮字号不一样，看上去还是「第二行字更小」。
	## 现在取「组里每个按钮都放得下」的最大字号，整组一起用。
	var parent := btn.get_parent()
	var group: Array[Button] = []
	if parent != null:
		for n in parent.get_children():
			var b := n as Button
			if b != null and b.visible and not b.text.is_empty():
				group.append(b)
	if group.is_empty():
		group.append(btn)
	var face := font()
	var fs := FS_SUBHEAD
	for b in group:
		var avail := b.size.x - 68.0
		if avail <= 0.0:
			continue
		while fs > FS_CAPTION \
				and face.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
			fs -= 1
	return fs


static func _unify_night_fonts(btn: Button) -> void:
	## 保证整组字号一致，并处理「文本变了但尺寸没变」——Button 改 text 不会发 resized，
	## 所以额外挂在 minimum_size_changed 上。设同一个字号不会再次触发该信号，天然收敛。
	if btn == null or not is_instance_valid(btn):
		return
	var fs := _night_group_font_size(btn)
	var parent := btn.get_parent()
	if parent == null:
		btn.add_theme_font_size_override("font_size", fs)
		return
	for n in parent.get_children():
		var b := n as Button
		if b == null or not b.visible or b.text.is_empty():
			continue
		b.add_theme_font_size_override("font_size", fs)


# ------------------------------------------------------------ R602 框内文字自适应
#
# 用户口径：「检查项目内所有有框的，文字会不会和外框重叠？文字太多会不会溢出？
# 溢出需要自适应缩小字体」。之前工程里只有三处各自写了缩字逻辑（按钮
# `_fit_action_button` / 回合横幅 `BannerFit` / 卡面效果文 `CardFace.fit_text_lines`），
# Label 与其它 draw_string 一律「超了就被裁 / 干脆画出框」—— 图鉴详情的长卡名
# 就是直接顶穿右框线。这里补**唯一两口**：
#   ① `fit_font_size()`：给定框宽高，返回放得下的字号（自绘 draw_string 用）；
#   ② `autoshrink_label()`：给 Label 赋值 + 缩字号 + 到下限仍放不下才裁切。
#
# ⚠️ 循环一律**严格递减** `fs -= 1`，不依赖「条件终将不成立」退出的写法 ——
#    绘制期死循环的表现是整帧不返回（游戏未响应），R164 踩过。

static func fit_font_size(face: Font, text: String, max_w: float, max_h: float,
		fs_max: int, fs_min: int, wrap := false) -> int:
	## 从 `fs_max` 逐级往下试，返回第一个「放得进 max_w × max_h」的字号。
	## `wrap=true` 时按折行后的整块尺寸判断（多行正文）；否则按单行宽度 + 行高。
	## 缩到 `fs_min` 仍放不下就返回 `fs_min` —— **截断与否交给调用方**，这里不悄悄丢字。
	if face == null or text.strip_edges() == "" or max_w <= 1.0:
		return maxi(fs_min, fs_max)
	var hi := maxi(fs_min, fs_max)
	var fs := hi
	while fs > fs_min:
		var need := text_need(face, text, max_w, fs, wrap)
		if need.x <= max_w + 0.5 and need.y <= max_h + 0.5:
			return fs
		fs -= 1
	return fs_min


static func text_need(face: Font, text: String, max_w: float, fs: int, wrap := false) -> Vector2:
	## 文字在 `fs` 字号下的实际占位（宽, 高）。绘制与测量共用这一口。
	if wrap:
		var sz := face.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				max_w, fs)
		return Vector2(minf(sz.x, max_w), sz.y)
	# ⚠️ 单行只判**宽度**，高度一律返回 0（= 不参与判定）。
	#   实测这个 FontFile 的高度度量按字号**跳变**：20px→60、18→54、16→25、14→42
	#   （不是线性，也不是行距 1.4 倍的关系，`get_ascent` / `get_descent` / `get_height`
	#   三个口都给这种跳变值）—— 拿它当上限比，会把能放下的 20px 卡名误缩成 16px、
	#   把 14px 的「种类 · 职业 · 费用」误缩成 10px。宽度度量是线性的、可靠。
	#   Label 的竖直溢出改由 `clip_text` 兜底，不靠缩字号。
	return Vector2(face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 0.0)


static func autoshrink_label(lb: Label, text: String, fs_max := -1, fs_min := 10,
		box := Vector2.ZERO) -> void:
	## Label 版「框里放不下就缩字号」。
	## `box` 传**场景里写死的框**（Label 自己的 size 会被长文本的 minimum size 撑大，
	## 拿 lb.size 当判据等于用「已经被撑开的框」去量，永远不超）。
	## 缩到 `fs_min` 仍放不下 → `clip_text = true` 兜底，绝不画到框外。
	if lb == null or not is_instance_valid(lb):
		return
	var face := lb.get_theme_font("font")
	if face == null:
		lb.text = text
		return
	var b := box if box.x > 1.0 and box.y > 1.0 else lb.size
	if b.x <= 1.0 or b.y <= 1.0:
		lb.text = text
		return
	var hi := fs_max if fs_max > 0 else lb.get_theme_font_size("font_size")
	var wrap := lb.autowrap_mode != TextServer.AUTOWRAP_OFF
	var fs := fit_font_size(face, text, b.x, b.y, hi, fs_min, wrap)
	lb.add_theme_font_size_override("font_size", fs)
	lb.text = text
	var need := text_need(face, text, b.x, fs, wrap)
	if need.x > b.x + 0.5 or (wrap and need.y > b.y + 0.5):
		lb.clip_text = true


static func _fit_action_button(btn: Button, primary: bool, night := false) -> void:
	if btn.size.y <= 0:
		return
	var compact := btn.size.y <= 44 or btn.size.x < 200
	if night:
		# R517：事件页的按钮**不分档**。原先按 size 判 compact，而场景里四个按钮的
		# custom_minimum_size 是 46 / 42 / 38 / 38 —— 46 走大档、其余走小档，
		# 于是「第二行更矮、字更小」。同一页里的同类按钮必须同高一档。
		compact = false
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		if night:
			# R516：暗紫肤 —— 这里原本会把 stylebox 整个换成浅色贴图，
			# 把 apply_night_button 设好的深色缎带冲掉（按钮变回奶油色）。
			btn.add_theme_stylebox_override(state, night_button_style(state))
			continue
		var bg := ADVENTURE_FOREST if primary else ADVENTURE_INPUT
		if state == "hover":
			bg = bg.lightened(0.08)
		elif state == "pressed":
			bg = bg.darkened(0.08)
		btn.add_theme_stylebox_override(state, _chip_box(bg, ADVENTURE_BRASS, 1, 10, 4) if compact else adventure_button_style(primary, state))
	if night:
		_unify_night_fonts(btn)
		return
	# 指定过字号的按钮**不吃 compact 分档**：同一列按钮必须同号，否则同为 286×46 的
	# 两个按钮会因为 primary 不同而一个 24 一个 20（R657 修的就是 Esc 菜单这个）。
	var ov := int(btn.get_meta("fs_override", 0))
	var fs := ov if ov > 0 else (FS_LABEL if compact else (FS_HEADING if primary else FS_SUBHEAD))
	var face := font_bold() if primary else font()
	while fs > FS_CAPTION and face.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > btn.size.x - (20 if compact else 68):
		fs -= 1
	btn.add_theme_font_size_override("font_size", fs)

static func apply_button(btn: Button, primary := false, _on_dark := false,
		fs_override := 0) -> void:
	## `fs_override > 0` 时**强制**该字号（缩字逻辑也只从这个上限往下走），用于
	## 「同一列按钮必须同号」的场合 —— Esc 菜单就这么用（R657）。
	## 不传则沿用老规则：主按钮 FS_HEADING、次按钮 FS_SUBHEAD。
	if btn == null:
		return
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, adventure_button_style(primary, state))
	btn.add_theme_stylebox_override("focus", _btn_box(Color.TRANSPARENT, ADVENTURE_BRASS_LIT, 2, RADIUS_SM))
	var ink := ADVENTURE_LIGHT if primary else PAGE_INK
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, ink)
	btn.add_theme_color_override("font_disabled_color", PAGE_MUTED)
	btn.add_theme_font_override("font", font_bold() if primary else font())
	if fs_override > 0:
		btn.set_meta("fs_override", fs_override)
	var fs0: int = fs_override if fs_override > 0 else (FS_HEADING if primary else FS_SUBHEAD)
	btn.add_theme_font_size_override("font_size", fs0)
	var fit := _fit_action_button.bind(btn, primary)
	if not btn.resized.is_connected(fit):
		btn.resized.connect(fit)
	fit.call_deferred()
	UiPressFx.attach(btn)


static func apply_paper_panel(panel: Panel) -> void:
	if panel != null:
		panel.add_theme_stylebox_override("panel", _btn_box(PAGE_PAPER, ADVENTURE_BRASS, 1, RADIUS_MD, 12, 12))


static func draw_panel_bg(canvas: CanvasItem, rect: Rect2) -> void:
	var tex := UiAssets.get_tex("adventure_shared/panel_journal_light_hd")
	if rect.size.y < 180 or tex == null:
		canvas.draw_style_box(_btn_box(PAGE_PAPER, ADVENTURE_BRASS, 1, RADIUS_SM, 12, 12), rect)
		return
	# High-resolution source, independent 34px destination corners preserve existing content insets.
	var source_x := [0.0, 68.0, tex.get_width() - 68.0, float(tex.get_width())]
	var source_y := [0.0, 68.0, tex.get_height() - 68.0, float(tex.get_height())]
	var xs := [rect.position.x, rect.position.x + 34, rect.end.x - 34, rect.end.x]
	var ys := [rect.position.y, rect.position.y + 34, rect.end.y - 34, rect.end.y]
	for y in 3:
		for x in 3:
			canvas.draw_texture_rect_region(tex, Rect2(xs[x], ys[y], xs[x+1]-xs[x], ys[y+1]-ys[y]),
					Rect2(source_x[x], source_y[y], source_x[x+1]-source_x[x], source_y[y+1]-source_y[y]))


const PAGE_PAPER := Color("f3eee2")
const PAGE_INK := Color("514735")
const PAGE_MUTED := Color("887b65")
const PAGE_GOLD := Color("cbb47e")
const PAGE_GREEN := Color("4c9a52")


## ---- R519：舞台（16:9 内容区）-------------------------------------------------
## 所有界面都是按 1280×720 排的。`window/stretch/aspect` 是 expand —— 屏幕一宽
## （手机 20:9、带鱼屏），逻辑视口就被拉宽成 1920×720，坐标却还是 0..1280，
## 于是内容全挤在左边、右侧空一大片。
##
## 这里把**内容**固定成 1280×720 的舞台并居中；背景不跟着缩，用 `bleed_rect()`
## 铺满整个窗口。好处是：坐标一行都不用改、内容永远居中、两侧是背景图自然延伸
## （不是黑边，也不是留白）。
const STAGE_W := 1280.0
const STAGE_H := 720.0


static func stage_origin(vp: Vector2) -> Vector2:
	## 舞台左上角在**视口坐标**里的位置。CanvasLayer 上的东西（`TopBar` 这类 autoload
	## HUD）不继承场景根的 1280 舞台，要自己按这个原点贴上去，否则会贴在屏幕最左缘、
	## 和居中的内容脱开。
	return Vector2(maxf(0.0, (vp.x - STAGE_W) * 0.5), maxf(0.0, (vp.y - STAGE_H) * 0.5))


static func fit_stage(c: Control) -> void:
	## 把 c 摆成「居中的 16:9 舞台」。视口比舞台大就居中，小就贴满（不会出现负偏移）。
	if c == null or not c.is_inside_tree():
		return
	var vp := c.get_viewport_rect().size
	var w := minf(STAGE_W, vp.x)
	var h := minf(STAGE_H, vp.y)
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.size = Vector2(w, h)
	c.position = Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)


static func bleed_rect(c: Control) -> Rect2:
	## 背景要铺满**整个窗口**：用舞台本地坐标表示 = 左上角取 -position、尺寸取视口。
	if c == null:
		return Rect2(Vector2.ZERO, Vector2(STAGE_W, STAGE_H))
	return Rect2(-c.position, c.get_viewport_rect().size)


static func attach_stage(c: Control) -> void:
	## 一行接入：设好舞台 + 跟随窗口尺寸变化重新居中（每个实例只接一次）。
	fit_stage(c)
	if c == null or c.has_meta("_stage_attached"):
		return
	c.set_meta("_stage_attached", true)
	var vp := c.get_viewport()
	if vp == null:
		return
	# ⚠️ 必须弱引用：lambda 直接捕获 c 会把场景根钉住，节点释放后 viewport 再发
	#    size_changed 就是「调已释放对象」。`queue_redraw` 也走弱引用同一个回调。
	var wr: WeakRef = weakref(c)
	vp.size_changed.connect(func() -> void:
		var cc = wr.get_ref()
		if cc != null:
			fit_stage(cc)
			cc.queue_redraw())


static func win_dx(c: Control) -> float:
	## 窗口比舞台**每侧**多出来的宽度（舞台居中，左右各一份）。
	## 「要贴屏幕边缘」的元素 = 1280 设计坐标 + 这个量；顶栏底带则左右各溢一份。
	if c == null or not c.is_inside_tree():
		return 0.0
	return maxf(0.0, (c.get_viewport_rect().size.x - STAGE_W) * 0.5)


static func stretch_topbar(bar: Control) -> void:
	## R519b（用户口径）：**顶栏横跨整个屏幕宽**，但上面的元素不掉队 ——
	## 左端信息、中间标题留在原设计位置；贴着右端的按钮组整体重新锚到窗口右缘。
	## ⚠️ 只认 `Button`：像战斗顶栏的 `StatusLabel`（敌人状态那行）虽然也排在右半边，
	##    但它是「接着血条往下读」的信息，被拽到右边就和血条断开了。
	if bar == null or not bar.is_inside_tree():
		return
	_apply_stretch_topbar(bar)
	if bar.has_meta("_bar_stretched"):
		return
	bar.set_meta("_bar_stretched", true)
	var vp := bar.get_viewport()
	if vp == null:
		return
	var wr: WeakRef = weakref(bar)
	vp.size_changed.connect(func() -> void:
		var bb = wr.get_ref()
		if bb != null:
			_apply_stretch_topbar(bb))


static func _apply_stretch_topbar(bar: Control) -> void:
	var p := bar.get_parent() as Control
	if p == null:
		return
	# ① 先把右侧按钮组换成右锚（此刻 bar 还是设计宽度，量的就是「距设计右缘多远」）
	for ch in bar.get_children():
		var c := ch as Control
		if c == null or not (c is Button) or c.has_meta("_bar_right_pin"):
			continue
		if c.offset_left < STAGE_W * 0.5:
			continue
		var d_l := STAGE_W - c.offset_left
		var d_r := STAGE_W - c.offset_right
		c.set_meta("_bar_right_pin", true)
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.offset_left = -d_l
		c.offset_right = -d_r
	# ② 底带铺满窗口（高度不变，纵向不动）
	var r := bleed_rect(p)
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar.position.x = r.position.x
	bar.size.x = r.size.x


static func bleed_child(c: Control) -> void:
	## 让某个子节点铺满**整个窗口**（父节点是舞台，所以用负偏移溢出去）。
	## 用于「不该跟着内容一起缩」的层：纯色底、整屏底图。
	## ⚠️ 只在父节点是舞台（`attach_stage` 已生效）时才有意义。
	if c == null:
		return
	var p := c.get_parent() as Control
	if p == null:
		return
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var r := bleed_rect(p)
	c.position = r.position
	c.size = r.size
	if c.has_meta("_bleed_attached"):
		return
	c.set_meta("_bleed_attached", true)
	var vp := c.get_viewport()
	if vp == null:
		return
	var wr: WeakRef = weakref(c)
	vp.size_changed.connect(func() -> void:
		var cc = wr.get_ref()
		if cc == null:
			return
		var pp := cc.get_parent() as Control
		if pp == null:
			return
		var rr := bleed_rect(pp)
		cc.position = rr.position
		cc.size = rr.size)


static func draw_page(canvas: CanvasItem, rect: Rect2) -> void:
	var paper: Texture2D = UiAssets.panel_parchment()
	if paper != null:
		canvas.draw_texture_rect(paper, rect, true)
	else:
		canvas.draw_rect(rect, PAGE_PAPER)
	draw_panel_bg(canvas, rect.grow(-16.0))


const SCROLL_EDGE := 0.16   # 羊皮卷九宫格：角块取源图宽/高的 16%


static func draw_scroll_bg(canvas: CanvasItem, rect: Rect2) -> void:
	# Shared journal frame replaces the old burnt scroll across common dialogs.
	draw_panel_bg(canvas, rect)


static func apply_chip(btn: Button, solid := false, compact := false) -> void:
	if btn == null:
		return
	var px: int = CHIP_COMPACT_PAD_X if compact else CHIP_PAD_X
	var py: int = CHIP_COMPACT_PAD_Y if compact else CHIP_PAD_Y
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var selected: bool = state == "pressed" or state == "hover_pressed"
		var dark: bool = solid or selected
		var bg := ADVENTURE_FOREST if dark else ADVENTURE_INPUT
		if state == "hover" or state == "hover_pressed":
			bg = bg.lightened(0.08)
		if state == "disabled":
			bg = PAGE_PAPER
		btn.add_theme_stylebox_override(state, _chip_box(bg, ADVENTURE_BRASS, 1, px, py))
	btn.add_theme_stylebox_override("focus", _chip_box(Color.TRANSPARENT, ADVENTURE_BRASS_LIT, 2, px, py))
	btn.add_theme_color_override("font_color", ADVENTURE_LIGHT if solid else PAGE_INK)
	btn.add_theme_color_override("font_hover_color", ADVENTURE_LIGHT if solid else PAGE_INK)
	btn.add_theme_color_override("font_pressed_color", ADVENTURE_LIGHT)
	btn.add_theme_color_override("font_hover_pressed_color", ADVENTURE_LIGHT)
	btn.add_theme_color_override("font_focus_color", ADVENTURE_LIGHT if solid else PAGE_INK)
	btn.add_theme_color_override("font_disabled_color", PAGE_MUTED)
	btn.add_theme_font_override("font", font())
	btn.add_theme_font_size_override("font_size", FS_LABEL)
	UiPressFx.attach(btn)


const ADVENTURE_FOREST := Color("2d3c30")
const ADVENTURE_LIGHT := Color("f4ecda")
const ADVENTURE_BRASS := Color("a58c58")
const ADVENTURE_BRASS_LIT := Color("dbc58d")
const ADVENTURE_INPUT := Color("eee5d2")

## ---- R516：事件页统一暗紫肤 --------------------------------------------------
## 用户口径：事件里「大块白底 + 接近白的背景」观感不好 → 全部换成暗紫底 + 米色字，
## 按钮**造型不变**（同样的胶囊圆角、同样的黄铜细边、同样的内距），只把底色压深。
## 只服务事件页（`event_scene`）；标题页 / 战斗 / 卡组编辑等仍各用各的，不受影响。
const NIGHT_BG_TOP := Color("141020")      ## 页面底：上（更冷更暗）
const NIGHT_BG_BOT := Color("1d1628")      ## 页面底：下
const NIGHT_CARD := Color("241a2e")        ## 信息卡底
const NIGHT_CARD_HOVER := Color("2e2239")  ## 信息卡底（悬浮）
const NIGHT_BTN := Color("2b2135")         ## 按钮底
const NIGHT_BTN_HOVER := Color("3a2c48")   ## 按钮底（悬浮）
const NIGHT_BTN_PRESSED := Color("221a2b") ## 按钮底（按下）
const NIGHT_BTN_DISABLED := Color("1b1622")
const NIGHT_INK := Color("e8dfc8")         ## 正文：米色
const NIGHT_INK_DIM := Color("a99c86")     ## 次要文字
const NIGHT_LINE := Color("6c5a86")        ## 分隔线（暗紫）


static func night_button_style(state := "normal") -> StyleBox:
	## R517：事件页的深色按钮 —— **形状与质感全部沿用 adventure_shared 的缎带素材**
	## （两端尖角 + 黄铜金线 + 纸面纹理 + 两侧四角星），只把它们换成暗紫肤。
	##
	## R516 的教训：这里本来用 `_btn_box` 画了个纯色小圆角矩形，底色对了，
	## 但尖角、金线、纹理全丢 → 用户一眼看出「风格没保留」。
	## 素材不是运行时调色做出来的，而是 `art_src/2026-11-07_暗紫按钮` 里
	## 按「暖度」把纸面与金线分开重映射、离线生成的四张 PNG（见该目录 README）。
	## 所以别在这里加 modulate_color：乘色会把本来就比纸暗的金线压成暗红、直接消失。
	var key := "button_night"
	if state == "hover" or state == "hover_pressed":
		key = "button_night_hover"
	elif state == "pressed":
		key = "button_night_pressed"
	elif state == "disabled":
		key = "button_night_disabled"
	var tex: Texture2D = UiAssets.get_tex("adventure_shared/" + key)
	if tex == null:
		# 素材缺失时的纯色兜底：形状仍跟着 adventure 按钮走（小圆角 + 黄铜细边）
		var bg := NIGHT_BTN
		var border := ADVENTURE_BRASS
		if state == "hover" or state == "hover_pressed":
			bg = NIGHT_BTN_HOVER
			border = ADVENTURE_BRASS_LIT
		elif state == "pressed":
			bg = NIGHT_BTN_PRESSED
		elif state == "disabled":
			bg = NIGHT_BTN_DISABLED
		return _btn_box(bg, border, 1, RADIUS_SM, BTN_PAD_X, BTN_PAD_Y)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	# 两端 46px 保形（尖角 + 四角星），中段自由拉伸；素材 400×92 → 按钮 46 高时
	# 纵向中段被压扁，金线相应变细，与浅色按钮在同一页上时厚度一致。
	sb.texture_margin_left = 46
	sb.texture_margin_right = 46
	sb.texture_margin_top = 16
	sb.texture_margin_bottom = 16
	sb.set_content_margin(SIDE_LEFT, maxi(BTN_PAD_X, 34))
	sb.set_content_margin(SIDE_RIGHT, maxi(BTN_PAD_X, 34))
	sb.set_content_margin(SIDE_TOP, BTN_PAD_Y)
	sb.set_content_margin(SIDE_BOTTOM, BTN_PAD_Y)
	return sb


static func apply_night_button(btn: Button, primary := false) -> void:
	## 事件页专用按钮：暗紫胶囊 + 米色字。与 `apply_button` 的区别只有配色，
	## 内距 / 字体 / 自适应字号 / 按压反馈全部复用同一套。
	if btn == null:
		return
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, night_button_style(state))
	btn.add_theme_stylebox_override("focus", _btn_box(Color.TRANSPARENT, ADVENTURE_BRASS_LIT, 2, RADIUS_SM))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, NIGHT_INK)
	btn.add_theme_color_override("font_disabled_color", NIGHT_INK_DIM.darkened(0.25))
	btn.add_theme_font_override("font", font_bold() if primary else font())
	btn.add_theme_font_size_override("font_size", FS_HEADING if primary else FS_SUBHEAD)
	var fit := _fit_action_button.bind(btn, primary, true)
	if not btn.resized.is_connected(fit):
		btn.resized.connect(fit)
	# 事件分支改 `text` 时按钮尺寸不变、`resized` 不会发 → 字号不会重算。
	# `minimum_size_changed` 会跟着文本变（文字变长 → 最小宽度变），补上这条路。
	if not btn.minimum_size_changed.is_connected(fit):
		btn.minimum_size_changed.connect(fit)
	fit.call_deferred()
	UiPressFx.attach(btn)

static func adventure_button_style(primary: bool, state := "normal", px := BTN_PAD_X, py := BTN_PAD_Y) -> StyleBox:
	var key := "button_disabled" if state == "disabled" else ("button_forest" if primary else "button_paper")
	var tex: Texture2D = UiAssets.get_tex("adventure_shared/" + key)
	if tex == null:
		return _btn_box(ADVENTURE_FOREST if primary else PAGE_PAPER, ADVENTURE_BRASS, 1, RADIUS_SM, px, py)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 28
	sb.texture_margin_right = 28
	sb.texture_margin_top = 12
	sb.texture_margin_bottom = 12
	sb.set_content_margin(SIDE_LEFT, maxi(px, 34))
	sb.set_content_margin(SIDE_RIGHT, maxi(px, 34))
	sb.set_content_margin(SIDE_TOP, py)
	sb.set_content_margin(SIDE_BOTTOM, py)
	if state == "hover" or state == "hover_pressed":
		sb.modulate_color = Color(1.12, 1.12, 1.08)
	elif state == "pressed":
		sb.modulate_color = Color(0.82, 0.84, 0.78)
	return sb


static func adventure_panel_style(padding := 24.0, dark := false) -> StyleBox:
	if dark:
		return _btn_box(ADVENTURE_FOREST, ADVENTURE_BRASS, 1, RADIUS_SM, int(padding), int(padding))
	var tex: Texture2D = UiAssets.get_tex("adventure_shared/panel_journal_light")
	if tex == null:
		return _btn_box(PAGE_PAPER, ADVENTURE_BRASS, 1, RADIUS_MD, int(padding), int(padding))
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(34.0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.set_content_margin_all(padding)
	return sb


static var _adventure_controls: Theme

static func control_theme() -> Theme:
	if _adventure_controls != null:
		return _adventure_controls
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FS_LABEL
	for kind in ["Button", "OptionButton", "MenuButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(state, kind, adventure_button_style(false, state, 12, 6))
		t.set_stylebox("focus", kind, _btn_box(Color.TRANSPARENT, ADVENTURE_BRASS_LIT, 2, RADIUS_SM))
		for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(role, kind, PAGE_INK)
		t.set_color("font_disabled_color", kind, PAGE_MUTED)
	for kind in ["OptionButton", "MenuButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var bg := ADVENTURE_INPUT if state != "hover" else PAGE_PAPER
			t.set_stylebox(state, kind, _btn_box(bg, ADVENTURE_BRASS, 1, RADIUS_SM, 12, 6))
	for kind in ["Panel", "PanelContainer", "PopupPanel", "AcceptDialog", "ConfirmationDialog"]:
		t.set_stylebox("panel", kind, adventure_panel_style(18.0, kind == "Panel"))
	for kind in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, _btn_box(ADVENTURE_INPUT, ADVENTURE_BRASS, 1, RADIUS_SM, 10, 6))
		t.set_stylebox("focus", kind, _btn_box(Color.TRANSPARENT, ADVENTURE_BRASS_LIT, 2, RADIUS_SM, 10, 6))
		t.set_stylebox("read_only", kind, _btn_box(PAGE_PAPER, PAGE_GOLD, 1, RADIUS_SM, 10, 6))
		t.set_color("font_color", kind, PAGE_INK)
		t.set_color("font_placeholder_color", kind, PAGE_MUTED)
		t.set_color("caret_color", kind, ADVENTURE_FOREST)
		t.set_color("selection_color", kind, ADVENTURE_FOREST)
		t.set_color("font_selected_color", kind, ADVENTURE_LIGHT)
	t.set_stylebox("panel", "PopupMenu", adventure_panel_style(12.0))
	t.set_stylebox("hover", "PopupMenu", _btn_box(ADVENTURE_INPUT, ADVENTURE_BRASS, 1, RADIUS_SM))
	t.set_color("font_color", "PopupMenu", PAGE_INK)
	t.set_color("font_hover_color", "PopupMenu", PAGE_INK)
	t.set_color("font_disabled_color", "PopupMenu", PAGE_MUTED)
	for kind in ["HScrollBar", "VScrollBar", "HSlider", "VSlider"]:
		t.set_stylebox("scroll", kind, _btn_box(ADVENTURE_INPUT, PAGE_GOLD, 1, RADIUS_SM, 3, 3))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			t.set_stylebox(state, kind, _btn_box(ADVENTURE_FOREST, ADVENTURE_BRASS, 1, RADIUS_SM, 3, 3))
		t.set_stylebox("slider", kind, _btn_box(ADVENTURE_INPUT, PAGE_GOLD, 1, RADIUS_SM, 3, 3))
		t.set_stylebox("grabber_area", kind, _btn_box(ADVENTURE_FOREST, ADVENTURE_BRASS, 1, RADIUS_SM, 3, 3))
	t.set_stylebox("background", "ProgressBar", _btn_box(ADVENTURE_INPUT, ADVENTURE_BRASS, 1, RADIUS_SM, 4, 3))
	t.set_stylebox("fill", "ProgressBar", _btn_box(ADVENTURE_FOREST, ADVENTURE_BRASS, 1, RADIUS_SM, 4, 3))
	t.set_stylebox("panel", "TooltipPanel", adventure_panel_style(12.0, true))
	t.set_color("font_color", "TooltipLabel", ADVENTURE_LIGHT)
	_adventure_controls = t
	return t


static func draw_action(canvas: CanvasItem, rect: Rect2, primary := false, disabled := false, hovered := false) -> void:
	var state := "disabled" if disabled else ("hover" if hovered else "normal")
	if rect.size.x < 200.0 or rect.size.y <= 44.0:
		var bg := ADVENTURE_FOREST if primary else ADVENTURE_INPUT
		canvas.draw_style_box(_chip_box(bg, ADVENTURE_BRASS, 1, 8, 3), rect)
	else:
		canvas.draw_style_box(adventure_button_style(primary, state, 10, 4), rect)


static func draw_close(canvas: CanvasItem, rect: Rect2, hovered: bool) -> void:
	var tex := UiAssets.small_icon("adventure_shared/close_forest", 64)
	if tex != null:
		var edge := minf(rect.size.x, rect.size.y)
		canvas.draw_texture_rect(tex, Rect2(rect.get_center() - Vector2.ONE * edge / 2, Vector2.ONE * edge), false,
				Color(1.15, 1.15, 1.15) if hovered else Color.WHITE)

static func draw_info_card(canvas: CanvasItem, rect: Rect2, hovered := false, dark := false) -> void:
	## dark（R513 起为全部事件）：暗页上的信息卡 —— 暗紫底 + 黄铜细线。
	## 浅底上的 #f3eee2 纸卡放进深色背景会变成一块发亮的便利贴；
	## 背景、卡片、文字三处的明暗关系必须一起翻过来才成立。
	if dark:
		var sbd := _btn_box(NIGHT_CARD_HOVER if hovered else NIGHT_CARD, ADVENTURE_BRASS, 1, RADIUS_MD, 12, 12)
		sbd.shadow_color = Color(0, 0, 0, 0.55)
		sbd.shadow_size = 10
		sbd.shadow_offset = Vector2(0, 3)
		canvas.draw_style_box(sbd, rect)
		return
	var sb := _btn_box(ADVENTURE_INPUT if hovered else PAGE_PAPER, ADVENTURE_BRASS, 1, RADIUS_MD, 12, 12)
	sb.shadow_color = Color(0.18, 0.14, 0.08, 0.12)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	canvas.draw_style_box(sb, rect)

static func draw_secondary_btn(canvas: CanvasItem, rect: Rect2, text: String, hovered := false, disabled := false, primary := false) -> void:
	draw_action(canvas, rect, primary and not disabled, disabled, hovered)
	var fs := mini(FS_BODY, int(rect.size.y * 0.48))
	while fs > 10 and font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x - 16:
		fs -= 1
	var ink := PAGE_MUTED if disabled else (ADVENTURE_LIGHT if primary else PAGE_INK)
	var baseline := rect.get_center().y + (font_bold().get_ascent(fs) - font_bold().get_descent(fs)) * 0.5
	canvas.draw_string(font_bold(), Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, ink)
