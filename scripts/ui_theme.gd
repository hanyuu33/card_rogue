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
## * `font_bold()` 依赖系统提供 Bold 字面，**headless 下无法验证粗细是否可见**。
##   若要 100% 可控 → 把 `.ttf` 放进 `assets/fonts/` 改用 `FontFile` 加载
##   （同时解决跨机字形/字宽漂移，对「手算文字宽度」的绘制方式是实际收益）。

# ══════════════════════════════════════════════════════════════════════
# 字体
# ══════════════════════════════════════════════════════════════════════

## 字体族优先级：微软雅黑 UI → 微软雅黑 → 黑体。**唯一一处**字体族声明。
## ⚠️ 必须是**数组字面量**：`const X := PackedStringArray([...])` 不是常量表达式，会解析失败。
const FONT_NAMES := ["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"]

## 系统粗体字面档（`font_weight`）。见文末「未决」。
const FONT_WEIGHT_BOLD := 700

static var _font: SystemFont = null
static var _font_bold: SystemFont = null


static func font() -> SystemFont:
	## 正文/常规字体。全工程共用一个实例。
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(FONT_NAMES)
	return _font


static func font_bold() -> SystemFont:
	## 强调字体。R113 起真正请求 Bold 字面（此前 `_font_bold` 与 `_font` 同款，粗体是假的）。
	if _font_bold == null:
		_font_bold = SystemFont.new()
		_font_bold.font_names = PackedStringArray(FONT_NAMES)
		_font_bold.font_weight = FONT_WEIGHT_BOLD
	return _font_bold


# ══════════════════════════════════════════════════════════════════════
# 字号阶（9 档）
# ══════════════════════════════════════════════════════════════════════
#
# 体检时是 19 档（8~64px）：17/18/19/22/26/30/34 全是只出现一两次的孤值，
# 15 与 16、17 与 18 肉眼几乎分不出 —— 它们只把层级搅浑。
#
# ⚠️ 为什么是 **9 档而不是 7 档**：R113 实测全工程 213 处设置点，其中 8~14px 段占了
#   绝大多数（8/9/10/11/12/13/14 共 149 处）。这是一块 1280×720 的**信息密集**策略界面，
#   底部确实需要一档「微型字」（棋盘表头、能量、卡组计数…）。若硬压成 7 档，
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
const CARD_ART_RATIO := 0.50
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

## 徽章圆盘色：**缺图标素材时的回退底衬**，同时充当图例（一个通道一个含义）。
const BADGE_COST := Color("2255aa")    ## 费用（水晶）
const BADGE_POWER := Color("8a5f00")   ## 力量（剑）
const BADGE_RANGE := Color("1f6b6b")   ## 攻击距离（弓）
const BADGE_HEALTH := Color("c1121f")  ## 生命（血）
const BADGE_SPEED := Color("4f4a8a")   ## 移动距离（鞋）
const BADGE_OUTLINE := Color(0.05, 0.05, 0.07, 0.94)  ## 压在图标上的数字描边
const BADGE_VALUE := Color("ffffff")   ## 徽章数字


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

# ── 卡种（`card_face.gd` 的种类着色）──
const KIND_ALLY := Color("2a7a2a")    ## 盟友
const KIND_SKILL := Color("7a2a7a")   ## 技能
const KIND_EFFECT := Color("1d7a4f")  ## 效果
const KIND_FORT := Color("7a5a2a")    ## 工事
const KIND_FALLBACK := Color("808080")  ## 未知种类

## 卡面说明文字里的「关键字」高亮（如数值、费用）。4.74:1。
const CODE_TEXT := Color("a8621f")

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

# ── 强调 / 状态 ──
const ACCENT_GOLD := Color("c8951c")  ## 装饰 / 描边
const ACCENT_LIT := Color("f2c14e")   ## 高亮 / 奖励
const STATE_GUARD := Color("1d9e4f")  ## 护盾
const STATE_TAUNT := Color("ff8f00")  ## 嘲讽
const STATE_FROZEN := Color("6ec6ff") ## 冰冻
const STATE_SLEEP := Color("b07bff")  ## 沉睡

