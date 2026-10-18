class_name CardData
extends RefCounted
## 一张卡的数据（对应 Python 版 cardtool.models.Card）。
##
## ⚠️ **const 字典里不能放 Color(...) 构造调用**（GDScript 的 const 必须是编译期常量，
## `Color()` 是运行时构造 → 整份 `card_data.gd` 解析失败、**所有**脚本都跟着挂，
## 而且报错只说 "Could not parse global class CardData"，完全看不出是哪一行）。
## 所以 `AFFIX_DEFS` 里只存**十六进制色串**，由 `affix_colors()` 运行时构造 Color。

const RARITY_NAMES: Array[String] = ["普通", "稀有", "史诗", "初始", "怪物", "事件", "诅咒"]
## 卡面边框色：普通=黑 稀有=蓝 史诗=紫 初始=绿 怪物=暗红 事件=亮紫 诅咒=暗紫灰（R223）
const RARITY_COLORS: Array[Color] = [Color("2c2c2a"), Color("1f5fbf"),
		Color("8a30b8"), Color("1d7a4f"), Color("7a1f1f"), Color("a44ad0"),
		Color("4e4560")]

## ── 【字段系统】（R91）`affixes` = 这张卡当前带有的**字段名**列表 ──
##
## **为什么要有字段**：以前每个机制都是「一个 trait + 一句手写文案」，于是
##   * 引擎改属性时**要同步改好几处文案**（卡面 / 悬停 / 提示），漏一处就前后矛盾；
##   * 别的卡**赋予**这个效果时（过载给 actions、能量屏障给护盾…）没有任何地方能显示它。
## 字段把「效果」抽象成**一个名字**，三个消费点自动同步：
##   ① **卡面**：`affix_line()` 在效果下方追加「疾行 · 嘲讽 · 幻影」；
##   ② **战场**：`_draw_affix_badges()` 在单位上方**轮流显示**（复用状态徽标底座）；
##   ③ **悬停**：列出该单位 / 该卡当前的全部字段。
##
## 现有 8 个字段（引擎判据都读这里，**不再按卡名 / trait 硬编码**）：
##   * **疾行** = 一回合行动两次（判据 `actions >= 2`；场上读 `acts_left > 1`）
##   * **嘲讽** = 敌方只能攻击这张卡
##   * **死亡** = 被破坏时生效（**只做标记**，具体内容看卡面 effect_text）
##   * **幻影** = 打出后手牌里多一张自身的短暂复制（回合结束消失）
##   * **护盾** = 第一次受到的伤害为 0（一次性；由「能量屏障」8033 赋予）
##   * **次元** = 使用后 / 离开战场后消失，**不进弃牌区**（R93）
##     技能卡用后的去向**唯一口径** = `GameEngine._spell_card_gone()`（R211）：带本字段的
##     技能卡打完即 `void_count += 1` 进消耗区，不写弃牌区；加新次元技能卡只改数据、不用改引擎。
##     ⚠️ 与「幻影」是**两种不同的消失**，别混：
##       · 次元 = **打出使用后**消失，或**在场上离场**时消失；
##       · 幻影 = 复制品**躺在手牌里**到回合结束消失 —— 那种**不给**次元。
##       所以衍生物（野兔 9032 / 幻影的复制卡）是**上场那一刻**才挂上次元
##       （唯一写入口 `FieldState.place`，与「沉睡 / 护盾」同一套路）。
##   * **超负荷** = 生命降到 0 以下不会立即死亡、以负血继续存活（R98）
##   * **交换** = 可放置在已有友方单位的格子上，把原单位顶回手（R101）
##
## ⚠️ **`on_board`（R118）**：字段定义里多一个键，回答「这张卡**已经站在场上**
##   之后，这个字段还有意义吗」—— 默认 true，只有**打出手 / 放置那一刻的规则**
##   才写 false：
##     · 交换 = 管的是「能不能放在已有友方单位上」，卡一落到格子上就再无作用；
##     · 幻影 = 管的是「打出时往手牌塞一张复制」，同样只在出手那一刻说话。
##   于是**战场卡面**（`CardFace.draw(..., on_board=true)` → `field_affix_line()`）
##   与**战场徽标 / 悬停**（`active_affixes()`）都会把它们滤掉 —— 用户口径
##   「像交换这种、在场后已经不再有用的字段，就不需要标明了」。
##   ⚠️ **手牌 / 图鉴 / 牌库 / 卡组编辑不过滤**：那几处正是这两种字段唯一有意义的
##   地方（玩家要靠它知道「这张牌能顶掉我场上的单位」）。
const AFFIX_DEFS: Dictionary = {
	"疾行": {"label": "疾行", "desc": "一回合行动两次。", "bg": "0e2e1a", "fg": "3fbf6f"},
	"嘲讽": {"label": "嘲讽", "desc": "敌方只能攻击这张卡。", "bg": "331c05", "fg": "ffa41f"},
	"死亡": {"label": "死亡", "desc": "这张卡被破坏时生效（具体效果见卡面）。", "bg": "330f14", "fg": "ff7a7a"},
	"幻影": {"label": "幻影", "desc": "打出后手牌里多一张这张卡的短暂复制（回合结束消失）。", "on_board": false, "bg": "1f1a38", "fg": "b79cff"},
	"护盾": {"label": "护盾", "desc": "第一次受到的伤害为 0（一次性，用完消失）。", "bg": "0f2a33", "fg": "6ec6ff"},
	"次元": {"label": "次元", "desc": "使用后 / 离开战场后消失，不会进入弃牌区。", "bg": "2a0d33", "fg": "e58cff"},
	"超负荷": {"label": "超负荷", "desc": "生命降到 0 以下不会立即死亡，会以负数血量继续存活；在自己回合结束时若生命仍是负数则死亡（伤害不会溢出）。", "bg": "33120a", "fg": "ff7a3c"},
	"交换": {"label": "交换", "desc": "可放置在已有友方单位的格子上，原本在那个格子上的友方单位返回手卡。", "on_board": false, "bg": "0a2a2e", "fg": "5fe0d0"},
	"保存": {"label": "保存", "desc": "回合结束时，手牌里的这张卡不会丢弃（保留到下一回合）。", "on_board": false, "bg": "1a2a0a", "fg": "b9e85a"},
}

