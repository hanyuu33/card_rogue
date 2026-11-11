extends RefCounted
## R577d：战斗右栏道具格排版的唯一口（纯静态，故意不写 class_name —— headless 回归
## 读不到全局类缓存，消费方一律 const X = preload(...)，见 ui_theme.gd 的说明）。
##
## 店长口径：数量少时铺得开，数量多时收紧间距；一行最多 6 个，放不下才换行；
## 换行后把总数**按行平均分配**（每行个数差 <= 1），不是「前几行填满 + 尾巴剩 1 个」。
## 图标尺寸恒定 44 —— R577c 刚按「别糊」放大过，紧凑只体现在间距，不缩图标。

const CELL := 44.0
const MAX_COLS := 6
const ROW_STEP := 48.0
const GAP_LOOSE := 60.0
const INNER_W := 310.0
const TOP_PAD := 34.0


static func row_counts(n: int, cap: int = 12) -> Array[int]:
	var count: int = clampi(n, 1, cap)
	var rows: int = ceili(float(count) / float(MAX_COLS))
	var base: int = int(count / rows)
	var extra: int = count % rows
	var out: Array[int] = []
	for r in rows:
		if r < extra:
			out.append(base + 1)
		else:
			out.append(base)
	return out


static func rect_for(i: int, zone: Rect2, counts: Array[int]) -> Rect2:
	var row: int = 0
	var col: int = maxi(i, 0)
	for r in counts.size():
		var c: int = counts[r]
		if col < c:
			row = r
			break
		col -= c
	var cnt: int = counts[row]
	var step_x: float = CELL + GAP_LOOSE
	if cnt > 1:
		step_x = minf(step_x, (INNER_W - CELL) / float(cnt - 1))
	var total_w: float = float(cnt - 1) * step_x + CELL
	var x0: float = zone.position.x + (zone.size.x - total_w) * 0.5
	return Rect2(x0 + float(col) * step_x,
			zone.position.y + TOP_PAD + float(row) * ROW_STEP,
			CELL, CELL)
