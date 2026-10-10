extends RefCounted
## 滚动容器的「上下还能滚」提示 —— **不画滚动条**，改画半透明**双箭头**。
##
## ⚠️ **故意不写 `class_name`**（与 UiTheme 同一个理由，见 ui_theme.gd 头部）：
## 全局类名要靠编辑器扫描才能进 `.godot/global_script_class_cache.cfg`，
## 而 headless 的 `--script` / `_verify.py` 认不到 → 新类名会报 not declared。
## 所以调用方一律 `const ScrollHint = preload("res://scripts/ui_scroll_hint.gd")`。

const UiTheme = preload("res://scripts/ui_theme.gd")
##
## R126 首创于冒险地图页；R127 抽出共享模块，让三处滚动容器共用同一套视觉
## （① 冒险地图页 / ② 战斗内地图总览 / ③ 棋盘格子区 —— ②③ 原先画的是右沿滚动条）。
## 规范：UI设计规范 §4.12。
##
## ## 为什么不画滚动条
##   滚动条要占一条固定宽度的右沿，还要有轨道 + 滑块的层次；内容本来就窄的时候，
##   它比「还能滚多少」这个信息更占地方。而且**滚动条还需要额外的拖动命中区** ——
##   只删视觉、留着隐形命中区，会变成「点右沿就莫名滚动」的陷阱。
##   双箭头只回答一个问题：**这个方向还有东西**。
##
## ## 画法（描边**不是**可选修饰）
##   同一条折线画两遍：先垫一道更粗的暗色（HALO），再画本色。
##   箭头是半透明的，底下压着色块 / 卡面时没有描边就整个糊掉 —— 实测出来的结论。
##
## ## 何时显示
##   只在**新玩家第一局**（判据见 `is_new_player`）；且只在该方向确实还有内容时画。
##   ⚠️ 方向语义各容器**不统一**：①② 内容偏移是 `+scroll`（越大看得越靠上），
##   ③ 是 `-_grid_scroll`（越大看得越靠下）—— 调用方各自判，别照抄。

const W := 24.0        ## 单枚箭头的半宽
const H := 9.0         ## 单枚箭头的高度（尖点到两端）
const GAP := 16.0      ## 两枚箭头之间的纵向间距
const LINE := 3.0      ## 折线粗细


## 「新玩家第一局」判据：**还没有任何战斗记录**（打完第一场之后就不再打扰）。
## 地图 / 战斗处本来就要读这份记录做「战斗记录」面板，这里复用同一份，不额外读盘。
## `-- --newplayer` 可强制打开，供截图核验（本机有战绩时默认看不到）。
## ⚠️ 会读盘 → 只在 `_ready` 里调一次，别放进 _draw。
static func is_new_player() -> bool:
	return RunState.load_records().is_empty() \
			or "--newplayer" in OS.get_cmdline_user_args()


## 呼吸系数 0.72~1.0：比静态更容易被看见，又不至于抢戏。
## 取 `Time.get_ticks_msec()` 而不是调用方自己的计时器 —— 三个场景不需要各自维护一个 `_t`。
static func breath() -> float:
	var t := float(Time.get_ticks_msec()) / 1000.0
	return 0.72 + 0.28 * (0.5 + 0.5 * sin(t * 2.6))


## 画两组双箭头。参数：
##   c     —— 目标 CanvasItem（draw 调用方自己）
##   cx    —— 两组箭头各自的中心 x
##   top_y / bot_y —— **离内容更近**那一枚箭头的尖点 y（整组朝画布外伸展）
##   up / down —— 该方向是否还有内容可滚（false 就整组不画）
##   k     —— 呼吸系数（见 `breath`）
static func draw(c: CanvasItem, cx: float, top_y: float, bot_y: float,
		up: bool, down: bool, k: float) -> void:
	if up:
		_chevron(c, Vector2(cx, top_y), -1.0, k)
	if down:
		_chevron(c, Vector2(cx, bot_y), 1.0, k)


static func _chevron(c: CanvasItem, base: Vector2, dir: float, k: float) -> void:
	## 两枚同向箭头叠放（dir = -1 朝上 / +1 朝下）；base = 第一枚的尖点。
	## 透明度 = UiTheme 令牌 × 呼吸系数 —— 不是新颜色，只是把令牌调暗。
	for i in 2:
		var col := UiTheme.HINT_CHEVRON if i == 0 else UiTheme.HINT_CHEVRON_DIM
		var y := base.y + dir * float(i) * GAP
		var pts := PackedVector2Array([
				Vector2(base.x - W, y - dir * H),
				Vector2(base.x, y),
				Vector2(base.x + W, y - dir * H)])
		# 先垫更粗的暗色（描边）→ 压在亮节点 / 卡面上也读得清
		var halo := UiTheme.HINT_CHEVRON_HALO
		c.draw_polyline(pts, Color(halo.r, halo.g, halo.b, halo.a * k), LINE + 2.5, true)
		c.draw_polyline(pts, Color(col.r, col.g, col.b, col.a * k), LINE, true)
