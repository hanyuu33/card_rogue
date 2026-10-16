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
##   稀有度缎带     ribbon_<0..5>.png 下标同上（R170：稀有度的**主通道**，挂在卡面右上角）
##   面板羊皮纸     panel_parchment.png（R170：白底面板的统一底，平铺自适应任意大小）
##   羊皮卷面板底   scroll_parchment.png（R191：奖励面板的卷轴底，九宫格自适应、无边框）
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


static func rarity_ribbon(rarity: int) -> Texture2D:
	## 稀有度缎带（R170）：挂在卡面**右上角**的锦旗，稀有度的主通道
	## （取代「底部框线涂稀有度色 + 色块小旗」—— 用户口径：不要粗暴的颜色块/颜色条）。
	## 下标同 `CardData.RARITY_COLORS`。透明底、燕尾下垂，源图 192 高。
	## 缺图时返回 null，`CardFace` 回退成程序绘制的小旗 —— 不空白也不报错。
	return get_tex("ribbon_%d" % clampi(rarity, 0, 5))


static func scroll_parchment() -> Texture2D:
	## 羊皮卷面板底（R191）：1524×953 透明底卷轴，四边自然破损、中心均匀干净。
	## 配 `UiTheme.draw_scroll_bg()` 九宫格使用（角块 16%，边条单向拉伸）。
	## 缺图返回 null，调用方回退 `draw_panel_bg` 平铺羊皮纸。
	return get_tex("scroll_parchment")


static func panel_parchment() -> Texture2D:
	## 面板羊皮纸（R170）：1536×1536 **镜像无缝**底纹，白底面板的统一底。
	## 窗口最大 1280×720，单张就盖得住任何面板 → 实际不会平铺出接缝；
	## 更大的 rect 走 `draw_texture_rect(..., tile=true)` 平铺也无缝。
	## 缺图时返回 null，调用方回退 `UiTheme.PANEL_PAPER_BG` 纯色。
	return get_tex("panel_parchment")


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


static func btn_primary() -> Texture2D:
	## 主按钮底（R154）：墨蓝金线胶囊 256×72，透明角。
	## 缺图时返回 null，`UiTheme.apply_button` 回退 StyleBoxFlat 程序样式。
	return get_tex("btn_primary")


static func btn_plain() -> Texture2D:
	## 次按钮底（R154）：羊皮纸奶油胶囊 256×72，透明角。缺图回退同上。
	return get_tex("btn_plain")


static func title_bg() -> Texture2D:
	## 标题页背景（R153 入库 / R154 挂接）：1280×720 晨光小镇。
	## 缺图时返回 null，`title_scene` 回退 battle_bg → 再退纯色渐变。
	return get_tex("title_bg")


static func card_back() -> Texture2D:
	## 卡背（R154）：牌堆 / 抽牌动画用 256×384。缺图回退程序绘制。
	return get_tex("card_back")


static func map_fog() -> Texture2D:
	## 战争迷雾云团（R154）：256×256 透明、四周渐隐。缺图回退程序云团。
	return get_tex("map_fog")


static func class_badge(cls: String) -> Texture2D:
	## 职业徽标（R154）：class_forest / class_rogue / class_mech，128×128 透明圆徽。
	## ⚠️ 传**职业 id**（森林精魄 / 暗影刺客 / 机械之心），英文素材键在这里映射 ——
	## 调用方不该各自猜键名。未知职业返回 null（调用方跳过画图）。
	var key := ""
	match cls:
		"森林精魄":
			key = "forest"
		"暗影刺客":
			key = "rogue"
		"机械之心":
			key = "mech"
	if key == "":
		return null
	return get_tex("class_" + key)


static func class_key(cls: String) -> String:
	## 职业 id → 素材键（forest / rogue / mech）。未知返回 ""。**唯一映射口** ——
	## class_badge / class_cg / class_avatar 都读它，调用方别各自猜键名。
	match cls:
		"森林精魄":
			return "forest"
		"暗影刺客":
			return "rogue"
		"机械之心":
			return "mech"
	return ""


static func class_cg(cls: String) -> Texture2D:
	## 职业 CG（R166）：选人界面的**整屏背景**，16:9（1280×720）。
	## 缺图返回 null，`class_pick_scene` 回退 `SCREEN_BG` 纯色 —— 不空白不报错。
	var k := class_key(cls)
	return get_tex("class_cg_" + k) if k != "" else null


static func class_avatar(cls: String) -> Texture2D:
	## 职业头像（R166）：**只有头部**的小图（透明底），用于选人界面的头像行
	## 与地图「当前格」的角色标记。缺图返回 null，调用方回退 `class_badge` 圆徽。
	var k := class_key(cls)
	return get_tex("class_avatar_" + k) if k != "" else null


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