## ── 【商店附魔】（R214）`enchant` = 这张卡吃过的商店附魔 id（"" = 没附魔）──
##
## **为什么不能只靠「数值变了」推断**：附魔本体在 `RunState._apply_mod` 里就被**烤进**了
## 副本的 cost / power / health / affixes（费用 -1、伤害 +10、次元 +2力+10血、保存），
## 烤完之后这张卡和「一张原生就长这样的卡」**完全一样** —— 卡面无从知道「它被附魔过」。
## 于是另记一个 id：玩家花了钱，就必须在**任何看到这张卡的地方**都能认出它（用户口径
## R214「带有附魔效果的卡片，应该在任何地方，都显示附魔标记」）。
##
## 显示（`CardFace` 的附魔标记 / 左栏 / 商店）读这里，**不许各处自己写白名单**：
##   * `label` 附魔显示名（与 `shop_scene.ENCHANTS` 的 name 同一份文案，smoke 有守卫）
##   * `icon`  `assets/ui/` 下的素材名（就是商店第二行那张图标 —— 「与附魔种类相同」）
##   * `col`   附魔种类色：标记描边环 / 左栏文字 / 商店悬停描边共用
const ENCHANT_DEFS: Dictionary = {
	"costdown": {"label": "费用 -1", "icon": "shop_icon_costdown", "col": "6db2f0"},
	"damage": {"label": "伤害 +10", "icon": "shop_icon_damage", "col": "f08a5a"},
	"dimension": {"label": "次元", "icon": "shop_icon_dimension", "col": "c08cf0"},
	"save": {"label": "保存", "icon": "shop_icon_save", "col": "8fdc9f"},
	"opening": {"label": "起手", "icon": "shop_icon_opening", "col": "f0c860"},
}

