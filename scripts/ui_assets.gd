class_name UiAssets
## 可替换 UI 图片的统一入口 —— 全部图片放在 res://assets/ui/ 下，
## 用固定文件名覆盖即可换皮；找不到文件时返回 null，
## 调用方自动回退到程序化绘制（保证永远不因缺图而报错或空白）。
##
## 命名规范（文件名即契约，改动须同步 assets/ui/图片命名说明.txt）：
##   地图节点图标   map_<类型>.png    类型 = start/battle/elite/rest/event/chest/boss
##   事件插图       event_<事件>.png  事件 = rest/treasure/whisper/struggle/gaze/pear/hero/relic_chest
##   事件背景       bg_<事件>.png     事件同上
##
## 说明：加载策略双保险 —— 优先用 Godot 的导入资源（编辑器导入 / 导出后的 .ctex），
## 失败则直接读原始 PNG（往 assets/ui/ 丢进去还没让编辑器导入也能立刻生效）。

const DIR := "res://assets/ui/"

static var _cache := {}   # 文件名 -> Texture2D / null（缺图也缓存，避免反复查盘）


static func path_for(name: String) -> String:
	## 图片名 → 完整资源路径（不要带 .png 后缀）。
	return DIR + name + ".png"


static func node_icon_path(type: String) -> String:
	return path_for("map_" + type)


static func event_pic_path(kind: String) -> String:
	return path_for("event_" + kind)


static func event_bg_path(kind: String) -> String:
	return path_for("bg_" + kind)


static func get_tex(name: String) -> Texture2D:
	## 按名字取图；没有该文件返回 null（调用方回退程序化绘制）。
	if not _cache.has(name):
		_cache[name] = _load(path_for(name))
	return _cache[name]


static func node_icon(type: String) -> Texture2D:
	return get_tex("map_" + type)


static func event_pic(kind: String) -> Texture2D:
	return get_tex("event_" + kind)


static func event_bg(kind: String) -> Texture2D:
	return get_tex("bg_" + kind)


static func clear_cache() -> void:
	## 运行中换了图想立刻生效时可以调（正常流程不需要）。
	_cache.clear()


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	# 回退：文件刚丢进目录、编辑器还没导入时，直接解 PNG。
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null
