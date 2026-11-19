class_name DemoScope
extends RefCounted
## R817：试玩版的**内容基线**（`res://demo_scope.json` 的唯一读口）。
##
## 口径（店长 2026-11-19）：「后续**修复**的部分需要更新到试玩，但**新增**的部分不需要。」
## 落成机制就是这张准入表：
##   * 表里的 id = 试玩版认的内容。改数值 / 修 bug / 换文案改的是**老 id 的数据** →
##     试玩版读同一份 cards.json / relics.json，自动跟着走，本文件一个字都不用动；
##   * 新卡 / 新道具 / 新工具 / 新事件 **id 不在表里** → 默认不进试玩版。
##     真要放进去，才把它加进 demo_scope.json（并同步 test_engine 的计数断言）。
##
## ⚠️ 只有 `GameBuild.is_demo()` 为真时才会被调用 —— 发布版 / 测试版一个分支都不经过，
##    所以这条基线再怎么写错也不会影响正式包。
## ⚠️ 失败策略是 **fail-open**（文件缺失 → 不裁，只报错）：试玩版宁可多给内容，
##    也不能因为丢一个 json 就变成空卡池 / 空商店。`is_loaded_ok()` 给测试断言用。

const PATH := "res://demo_scope.json"

static var _cards := {}
static var _relics := {}
static var _traps := {}
static var _events := {}
static var _ready := false
static var _ok := false


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var raw := FileAccess.get_file_as_string(PATH)
	if raw.is_empty():
		push_error("demo_scope.json 缺失 —— 试玩版退回「只认 no_demo」的老口径（新增内容会漏进试玩）")
		return
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("demo_scope.json 解析失败 —— 同上，退回老口径")
		return
	_cards = _to_int_set(parsed.get("cards", []))
	_relics = _to_int_set(parsed.get("relics", []))
	_traps = _to_int_set(parsed.get("traps", []))
	_events = _to_str_set(parsed.get("events", []))
	_ok = not _cards.is_empty()


static func _to_int_set(arr: Variant) -> Dictionary:
	var out := {}
	if arr is Array:
		for v: Variant in arr:
			out[int(v)] = true
	return out


static func _to_str_set(arr: Variant) -> Dictionary:
	var out := {}
	if arr is Array:
		for v: Variant in arr:
			out[str(v)] = true
	return out


static func is_loaded_ok() -> bool:
	## 基线文件是否真的读进来了（测试用；运行期一律走下面的 allows_*）。
	_ensure()
	return _ok


static func baseline_count(kind: String) -> int:
	## 基线里某一类的条目数（测试断言用：`cards` / `relics` / `traps` / `events`）。
	_ensure()
	match kind:
		"cards":
			return _cards.size()
		"relics":
			return _relics.size()
		"traps":
			return _traps.size()
		"events":
			return _events.size()
	return -1


static func baseline_ids(kind: String) -> Array:
	## 基线里某一类的 id 列表（测试用：反过来核对「基线里的东西还存在吗」）。
	_ensure()
	var src: Dictionary = {}
	match kind:
		"cards":
			src = _cards
		"relics":
			src = _relics
		"traps":
			src = _traps
		"events":
			src = _events
	var out: Array = src.keys()
	out.sort()
	return out


static func allows_card(id: int) -> bool:
	_ensure()
	if not _ok:
		return true
	return _cards.has(id)


static func allows_relic(id: int) -> bool:
	_ensure()
	if not _ok:
		return true
	return _relics.has(id)


static func allows_trap(id: int) -> bool:
	_ensure()
	if not _ok:
		return true
	return _traps.has(id)


static func allows_event(kind: String) -> bool:
	_ensure()
	if not _ok:
		return true
	return _events.has(kind)
