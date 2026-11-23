class_name DataPaths
extends RefCounted
## R789 / R816：静态数据与素材的**外部内容层**。
##
## 三层（低 → 高）：
##   0. pck 内 `res://` 基线
##   1. 官方热更 `content/`（**整份替换**）
##      —— Steam depot 下发位置，R789 的语义，一行没改
##   2. mod 目录（**增量合并**；素材为覆盖）
##      —— 顺序由 `ModRegistry.load_order()` 决定（priority 升序）
##
## 为什么数据层是「整份替换 → 增量合并」，素材层却是「先命中者胜」：
##   数据要能被多个 mod 叠加（A 加卡、B 改卡，谁都不该被迫交出整份 cards.json）；
##   素材是一个路径只能有一个结果（同一张卡图只能有像素）。
##   两个层面共同的结论都是 **mod 赢** —— 数据层最后叠，素材层最先查。
##
## 约束：
##   * 只覆盖**静态数据 JSON 与素材**，不碰脚本、场景（脚本 mod 不走这条路）。
##   * 增量合并**按 id 深合并**：mod 只写 `{"id":8001,"name":"新名"}` 就只改名字，
##     其余字段仍是基线的值；不给 id 的数组（如 `traits`）整份替换。
##   * 坏文件只跳过自己那一层，绝不把别的层或基线一起拖下水。

## 环境变量名：测试与本地验证用，发行包不该设置它。
const ENV_ROOT := "CARDROGUE_CONTENT_DIR"

static var _root := ""
static var _root_ready := false
static var _mod_dirs := PackedStringArray()
static var _mod_dirs_ready := false


## 官方热更目录；空串 = 没有覆盖，一律走 pck 基线。
static func content_root() -> String:
	if _root_ready:
		return _root
	_root_ready = true
	var env := OS.get_environment(ENV_ROOT).strip_edges()
	if env != "":
		_root = env.replace("\\", "/").trim_suffix("/")
		return _root
	if not _is_packed():
		# 编辑器 / 回归环境：默认不启用覆盖，避免仓库里的临时文件干扰测试。
		_root = ""
		return _root
	var base := OS.get_executable_path().get_base_dir().replace("\\", "/")
	_root = base.path_join("content") if base != "" else ""
	return _root


## mod 目录（低 → 高），直接来自清单层的加载顺序。
static func mod_dirs() -> PackedStringArray:
	if _mod_dirs_ready:
		return _mod_dirs
	_mod_dirs_ready = true
	_mod_dirs = PackedStringArray()
	for m: Dictionary in ModRegistry.load_order():
		_mod_dirs.append(str(m["dir"]))
	return _mod_dirs


static func reset_root() -> void:
	## 仅供探针与「设置里改完 mod 后重扫」：改过环境变量或 mod 目录后重新解析。
	_root = ""
	_root_ready = false
	_mod_dirs = PackedStringArray()
	_mod_dirs_ready = false
	ModRegistry.reset()


static func _is_packed() -> bool:
	## 与 test_engine / test_smoke 同一口径：export_presets.cfg 不进 pck。
	return not FileAccess.file_exists("res://export_presets.cfg")


## 素材查找链（**先命中者胜**）：mod（高 → 低）→ 官方热更 content。
## 顺序反过来是因为 mod 在数据层是「最后叠」，到素材层就等价于「最先查」。
static func asset_roots() -> PackedStringArray:
	var out := PackedStringArray()
	var dirs := mod_dirs()
	for i: int in range(dirs.size() - 1, -1, -1):
		out.append(dirs[i])
	var c := content_root()
	if c != "":
		out.append(c)
	return out


## `res://` 路径 → 命中覆盖时返回绝对路径，否则原样返回。
## 非 `res://` 路径（存档、临时文件）一律不参与覆盖。
static func resolve(path: String) -> String:
	if not path.begins_with("res://"):
		return path
	for r: String in asset_roots():
		var candidate := r.path_join(path.trim_prefix("res://"))
		if FileAccess.file_exists(candidate):
			return candidate
	return path


## 读 JSON：pck 基线 → 官方热更整份替换 → 各 mod 目录按序增量合并。
## `required_key` 用来做结构体检（如 cards / relics / episodes），空串则只检查非空容器。
## `id_key` 是数组元素的合并主键；`cards` / `relics` / `episodes` 都是 `id`。
static func read_json(path: String, required_key: String = "", id_key: String = "id") -> Variant:
	var base: Variant = null

	## 第 1 层：官方热更，整份替换（R789 语义）
	var root := content_root()
	if root != "" and path.begins_with("res://"):
		var candidate := root.path_join(path.trim_prefix("res://"))
		if FileAccess.file_exists(candidate):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
			if _plausible(data, required_key):
				base = data
			else:
				push_warning("[DataPaths] 外部内容不可用，回落 pck 基线：" + candidate)

	## 第 0 层：pck 基线
	if base == null:
		if not FileAccess.file_exists(path):
			return null
		base = JSON.parse_string(FileAccess.get_file_as_string(path))

	if not path.begins_with("res://"):
		return base

	## 第 2 层：mod，按加载顺序叠。坏文件只跳过自己这一份。
	for dir: String in mod_dirs():
		var mp := dir.path_join(path.trim_prefix("res://"))
		if not FileAccess.file_exists(mp):
			continue
		var patch: Variant = JSON.parse_string(FileAccess.get_file_as_string(mp))
		if not (patch is Dictionary or patch is Array):
			push_warning("[DataPaths] mod 文件不可解析，已跳过：" + mp)
			continue
		if not _plausible(patch, required_key):
			push_warning("[DataPaths] mod 文件结构不对，已跳过：" + mp)
			continue
		base = _merge(base, patch, id_key)
	return base


