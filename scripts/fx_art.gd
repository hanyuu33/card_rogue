class_name FxArt
extends RefCounted
## R670：战斗特效素材的**唯一取图 + 绘制口**。
##
## 店长口径：**不要用文字特效，用素材图做特效**。素材由 codex 纯文生图出黑底发光图，
## `art_src/.../_finish_fx.py` 把亮度当 alpha 转透明，落 `assets/fx/bx_<name>.png`。
## 一律「有图贴图、缺图返回 false 让调用方退回程序化光环」——先落几张就能先接几张，
## 素材没到也绝不会出现「什么都不画」。
##
## 命名分两族：
##   * 机制专属：`vortex`（漩涡吸入）/ `air_raid`（空袭落弹）/ `blast`（爆裂）/
##     `gale`（风刃）/ `stun`（眩晕星环）。
##   * 技能通用：`skill_fire` / `skill_ice` / `skill_shadow` / `skill_holy` / `skill_nature`，
##     由卡面 `color` 映射（见 `skill_name_for_color()`）。R670 之前 29 张伤害技能共用
##     同一坨紫色爆点，玩家看不出用了哪张牌；现在按卡色分五族，牌一落就知道是什么属性。

const DIR := "res://assets/fx/"
const PREFIX := "bx_"

const VORTEX := "vortex"
const AIR_RAID := "air_raid"
const BLAST := "blast"
const GALE := "gale"
const STUN := "stun"
const SKILL_FIRE := "skill_fire"
const SKILL_ICE := "skill_ice"
const SKILL_SHADOW := "skill_shadow"
const SKILL_HOLY := "skill_holy"
const SKILL_NATURE := "skill_nature"
## R675：闪电（充电装置接通链 / 机制伤害）。试过复用 `fx_arc_elec`（电磁屏障那条细电弧），
## 168px 铺在草皮上几乎看不见 —— 那是「电流爬过护盾」的量级，不是「一道雷炸开」。
## 已委托 codex 单独出图：白芯 + 青紫分叉闪电，成同心放射状。
const BOLT := "bolt"
## R679：中毒每回合的持续伤害（`_poison_tick` → `_hit_unit(p, dmg, "中毒")`）。
## 走的是 `trap_fx_7003` 那张毒绿 —— 与毒瓶陷阱、毒沼**同一张图**
## （店长定案：毒瓶与毒沼统一口径，不另出毒雾）。所以这个常量**故意不符合**
## `bx_` 契约，由 `path_of()` 单独放行；也因此**不进** `all_names()`
## （那是 bx_ 十一张齐不齐的清单，混进来会把断言撑爆）。
const POISON := "poison"

## 素材名 -> Texture2D / null（缺图也缓存，避免每帧查盘）
static var _cache := {}


static func all_names() -> Array:
	## 全部素材名（回归断言「十一张都落盘了」用这一份，不手抄第二处）。
	return [VORTEX, AIR_RAID, BLAST, GALE, STUN, BOLT,
			SKILL_FIRE, SKILL_ICE, SKILL_SHADOW, SKILL_HOLY, SKILL_NATURE]


static func path_of(name: String) -> String:
	## 文件名契约：`assets/fx/bx_<name>.png`。与 UI 贴图分目录 —— 这是战场特效，不是界面元件。
	## R679 唯一例外：`POISON` 直接借陷阱那张毒绿。中毒掉血与毒瓶触发用同一个笔触，
	## 玩家才不会觉得「毒」在游戏里是两种东西。
	if name == POISON:
		return DIR + "trap_fx_7003.png"
	return DIR + PREFIX + name + ".png"


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = _load(path_of(name))
	return _cache[name]


static func clear_cache() -> void:
	## 只给测试用：换图 / 热重载后要重新解盘。
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


static func draw(ci: CanvasItem, name: String, rect: Rect2, alpha: float) -> bool:
	## 有图就贴、返回 true；缺图返回 false，由调用方画程序化光环兜底。
	var t: Texture2D = tex(name)
	if t == null:
		return false
	ci.draw_texture_rect(t, rect, false, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))
	return true


static func color_of(name: String) -> Color:
	## 兜底光环 / 通用爆点用的本色。与素材主色一致，缺图时看着仍是同一族。
	match name:
		VORTEX:
			return Color(0.36, 0.72, 0.95)     # 漩涡 · 青蓝
		AIR_RAID:
			return Color(0.98, 0.66, 0.26)     # 空袭 · 橙金
		BLAST:
			return Color(0.96, 0.48, 0.16)     # 爆裂 · 橙红
		GALE:
			return Color(0.61, 0.86, 1.00)     # 风刃 · 淡青
		STUN:
			return Color(0.98, 0.84, 0.33)     # 眩晕 · 明黄
		SKILL_FIRE:
			return Color(1.00, 0.46, 0.16)
		SKILL_ICE:
			return Color(0.50, 0.83, 1.00)
		SKILL_SHADOW:
			return Color(0.60, 0.36, 0.90)
		SKILL_HOLY:
			return Color(1.00, 0.84, 0.34)
		SKILL_NATURE:
			return Color(0.52, 0.76, 0.32)
		BOLT:
			return Color(0.58, 0.86, 1.00)     # 闪电 · 电光蓝
		POISON:
			return Color(0.46, 0.72, 0.22)     # 中毒 · 毒绿（与 trap_fx_7003 同族）
	return Color(0.80, 0.76, 0.66)


static func skill_name_for_color(card_color: String) -> String:
	## 卡面 `color` → 通用施法图。五族覆盖卡表全部色值（紫74/蓝55/灰37/绿34/白30/金28/黑23/红20/橙7/棕4/黄3）。
	## ⚠️ 归类口径按「读起来像什么属性」而不是色值本身：灰 / 棕 / 黄跟着绿走自然与物理，
	##    金 / 白走圣光，紫 / 黑走暗影，红 / 橙走火，蓝走冰。
	match card_color:
		"红", "橙":
			return SKILL_FIRE
		"蓝":
			return SKILL_ICE
		"紫", "黑":
			return SKILL_SHADOW
		"金", "白":
			return SKILL_HOLY
	return SKILL_NATURE