# ── 滚动提示（R126）──
## 地图「还能上下滚」的半透明双箭头。第一枚亮、第二枚更淡 → 形成层次，
## 读起来就是「双箭头」（= 还有更多），而不是两个孤立的三角。
## ⚠️ 地图上会与节点重叠（地图节点是亮橙/亮绿）→ 箭头的**下沿再垫一道更粗的暗色折线**
## （与卡面数字描边同一手法），否则浅色箭头会被亮节点淹没。
const HINT_CHEVRON := Color(1, 1, 1, 0.52)      ## 第一枚（离内容更近的那枚）
const HINT_CHEVRON_DIM := Color(1, 1, 1, 0.26)  ## 第二枚（更淡）
const HINT_CHEVRON_HALO := Color(0.05, 0.06, 0.09, 0.55)  ## 垫底的暗色描边


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
const BTN_PRIMARY_BG := Color("22304a")        ## 深墨蓝（日式西幻的夜色）
const BTN_PRIMARY_BG_HOVER := Color("2c3f61")
const BTN_PRIMARY_BG_PRESS := Color("1a2438")
const BTN_PRIMARY_LINE := Color("c8951c")      ## 金线
const BTN_PRIMARY_LINE_FOCUS := Color("f2c14e") ## 焦点环（更亮，键盘可达性）
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
const BTN_SECONDARY_TEXT := Color("1a1c22")

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
const CHIP_TEXT := Color("1a1c22")
const CHIP_PAD_X := 12
const CHIP_PAD_Y := 5

## 实心档（solid）：实心暗蓝灰 + 亮字 —— 顶部工具条 / HUD，要从背景里跳出来。
## 取值沿用 `map_scene` 原本手写的样式，所以地图页观感**不变**，只是收进唯一口、并补回焦点环
## （原来那里把 focus 设成了 `StyleBoxEmpty`，键盘可达性直接没了）。
const CHIP_SOLID_BG := Color("343947")
const CHIP_SOLID_BG_HOVER := Color("414860")
const CHIP_SOLID_BG_PRESS := Color("272b37")
const CHIP_SOLID_LINE := Color(0, 0, 0, 0.35)
const CHIP_SOLID_TEXT := Color("e6e2d8")
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


static func apply_button(btn: Button, primary := false, on_dark := false) -> void:
	## 给按钮套上统一规格（**唯一口**）。新界面写按钮就调这一行，别自己画 StyleBox。
	##   primary = 主行动。**一屏最多一个**；选择类界面（多个等价选项）可以全是次按钮。
	##   on_dark = 按钮坐在**暗底**上。除标题页外，本作其余界面底色都是暗的，
	##             **暗底上必须传 true**，否则深字压暗底读不出来。
	if btn == null:
		return
	var r := RADIUS_MD
	var bg := BTN_SECONDARY_BG
	var bg_h := BTN_SECONDARY_BG_HOVER
	var bg_p := BTN_SECONDARY_BG_PRESS
	var line := BTN_SECONDARY_LINE
	var line_focus := BTN_SECONDARY_LINE_FOCUS
	var txt := BTN_SECONDARY_TEXT
	var txt_h := Color("1a1c22")
	var font_size := FS_SUBHEAD
	var use_bold := false
	if primary:
		font_size = FS_HEADING
		use_bold = true
		line_focus = BTN_PRIMARY_LINE_FOCUS
		txt_h = Color("ffffff")
		if on_dark:
			bg = BTN_PRIMARY_DARK_BG
			bg_h = BTN_PRIMARY_DARK_BG_HOVER
			bg_p = BTN_PRIMARY_DARK_BG_PRESS
			line = BTN_PRIMARY_DARK_LINE
			txt = BTN_PRIMARY_DARK_TEXT
		else:
			bg = BTN_PRIMARY_BG
			bg_h = BTN_PRIMARY_BG_HOVER
			bg_p = BTN_PRIMARY_BG_PRESS
			line = BTN_PRIMARY_LINE
			txt = BTN_PRIMARY_TEXT
	elif on_dark:
		bg = BTN_SECONDARY_DARK_BG
		bg_h = BTN_SECONDARY_DARK_BG_HOVER
		bg_p = BTN_SECONDARY_DARK_BG_PRESS
		line = BTN_SECONDARY_DARK_LINE
		txt = BTN_SECONDARY_DARK_TEXT
		txt_h = Color("ffffff")
		line_focus = BTN_PRIMARY_LINE_FOCUS
	var w := 2 if primary else 1
	btn.add_theme_stylebox_override("normal", _btn_box(bg, line, w, r))
	btn.add_theme_stylebox_override("hover", _btn_box(bg_h, line, w, r))
	btn.add_theme_stylebox_override("pressed", _btn_box(bg_p, line, w, r))
	btn.add_theme_stylebox_override("disabled", _btn_box(bg, BTN_DISABLED_LINE, w, r))
	btn.add_theme_stylebox_override("focus", _btn_box(Color(0, 0, 0, 0), line_focus, 3, r))
	btn.add_theme_color_override("font_color", txt)
	btn.add_theme_color_override("font_hover_color", txt_h)
	btn.add_theme_color_override("font_pressed_color", txt)
	btn.add_theme_color_override("font_focus_color", txt)
	btn.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)
	btn.add_theme_font_override("font", font_bold() if use_bold else font())
	btn.add_theme_font_size_override("font_size", font_size)