var id: int = 0
var card_name: String = ""
var kind: String = ""          # 盟友 / 法术 / 工事 / 场地 / 效果
var cost: int = 0
var power: int = 0
var health: int = 0
var attack_range: int = 0
var move_speed: int = 0
var color: String = ""
var traits: Array = []
var effect_text: String = ""
## 技能是否需要选目标：none=不需要 / unit=选一个单位 / cell=选一个格子 /
## hand_unit=选手牌里的一张盟友或工事（R90「系统升级」8039）；
## hand_any=选手牌里**任意一张**卡（R198「回收」8064 —— 目标被换成素体，种类不限）。
var target_mode: String = "none"
var value: int = 0
## 「一回合行动两次」的次数（1 = 普通）。**没有对应 trait**（R91 统一成字段「疾行」）。
var actions: int = 1
var rarity: int = 0             # 0普通 1稀有 2史诗 3初始 4怪物 5事件
var group: String = "player"
var card_class: String = "森林精魄"
## R123：「按张记账」的卡（留手 / 魔像）**第一次**抽到时已换成独立副本的标记
## （见 FieldState.draw）。副本离开手卡（打出 → 弃牌区 → 洗回牌库 → 再抽到）沿用
## 同一个对象 → 实例级**永久**减费（陨石术 9077）不再重置。
var own_copy := false
## X 费卡（流星雨 9083）：费用 = 施放瞬间该方剩余的全部能量（一次性消耗），卡面显示「X」。
var x_cost: bool = false
## **陷阱 / 场地的触发类型**（R84，**纯数据**）：「范围伤害」/「伤害·禁足」/「伤害·冰封」/
## 「中毒」/「单体伤害」/ 空串。
## ⚠️ **纯数据，不驱动引擎** —— 引擎仍按 trait（`爆炸陷阱` / `冰霜陷阱` …）判定，
## 这里只给卡面 / 图鉴 / 界面读，以及往后按触发类型做分组展示或扩展新触发。
## 空串 = 无触发（**持续型场地「清泉」/「维修间」/「改造工厂」刻意留空**：
## 它不走「经过触发」这条路，写触发类型会误导成「走过去会引爆」）。
var trigger: String = ""
## **被「升级」（8027）改造时的额外加成**（R84，机械之心系）。
##   * 素体 8025：hp=1（被改造时额外 +1 生命）
##   * 战斗骨骼 8029：atk=1 / hp=1（被改造时额外 +1 力量 +1 生命）
## 0 = 没有这类额外加成。加成**只在场上有效**，与改造本体一起由
## `GameEngine._card_leaving_field` 离场还原。
## 放在卡面（而不是引擎里按卡名/trait 硬编码）是为了**加新卡不用改引擎**。
var upgrade_atk_bonus: int = 0
var upgrade_hp_bonus: int = 0
## **这张卡随身携带的「改造层数」**（R209）—— 手牌 / 牌库 / 弃牌区里被改造过几次。
##
## 与 `Placement.upgrade_stacks` 是同一口径的**两段**：
##   * **上桌前**的改造（系统升级 8039 / 批量改造 8031 / 批量传输 8040 / 自主升级 8045 /
##     生产订单 8048 / 回收 8064 / 返修 9127）把数值烤进这张卡的副本，层数记在这里 ——
##     否则那些卡上场后 `upgrade_stacks` 从 0 开始，侦察塔的光环（每层 +1 易伤）与卡面
##     「改造 ×N」徽标都看不到改造（用户实测报「系统升级改造侦查塔后没有获得一层改造」）。
##   * **上场后**的改造（升级 8027 / 自我修复 / 改造工厂…）只加 `Placement.upgrade_stacks`，
##     **不写回这里** —— 那是「只在场上有效」的加固，离场即消失（R86 口径不变）。
## `FieldState.place()` 是唯一衔接口：`p.upgrade_stacks = card.upgrade_stacks`。
var upgrade_stacks: int = 0
## **持续型场地每回合的回血量**（R88）：清泉 8028 = 2、维修间 8036 = 2，其余 = 0。
## 0 = 这张持续型场地不回血（判据：`GameEngine._field_aura_tick` 靠它决定要不要结算，
## 以及结算多少 —— 之前那里硬编码 `f.id == FOUNTAIN_ID`，加第二张持续型场地就会被忽略）。
## 放卡面而不是引擎常量：**加新的治疗型场地只要填这个数字，引擎一行都不用改**。
var field_heal: int = 0
## **字段系统（R91）**：这张卡当前带有的字段名列表。见上方 AFFIX_DEFS。
var affixes: Array[String] = []
## **商店附魔 id**（R214，见上方 ENCHANT_DEFS；"" = 没附魔）。
## 附魔的效果本身早烤进了 cost/power/health/affixes —— 这个 id **只负责“让人看出来”**：
## 卡面费用正下方的附魔标记、战斗左栏、商店/牌库/地图的卡面都读它。
## 必须随 `to_dict` 走（复制 / 离场还原 / 联机都是同一条通道），否则标记会静默消失。
var enchant: String = ""
## **本场战斗内的衍生物**（R82：野兔 9032 复制出来的那些）—— 不进牌库也不进弃牌区。
## 为什么要单独一个字段而不是只靠 trait「自我复制」：
## **卡库里的原卡也带同一个 trait**（否则引擎认不出该给谁发复制），
## 若只判 trait，原卡被打死时也会被当成衍生物「消失」—— 它就该老实地进弃牌区被洗回牌库。
## 于是规矩是：trait 决定「**会不会自己复制**」，本字段决定「**是不是衍生物**」。
## ⚠️ 不是 cards.json 的字段，**不进 to_dict** —— 序列化出去时衍生物应当退化成普通卡。
var is_ephemeral: bool = false


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = int(d.get("id", 0))
	c.card_name = str(d.get("name", ""))
	c.kind = str(d.get("kind", ""))
	c.cost = int(d.get("cost", 0))
	for key in ["power", "health", "attack_range", "move_speed"]:
		var v = d.get(key)
		c.set(key, 0 if v == null else int(v))
	c.color = str(d.get("color", ""))
	c.traits = d.get("traits", []) as Array
	c.effect_text = str(d.get("effect_text", ""))
	c.target_mode = str(d.get("target_mode", "none"))
	c.value = int(d.get("value", 0))
	c.actions = maxi(1, int(d.get("actions", 1)))
	c.rarity = clampi(int(d.get("rarity", 0)), 0, 6)
	c.group = str(d.get("group", "player"))
	c.card_class = str(d.get("class", "森林精魄"))
	c.x_cost = bool(d.get("x_cost", false))
	c.trigger = str(d.get("trigger", ""))
	c.upgrade_atk_bonus = int(d.get("upgrade_atk_bonus", 0))
	c.upgrade_hp_bonus = int(d.get("upgrade_hp_bonus", 0))
	c.upgrade_stacks = maxi(0, int(d.get("upgrade_stacks", 0)))
	c.field_heal = int(d.get("field_heal", 0))
	c.own_copy = bool(d.get("own_copy", false))
	# R214：附魔 id 随序列化走（烤数值之后它是「这张卡被附魔过」的唯一凭据）
	c.enchant = str(d.get("enchant", ""))
	# ⚠️ 数组字段**必须逐个 append**（不能直接接字典里那个 Array）：
	# `from_dict` 只接引用的话，赋给场上那张副本后引擎往里 append 字段会
	# **连带改到卡库**（MEMORY 里「from_dict 只复制壳」那个老坑）。
	c.affixes = []
	for a in (d.get("affixes", []) as Array):
		c.affixes.append(str(a))
	return c


