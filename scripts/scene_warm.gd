class_name SceneWarm
extends Node
## R767：场景与图片的**后台预加载唯一口**。
##
## 为什么要有它：`change_scene_to_file()` 是同步的。安卓上切到选人页要解码 1280×720 的 CG、
## 上传纹素、解析场景，主线程一停就是几百毫秒；而 `SceneFx` 的擦入计时起点记在**卡之前**，
## 等主线程回来时 `IN_MS + SETTLE_MS` 早已走完 → 擦入动画整个被吞，
## 玩家看到的就是「黑屏一阵，画面突然蹦出来」。
##
## 这里只负责一件事：把「切场景那一下的同步读盘」提前到更早的空闲帧，用
## `ResourceLoader.load_threaded_request` 在后台线程完成。`SceneFx` 切场景时先 `take()`，
## 拿到了就 `change_scene_to_packed`，拿不到才回退同步加载。
##
## 三条纪律：
##   * **headless 完全不启用** —— 回归与出图不关心加载速度，别把线程引进测试。
##   * **只预热「下一站」** —— 不是资源池：`take()` 拿走即删，不长期攥着内存。
##   * **同一条路径幂等** —— 已加载 / 正在读 / 已在队列 → 直接返回，重复调用安全。

const MAX_PARALLEL := 2   # 同时两条线程：再多在低端机上只是互相抢 IO

static var _inst: Node = null        # 不拿自身 class_name 当类型注解（解析器自引用）
static var _done: Dictionary = {}    # path -> Resource（已读完、待取）
static var _busy: Dictionary = {}    # path -> true（线程正在读）
static var _queue: Array[String] = []


static func warm(path: String) -> void:
	## 幂等入队。非资源路径、headless、已在本流程里的一律静默跳过。
	if DisplayServer.get_name() == "headless":
		return
	# 出图 / 演示探针也跳过：它们只关心某一帧长什么样，多线程读盘只会污染时序。
	var uargs := OS.get_cmdline_user_args()
	if "--screenshot" in uargs or "--demo" in uargs:
		return
	if path == "" or _done.has(path) or _busy.has(path) or _queue.has(path):
		return
	if not ResourceLoader.exists(path):
		return
	_ensure()
	if _inst == null:
		return
	_queue.append(path)
	_inst.set_process(true)


static func warm_all(paths: Array) -> void:
	## 按顺序入队（第一个最先进线程）。调用方按「最可能马上要的」排前面。
	for p: Variant in paths:
		warm(str(p))


static func take(path: String) -> Resource:
	## 取走成品（取走即删）。没预热到 / 已取过 → null，调用方回退同步加载。
	var r: Variant = _done.get(path, null)
	if r == null:
		return null
	_done.erase(path)
	return r as Resource


static func is_ready(path: String) -> bool:
	return _done.has(path)


static func is_pending(path: String) -> bool:
	## 还在队列里或线程里。`SceneFx` 用它决定「要不要为它多黑一会儿」。
	return _busy.has(path) or _queue.has(path)


static func _ensure() -> void:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	# 与 SceneFx 同款懒实例：`--headless --script` 跑回归时 autoload 不加载，
	# 自建实例挂在 root 上，切场景不会把它一起销毁。
	_inst = load("res://scripts/scene_warm.gd").new()
	_inst.name = "SceneWarm"
	tree.root.add_child(_inst)


func _process(_delta: float) -> void:
	_pump()
	if _busy.is_empty() and _queue.is_empty():
		set_process(false)     # 没活儿就彻底停掉，别每帧白跑


func _pump() -> void:
	var finished: Array[String] = []
	for p: String in _busy.keys():
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_done[p] = ResourceLoader.load_threaded_get(p)
			finished.append(p)
		elif st == ResourceLoader.THREAD_LOAD_FAILED \
				or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("SceneWarm：预热失败 " + p)
			finished.append(p)
	for p: String in finished:
		_busy.erase(p)
	while _busy.size() < MAX_PARALLEL and not _queue.is_empty():
		var q: String = _queue.pop_front()
		if _done.has(q) or _busy.has(q):
			continue
		if ResourceLoader.load_threaded_request(q) == OK:
			_busy[q] = true
