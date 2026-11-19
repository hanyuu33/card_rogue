class_name ModRegistry
extends RefCounted
## R816：本地 mod 清单层（创意工坊的地基第二块）。
##
## 只做三件事：**找目录、读清单、排顺序**。它不读 cards.json，也不碰 UI ——
## 数据怎么合并在 DataPaths，界面留给后续轮次。
##
## 目录约定：`<mods_root>/<任意目录名>/mod.json`
##   {"id","name","version","author","priority","requires"}
##   * `priority` 越大越**后**加载（越优先），缺省 0；同 priority 按 id 字典序
##   * 同 id 只认扫描到的第一份，其余丢弃并记一条 problem
##   * `requires` 里出现本目录没有的 id → 整个 mod 跳过并记 problem
##   * 没有 mod.json 的普通文件夹一律忽略（不算 mod，因为无法确定身份）
##
## 隔离纪律（与 `DataPaths.content_root()` 同一口径）：
##   * 编辑器 / 回归环境默认**不扫** `user://mods` —— 本机的 mod 绝不能污染测试
##   * 要测就设 `CARDROGUE_MODS_DIR` 指向临时目录（绝对路径或 `user://…` 都行）
##   * 导出包才读 `user://mods`；创意工坊订阅目录将来作为第二个 root 接进来

## 环境变量名：测试与本地验证用，发行包不该设置它。
const ENV_MODS := "CARDROGUE_MODS_DIR"
const MANIFEST := "mod.json"
const USER_DIR := "user://mods"

static var _list: Array = []          # 加载顺序（低 → 高），元素见 _read_manifest
static var _problems: Array = []      # 坏清单 / 缺依赖 / 重复 id，给将来的管理页用
static var _ready := false


## 加载顺序（低 → 高）。元素：{id,name,version,author,priority,requires,dir}
static func load_order() -> Array:
	if not _ready:
		_scan()
	return _list


## 本轮扫描遇到的问题（纯文本，给管理页和日志用）。
static func problems() -> Array:
	if not _ready:
		_scan()
	return _problems


static func reset() -> void:
	## 仅供探针与「玩家在设置里改完 mod 后重扫」。
	_list.clear()
	_problems.clear()
	_ready = false


## 空串 = 没有 mod 根目录，一律不扫。
static func root() -> String:
	var env := OS.get_environment(ENV_MODS).strip_edges()
	if env != "":
		return env.replace("\\", "/").trim_suffix("/")
	if not _is_packed():
		## 编辑器 / 回归：默认关掉，避免仓库或本机目录里的东西干扰测试。
		return ""
	return USER_DIR


static func _is_packed() -> bool:
	## 与 DataPaths._is_packed() 同一口径：export_presets.cfg 不进 pck。
	return not FileAccess.file_exists("res://export_presets.cfg")


static func _scan() -> void:
	_ready = true
	_list.clear()
	_problems.clear()
	var r := root()
	if r == "":
		return
	var d := DirAccess.open(r)
	if d == null:
		return
	var seen := {}
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if d.current_is_dir() and not name.begins_with("."):
			var dir := r.path_join(name)
			var m := _read_manifest(dir)
			if m.is_empty():
				_problems.append("清单缺失或格式不对，已跳过：%s" % dir)
			elif seen.has(m["id"]):
				_problems.append("mod id 重复，已跳过后者：%s（%s）" % [m["id"], dir])
			else:
				seen[m["id"]] = true
				m["dir"] = dir
				_list.append(m)
		name = d.get_next()
	d.list_dir_end()

	## 依赖体检：缺依赖的整条剔除。只认同一根目录里已扫到的 id，
	## 不做传递解析 —— mod 之间环状依赖没有意义，也不值得为它写拓扑排序。
	var have := {}
	for m2: Dictionary in _list:
		have[m2["id"]] = true
	var kept: Array = []
	for m3: Dictionary in _list:
		var miss := PackedStringArray()
		for req: Variant in (m3["requires"] as Array):
			if not have.has(str(req)):
				miss.append(str(req))
		if miss.is_empty():
			kept.append(m3)
		else:
			_problems.append("缺依赖 %s，已跳过：%s" % [", ".join(miss), m3["id"]])
	_list = kept

	_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) < int(b["priority"])
		return str(a["id"]) < str(b["id"]))


## 读一份 mod.json；任何必填项缺失都返回空字典（调用方记 problem）。
static func _read_manifest(dir: String) -> Dictionary:
	var p := dir.path_join(MANIFEST)
	if not FileAccess.file_exists(p):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var id := str(d.get("id", "")).strip_edges()
	if id == "":
		return {}
	var req: Array = []
	var rv: Variant = d.get("requires", [])
	if rv is Array:
		req = rv
	return {
		"id": id,
		"name": str(d.get("name", id)),
		"version": str(d.get("version", "")),
		"author": str(d.get("author", "")),
		## 走 str→to_int：JSON 里写 100.0 或 "100" 都能吃下，写垃圾则退成 0。
		"priority": str(d.get("priority", "0")).to_int(),
		"requires": req,
	}