func to_dict() -> Dictionary:
	## 序列化（联机时随「play / spell」消息发给对方重放）。
	return {
		"id": id, "name": card_name, "kind": kind, "cost": cost,
		"power": power, "health": health,
		"attack_range": attack_range, "move_speed": move_speed,
		"color": color, "traits": traits,
		"effect_text": effect_text, "target_mode": target_mode,
		"rarity": rarity, "value": value, "actions": actions,
		"group": group, "class": card_class, "x_cost": x_cost,
		# ⚠️ `is_ephemeral` **故意不进** —— 衍生物序列化出去应当退化成普通卡。
		"trigger": trigger,
		"upgrade_atk_bonus": upgrade_atk_bonus, "upgrade_hp_bonus": upgrade_hp_bonus,
		# R209：随身改造层数必须随序列化走（复制 / 离场还原 / 联机共用这一条通道），
		# 漏了它 = 上场后层数静默归 0（侦察塔光环失效）。
		"upgrade_stacks": upgrade_stacks,
		# ⚠️ `field_heal` **必须**在这里 —— `from_dict(card.to_dict())` 是复制 /
		# 改造 / 离场还原 / 联机序列化的统一通道，漏了它字段会静默归 0
		#（持续型场地直接失效）。
		"field_heal": field_heal,
		# R123：独立副本标记随序列化走 —— 复制 / 离场还原之后减费记账仍跟着这一张。
		"own_copy": own_copy,
		# R214：附魔 id **必须**在这里 —— 复制 / 离场还原 / 联机共用这条通道，
		# 漏了它 = 卡一进战场附魔标记就没了（数值还在，看不出是附魔来的）。
		"enchant": enchant,
		# ⚠️ `affixes` 同样**必须**在这里 —— 漏了字段会静默清空
		#（「这张卡被别的卡赋了疾行/幻影/护盾」的强化就没了）。
		"affixes": affixes.duplicate(),
	}


