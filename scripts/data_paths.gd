class_name DataPaths
extends RefCounted
## R789：静态数据的热更入口（Steam 上只下变化的小文件）。
##
## 背景：Windows 包把全部资源内嵌进 exe（277MB），任何一点数据改动都会让整个 exe
## 变化，Steam 只能近乎全量重下。而真正经常改的静态数据只有约 1.85MB
## （cards/relics/stories/traps + i18n/*.json）。
##
## 读取优先级（高 → 低）：
##   1. `CARDROGUE_CONTENT_DIR` 环境变量（测试/自检用，绝对路径）
##   2. 导出包可执行文件同目录的 `content/`（Steam depot 下发位置）
##   3. pck 内 `res://` 基线（缺文件、坏文件、结构不对都回落到这里）
##
## 约束：
##   * 只覆盖**静态数据 JSON**，不碰脚本、场景与美术（那些走补丁 pck，另议）。
##   * 外部文件是**整份替换**，不是增量合并；补丁必须写完整的 cards.json。
##   * 安装目录只读不写：补丁一律由 Steam 下发，游戏自己不去改安装目录。
##   * 外部文件解析失败或结构明显不对 → 打 warning 并回落基线，绝不让坏文件把游戏搞崩。

## 环境变量名：测试与本地验证用，发行包不该设置它。
const ENV_ROOT := "CARDROGUE_CONTENT_DIR"

static var _root := ""
static var _root_ready := false


## 覆盖目录；空串 = 没有覆盖，一律走 pck 基线。
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


static func reset_root() -> void:
	## 仅供探针：改过环境变量后重新解析。
	_root = ""
	_root_ready = false


static func _is_packed() -> bool:
	## 与 test_engine / test_smoke 同一口径：export_presets.cfg 不进 pck。
	return not FileAccess.file_exists("res://export_presets.cfg")


## `res://` 路径 → 命中覆盖时返回绝对路径，否则原样返回。
## 非 `res://` 路径（存档、临时文件）一律不参与覆盖。
static func resolve(path: String) -> String:
	if not path.begins_with("res://"):
		return path
	var root := content_root()
	if root == "":
		return path
	var candidate := root.path_join(path.trim_prefix("res://"))
	return candidate if FileAccess.file_exists(candidate) else path


## 读 JSON：先试覆盖，再回落基线。
## `required_key` 用来做结构体检（如 cards / relics / episodes），空串则只检查非空容器。
static func read_json(path: String, required_key: String = "") -> Variant:
	var root := content_root()
	if root != "" and path.begins_with("res://"):
		var candidate := root.path_join(path.trim_prefix("res://"))
		if FileAccess.file_exists(candidate):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
			if _plausible(data, required_key):
				return data
			push_warning("[DataPaths] 外部内容不可用，回落 pck 基线：" + candidate)
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## 素材覆盖：`res://assets/...` → `<root>/assets/...`。
## 目录结构刻意与 res:// 一致，改图的人只需要照原路径丢文件。
## 覆盖层既能**替换**（同名）也能**新增**（基线里没有的图），后者不用重导 pck。
static func asset_path(path: String) -> String:
	if not path.begins_with("res://assets/"):
		return path
	var root := content_root()
	if root == "":
		return path
	var candidate := root.path_join(path.trim_prefix("res://"))
	return candidate if FileAccess.file_exists(candidate) else path


static func has_asset_override(path: String) -> bool:
	if not path.begins_with("res://assets/"):
		return false
	var root := content_root()
	if root == "":
		return false
	return FileAccess.file_exists(root.path_join(path.trim_prefix("res://")))


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
