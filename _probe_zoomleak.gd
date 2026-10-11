extends SceneTree
## 一次性探针（headless）：**开场缩放的漏色检测器**（R146）。
##
## 原理：同一场景、同一 `_grid_scroll` 下渲染两次 —— 一次 `--gridzoom 1`（棋盘只占
##       x 392..792），一次 `--gridzoom 1.15`（棋盘外溢到 x≈362..822）。
##       只该是**背景 / 侧栏**的那几条带里，两张图必须逐像素一致；
##       任何差异 = 放大的棋盘没被 `_draw_grid_mask` 裁干净（石色 / 金线漏到侧栏上）。
##
## 用法：
##   godot --path . scenes/battle.tscn -- --screenshot --level 0 --gridscroll -16 --gridzoom 1.0  --shotframe 20
##   mv screenshot.png _ref.png
##   godot --path . scenes/battle.tscn -- --screenshot --level 0 --gridscroll -16 --gridzoom 1.15 --shotframe 20
##   mv screenshot.png _zoom.png
##   godot --headless --path . --script res://_probe_zoomleak.gd -- res://_ref.png res://_zoom.png [tol]
##
## ⚠️ **必须带自检带**：一条「放在棋盘内部、当然不一样」的带。它若报 0 差异，说明探针
##    根本没在比对 —— 「永远通过」的探针等于没测（R146 就是这么验的）。
## ⚠️ 为什么值得单独跑一次：漏出来的是 **1px 级的金线**（边框的 1.5px 描边 + 外圈投影探出
##    遮罩几个像素），在整图上肉眼几乎看不出来，出图核验抓不到。

const TOL := 10     # 每通道允许的偏差（背景纹理采样取整的细微差别）


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("!! 用法：-- <ref.png(zoom=1)> <zoom.png(zoom>1)> [tol]")
		quit()
		return
	var tol := TOL
	if a.size() >= 3:
		tol = int(a[2])
	var ia := Image.load_from_file(ProjectSettings.globalize_path(a[0]))
	var ib := Image.load_from_file(ProjectSettings.globalize_path(a[1]))
	if ia == null or ib == null:
		print("!! 读不到图：", a[0], " / ", a[1])
		quit()
		return
	if ia.get_width() != ib.get_width() or ia.get_height() != ib.get_height():
		print("!! 两张图尺寸不一致")
		quit()
		return
	# 必须「两张图一致」的带：放大的棋盘一律不该碰到的地方（棋盘 404..776、外框 392..792）。
	# 左右两条留在遮罩的加宽范围之内；上下两条避开工具体的 36px 与手牌。
	var bands := [
		["左带 (356..391, 53..591)", Rect2i(356, 53, 391 - 356, 591 - 53)],
		["右带 (793..828, 53..591)", Rect2i(793, 53, 828 - 793, 591 - 53)],
		["上带 (356..828, 38..51)", Rect2i(356, 38, 828 - 356, 51 - 38)],
		["下带 (356..828, 593..600)", Rect2i(356, 593, 828 - 356, 600 - 593)],
	]
	var all_ok := true
	for pair: Array in bands:
		var st := _scan(ia, ib, pair[1] as Rect2i, tol)
		if int(st["bad"]) != 0:
			all_ok = false
		print("  %-26s 最大偏差 %3d/255  超阈值 %4d px  %s  最差点 %s"
				% [pair[0], int(st["worst"]), int(st["bad"]),
					"OK" if int(st["bad"]) == 0 else "*** 漏色 ***", str(st["at"])])
	# 自检带：棋盘**内部**（缩放后内容当然不同）→ 必须报出差异，否则探针没在比对。
	var self_st := _scan(ia, ib, Rect2i(404, 400, 96, 100), tol)
	var self_ok := int(self_st["bad"]) > 0
	print("  %-26s 最大偏差 %3d/255  超阈值 %4d px  %s"
			% ["自检带 (棋盘内, 须不同)", int(self_st["worst"]), int(self_st["bad"]),
				"OK（探针有效）" if self_ok else "*** 探针没在比对，结果不可信 ***"])
	print("== R146 漏色检测：",
			"全部通过（放大态没有漏到侧栏）" if (all_ok and self_ok) else "**未通过，见上**")
	quit()


func _scan(ia: Image, ib: Image, r: Rect2i, tol: int) -> Dictionary:
	var bad := 0
	var worst := 0
	var at := Vector2i.ZERO
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ca := ia.get_pixel(x, y)
			var cb := ib.get_pixel(x, y)
			var d := maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b))
			var di := int(round(d * 255.0))
			if di > worst:
				worst = di
				at = Vector2i(x, y)
			if di > tol:
				bad += 1
	return {"bad": bad, "worst": worst, "at": at}