func rarity_name() -> String:
	return RARITY_NAMES[clampi(rarity, 0, 6)]


func rarity_color() -> Color:
	return RARITY_COLORS[clampi(rarity, 0, 6)]


## ── 卡种判定（R91 重建时补回；这几张卡种互不重叠，读法统一走这里）──

func is_spell() -> bool:
	## 技能卡：需要**使用**（选目标 / 立即结算），不是摆到场上。
	return kind == "技能"


func is_effect() -> bool:
	## 效果卡：使用后进入**效果区**持续生效（不占格子、不进场）。
	return kind == "效果"


func is_fort() -> bool:
	## 工事：会挡路的**站着的单位**（与「场地」相对 —— 场地只是格子上的标记）。
	return kind == "工事"


func is_field() -> bool:
	## 场地卡（R74）：**不是单位**，而是「钉在某个格子上的一次性/持续效果」。
	##   * 不能被攻击（没有 HP、没有攻击目标，也不算挡路）；
	##   * 一次性族：敌人**移动经过**该格时触发一次并停止移动，随后该格场地消失；
	##   * 持续型（trait「持续场地」）：永不触发、永不消失，每回合结束结算一次。
	##   * 每个格子最多 1 个场地效果（`FieldState.field_effects` 单一来源）。
	## 「工事」与「场地」是两种东西：工事是会挡住路的单位，场地是格子上的标记。
	return kind == "场地"


func is_curse() -> bool:
	## 诅咒卡（R223 难度 5「疲惫」9149）：**打出无效果**；真正的威力在手里 ——
	## 手牌里有它时，所有**技能卡**费用 +1（引擎 `cost_of` 是唯一消费点）。
	## ⚠️ 诅咒既不是单位也不是技能/效果：`play_from_hand`（单位）、`use_spell`（技能）、
	##    `use_effect`（效果）三条出牌路径都不该碰它 —— 引擎 `use_curse` 是唯一打出入口，
	##    界面（battle_scene）三处据此分流；鸭语耳环自动出牌显式跳过（否则会掉进
	##    `play_from_hand` 被当成单位摆上场）。
	return kind == "诅咒"


func is_damage_spell() -> bool:
	## 这张技能卡能不能**直接造成伤害**（R226：伤害 +10 附魔的资格判据）。
	## * 为什么不能看 `power`：技能卡的 `power` 在卡面上**恒为 0**，伤害写死在引擎结算里；
	## * 为什么用文案判据：cards.json 没有「是否造成伤害」字段，而当前 68 张玩家技能卡里，
	##   能直接造成伤害的 25 张都写成「造成 … 伤害」；只提「受到 / 承受伤害」的 5 张防御卡
	##   （森林守护 9037 / 以太屏障 9060 / 坚固围栏 9071 / 闪躲 9103 / 能量屏障 8033）
	##   都不含「造成」二字 → 天然排除（R226 已逐张核对，零误判）。
	## ⚠️ 以后新增「造成伤害」的技能卡，effect_text 必须带「造成…伤害」四个字，否则附魔
	##    选不中它；回归里 `is_damage_spell` 有守卫（engine 计数 + 抽查）。
	return kind == "技能" and effect_text.contains("造成") and effect_text.contains("伤害")


