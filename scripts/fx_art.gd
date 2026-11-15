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
##     由卡面 `color` 映射（见 `skill_name_for()`）。R670 之前 29 张伤害技能共用
##     同一坨紫色爆点，玩家看不出用了哪张牌；现在按卡色分族，牌一落就知道是什么属性。
##
## R738 重整：`color` 从「色相词」改成「元素族」（火 / 冰 / 雷 / 毒 / 暗影 /
## 圣光 / 自然 / 物理 / 水风）。旧口径按色相词猜属性，于是机械之心（卡面蓝）的
## 34 张卡全成了冰霜、暗影刺客（卡面紫）全成了暗影 —— 属性其实由职业决定，不是卡本身。
## 现在：
##   * 有元素的卡显式写族（`cards.json` 的 `color`）；
##   * 没有明显属性的卡写空串 → `family_of()` 按**职业**兜底
##     （森林精魄 自然 / 暗影刺客 暗影 / 机械之心 圣光 / 敌人 物理）；
##   * 公用初始卡（木栅栏 / 攻击）class 为空 → 跟 `RunState.player_class`
##     （R328 的「卡面吃本职业皮」同理，战斗特效也吃本职业）。

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

## ── R738 元素族 ──
## `cards.json` 的 `color` 字段就用这九个值（外加空串 = 无属性 → 按职业）。
## 族名不是色相：同一个「蓝」可以是水（清泉）也可以是机械（护盾），旧口径分不开。
const FAM_FIRE := "火"
const FAM_ICE := "冰"
const FAM_BOLT := "雷"
const FAM_POISON := "毒"
const FAM_SHADOW := "暗影"
const FAM_HOLY := "圣光"
const FAM_NATURE := "自然"
const FAM_PHYS := "物理"
const FAM_STORM := "水风"
## 全部合法族名（回归断言 + 数据体检共用这一份，不手抄第二处）。
const FAMILIES: Array[String] = [FAM_FIRE, FAM_ICE, FAM_BOLT, FAM_POISON,
		FAM_SHADOW, FAM_HOLY, FAM_NATURE, FAM_PHYS, FAM_STORM]

## 职业 → 无属性卡的默认族（店长口径：「没有明显卡色的卡按职业来」）。
## 机械之心是「光 + 火」：默认圣光，炮击 / 爆炸 / 锻造类在数据里显式写「火」。
const CLASS_FAMILY := {
	"森林精魄": FAM_NATURE,
	"暗影刺客": FAM_SHADOW,
	"机械之心": FAM_HOLY,
	## R761：吟游诗人 = 水风（琴音如风）。现存八个族里唯一没被任何职业占用的一个，
	## 卡面写空 `color` 时它就是「吟游诗人的默认特效」。
	"吟游诗人": FAM_STORM,
}
## 敌人没有职业可依 → 普通打击就是物理（橙红爆点），一眼看得懂。
const ENEMY_FAMILY := FAM_PHYS

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


static func art_of_family(fam: String) -> String:
	## 元素族 → 通用施法素材名。九族各有一张，缺族（手滑写了别的字）退回自然，
	## 宁可画错一张图，也不能什么都不画。
	match fam:
		FAM_FIRE:
			return SKILL_FIRE
		FAM_ICE:
			return SKILL_ICE
		FAM_BOLT:
			return BOLT
		FAM_POISON:
			return POISON
		FAM_SHADOW:
			return SKILL_SHADOW
		FAM_HOLY:
			return SKILL_HOLY
		FAM_PHYS:
			return BLAST
		FAM_STORM:
			return GALE
	return SKILL_NATURE


static func family_of(card: CardData, player_class := "") -> String:
	## 这张卡该用哪一族特效（R738 唯一口径）。
	##   ① `color` 是九族之一 → 直接用它（卡自己说了算）；
	##   ② `color` 为空 → 没有明显属性，按**卡的职业**兜底；
	##   ③ 卡是公用初始卡（`class` 为空，如 8002 攻击）→ 按**当前在玩谁**
	##      （与 `PlayerClass.skin_class()` 同一条规则：卡面吃职业皮，特效也吃）。
	##      ⚠️ 这正是「森林精魄打攻击喷冰」的老毛病：8002 的 color 原写「蓝」，
	##      旧口径一路映射到冰霜；现在它写空，森林打出来是自然绿。
	##   ④ 敌人 / 查不到职业 → 物理。
	if card == null:
		return ENEMY_FAMILY
	var c := str(card.color)
	if FAMILIES.has(c):
		return c
	var cls := str(card.card_class)
	if cls == "":
		cls = player_class if player_class != "" else str(RunState.player_class)
	if CLASS_FAMILY.has(cls):
		return str(CLASS_FAMILY[cls])
	return ENEMY_FAMILY


static func skill_name_for(card: CardData, player_class := "") -> String:
	## 卡 → 通用施法素材名（界面唯一的调用口）。
	return art_of_family(family_of(card, player_class))

