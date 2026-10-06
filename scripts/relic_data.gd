class_name RelicData
extends RefCounted
## 道具（肉鸽遗物）数据 —— 与 CardData 同风格，从 relics.json 读取。
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

const KIND_INSTANT := "即时"
const KIND_BATTLE := "战斗"
const KIND_PASSIVE := "持续"

const SRC_INITIAL := "初始"
const SRC_REWARD := "奖励"
const SRC_EVENT := "事件"
const SRC_LAYER2 := "二层"
const SRC_CLASS := "角色"

var id := 0
var relic_name := ""
var kind := KIND_INSTANT
var source := SRC_INITIAL
var desc := ""


static func from_dict(d: Dictionary) -> RelicData:
	var r := RelicData.new()
	r.id = int(d.get("id", 0))
	r.relic_name = str(d.get("name", ""))
	r.kind = str(d.get("kind", KIND_INSTANT))
	r.source = str(d.get("source", SRC_INITIAL))
	r.desc = str(d.get("desc", ""))
	return r


func needs_pick() -> bool:
	## 即时类道具中需要玩家再选卡的（源数之力 / 失忆药水 / 鸭血）。
	return id in [6002, 6004, 6024]


func source_color() -> Color:
	## 按获得途径着色：初始白 / 奖励黄 / 事件紫 / 二层青。
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