func needs_target() -> bool:
	## 目标是单位（攻击/火焰箭/击退/削弱/寒冰箭）或格子（火球术）的技能，
	## 使用前必须先指定目标 —— UI 据此进入选目标模式，引擎据此拒绝空目标施放。
	## ⚠️ **不含 `hand_unit` / `hand_any`**（R90「系统升级」8039 / R198「回收」8064）：
	## 那两套目标都在**手牌**里，不走棋盘选目标（`_spell_target_cells` 返回的是棋盘格），
	## 界面另开分支（`_sys_upgrade_idx` / `_recycle_idx`）。
	return target_mode == "unit" or target_mode == "cell"


func needs_cell() -> bool:
	## 目标是格子而不是单位（火球术 9007 / 闪电链等）。
	return target_mode == "cell"


func is_enemy_card() -> bool:
	## 图鉴归类：敌人卡（怪物 / 敌方衍生物）。**敌方关卡效果卡不算**（那是 is_level_effect）。
	return group == "enemy"


func is_level_effect() -> bool:
	## 敌方**关卡效果卡**（图鉴里单列一类）：`group == "enemy"` 且 `kind == "效果"`。
	## 当前 6 张：9013 鸭子之力 / 9015 鸭子号角 / 9024 哈气 / 9049 齿轮升腾 /
	## 9115 使魔之力 / 9117 恶魔使魔。它们只在敌方关卡里启用（图鉴过滤条件用它）。
	return group == "enemy" and kind == "效果"


## 这张卡带某个字段吗（**唯一判定口**，引擎与界面都读它）。
func has_affix(name: String) -> bool:
	return affixes.has(name)


## 给这张卡加一个字段（**唯一写口**，R91）。重复加不会重复写。
## ⚠️ 调用方负责保证 `card` 是**独立副本**（`from_dict` 过）——
## 直接改卡库共享实例会跨 run 泄漏。
func add_affix(name: String) -> bool:
	if affixes.has(name):
		return false
	affixes.append(name)
	return true


## 字段的显示名（未注册的字段回退到字段名本身 —— 加字段忘了写进 AFFIX_DEFS
## 也不至于显示空白，只是没有专属配色与说明）。
static func affix_label(name: String) -> String:
	var d: Dictionary = AFFIX_DEFS.get(name, {})
	return str(d.get("label", name))


## 字段的说明文字（卡面 / 悬停 / 图鉴用）。未注册 → 空串。
static func affix_desc(name: String) -> String:
	var d: Dictionary = AFFIX_DEFS.get(name, {})
	return str(d.get("desc", ""))


## 这个字段在这张卡**已经站在场上**之后还有意义吗（R118，`AFFIX_DEFS.on_board`）。
## 只有「打出手 / 放置那一刻的规则」才是 false（当前：交换 / 幻影），其余一律 true。
## **唯一判定口** —— 战场卡面（`field_affix_line`）、战场徽标与悬停
## （`active_affixes`）都读它，不许各处自己写白名单。
## ⚠️ 未注册字段回退 true：宁可多标一个陌生字段，也不能凭空把它吞掉。
static func affix_on_board(name: String) -> bool:
	var d: Dictionary = AFFIX_DEFS.get(name, {})
	return bool(d.get("on_board", true))


## 字段徽标配色（战场用），返回 [底色, 字色]。
## 色值是**十六进制字符串**（const 里不能放 Color(...) 构造），这里运行时构造 ——
## 底色统一 0.92 透明度，保证字能读清；未注册字段回退到中性灰。
static func affix_colors(name: String) -> Array:
	var d: Dictionary = AFFIX_DEFS.get(name, {})
	if d.is_empty():
		return [Color(0.15, 0.15, 0.15, 0.92), Color("dddddd")]
	var bg := Color(str(d["bg"]))
	bg.a = 0.92
	return [bg, Color(str(d["fg"]))]


