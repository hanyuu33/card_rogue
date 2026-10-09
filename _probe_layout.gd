extends SceneTree
## 一次性探针（headless，不弹窗）：**直接 new 出界面实例**跑真正的布局函数，
## 核对 R115「数值骑在框上 → 容器必须让出 2 × CARD_BLEED × k」这件事在
## 卡高可变的容器里是否真的成立（这类东西没有自动化断言，只能这样验）。
## 用法：godot --headless --path . --script res://_probe_layout.gd

const UiTheme = preload("res://scripts/ui_theme.gd")
const DeckEdit = preload("res://scripts/deck_edit_scene.gd")
const DeckViewerScript = preload("res://scripts/deck_viewer.gd")


func _init() -> void:
	print("== 卡组编辑（间距由卡高反算）==")
	for n: int in [1, 3, 8, 15, 20, 28, 30]:
		var s: Control = DeckEdit.new()
		s.size = Vector2(1280, 720)
		var cards: Array[int] = []
		for i in n:
			cards.append(1001 + i)
		s._cards = cards
		s._layout()
		var kc: float = minf(s._ch / 70.0, UiTheme.CARD_BADGE_SCALE_CAP)
		var need: float = 2.0 * UiTheme.CARD_BLEED * kc
		print("  n=%-3d cols=%-3d 卡高=%.1f 卡宽=%.1f 间距=%.1f 需要>=%.1f  %s" % [
			n, s._cols, s._ch, s._cw, s._gap, need,
			"OK" if s._gap + 0.02 >= need else "!! 会重叠"])
		s.free()

	print()
	print("== 牌库（卡尺寸固定 76x92）==")
	var v: Node = DeckViewerScript.new()
	for n: int in [8, 22, 40]:
		var L: Dictionary = v._layout(n)
		print("  n=%-3d cols=%-3d rows=%-3d" % [n, L["cols"], L["rows"]])
	var k_dv: float = 92.0 / 70.0
	print("  k=%.3f  间距 22 → 每侧 %.1f，需要 >= %.1f  %s" % [
		k_dv, 22.0 / 2.0, UiTheme.CARD_BLEED * k_dv,
		"OK" if 11.0 + 0.02 >= UiTheme.CARD_BLEED * k_dv else "!! 会重叠"])
	v.free()

	print()
	print("== 图鉴（单元格 100x116 / 卡 76x92）==")
	var k_g: float = 92.0 / 70.0
	print("  每侧留白 水平 %.1f 垂直 %.1f，需要 >= %.1f  %s" % [
		(100.0 - 76.0) / 2.0, (116.0 - 92.0) / 2.0, UiTheme.CARD_BLEED * k_g,
		"OK" if (100.0 - 76.0) / 2.0 + 0.02 >= UiTheme.CARD_BLEED * k_g else "!! 会重叠"])
	print("  列数 = int(756 / 100) = %d（原 int(756 / 96) = %d）" % [
		int(756.0 / 100.0), int(756.0 / 96.0)])
	quit()
