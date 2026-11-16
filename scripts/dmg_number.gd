class_name DmgNumber
extends RefCounted
## R770：伤害数字的**美术规格唯一口**（纯函数，绘制与回归共用）。
##
## 改版动机（用户口径）：原来的飘字是「亮字 + 半透明深色底条」，读得出的只是数字，
## 读不出「这一下有多重」；拖卡预览更糟 —— 一个深红硬方块压在卡图上。参照 GBF 的
## 出伤害手感，数字本身要承担三件事：
##   ① **分量** —— 重击 / 致命在字号与配色上分级，一眼能分出「这一下疼不疼」；
##   ② **冲击** —— 出现瞬间先冲过 1 再回落（弹性 pop），配一点倾斜与横摆；
##   ③ **立体** —— 外暗描边 + 厚度层 + 顶高光，三层叠出「印上去」的实体感。
##
## ⚠️ 这里的函数**一律不许有副作用**（不读节点、不读时钟），`t` 由调用方传进来；
##    `test_engine` 的 R770 段落直接喂数值断言曲线，不构造场景。

## ⚠️ `UiTheme` **故意没有 `class_name`**（见 ui_theme.gd 文件头）—— 只能 preload。
const UiTheme = preload("res://scripts/ui_theme.gd")

## ---------------------------------------------------------------- 分级
const TIER_NORMAL := 0     ## 普通伤害
const TIER_HEAVY := 1      ## 重击（> 20）
const TIER_FATAL := 2      ## 致命（> 40）

## 两道坎按店长口径取**严格大于**：20 仍是普通、40 仍是重击 —— 门槛抬高后
## 金色留给真正的大数字，小伤害不再动不动跳金（首版 15 / 30 门槛太低）。
const HEAVY_AT := 20
const FATAL_AT := 40

## 字号倍率（相对调用方给的基准号，历史默认 20）。致命必须明显压过普通。
## R770 首版偏小（1.10/1.34/1.62）—— 实测在 1280x720 上「像普通提示文字」，
## 提到 24 / 30 / 37 px 之后才有 GBF 那种占满格子的压迫感。
const SCALE_NORMAL := 1.20
const SCALE_HEAVY := 1.50
const SCALE_FATAL := 1.85

## 拖拽 / 选目标预览的基准字号（比飘字小一档：它要待在格子里）
const PREVIEW_BASE := 24

## 三种分级的字面 / 厚度 / 描边（暖白 → 金 → 橙红，与卡面上的元素族配色不冲突）。
const CORE_NORMAL := Color("fff4e2")
const DEPTH_NORMAL := Color("a8401c")
const EDGE_NORMAL := Color("2a0804")
const CORE_HEAVY := Color("ffd35c")
const DEPTH_HEAVY := Color("b8570a")
const EDGE_HEAVY := Color("240603")
const CORE_FATAL := Color("ffa64a")
const DEPTH_FATAL := Color("c62410")
const EDGE_FATAL := Color("1f0502")
const HI_ALPHA := Color(1.0, 1.0, 1.0, 0.24)


## ---------------------------------------------------------------- 说明类飘字（徽标）
## R770b：说明类飘字（「冰封」「隐藏能源 -3」「接下 5」）原来是**便利贴** —— 直角深色方块，
## 和 GBF 化的数字摆在一起像两个年代的 UI。改成**胶囊徽标**：落地阴影 + 深底 +
## 上半弧面高光 + 一圈色相细边 + 描边文字。它们仍然要**读**（所以不进数字的弹字曲线），
## 但不再是「贴纸」。规格照样收在这里，绘制层只取数。
const LABEL_PAD_X_RATIO := 0.62   ## 左右留白 / 字号
const LABEL_PAD_Y_RATIO := 0.26   ## 上下留白 / 字号（小于左右 → 天然长条胶囊）
const LABEL_PLATE_ALPHA := 0.80   ## 深底不透明度（比旧的 TEXT_BG 0.76 略实，因为面积小）
const LABEL_EDGE_ALPHA := 0.85    ## 色相细边（太淡等于没有：0.52 实地几乎看不见）
const LABEL_SHADOW_ALPHA := 0.26  ## 落地阴影
const LABEL_ARC_ALPHA := 0.07     ## 上半弧面高光
const LABEL_GLOW_ALPHA := 0.10    ## 外圈微光（把胶囊从底图上托起来）


