class_name TrapData
extends RefCounted
## R663：工具（R690 前叫「陷阱」）消耗品的一条定义。工具**不是卡牌、也不是道具**（relics）——
## 它只存在于 RunState.traps 的定长栏位里：放置型拖到战场空格变成场地效果，
## 使用型（小血瓶 / 法力药剂）轻点一下直接结算。
## 独立 id 段 7001~7006，避免与 cards.json / relics.json 撞号。

var id := 0
var trap_name := ""
var desc := ""
var price := 0
## 踩到那一刻的伤害（走 GameEngine._hit_unit，自动吃减伤 / 护盾 / 接通）。
var damage := 0
## 冻结回合数（>0 → _apply_frozen）。
var freeze := 0
## 禁足回合数（>0 → p.rooted = 1，下回合生效）。
var root := 0
## 中毒总结算次数（踩到时 1 次 + 之后所属方回合结束各 1 次，与毒沼同口径）。
var poison_turns := 0
## R690：**使用型工具**的回复量（百分比，按当前最大生命算）。>0 → 不放置，点一下直接用。
var heal_pct := 0
## R690：使用型工具回复的费用点数。>0 → 不放置，点一下直接用。
var energy := 0
var icon := ""
## R743：**只在休息处烤制**才能拿到（烤肉）。不进战斗掉落池、也不进商店货架 ——
## 这两处的池子走 `TrapRepo.random_traps()`，它按这个标记筛。
var rest_only := false
## R745：使用型工具给**本场战斗**所有己方盟友的力量加成（野性图腾 7008 = 2）。
## >0 → 不放置，点一下直接用。与回血 / 回费不同，这个加成**不会因为工具被用掉而消失** ——
## 它在本场战斗里持续生效（口径与竖琴 6052 的持续 buff 一致，见 `Placement.totem_atk`）。
var ally_atk := 0


## R690：「工具」分两类 —— 放置型（陷阱，拖到战场空格）与使用型（药水，轻点即用）。
## 判据只看数据：带 heal_pct / energy / ally_atk 的就是使用型，界面与引擎共用这一个口。
func is_usable() -> bool:
	return heal_pct > 0 or energy > 0 or ally_atk > 0


static func from_dict(d: Dictionary) -> TrapData:
	var t := TrapData.new()
	t.id = int(d.get("id", 0))
	t.trap_name = GameI18n.trap_name(t.id, str(d.get("name", "")))
	t.desc = GameI18n.trap_desc(t.id, str(d.get("desc", "")))
	t.price = int(d.get("price", 0))
	t.damage = int(d.get("damage", 0))
	t.freeze = int(d.get("freeze", 0))
	t.root = int(d.get("root", 0))
	t.poison_turns = int(d.get("poison_turns", 0))
	t.heal_pct = int(d.get("heal_pct", 0))
	t.energy = int(d.get("energy", 0))
	t.icon = str(d.get("icon", ""))
	t.rest_only = bool(d.get("rest_only", false))
	t.ally_atk = int(d.get("ally_atk", 0))
	return t