static func apply_chip(btn: Button, solid := false, compact := false) -> void:
	## 小按钮规格（**唯一口**）：顶部工具条 / HUD、难度档位、筛选、多选标签。
	##   solid   = 实心暗蓝灰 + 亮字（**工具条 / HUD**，要从背景里跳出来）
	##   compact = 更小的内距（给固定高度的工具条用，如 battle 顶栏按钮只有 28px 高）
	##
	## 切换按钮（`toggle_mode = true`）的**选中态由 `button_pressed` 驱动** —— Godot 在按下态
	## 画 "pressed" 样式，所以**不需要**每次刷新重设样式。
	if btn == null:
		return
	var px: int = CHIP_COMPACT_PAD_X if compact else CHIP_PAD_X
	var py: int = CHIP_COMPACT_PAD_Y if compact else CHIP_PAD_Y
	if solid:
		# 常态：只留底边；选中 / 按下：**整圈金线 + 更亮的底**（明确「已打开」）
		btn.add_theme_stylebox_override("normal",
				_chip_box(CHIP_SOLID_BG, CHIP_SOLID_LINE, 2, px, py, true))
		btn.add_theme_stylebox_override("hover",
				_chip_box(CHIP_SOLID_BG_HOVER, CHIP_SOLID_LINE, 2, px, py, true))
		btn.add_theme_stylebox_override("pressed",
				_chip_box(CHIP_SOLID_BG_HOVER, BTN_PRIMARY_LINE, 2, px, py))
		btn.add_theme_stylebox_override("hover_pressed",
				_chip_box(CHIP_SOLID_BG_HOVER, BTN_PRIMARY_LINE_FOCUS, 2, px, py))
		btn.add_theme_stylebox_override("disabled",
				_chip_box(CHIP_SOLID_BG, BTN_DISABLED_LINE, 2, px, py, true))
		btn.add_theme_stylebox_override("focus",
				_chip_box(Color(0, 0, 0, 0), BTN_PRIMARY_LINE_FOCUS, 3, px, py))
		btn.add_theme_color_override("font_color", CHIP_SOLID_TEXT)
		btn.add_theme_color_override("font_hover_color", CHIP_SOLID_TEXT_HOVER)
		btn.add_theme_color_override("font_pressed_color", BTN_PRIMARY_TEXT)
		btn.add_theme_color_override("font_hover_pressed_color", Color("ffffff"))
		btn.add_theme_color_override("font_focus_color", CHIP_SOLID_TEXT)
		btn.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)
	else:
		# 选中 / 按下 = 深墨蓝 + 金线（与主按钮同族，但体量更小）
		btn.add_theme_stylebox_override("normal", _chip_box(CHIP_BG, CHIP_LINE, 1, px, py))
		btn.add_theme_stylebox_override("hover", _chip_box(CHIP_BG_HOVER, CHIP_LINE, 1, px, py))
		btn.add_theme_stylebox_override("pressed",
				_chip_box(BTN_PRIMARY_BG, BTN_PRIMARY_LINE, 1, px, py))
		btn.add_theme_stylebox_override("hover_pressed",
				_chip_box(BTN_PRIMARY_BG_HOVER, BTN_PRIMARY_LINE, 1, px, py))
		btn.add_theme_stylebox_override("disabled",
				_chip_box(Color(1, 1, 1, 0.16), BTN_DISABLED_LINE, 1, px, py))
		btn.add_theme_stylebox_override("focus",
				_chip_box(Color(0, 0, 0, 0), BTN_SECONDARY_LINE_FOCUS, 3, px, py))
		btn.add_theme_color_override("font_color", CHIP_TEXT)
		btn.add_theme_color_override("font_hover_color", Color("1a1c22"))
		btn.add_theme_color_override("font_pressed_color", BTN_PRIMARY_TEXT)
		btn.add_theme_color_override("font_hover_pressed_color", Color("ffffff"))
		btn.add_theme_color_override("font_focus_color", CHIP_TEXT)
		btn.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)
	btn.add_theme_font_override("font", font())
	btn.add_theme_font_size_override("font_size", FS_LABEL)