static func label_metrics(px: int) -> Dictionary:
	## 徽标的几何：留白与描边宽度。字号越小比例越要紧一点，否则小字被留白淹没。
	var p := maxi(7, px)
	return {
		"pad_x": int(round(float(p) * LABEL_PAD_X_RATIO)),
		"pad_y": int(round(float(p) * LABEL_PAD_Y_RATIO)),
		"outline": maxi(2, int(round(float(p) * 0.18))),
	}


static func label_ink(tint: Color) -> Color:
	## 字面：留住色相、压饱和、亮度拉满。徽标底已经是深色 —— 字再暗就糊；
	## 直接写纯白又会把「冰封」的冷色 / 「隐藏能源」的紫调丢掉。
	return Color.from_hsv(tint.h, minf(tint.s * 0.55, 0.45), 1.0)


static func label_edge(tint: Color) -> Color:
	## 细边：同色相但比字暗一档。边比字亮会抢视线，也容易变成霓虹条。
	return Color.from_hsv(tint.h, minf(tint.s, 1.0), 0.74)


## ---------------------------------------------------------------- 分级与配色
static func tier_of_amount(amount: int) -> int:
	## 绝对值分级 —— 治疗走正数，重击的门槛与伤害同口径。
	var a := absi(amount)
	if a > FATAL_AT:
		return TIER_FATAL
	if a > HEAVY_AT:
		return TIER_HEAVY
	return TIER_NORMAL


static func size_scale(tier: int) -> float:
	match tier:
		TIER_FATAL:
			return SCALE_FATAL
		TIER_HEAVY:
			return SCALE_HEAVY
		_:
			return SCALE_NORMAL


static func is_number_text(text: String) -> bool:
	## 整串是不是一个**带符号的整数**（`-12` / `+7`）—— 伤害与治疗数字的形状判据。
	## 「冰封」「接下 5」「隐藏能源 -3」这类要**读**的句子一律 false（回落到带底条样式）。
	## ⚠️ 判据**不能**写成「`amount_of_text() < 0` 就不是数字」：伤害数字本身就是负数，
	##    那样写会把所有 `-N` 都甩回说明分支（R770 首版实测：红的方块底一个没少）。
	var s := text.strip_edges()
	if s.length() < 2:
		return false
	var head := s.substr(0, 1)
	if head != "-" and head != "+":
		return false
	for i in range(1, s.length()):
		var c := s.substr(i, 1)
		if c < "0" or c > "9":
			return false
	return s.substr(1, s.length() - 1).to_int() > 0


static func amount_of_text(text: String) -> int:
	## 带符号数值（`-12` → -12，`+7` → 7）。**调用前必须先用 `is_number_text()` 判形状**；
	## 这里不负责区分「不是数字」——`String.to_int()` 对非数字返回 0，硬判会误伤真 0 伤害。
	return text.strip_edges().to_int()


static func is_default_tint(tint: Color) -> bool:
	## 调用方没做特殊染色（= 普通受击）。
	## ⚠️ 判据直接比 `UiTheme.SIDE_FOE`：R679 的中毒改毒绿、接通传递的浅红都必须走
	##    「保留色相提亮」那一支，不能被我这里的金白配色吞掉。
	return tint.is_equal_approx(UiTheme.SIDE_FOE)


