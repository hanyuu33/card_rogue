extends SceneTree
## 探针：const 引用 preload 脚本里的 const，能否作为常量表达式折叠？

const UiTheme = preload("res://scripts/ui_theme.gd")
const A := UiTheme.INK_600
const B: Color = UiTheme.STAT_POWER
const C := [UiTheme.INK_600, UiTheme.PAPER]


func _init() -> void:
	print("A=", A, "  B=", B, "  C=", C)
	quit()
