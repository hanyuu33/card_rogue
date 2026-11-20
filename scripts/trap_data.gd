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
## R752：使用型工具里**需要先选卡**的那一类（万能牌 7009 / 神秘牌 7011）。
##   * `"deck_copy"` —— 从抽牌库选一张，幻影复制入手（费用 0，离手即恢复原费用）；
##   * `"random3"`   —— 从随机 3 张本职业奖励卡里选一张入手，本回合费用 0。
## 空串 = 选中即结算（回血 / 回费 / 力量这一类）。
## ⚠️ 它把「使用」拆成两段（点工具 → 选卡页 → 确认才摘槽），
##    所以界面**不许**在 `use_tool` 之后无条件 consume，见 `battle_scene._use_tool_slot`。
var pick_kind := ""
## R752：快送鸭 7010 —— 使用后**用随机商店工具填满工具栏**（不选卡、当场结算）。
## 与 `pick_kind` 并列：一个工具只说明自己「怎么生效」，判据全在数据里。
var fill_toolbar := false
## R796：卡牌包 7013 —— 使用后**用随机卡牌填满手牌**（不选卡、当场结算）。
## 与 `fill_toolbar` 是同一条思路的两个栏位：一个补工具栏，一个补手牌。
var fill_hand := false
## R797：河豚 7015 —— 踩到的单位**回弹这么多格**（1 = 回到来时的格子）。
## 回弹方向不走 `_knockback`（那是「朝对方后排直推」）：河豚是「原地弹回」，
## 只有「没有来路」（效果直达 / 上一格已被占）时，才改朝**河豚所属方**的方向弹一格。
var bounce := 0
## R801：爆炸蘑菇 7016 —— 爆炸半径（**曼哈顿距离**，1 = 正交四邻）。
## >0 = **范围伤害型**：`_trigger_trap()` **不走**单体那一笔 `_hit_unit(p, damage)`，
## 改由 `_blast_trap()` 对「距离 ≤ blast」的**所有单位**（不分敌我、含中心格自身）
## 各结算一次 `damage`。两条判据必须成对理解 —— 漏掉「跳过单体」就是踩上去吃两遍。
## 与 `bounce` / `fill_hand` 同一条思路：一个工具只说明自己「怎么生效」，判据全在数据里。
var blast := 0
## R796：智慧药剂 7014 —— 使用后**抽这么多张卡**（走 `_draw_many`，手牌满时照常
## 进弃牌区，与战斗中一切抽卡同一口径）。
var draw_cards := 0
## R754：**直接伤害型**工具（石头 7012）—— 拖到**敌方单位身上**，当场砸出这么多伤害。
## 与放置型（`damage`，埋进空格等敌人踩）是两回事：`damage` 归陷阱触发用，
## 这个归「指着谁砸谁」，所以必须是独立字段，判据见 `GameEngine.trap_drop_cells()`。
var direct_damage := 0
## R839：大蒜 7017 —— 放置后该格 **连续 N 个我方回合不可使用**
## （任何单位不能进入 / 经过，也不能往上放陷阱 / 场地 / 单位）。
## >0 = **封锁型**：`place_trap()` 写进 `FieldState.sealed_cells`，**刻意不进 `trap_fields`** ——
## 那张表的语义是「踩上去触发」，而封锁格根本踩不进去；混进去会让 `trap_legal_cells()`
## 把它当成一件已布置的陷阱（同格不许再放），`_trigger_trap()` 又永远等不到人踩。
## 与 `bounce` / `blast` / `fill_hand` 同一条思路：一个工具只说明自己「怎么生效」。
var block_turns := 0
## R754：「不受随机获得影响」—— 石头只从事件「奇异雕像」的摧毁选项拿，
## 混进掉落 / 工具箱就会变成「打怪掉石头」，把事件的选择变成笑话。
## 只影响 `TrapRepo.random_traps()`；商店本来就不收没有售价的（见 `in_shop()`）。
var no_drop := false


## R690：「工具」分两类 —— 放置型（陷阱，拖到战场空格）与使用型（药水，轻点即用）。
## 判据只看数据：带 heal_pct / energy / ally_atk / pick_kind / fill_toolbar /
## fill_hand / draw_cards 的就是使用型，
## 界面与引擎共用这一个口。
## ⚠️ R754：直接伤害型（石头 `direct_damage`）**不算使用型** —— 它要落点（敌方单位），
##    走的是拖放那条路，所以这里故意不收 `direct_damage`；别「顺手」加进来，
##    加了它会被当成「轻点即结算」直接砸空。
func is_usable() -> bool:
	return (heal_pct > 0 or energy > 0 or ally_atk > 0
			or pick_kind != "" or fill_toolbar or fill_hand or draw_cards > 0)


## R752（用户口径「以后没有售价的则不计入商店」）：**能不能上商店货架**只看售价。
## `price <= 0` = 没有售价 = 非卖品（烤肉 7007 只能休息处烤，万能牌 / 快送鸭 / 神秘牌
## 只能靠掉落或工具箱拿到）。⚠️ 判据只写这一处 —— 商店取货、快送鸭的池子都走它。
func in_shop() -> bool:
	return price > 0


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
	t.pick_kind = str(d.get("pick_kind", ""))
	t.fill_toolbar = bool(d.get("fill_toolbar", false))
	t.fill_hand = bool(d.get("fill_hand", false))
	t.draw_cards = int(d.get("draw_cards", 0))
	t.bounce = int(d.get("bounce", 0))
	t.blast = int(d.get("blast", 0))
	t.direct_damage = int(d.get("direct_damage", 0))
	t.block_turns = int(d.get("block_turns", 0))
	t.no_drop = bool(d.get("no_drop", false))
	return t
