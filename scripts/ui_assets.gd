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
##   卡图区边框     art_frame_<归属>.png  归属 = forest / shadow / mech / common / enemy
##                  （R498：卡图窗上的窄边框，按卡牌归属分色）
##   稀有度缎带     ribbon_<0..5>.png 下标同上（R170：稀有度的**主通道**，挂在卡面右上角）
##   面板羊皮纸     panel_parchment.png（R170：白底面板的统一底，平铺自适应任意大小）
##   羊皮卷面板底   scroll_parchment.png（R191：奖励面板的卷轴底，九宫格自适应、无边框）
##   敌方效果弹窗底 void_portal.png（R197：战斗开场敌方效果弹窗，中心纯黑、白字）
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


static func small_icon(name: String, edge := 128) -> Texture2D:
	# Cache a filtered thumbnail; avoid sparse sampling of large source art.
	var key := "%s@%d" % [name, edge]
	if not _cache.has(key):
		var source := get_tex(name)
		if source == null:
			return null
		var img := source.get_image()
		# R613：驱动读回失败时退回原纹理，不能继续对空图取宽高。
		if img == null or img.is_empty():
			return source
		# R596g：卡图改成 VRAM 压缩（astc/bptc）后 get_image() 拿到的是压缩图，
		# 直接 resize 会报 "Cannot resize in compressed or custom image formats"。
		# 与 test_smoke 的 _ribbon_opaque_ratio 同口径：先解压再处理。
		if img.is_compressed():
			img.decompress()
		var scale := minf(1.0, float(edge) / maxf(img.get_width(), img.get_height()))
		img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		img.fix_alpha_edges()
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func filtered(tex: Texture2D, edge: int) -> Texture2D:
	if tex == null:
		return null
	# Bucket sizes limit cache growth during animated scaling; retain source for large cards.
	var target := maxi(16, ceili(edge / 16.0) * 16)
	if maxi(tex.get_width(), tex.get_height()) <= target:
		return tex
	var key := "filtered:%d:%d" % [tex.get_instance_id(), target]
	if not _cache.has(key):
		var img := tex.get_image()
		# R613：驱动读回失败时退回原纹理，不能继续对空图取宽高。
		if img == null or img.is_empty():
			return tex
		if img.is_compressed():
			img.decompress()
		var ratio := float(target) / maxf(img.get_width(), img.get_height())
		img.resize(maxi(1, roundi(img.get_width() * ratio)), maxi(1, roundi(img.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		img.fix_alpha_edges()
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

static func shop_icon(name: String) -> Texture2D:
	var replacements := {
		"shop_icon_remove": "reward_icons/deck_delete",
		"shop_icon_card": "reward_icons/cards", "shop_icon_draw": "reward_icons/cards",
		"shop_icon_costdown": "icon_cost", "shop_icon_damage": "map_icons/battle",
		"shop_icon_dimension": "reward_icons/core", "shop_icon_save": "map_icons/chest",
		"shop_icon_opening": "map_icons/start", "shop_icon_maxhp": "adventure_shared/service_vitality",
		"shop_icon_dagger": "key_icon_dagger"}
	# R508：64 → 96。商店里图标实际画到 84~120px（`shop_scene._goods_icon_box` 随行高自适应），
	# 64px 纹理是被**放大**在用，边缘发虚；96 起才是缩小采样。
	return small_icon(str(replacements.get(name, name)), 96)

static func node_icon(type: String) -> Texture2D:
	var name := "map_icons/" + type
	if ResourceLoader.exists(path_for(name)):
		return small_icon(name)
	return get_tex("map_" + type)


static func event_pic(kind: String) -> Texture2D:
	return get_tex("event_" + kind)


static func event_side_pic(kind: String) -> Texture2D:
	## R516：左右布局专用的**竖版**图 —— 占满事件页左侧全高（1280×720 下约 742×720）。
	## 与 `event_pic`（320×240 居中插图）分开命名：尺寸与用途都不同，
	## 混用会让「插图标准尺寸 320×240」的规范失效。
	return get_tex("side_" + kind)


static func event_bg(kind: String) -> Texture2D:
	## R519h：rest 改走左右布局（`side_rest.png`），不再有整屏背景，
	## 原来的 `adventure_shared/rest_clearing` 特判与素材一并删除。
	## 左右布局的 kind 由 `event_scene._apply_side_layout()` 走 `_add_fallback_bg()`，不经这里。
	return get_tex("bg_" + kind)


static func div_vision(n: int) -> Texture2D:
	## 占卜室球内幻象（R511）：1 鲸鱼 / 2 液体 / 3 荆棘 / 4 宴席。
	## 256×256、**圆外全透明、边缘羽化** —— 调用方按球的可见直径直接贴，不需要再裁。
	## 与 `bg_divination.png` 里的球同径，缺图返回 null（球里保持原图的星云，不空白不报错）。
	if n < 1 or n > 4:
		return null
	return get_tex("div_vision_%d" % n)


static func core_relic_icon() -> Texture2D:
	## 道具「核心」（6059）的标志：`reward_icons/core.png`。
	## R512「契约的核心」事件把底图石台中央**故意留成空凹槽**（标志画死在背景里，
	## 取走核心后它还会留在石台上，和文案「只剩一圈浅浅的凹痕」打架），
	## 由事件场景把这张图叠进凹槽。**要换标志只换这张**，别在背景里另画一个。
	## 缺图返回 null（事件照常可玩，只是石台上没有核心）。
	return get_tex("reward_icons/core")


static func key_relic_icon(id: int, gray: bool = false) -> Texture2D:
	## R543：三样信物（解锁第三层所需的信物）的小图标。缺图返回 null（调用方兜底）。
	##   * 6061 完美螺钉 → key_icon_screw.png
	##   * 6062 生命之种 → key_icon_seed.png
	##   * 6063 屠戮匕首 → key_icon_dagger.png（参照暗影刺客角色 CG 里的匕首）
	## `gray=true`（R543b）：返回**去饱和灰阶版** `key_icon_*_gray.png`，用于
	##   地图上「未持有」的信物图标整格黑白化（含图标本体，不只外框）。
	var suffix := "_gray" if gray else ""
	match id:
		6061:
			return get_tex("key_icon_screw" + suffix)
		6062:
			return get_tex("key_icon_seed" + suffix)
		6063:
			return get_tex("key_icon_dagger" + suffix)
	return null


static func relic_icon_path(id: int) -> String:
	## R577b：道具图标文件名（128x128 无背景 PNG）。文件名即契约 —— 换图只覆盖
	## assets/ui/relic_icon_<id>.png，别在别处另写一份路径。
	return path_for("relic_icon_%d" % id)


static func relic_icon(id: int) -> Texture2D:
	## R577b：道具小图标**唯一取图口**。缺图返回 null → 调用方必须回退到原来的文字
	## 绘制（项目既有纪律：没导入 / 导出包读不到 png 时游戏照常可玩）。
	## 三样信物（6061~6063）不入 relics.json，沿用 R543 的 key_icon_*.png。
	if id == 6061 or id == 6062 or id == 6063:
		return key_relic_icon(id)
	return get_tex("relic_icon_%d" % id)


static func trap_icon_path(id: int) -> String:
	## R663：陷阱图标文件名契约 `assets/ui/trap_icon_<id>.png`。
	## 缺图时 `trap_icon()` 返回 null → `TrapArt.draw()` 走程序化图案兜底。
	return path_for("trap_icon_%d" % id)


static func trap_icon(id: int) -> Texture2D:
	## R663：陷阱图标**唯一取图口**。刻意不复用 relic_icon/relic_rim。
	return get_tex("trap_icon_%d" % id)


static func trap_slot_frame() -> Texture2D:
	## R663：陷阱槽框（战斗 / 地图 / 战场标记共用），缺图返回 null → 程序化底照常画。
	return get_tex("trap_slot")


static func trap_bar_bg() -> Texture2D:
	## R667：战斗与地图**共用同一张**竖栏底板（店长口径：没必要专门做区别）。
	## 原 trap_bar_map.png 已停用、移出 assets/ui；缺图返回 null。
	return get_tex("trap_bar_battle")


static func trap_group_tag() -> Texture2D:
	## R663：商店中行左右分组的题签底；缺图返回 null → 程序化文字照常画。
	return get_tex("trap_group_tag")


static func trap_fx_path(id: int) -> String:
	## R669：陷阱触发特效贴图文件名契约 `assets/fx/trap_fx_<id>.png`（黑底发光图转透明）。
	## 与 UI 贴图分目录：它是战斗特效，不是界面元件；缺图返回 null → TrapArt 画程序化光环。
	return "res://assets/fx/trap_fx_%d.png" % id


static func trap_fx(id: int) -> Texture2D:
	## R669：陷阱触发特效**唯一取图口**；`_load()` 兼容已导入与刚落盘未导入的 PNG。
	var key := "trap_fx_%d" % id
	if not _cache.has(key):
		_cache[key] = _load(trap_fx_path(id))
	return _cache[key]


static func relic_rim_path(id: int) -> String:
	## R577f：沿图标 alpha 轮廓预生成的「蓝色边缘光」叠加图（128x128 RGBA）。
	## 文件名即契约；换 rim 只覆盖 assets/ui/relic_rim_<id>.png。
	return path_for("relic_rim_%d" % id)


static func relic_rim(id: int) -> Texture2D:
	## R577f：蓝色边缘光**唯一取图口**。缺图返回 null → 界面只画转动弧，照常可玩。
	## 6061~6063 三样信物走 R543 的 key_icon_*，且不参与高亮判定，故无 rim。
	if id == 6061 or id == 6062 or id == 6063:
		return null
	return get_tex("relic_rim_%d" % id)


static func affix_badge_path(glyph: String) -> String:
	## R592：字段标志文件名（128x128 无背景 PNG）。文件名即契约 —— 换图只覆盖
	## assets/ui/affix_<glyph>.png；`<glyph>` 由 `CardData.affix_glyph(字段名)` 给出。
	return path_for("affix_%s" % glyph)


static func affix_badge(glyph: String) -> Texture2D:
	## R592：字段标志**唯一取图口**。缺图返回 null → 卡面回退
	## `CardInfoBoxes.draw_glyph()` 的矢量符号（没导入 / 导出包读不到 png 时照常可玩）。
	if glyph == "":
		return null
	return get_tex("affix_%s" % glyph)


static func div_orb_glass() -> Texture2D:
	## 水晶球玻璃壳（R511）：从 `bg_divination.png` 原图剥离的高光/内壁/边缘，
	## 只保留亮部（暗部近乎全黑）。代码侧用 **ADD 混合**盖在幻象之上，
	## 于是幻象看起来是「装在这个球里」的，而不是贴上去的一张图。
	## 缺图返回 null，幻象照常显示（只是少了玻璃反光）。
	return get_tex("div_orb_glass")


static func card_paper() -> Texture2D:
	## 卡面纸底（R113）。设计基准 58 × 70（与 CARD_W:CARD_H 同比）。
	## 卡面宽高比恒定，只是整体缩放，所以**不需要九宫格**，直接拉伸即可。
	return get_tex("card_paper")


static func card_frame(rarity: int) -> Texture2D:
	## 稀有度边框（R113）。下标与 `CardData.RARITY_COLORS` 对齐：
	##   0 普通 / 1 稀有 / 2 史诗 / 3 初始 / 4 怪物 / 5 事件 / 6 诅咒（R223）。
	return get_tex("frame_%d" % clampi(rarity, 0, 6))


static func art_frame(kind: String) -> Texture2D:
	## 卡图区窄边框（R498）。`kind` = 卡牌归属，见 `CardFace.art_frame_kind()`：
	##   forest 森林精魄 / shadow 暗影刺客 / mech 机械之心 / common 公用 / enemy 敌人。
	## 源图 **200×160**（= 卡图窗宽高比 1.25），代码里**整张拉伸**贴合卡图区（不是九宫格）。
	## 中心全透明、最外 1px 不透明 —— 直接盖在卡图之上即可，既不遮图也不在纸底上露缝。
	## 缺图返回 null，`CardFace` 回退成同色细线框（不空白、不报错）。
	return get_tex("art_frame_" + kind)


static func rarity_ribbon(rarity: int) -> Texture2D:
	## 稀有度缎带（R170）：挂在卡面**右上角**的锦旗，稀有度的主通道
	## （取代「底部框线涂稀有度色 + 色块小旗」—— 用户口径：不要粗暴的颜色块/颜色条）。
	## 下标同 `CardData.RARITY_COLORS`。透明底、燕尾下垂，源图 192 高。
	## 缺图时返回 null，`CardFace` 回退成程序绘制的小旗 —— 不空白也不报错。
	return get_tex("ribbon_%d" % clampi(rarity, 0, 6))


static func scroll_parchment() -> Texture2D:
	## 羊皮卷面板底（R191）：1524×953 透明底卷轴，四边自然破损、中心均匀干净。
	## 配 `UiTheme.draw_scroll_bg()` 九宫格使用（角块 16%，边条单向拉伸）。
	## 缺图返回 null，调用方回退 `draw_panel_bg` 平铺羊皮纸。
	return get_tex("scroll_parchment")


static func void_portal() -> Texture2D:
	## 虚空洞口弹窗底（R197）：768×540，与敌方效果开场弹窗 **1:1 不缩放**；
	## 中心 r=225 纯黑圆盘、文字画白色，几何契约见 battle_scene 的 EE_TEXT_* 常量。
	## 缺图返回 null，battle_scene 回退程序化绘制（紫环 + 纯黑内圆），不空白不报错。
	return get_tex("void_portal")


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


static func enchant_icon(ench_id: String) -> Texture2D:
	## 商店附魔的图标（R214）—— 与商店第二行商品**同一张素材**，所以卡面上的
	## 附魔标记天然「与附魔种类相同」（用户口径）。
	## 素材名来自 `CardData.ENCHANT_DEFS[id].icon`（唯一口），这里只负责取图；
	## 未注册 / 缺图 → null，`CardFace` 回退成附魔名首字，不空白也不报错。
	var nm := CardData.enchant_icon_name(ench_id)
	if nm == "":
		return null
	return shop_icon(nm)


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


static func title_art() -> Texture2D:
	## R604 主界面主视觉：1920×1080，标题字已烘焙进图里（合成脚本 tools/_compose_r604_art.py）。
	## 缺图返回 null → `title_scene` 回退 `title_bg` + 文字标题，`opening_scene` 直接跳标题。
	return get_tex("title_art")


static func language_bg() -> Texture2D:
	## R660 首次语言选择背景：1920×1080，codex 纯文生图（无文字）。
	## 缺图返回 null → 选择页回退 `title_art` → `title_bg`，不会黑屏。
	return get_tex("language_bg")


static func studio_mark() -> Texture2D:
	## R604 厂牌徽记（透明底）：片头卡中心 + 启动 splash 共用同一张。缺图时片头只出文字。
	return get_tex("studio_mark")


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
	return small_icon("class_avatar_" + k, 160) if k != "" else null


static func class_avatar_locked(cls: String) -> Texture2D:
	## 锁定职业的**剪影 + 金锁**头像（R550，发布版解锁）—— 不露真实立绘。
	## 缺图返回 null，调用方回退 `class_badge` 圆徽。
	var k := class_key(cls)
	return small_icon("class_avatar_" + k + "_locked", 160) if k != "" else null


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
