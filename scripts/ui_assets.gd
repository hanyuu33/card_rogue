class_name UiAssets
## 可替换 UI 图片的统一入口 —— 全部图片放在 res://assets/ui/ 下，
## 用固定文件名覆盖即可换皮；找不到文件时返回 null，
## 调用方自动回退到程序化绘制（保证永远不因缺图而报错或空白）。
##
## 命名规范（文件名即契约，改动须同步 assets/ui/图片命名说明.txt）：
##   地图节点图标   map_<类型>.png    类型 = start/battle/elite/rest/event/chest/boss
##   事件插图       event_<事件>.png  事件 = rest/treasure/whisper/struggle/gaze/pear/hero/relic_chest
##   事件背景       bg_<事件>.png     事件同上
##   战斗背景       battle_bg_<关卡key>.png（每关专属）/ map_bg_<层号>.png（当层）/
##                    battle_bg.png（全局）—— 三级回退，见 battle_bg_name()
##   卡面纸底       card_paper.png
##   稀有度边框     frame_<0..5>.png  下标同 CardData.RARITY_COLORS
##   数值徽章图标   icon_<键>.png     键 = cost 水晶 / power 剑 / range 弓 /
##                                      health 血 / speed 鞋
##
## 说明：加载策略双保险 —— 优先用 Godot 的导入资源（编辑器导入 / 导出后的 .ctex），
## 失败则直接读原始 PNG（往 assets/ui/ 丢进去还没让编辑器导入也能立刻生效）。

const DIR := "res://assets/ui/"
## ⚠️ 全局兜底的战斗背景**在仓库根 `assets/`**（不在 `assets/ui/`）—— 历史遗留位置，
##    标题页也在用它，所以单独列出来，别让 `get_tex()` 去 ui/ 里找。
const FALLBACK_BATTLE_BG := "res://assets/battle_bg.png"

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


static func card_paper() -> Texture2D:
	## 卡面纸底（R113）。设计基准 58 × 70（与 CARD_W:CARD_H 同比）。
	## 卡面宽高比恒定，只是整体缩放，所以**不需要九宫格**，直接拉伸即可。
	return get_tex("card_paper")


static func card_frame(rarity: int) -> Texture2D:
	## 稀有度边框（R113）。下标与 `CardData.RARITY_COLORS` 对齐：
	##   0 普通 / 1 稀有 / 2 史诗 / 3 初始 / 4 怪物 / 5 事件。
	return get_tex("frame_%d" % clampi(rarity, 0, 5))


static func badge_icon(key: String) -> Texture2D:
	## 卡面数值徽章的图标（R114）。`key` 就是槽位名，所以**键名即素材契约**：
	##   cost   费用   水晶   建议 32 × 32
	##   power  力量   剑
	##   range  攻击距离 弓
	##   health 生命   血
	##   speed  移动距离 鞋
	## 缺图时返回 null，`CardFace` 会回退成该数值的语义色圆盘 —— 不会空白也不会报错。
	return get_tex("icon_" + key)


static func map_bg(layer: int) -> Texture2D:
	## 冒险地图背景（R128）：**每层一张**，1280 × 720 铺满。
	## 缺图时返回 null，`map_scene` 回退成内置的纵向渐变底 —— 不空白也不报错。
	return get_tex("map_bg_%d" % layer)


static func battle_bg_path(key: String, layer: int) -> String:
	## 战斗背景**取哪一张**的唯一口径（R133）—— 三级回退，返回**完整资源路径**：
	##   ① `res://assets/ui/battle_bg_<关卡key>.png` —— 这一关**专属**（每关独立可替换）
	##   ② `res://assets/ui/map_bg_<层号>.png`       —— **当层**的地图底图（与地图页观感统一）
	##   ③ `res://assets/battle_bg.png`              —— 全局兜底
	## ⚠️ 这里返**完整路径**而不是「槽位名」：兜底那张在**仓库根 `assets/`**（不在 `assets/ui/`），
	##    用槽位名再拼一次目录就会拼错（R133 第一版就是这么翻车的，被断言抓出来）。
	## ⚠️ 判存在要 `FileAccess` **或** `ResourceLoader`：导出包里原始 png 不在、只有导入后的
	##    `.ctex`，只看 `FileAccess.file_exists` 会在包里全部落空。
	if key != "" and _path_exists(path_for("battle_bg_" + key)):
		return path_for("battle_bg_" + key)
	var lp := path_for("map_bg_%d" % layer)
	if _path_exists(lp):
		return lp
	return FALLBACK_BATTLE_BG


static func battle_bg(key: String, layer: int) -> Texture2D:
	## 战斗背景（R133）。取名口径见 `battle_bg_path()`。
	## 全缺时返回 null，`battle_scene` 回退成内置纯色 —— 不空白也不报错。
	var p := battle_bg_path(key, layer)
	if not _cache.has(p):
		_cache[p] = _load(p)
	return _cache[p]


static func _path_exists(p: String) -> bool:
	return FileAccess.file_exists(p) or ResourceLoader.exists(p)


static func bridge_icon() -> Texture2D:
	## 地图「通路」的桥（R130；R132 起**只有一张**）：
	##   map_bridge  = 小桥的**俯视图**，桥身在画面上**竖着**
	## 左右连通时由 `map_bridge.gd` 绕桥心**转 90°** —— 所以**换一次图两个方向一起变**，
	## 这正是「以后换更好的图标能无缝替换」想要的效果。
	## ⚠️ R132 起不再有侧视图（`map_bridge_h`）：那张图的栏杆只有左右两段、中间光秃，
	##    怎么看都别扭；俯视图两个方向共用反而干净一致。
	## 缺图时返回 null，`map_bridge.gd` 回退成一小段发光横条 —— 不会空白也不报错。
	return get_tex("map_bridge")


static func chocolate() -> Texture2D:
	## 巧克力（R128）：地图 HUD 的「每层行动力」图标，建议 64 × 64（带透明通道）。
	## 缺图时返回 null，`map_scene` 回退成程序画的圆角方块 —— 不会变成空白洞。
	return get_tex("chocolate")


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
