extends SceneTree
## 只读探针：独行 9189 打出时的**事件序列**与左侧显示口径（2026-11-12 R625）
## 用户报障：「卡牌《独行》伤害显示不正常，实际打出伤害正常」。
## 本探针不改数据，只回答四个问题：
##   ① 打出时引擎到底 emit 了哪些 action（有没有 fx_impact / 有没有专属事件）；
##   ② fx_impact 里带的 amount 是不是实际伤害（7 + 累积）；
##   ③ spell_now() 对独行返回什么（左栏 / 拖到场上报不报数）；
##   ④ 手卡里没有盟友/工事时是否也正常（落空分支）。
## 跑法：Godot --headless --path . --script res://tools/_r622_probe.gd

const LONE_ID := 9189


func _mk_lone() -> CardData:
	var c := CardData.new()
	c.id = LONE_ID
	c.card_name = "独行"
	c.kind = "技能"
	c.cost = 2
	c.rarity = 0
	c.target_mode = "unit"
	return c


func _mk_ally(id: int, nm: String, pw: int, hp: int) -> CardData:
	var c := CardData.new()
	c.id = id
	c.card_name = nm
	c.kind = "盟友"
	c.cost = 3
	c.power = pw
	c.health = hp
	c.attack_range = 1
	c.move_speed = 1
	return c


func _mk_foe() -> CardData:
	var c := CardData.new()
	c.id = 9001
	c.card_name = "鸭子骑士"
	c.kind = "盟友"
	c.cost = 6
	c.power = 5
	c.health = 40
	c.attack_range = 1
	c.move_speed = 1
	return c


func _run(tag: String, with_ally: bool) -> void:
	var st := FieldState.new([], 20, 20, -1, "探针", false)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	eng.start_game(4242)
	var events: Array = []
	eng.action.connect(func(kind: String, data: Dictionary):
		var brief := ""
		if kind == "fx_impact":
			brief = "cell=%s amount=%s source=%s" % [str(data.get("cell", "")),
					str(data.get("amount", "")), str(data.get("source", ""))]
		elif kind == "stun_blow":
			brief = "cell=%s amount=%s" % [str(data.get("cell", "")),
					str(data.get("amount", ""))]
		elif kind == "spell":
			brief = str(data.get("detail", ""))
		events.append("%s  %s" % [kind, brief]))
	var foe := eng.state.place(_mk_foe(), Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	var hand: Array[CardData] = []
	var lone := _mk_lone()
	hand.append(lone)
	if with_ally:
		hand.append(_mk_ally(8003, "农民", 3, 8))
		hand.append(_mk_ally(8004, "工事兵", 2, 6))
	eng.state.hand = hand
	eng.state.energy = 9
	print("\n===== %s =====" % tag)
	print("[before] spell_now = %s" % str(eng.spell_now(lone)))
	print("[before] cost = %d  hand = %s" % [eng.cost_of(lone),
			str(eng.state.hand.map(func(c): return c.card_name))])
	var hp0: int = foe.health if foe != null else -1
	var cell := Vector2i(2, 0)
	var res: String = eng.use_spell(0, cell)
	print("[use_spell] -> %s" % res)
	var foe2 := eng.state.unit_at(cell)
	print("[after] foe hp %d -> %d" % [hp0, foe2.health if foe2 != null else -1])
	print("[after] lone_dmg_bonus = %d  lone_str_bonus = %d"
			% [lone.lone_dmg_bonus, lone.lone_str_bonus])
	print("[after] spell_now = %s" % str(eng.spell_now(lone)))
	print("[after] hand = %s" % str(eng.state.hand.map(func(c): return c.card_name)))
	print("[events] %d 条" % events.size())
	for e in events:
		print("   · " + str(e))


func _init() -> void:
	_run("有盟友可吞（8 血 / 3 力）", true)
	_run("手卡无盟友/工事（落空）", false)
	quit()
