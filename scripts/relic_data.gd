class_name RelicData
extends RefCounted
## 道具数据 —— 与 CardData 同风格，从 relics.json 读取。
##
## kind 分类（生效时机，仅描述性，不再决定颜色）：
##   即时  获得时当场生效一次（可能有后续选择，见 needs_pick）；
##   战斗  战斗内持续/触发生效（引擎每场战斗读取）；
##   持续  战斗外持续生效（地图/事件层结算）。
##
## source 分类（获得途径 → 决定徽章颜色）：
##   初始  第一层起点三选一 → 白
##   奖励  精英 / Boss 掉落 → 黄
##   事件  事件获取 → 紫
##   二层  第二层起点三选一 → 青
##   角色  选定角色时发放 → 绿
##
## tier 分类（R289 奖励道具二级分档；只对 source == 奖励 有意义）：
##   一般  默认档，现有 11 件奖励道具全在这一档；
##   传奇  稀有档，目前空置（留位给后续道具）。
## 分档只影响展示与筛选，**不改动掉落概率**；按档取池见 RelicRepo.reward_ids(tier)。

const KIND_INSTANT := "即时"
const KIND_BATTLE := "战斗"
const KIND_PASSIVE := "持续"

const SRC_INITIAL := "初始"
const SRC_REWARD := "奖励"
const SRC_EVENT := "事件"
const SRC_LAYER2 := "二层"
const SRC_CLASS := "角色"

const TIER_NORMAL := "一般"
const TIER_LEGENDARY := "传奇"
const RELIC_TIERS := [TIER_NORMAL, TIER_LEGENDARY]

var id := 0
var relic_name := ""
var kind := KIND_INSTANT
var source := SRC_INITIAL
var tier := TIER_NORMAL
var desc := ""
## **是否默认锁在随机池外**（R346 剧情解锁系统）。
##   * `false`（缺省）= 老行为：一直在奖励池里；
##   * `true` = 必须先在故事界面解锁（`ProfileData.is_relic_unlocked`）才进奖励池。
## ⚠️ 只影响**奖励池**（`RelicRepo.reward_ids()`）：初始池 / 二层池 / 事件池 / 角色赠品
##    是显式 id 列表，不走随机，锁定标记对它们没有意义。
var locked := false


static func normalize_tier(raw: String) -> String:
	## 非法 / 缺失的 tier 一律回落「一般」（旧数据、手写漏字段都安全）。
	return raw if RELIC_TIERS.has(raw) else TIER_NORMAL


static func from_dict(d: Dictionary) -> RelicData:
	var r := RelicData.new()
	r.id = int(d.get("id", 0))
	r.relic_name = str(d.get("name", ""))
	r.kind = str(d.get("kind", KIND_INSTANT))
	r.source = str(d.get("source", SRC_INITIAL))
	r.tier = normalize_tier(str(d.get("tier", TIER_NORMAL)))
	r.desc = str(d.get("desc", ""))
	# R346：剧情解锁标记（缺省 false = 老数据不用改，一直在奖励池里）
	r.locked = bool(d.get("locked", false))
	return r


func needs_pick() -> bool:
	## 即时类道具中需要玩家再选卡的（源数之力 / 失忆药水 / 鸭血）。
	return id in [6002, 6004, 6024]


func source_color() -> Color:
	## 按获得途径着色：初始白 / 奖励黄 / 事件紫 / 二层青 / 角色绿。
	match source:
		SRC_REWARD:
			return Color("e0b23c")   # 黄（奖励）
		SRC_EVENT:
			return Color("a44ad0")   # 紫（事件）
		SRC_LAYER2:
			return Color("3fc7d4")   # 青（二层起始）
		SRC_INITIAL:
			return Color("f4f6fa")   # 白（初始）
		SRC_CLASS:
			return Color("4caf50")   # 绿（角色赠品）
	return Color.GRAY


func source_label() -> String:
	return "%s道具" % source


func is_initial() -> bool:
	return source == SRC_INITIAL


func is_legendary() -> bool:
	return tier == TIER_LEGENDARY


func tier_label() -> String:
	return "%s道具" % tier


func tier_color() -> Color:
	## 分档色：一般 = 中性灰（不抢来源色），传奇 = 橙金（徽章上要一眼看出来）。
	match tier:
		TIER_LEGENDARY:
			return Color("e8933a")
	return Color("9aa0a6")


## 名字色（R343，用户口径「传奇道具的名字颜色要和普通道具区分开」）。
##
## 传奇 = 金橙，普通道具**原样返回调用方给的正文色**（不抢眼、也不改现有观感）。
## 名字会画在两种底上，所以分两档：
##   · 浅底（羊皮纸 / 米白，正文是深墨 `#1a1c22` 那一类）→ 用**暗金**（亮金压米白会糊成一团）；
##   · 深底（墨蓝夜色，正文是米白 `#f2e6c8` 那一类）→ 用**亮金**。
## 判据 = 调用方原本的正文色 `base` 的亮度：亮 → 说明字是浅色的，底就是深的。
## 消费方 = 奖励列表 / 奖励详情 / 道具图鉴（列表 + 浮层）/ 地图道具栏 / 起点三选一 /
##          幕间提示 / 战斗道具栏 / 战斗道具面板 / 记录页 / 提及浮窗。
const NAME_LEGENDARY_ON_LIGHT := Color("a85a10")   # 浅底上的暗琥珀金（对 #efece4 ≈ 4.3:1）
const NAME_LEGENDARY_ON_DARK := Color("f2bb45")    # 深底上的亮金


func name_color(base: Color) -> Color:
	if not is_legendary():
		return base
	return NAME_LEGENDARY_ON_DARK if base.get_luminance() > 0.45 \
			else NAME_LEGENDARY_ON_LIGHT


func badge_color() -> Color:
	## 玩家看到的徽章色**唯一口**：传奇一律橙金（盖过来源色），其余沿用来源色。
	## 消费方 = 奖励悬浮窗 / 道具图鉴（浮层 + 列表）/ 提及浮窗 / 地图道具面板 / 记录页。
	return tier_color() if is_legendary() else source_color()


func tag_line() -> String:
	## 道具标签**唯一口**：来源 · 生效时机（奖励道具再追加档位）。
	## 消费方 = 奖励悬浮窗 / 道具图鉴 / 提及浮窗 / 地图道具面板 共 6 处。
	var base := "%s · %s" % [source_label(), kind]
	if source == SRC_REWARD:
		return "%s · %s" % [base, tier]
	return base
