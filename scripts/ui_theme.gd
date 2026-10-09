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
# 字号阶（7 档）
# ══════════════════════════════════════════════════════════════════════
#
# 现状是 19 档（8~64px），其中 17/18/19/22/24/26/30/34 都是只出现一两次的孤值，
# 而 15 与 16、17 与 18 肉眼几乎分不出 —— 它们只把层级搅浑，让人读不出谁更重要。

const FS_CAPTION := 12   ## 说明文字、次要信息
const FS_LABEL := 14     ## 标签、次要正文、按钮
const FS_BODY := 16      ## 正文
const FS_SUBHEAD := 20   ## 小标题、重要数字
const FS_HEADING := 24   ## 区块标题
const FS_TITLE := 32     ## 大面板标题、结算大字
const FS_DISPLAY := 48   ## 标题页主标题

## 全部合法字号。新增界面字号**必须**落在这 7 个值上。
## ⚠️ 用**数组字面量**（`Array[int]` 类型标注的常量不可靠）。
const FS_STEPS := [FS_CAPTION, FS_LABEL, FS_BODY, FS_SUBHEAD, FS_HEADING, FS_TITLE, FS_DISPLAY]


static func nearest_font(px: int) -> int:
	## 把任意字号吸附到最近的合法档位（迁移存量用；**不要**用在卡面尺寸上）。
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
# 基阶从 6 档（7 / 7.5 / 8 / 9 / 10 / 12）收到 3 档。取值用 float 保留比例，
# 调用点必须 `roundi(CARD_FS_* * k)`，**不要 `int()`**。

const CARD_FS_NAME := 9.0    ## 卡名
const CARD_FS_VALUE := 12.0  ## 力/生数值角标
const CARD_FS_META := 9.0    ## 种类 / 程速 / 字段（原为 7~8px，提至 9px 以进入可读区）


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
const INK_600 := Color("555555")      ## 次要文字（替代散落的 #444444 / #666666）
const INK_500 := Color("6b6b6b")      ## 弱化文字（5.33:1；原 #777777 只有 4.48:1，未过 AA）
const INK_ON_DARK := Color("8a867c")  ## 暗底上的提示文字
const INK_300 := Color("b8b4aa")      ## 分割线 / 描边

# ── 底 ──
const SURFACE := Color("ffffff")      ## 卡面 / 面板底
const PAPER := Color("f7f5f0")        ## 纸面底
const SAND := Color("e8e4da")         ## 卡片槽底
const BOARD_BG := Color("e9e7e2")     ## 棋盘底

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

# ── 强调 / 状态 ──
const ACCENT_GOLD := Color("c8951c")  ## 装饰 / 描边
const ACCENT_LIT := Color("f2c14e")   ## 高亮 / 奖励
const STATE_GUARD := Color("1d9e4f")  ## 护盾
const STATE_TAUNT := Color("ff8f00")  ## 嘲讽
const STATE_FROZEN := Color("6ec6ff") ## 冰冻
const STATE_SLEEP := Color("b07bff")  ## 沉睡


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