## ── 附魔（R214）：显示口径的唯一入口（未注册 id 回退到 id 本身 / 中性紫，不空白）──

## 附魔的显示名（「费用 -1」/「伤害 +10」/「次元」/「保存」）。
static func enchant_name(id: String) -> String:
	if id == "":
		return ""
	var d: Dictionary = ENCHANT_DEFS.get(id, {})
	return str(d.get("label", id))


## 附魔的种类色：卡面标记的描边环、左栏文字、商店悬停描边共用这一个色。
static func enchant_color(id: String) -> Color:
	var d: Dictionary = ENCHANT_DEFS.get(id, {})
	return Color(str(d.get("col", "9b6bd8")))


## 附魔图标素材名（`UiAssets.enchant_icon()` 的入参）；未注册 → 空串（调用方回退首字）。
static func enchant_icon_name(id: String) -> String:
	var d: Dictionary = ENCHANT_DEFS.get(id, {})
	return str(d.get("icon", ""))


## 这张卡带附魔吗（卡面标记 / 左栏 / 商店的唯一判据 —— 别各处写 `enchant != ""`）。
func has_enchant() -> bool:
	return enchant != "" and ENCHANT_DEFS.has(enchant)


## 卡面上要追加的那一行字段提示（引擎在卡被赋予新字段后会自动补上 ——
## 因为它改的就是 `affixes` 这个数组）。
func affix_line() -> String:
	var parts: Array[String] = []
	for a in affixes:
		parts.append(affix_label(a))
	return "　".join(parts)


## **战场卡面**要写的那一行字段（`affix_line()` 的战场版，R118）：
## 滤掉「上场之后已经不再有用」的字段（`affix_on_board()` 为 false 的那些）。
## ⚠️ 与 `affix_line()` 是两个口、刻意不合并：手牌 / 图鉴 / 牌库正需要完整的那一行。
func field_affix_line() -> String:
	var parts: Array[String] = []
	for a in affixes:
		if not affix_on_board(a):
			continue
		parts.append(affix_label(a))
	return "　".join(parts)


## 战场单位「此刻生效的字段」—— 与卡面 `affixes` 的差别：
## ① 上场之后已经不起作用的字段根本不进来（R118：交换 / 幻影，见 `affix_on_board()`）——
##    它的消费者是**战场徽标**与**悬停列表**，两处都在讲「这个单位此刻有什么」；
## ② 疾行看**场上剩余行动轮数**（`acts_left`）—— **不要求卡面自带这个字段**（R135 改）：
##    判据是「此刻还能不能多打一轮」，因为双动还有两个**不写在卡面上**的来源；
## ③ 护盾用掉了就不显示（`shield` 传 false）。
func active_affixes(acts_left: int, shield: bool) -> Array[String]:
	var out: Array[String] = []
	for a in affixes:
		if not affix_on_board(a):
			continue    # R118：交换 / 幻影 —— 上场后已无作用，不进战场徽标
		if a == "护盾" and not shield:
			continue    # 护盾已用掉 → 不再显示
		if a == "疾行":
			continue    # 疾行不在这趟里判，见下面（判据是场上实况而不是卡面）
		out.append(a)
	# 疾行（R135 改判据）：从「**卡面有没有这个字段**」改成「**此刻还能不能多打一轮**」。
	# 原因：双动有两个**不写在卡面上**的来源 —— 效果卡「哈气」（所属阵营整方生效）
	# 与场上的赫利俄斯（只给量产型俄倪厄）。按卡面判的话，这两类单位身上
	# **一个徽标都没有**，玩家看不出「它这回合能打两次」。
	# 而「能打两次」正是**看卡面看不出来的隐藏状态**（与冰封 / 护盾同性质），必须常驻可见。
	if acts_left > 1:
		out.append("疾行")
	return out
