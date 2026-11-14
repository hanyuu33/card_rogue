class_name TrapData
extends RefCounted
## R663：陷阱消耗品的一条定义。陷阱**不是卡牌、也不是道具**（relics）——
## 它只存在于 RunState.traps 的定长栏位里，放置后变成战场上的场地效果。
## 独立 id 段 7001~7004，避免与 cards.json / relics.json 撞号。

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
var icon := ""


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
	t.icon = str(d.get("icon", ""))
	return t