## 把 `patch` 增量叠到 `base` 上。
##   字典 + 字典 → 逐键递归
##   数组 + 数组 → 元素都带 id_key 时按 id 合并，否则整份替换
##   其他（标量 / 类型不同）→ patch 赢
static func _merge(base: Variant, patch: Variant, id_key: String) -> Variant:
	if patch == null:
		return base
	if base == null:
		return patch
	if base is Dictionary and patch is Dictionary:
		var out: Dictionary = base
		for k: Variant in (patch as Dictionary).keys():
			out[k] = _merge(out.get(k), (patch as Dictionary)[k], id_key)
		return out
	if base is Array and patch is Array:
		return _merge_array(base, patch, id_key)
	return patch


static func _merge_array(base: Array, patch: Array, id_key: String) -> Array:
	## 只要有一边不是「带 id 的字典数组」，就没有可靠的合并主键 → 整份替换。
	## 这条恰好覆盖 `traits` 这类字符串数组：mod 写了就以 mod 为准。
	var patch_by_id := {}
	for it: Variant in patch:
		if not (it is Dictionary) or not (it as Dictionary).has(id_key):
			return patch
		patch_by_id[int((it as Dictionary)[id_key])] = it
	for it0: Variant in base:
		if not (it0 is Dictionary) or not (it0 as Dictionary).has(id_key):
			return patch

	var out: Array = []
	var hit := {}
	for bi: Variant in base:
		var cid := int((bi as Dictionary)[id_key])
		if patch_by_id.has(cid):
			## 深合并：mod 只写要改的字段，其余仍用基线的值
			out.append(_merge(bi, patch_by_id[cid], id_key))
			hit[cid] = true
		else:
			out.append(bi)
	## 追加 mod 新增的 id，保持 mod 文件里的书写顺序
	for pi: Variant in patch:
		var pid := int((pi as Dictionary)[id_key])
		if not hit.has(pid):
			out.append(pi)
			hit[pid] = true
	return out


## 素材覆盖：`res://assets/...` → `<root>/assets/...`。
## 目录结构刻意与 res:// 一致，改图的人只需要照原路径丢文件。
## 覆盖层既能**替换**（同名）也能**新增**（基线里没有的图），后者不用重导 pck。
static func asset_path(path: String) -> String:
	if not path.begins_with("res://assets/"):
		return path
	for r: String in asset_roots():
		var candidate := r.path_join(path.trim_prefix("res://"))
		if FileAccess.file_exists(candidate):
			return candidate
	return path


static func has_asset_override(path: String) -> bool:
	if not path.begins_with("res://assets/"):
		return false
	return asset_path(path) != path


## 判存统一口径：覆盖层 → 源文件 → 已导入资源（导出包里只有 .ctex 时靠后者）。
static func asset_exists(path: String) -> bool:
	if has_asset_override(path):
		return true
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


## 取贴图：覆盖优先（外部 PNG 直解，可新增可替换），否则回落 pck 的导入资源。
## 覆盖图带 mipmap，否则卡面缩到小尺寸会有锯齿/闪烁。
static func load_texture(path: String) -> Texture2D:
	if has_asset_override(path):
		var abs := asset_path(path)
		var img := Image.new()
		if img.load(abs) == OK and not img.is_empty():
			if not img.has_mipmaps():
				img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
		push_warning("[DataPaths] 覆盖贴图读取失败，回落基线：" + abs)
	if ResourceLoader.exists(path):
		var res: Variant = load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img2 := Image.new()
		if img2.load(path) == OK and not img2.is_empty():
			return ImageTexture.create_from_image(img2)
	return null


## 取音频：覆盖层里的 .ogg/.wav 直接读缓冲，其余回落 pck。
static func load_audio(path: String) -> AudioStream:
	if has_asset_override(path):
		var abs := asset_path(path)
		if abs.get_extension().to_lower() == "ogg":
			## 项目音频全是 ogg；4.3 只有 load_from_buffer（WAV 直读要 4.4+，不做）。
			var bytes := FileAccess.get_file_as_bytes(abs)
			if bytes.size() > 0:
				var s := AudioStreamOggVorbis.load_from_buffer(bytes)
				if s != null:
					return s
		push_warning("[DataPaths] 覆盖音频读取失败，回落基线：" + abs)
	if ResourceLoader.exists(path):
		var res: Variant = load(path)
		if res is AudioStream:
			return res
	return null


static func _plausible(data: Variant, required_key: String) -> bool:
	if data == null:
		return false
	if required_key != "":
		if not (data is Dictionary):
			return false
		var v: Variant = (data as Dictionary).get(required_key)
		if v == null:
			return false
		if v is Array and (v as Array).is_empty():
			return false
		if v is Dictionary and (v as Dictionary).is_empty():
			return false
		return true
	if data is Dictionary:
		return not (data as Dictionary).is_empty()
	if data is Array:
		return not (data as Array).is_empty()
	return false
