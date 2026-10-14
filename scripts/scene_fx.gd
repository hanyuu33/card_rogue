class_name SceneFx
extends CanvasLayer
## 场景转场唯一口（R151 批 1 · P0-5，动效设计 §三-5）——
## 全工程的场景切换一律 `SceneFx.goto(path)`，不再直接 `change_scene_to_file`。
##
## 主方案 = **硬边斜切 wipe**（INK_900 色块沿 45° 斜线扫过，日漫过场感），
## 淡出淡入是同一条擦除的进/退两段；自绘 + `_process`，不用 Tween（工程纪律：0 个 create_tween）。
##
## 两条安全闸：
##   * headless / 出图探针（--screenshot / --demo）→ **立即切换**（不播动画），
##     否则烟测时序与 --shotframe 钉帧全被打乱；
##   * `instant = true` → 立即切换（给「本不该被看见」的中转场景用，如 map → relic_pick 重定向）。
##
## 实现要点：class_name + 懒实例（不是 autoload —— `--headless --script` 跑烟测时
## autoload 不加载，懒实例靠 `Engine.get_main_loop().root` 自建，两条路都活）。
## layer = 100：压所有场景内覆盖层（奖励悬浮窗 18 之上）；鼠标 IGNORE：不锁输入（纪律⑤）。

const OUT_MS := 220        # 擦出（盖住旧场景）
const IN_MS := 220         # 擦入（揭开新场景）
const SETTLE_MS := 80      # 切完多压一拍纯黑，等新场景首帧 ready
const STUCK_MS := 1500     # R167 防卡死：转场卡住超过它就强制接上，不再吞掉后续 goto
const WIPE_COL := Color("1a1c22")   # INK_900（不 preload ui_theme：越早越轻，少依赖）

static var _inst: SceneFx = null

var _phase := 0            # 0 闲 / 1 擦出 / 2 擦入
var _t0 := 0
var _target := ""
var _cv: Control = null


static func goto(path: String, instant := false) -> void:
	## 唯一入口。重复调用（转场途中）直接忽略 —— 双击 / 连点防护。
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return   # 没有场景树（纯逻辑测试）：放弃切换，别崩
	if instant or _skip_fx():
		tree.change_scene_to_file.call_deferred(path)
		return
	# R167：实例被释放 / 被移出树（转场途中出意外）→ 直接重建，别拿着死引用继续吞 goto。
	if _inst == null or not is_instance_valid(_inst) or not _inst.is_inside_tree():
		_inst = load("res://scripts/scene_fx.gd").new()
		tree.root.add_child(_inst)
	if _inst._phase != 0:
		# 上一次转场还卡在半路：短暂等待是正常的（连点防护），但**卡太久就必须接手** ——
		# 否则 `goto` 会被永远吞掉，表现就是「点哪都没反应」的假死。
		if Time.get_ticks_msec() - _inst._t0 < STUCK_MS:
			return
		_inst._phase = 0
		_inst._cv.queue_redraw()
	_inst._begin(path)


static func _skip_fx() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var args := OS.get_cmdline_user_args()
	return "--screenshot" in args or "--demo" in args


func _ready() -> void:
	layer = 100
	_cv = Control.new()
	_cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cv.draw.connect(_on_cv_draw)
	add_child(_cv)


func _begin(path: String) -> void:
	_target = path
	_phase = 1
	_t0 = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if _phase == 0:
		return
	var n := Time.get_ticks_msec()
	if _phase == 1 and n - _t0 >= OUT_MS:
		var p := _target
		_target = ""
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.change_scene_to_file.call_deferred(p)
		_phase = 2
		_t0 = n
	elif _phase == 2 and n - _t0 >= IN_MS + SETTLE_MS:
		_phase = 0
	_cv.queue_redraw()


func _on_cv_draw() -> void:
	if _phase == 0:
		return
	var n := Time.get_ticks_msec()
	var p: float
	if _phase == 1:
		p = clampf(float(n - _t0) / OUT_MS, 0.0, 1.0)
		p = p * p * (3.0 - 2.0 * p)              # smoothstep：起步缓、合拢快
	else:
		var q := clampf(float(n - _t0 - SETTLE_MS) / IN_MS, 0.0, 1.0)
		q = q * q * (3.0 - 2.0 * q)
		p = 1.0 - q
	_draw_wipe(p)


func _draw_wipe(p: float) -> void:
	## 斜切擦除：{x + y <= E} 的一侧已被 INK_900 盖住；E 随 p 从 -1 扫到 W+H+1。
	var vp := _cv.size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(1280, 720)
	var w := vp.x
	var h := vp.y
	var e := lerpf(-1.0, w + h + 1.0, p)
	var pts := PackedVector2Array()
	if e <= 0.0:
		return
	if e >= w + h:
		pts = PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	elif e <= h:
		pts = PackedVector2Array([Vector2.ZERO, Vector2(e, 0), Vector2(0, e)])
	elif e <= w:
		pts = PackedVector2Array([Vector2.ZERO, Vector2(e, 0), Vector2(e - h, h), Vector2(0, h)])
	else:
		pts = PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, e - h),
				Vector2(e - h, h), Vector2(0, h)])
	_cv.draw_colored_polygon(pts, WIPE_COL)