static func palette(tier: int, tint: Color) -> Dictionary:
	## 返回 {core, depth, edge, hi}：
	##   core  = 字面（最亮）
	##   depth = 厚度层（往下一档，衬立体）
	##   edge  = 外描边（最暗，负责在任何底图上压出边界）
	##   hi    = 顶高光（半透白，只提亮不抢色）
	## **配色成对定**（R768 口径）：core 与 edge 必须拉开明度，符号才立得住；
	## depth 夹在中间既不能糊进 edge，也不能亮到跟 core 打架。
	if not is_default_tint(tint):
		var h := tint.h
		var s := clampf(tint.s, 0.0, 1.0)
		return {
			"core": Color.from_hsv(h, minf(s * 0.62, 0.55), 1.0),
			"depth": Color.from_hsv(h, minf(s * 0.96, 1.0), 0.58),
			"edge": Color.from_hsv(h, minf(s * 0.96, 1.0), 0.17),
			"hi": HI_ALPHA,
		}
	match tier:
		TIER_FATAL:
			return {"core": CORE_FATAL, "depth": DEPTH_FATAL,
					"edge": EDGE_FATAL, "hi": HI_ALPHA}
		TIER_HEAVY:
			return {"core": CORE_HEAVY, "depth": DEPTH_HEAVY,
					"edge": EDGE_HEAVY, "hi": HI_ALPHA}
		_:
			return {"core": CORE_NORMAL, "depth": DEPTH_NORMAL,
					"edge": EDGE_NORMAL, "hi": HI_ALPHA}


## ---------------------------------------------------------------- 动画
static func anim(t: float) -> Dictionary:
	## 一串飘字的这一帧怎么画。t = 0（刚出现）→ 1（消失）。
	## 返回 {scale, dx, dy, alpha, rot}：
	##   scale 弹性缩放；dx/dy 相对起始点的位移（dy 为负 = 向上）；
	##   alpha 整体不透明度；rot 弧度（轻微倾斜，末段回正）。
	##
	## 曲线分段（与 GBF 的手感对齐）：
	##   0.00~0.16  从 0.70 冲过 ~1.28 再落回 1.00（**先过头**，这是「弹」的来源）
	##   0.16~0.72  定住不动 —— 数字要留在眼前让人读出数值
	##   0.72~1.00  收到 0.93 并淡出
	var tc := clampf(t, 0.0, 1.0)
	var pop := 1.0
	if tc < 0.16:
		var p := tc / 0.16
		# ease(p, 0.4) 是「先快后慢」；正弦项负责冲过头那一下
		pop = lerpf(0.70, 1.0, ease(p, 0.4)) + 0.42 * sin(p * PI)
	var settle := 1.0
	if tc > 0.72:
		settle = lerpf(1.0, 0.93, (tc - 0.72) / 0.28)
	# 上飘：越到后段越慢（1 - (1-t)^2.6），停在半空等人读完再淡
	var up := -52.0 * (1.0 - pow(1.0 - tc, 2.6))
	# 右漂 + 横向微摆：避免多段伤害的数字叠成一坨死板的正直线
	var right := 13.0 * ease(tc, 0.5) + sin(tc * 5.2) * 2.0 * (1.0 - tc)
	# 前 4% 快速显形（否则第一帧的 pop 会被低 alpha 吃掉）
	var alpha := clampf(tc / 0.04, 0.0, 1.0) * (1.0 - smoothstep(0.62, 1.0, tc))
	return {
		"scale": pop * settle,
		"dx": right,
		"dy": up,
		"alpha": alpha,
		"rot": deg_to_rad(-4.5) * (1.0 - 0.55 * tc),
	}


## ---------------------------------------------------------------- 笔宽
static func outline_width(px: int) -> int:
	## 外描边宽（像素）。GBF 的数字靠这圈黑压住任何底图 —— 字号越大越要粗，
	## 但上限 10：再粗会把「8」的内孔糊实。
	return clampi(int(round(float(px) * 0.22)), 3, 10)


static func preview_size(tier: int) -> int:
	## 预览字号：**分级直接给绝对值**（不走 `PREVIEW_BASE * size_scale`，那样致命会被格子撑爆）。
	## 两位数在 36px 下约 50px 宽、三位数 75px —— 格宽 98，都放得下。
	match tier:
		TIER_FATAL:
			return 38
		TIER_HEAVY:
			return 33
		_:
			return 28
