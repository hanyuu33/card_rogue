class_name ModRegistry
extends RefCounted
## R816 / R818：本地 mod 清单层（创意工坊的地基第二块）。
##
## 只做四件事：**找目录、读清单、排顺序、记启停**。不读 cards.json，也不画界面 ——
## 数据怎么合并在 DataPaths，列表怎么画在 mod_list.gd。
##
## 目录约定：`<mods_root>/<任意目录名>/mod.json`
##   {"id","name","version","author","priority","requires"}
##   * `priority` 越大越**后**加载（越优先），缺省 0；同 priority 按 id 字典序
##   * 同 id 只认扫描到的第一份，其余丢弃并记一条 problem
##   * `requires` 里出现本目录没有的 id → 整个 mod 跳过并记 problem
##   * 没有 mod.json 的普通文件夹一律忽略（不算 mod，因为无法确定身份）
##
## R818 启停：停用列表存 `user://mods.cfg`，**记停用的而不是记启用的** ——
##   新装一个 mod 默认就是开的，符合直觉；玩家没关过就一条记录都不写。
##   停用的 mod 只是不进 `load_order()`（数据层等于不存在），仍留在 `all_mods()` 里
##   给设置页列出来，随时能再打开。
##
## 隔离纪律（与 `DataPaths.content_root()` 同一口径）：
##   * 编辑器 / 回归环境默认**不扫** `user://mods` —— 本机的 mod 绝不能污染测试
##   * 要测就设 `CARDROGUE_MODS_DIR` 指向临时目录（绝对路径或 `user://…` 都行）
##   * 导出包才读 `user://mods`；创意工坊订阅目录将来作为第二个 root 接进来

## 环境变量名：测试与本地验证用，发行包不该设置它。
const ENV_MODS := "CARDROGUE_MODS_DIR"
## 启停配置的路径出口：探针必须能把它指到临时文件，否则一跑就写脏玩家的 mods.cfg。
const ENV_CFG := "CARDROGUE_MODS_CFG"
const MANIFEST := "mod.json"
const USER_DIR := "user://mods"
const CFG_PATH := "user://mods.cfg"
const CFG_SECTION := "mods"
const CFG_KEY := "disabled"

static var _all: Array = []           # 扫到的全部（含停用），已排序 —— 设置页用
static var _list: Array = []          # 其中**启用的**，已排序 —— 只有它进 DataPaths
static var _off: Array = []           # 停用 id（与 mods.cfg 同步）
static var _problems: Array = []      # 坏清单 / 缺依赖 / 重复 id，给管理页用
static var _ready := false


## 加载顺序（低 → 高），**只含启用的**。元素：{id,name,version,author,priority,requires,dir}
## 这是 DataPaths 唯一的取数口 —— 停用的 mod 在数据层等于不存在。
static func load_order() -> Array:
	if not _ready:
		_scan()
	return _list


## 扫到的全部（含停用），已排序。设置页列这个，**不要**用 load_order。
static func all_mods() -> Array:
	if not _ready:
		_scan()
	return _all


## 本轮扫描遇到的问题（纯文本，给管理页和日志用）。
static func problems() -> Array:
	if not _ready:
		_scan()
	return _problems


static func is_enabled(id: String) -> bool:
	if not _ready:
		_scan()
	return not _off.has(id)


## 打开 / 关掉一个 mod。只改清单层与 cfg，**不碰 DataPaths** ——
## 什么时候让数据层重算（reset_root）由调用方决定：设置页是「不在对局里就立刻生效」。
static func set_enabled(id: String, on: bool) -> void:
	if not _ready:
		_scan()
	var had := _off.has(id)
	if on and had:
		_off.erase(id)
	elif not on and not had:
		_off.append(id)
	else:
		return
	_save_off()
	_ready = false   # 下次 load_order / all_mods 重扫（重扫会重读全部 mod.json）


static func reset() -> void:
	## 仅供探针与「改完 mod 后重扫」。
	_all.clear()
	_list.clear()
	_off.clear()
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
	_all.clear()
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
				_all.append(m)
		name = d.get_next()
	d.list_dir_end()

	## 依赖体检：缺依赖的整条剔除。只认同一根目录里已扫到的 id，
	## 不做传递解析 —— mod 之间环状依赖没有意义，也不值得为它写拓扑排序。
	var have := {}
	for m2: Dictionary in _all:
		have[m2["id"]] = true
	var kept: Array = []
	for m3: Dictionary in _all:
		var miss := PackedStringArray()
		for req: Variant in (m3["requires"] as Array):
			if not have.has(str(req)):
				miss.append(str(req))
		if miss.is_empty():
			kept.append(m3)
		else:
			_problems.append("缺依赖 %s，已跳过：%s" % [", ".join(miss), m3["id"]])
	_all = kept

	_all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) < int(b["priority"])
		return str(a["id"]) < str(b["id"]))

	_off = _load_off()
	for m4: Dictionary in _all:
		if not _off.has(m4["id"]):
			_list.append(m4)


static func _cfg_path() -> String:
	var env := OS.get_environment(ENV_CFG).strip_edges()
	if env != "":
		return env.replace("\\", "/")
	return CFG_PATH


static func _load_off() -> Array:
	var out: Array = []
	var cf := ConfigFile.new()
	if cf.load(_cfg_path()) != OK:
		return out
	var v: Variant = cf.get_value(CFG_SECTION, CFG_KEY, [])
	if v is Array:
		for it: Variant in v:
			var s := str(it).strip_edges()
			if s != "":
				out.append(s)
	return out


static func _save_off() -> void:
	var cf := ConfigFile.new()
	cf.load(_cfg_path())   # 保留别的段（将来要往这个 cfg 里加东西，别整份冲掉）
	cf.set_value(CFG_SECTION, CFG_KEY, _off)
	cf.save(_cfg_path())


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
