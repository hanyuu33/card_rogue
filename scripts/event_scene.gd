extends Control
## 事件界面（肉鸽版）—— 由地图节点类型 / 事件子类型决定：
##   * rest  休息处：恢复 25% 最大生命（向上取整，不超过上限）；
##            另有「烤肉」选项：获得事件道具「烤肉」（进入 Boss 战时自动消耗
##            并回复 25% 最大生命）。持有烤肉时不能再选，消耗后可再次烤制。
##   * event + treasure 宝箱：支付 5 生命获得一组卡牌奖励（选 1 张入卡组），或跳过；
##   * event + whisper  鸭鸭低语：获得事件道具「鸭之低语」，或放弃；
##   * event + struggle 挣扎：失去 21 点生命，将一张「金属龙」加入卡组，或离开；
##   * event + gaze     鸭之凝视：获得事件道具「一袋米抗几楼」，或放弃；
##   * event + pear     鸭梨山大（第二层专属）：获得事件道具「鸭梨」，或放弃；
##   * event + bluefish 蓝色大肥鱼（第二层专属）：把一张「鲸鱼之怒」加入卡组，或放弃；
##   * event + gaze     鸭之凝视（**第二层**）：获得事件道具「一袋米抗几楼」，或放弃；
##   * event + arcane   奥秘之泉（第一层专属）：获得道具「奥秘护符」（每回合第一张效果牌费用 -1），
##                      或「喝下泉水」从随机 3 张效果 / 技能牌中选 1 张加入卡组（也可什么都不拿）；
##   * event + oblivion 遗忘之泉（**全层通用**）：从卡组中删一张卡，或直接离开；
##   * chest  宝箱层（第六层）：开启后获得 1 个随机奖励道具（不与已拥有的重复）。
## 生命保存在 RunState（跨战斗保留的最大/当前双值）。
##
## 插图与背景走 assets/ui/ 的可替换图片（详见 assets/ui/图片命名说明.txt）：
##   event_<事件>.png 插图（标题下方） / bg_<事件>.png 整屏背景；
##   事件 = rest / treasure / whisper / struggle / gaze / pear / bluefish / relic_chest。
## 缺图时回退内置绘制（所有事件共用的篝火动画 / 深灰底色）。

const WHISPER_ID := 6010
const RICE_ID := 6012             # 一袋米抗几楼（鸭之凝视事件道具）
const PEAR_ID := 6019             # 鸭梨（鸭梨山大事件道具）
const HERO_CARD_ID := 9023        # 英雄（绝赞五换一的奖励卡）
const HERO_TRADE_NEED := 5        # 绝赞五换一：要交出 5 张**不同名**的卡
const STRUGGLE_CARD_ID := 9018    # 金属龙（事件卡牌，不可奖励获取）
const STRUGGLE_LIFE := 21         # 挣扎代价：失去的生命
const WHALE_CARD_ID := 9050       # 鲸鱼之怒（蓝色大肥鱼事件的奖励卡，不可奖励获取）
const ARCANE_CHARM_ID := 6020     # 奥秘护符（奥秘之泉事件给予；奖励池也能正常获得）

const WHISPER_DESC := """深处的鸭鸣在你耳畔回荡，绕梁不散……
获得「鸭之低语」：你将不再能控制自己接下来的前进方向
（每一步都由系统随机决定）；
但每个回合开始时，你会随机获得一种强化——
本回合费用 +1 / 本回合造成的伤害 +1 / 本回合多抽 1 张卡。"""

const WHISPER_TAKEN_DESC := """低语已经住进了你的脑海。
从今往后，前路不再由你选择——命运会替你走完剩下的路。"""

const GAZE_DESC := """一只巨大的鸭眼自虚空中睁开，死死盯着你。
它不说话，只是看着——看得你后背发凉，手里莫名多了一袋米。
获得「一袋米抗几楼」：每回合第一次受到伤害后，抽 1 张卡，
且本回合内你的技能（法术）造成的伤害 +1。
也可以别过头去，假装没看见。"""

const GAZE_TAKEN_DESC := """那只眼睛还在看着你。
米袋沉甸甸地压在肩头——被注视的感觉，从此挥之不去。"""

const PEAR_DESC := """不知从哪儿滚来一堆鸭梨，一颗一颗，把你压得喘不过气。
压力，也是一种力量——只要你还扛得住。
获得「鸭梨」：此后每次你的 HP 受到伤害，最大生命 +1（只提高上限，不回复生命）。
也可以把梨推开，假装自己毫无压力。"""

const PEAR_TAKEN_DESC := """肩上那座鸭梨山，你已经背起来了。
往后每一次受伤，都会让你更「强大」一点——
只是那点强大，补不回已经失去的血。"""

const BLUEFISH_DESC := """一条通体蓝色的大肥鱼搁浅在岸边，肚皮一起一伏，像还在做梦。
它翻了个身，从嘴里吐出一枚亮晶晶的东西——
「鲸鱼之怒」：1 费技能，造成 11 点伤害，
随后可从弃牌堆选 2 张卡回到手牌；用掉之后本场战斗里不再出现。
要不要把它捡起来？"""

const BLUEFISH_TAKEN_DESC := """大肥鱼心满意足地打了个嗝，翻着肚皮漂远了。
「鲸鱼之怒」已经躺进你的卡组——什么时候用它，就看你了。"""

const CHEST_LAYER_DESC := """这一层堆满了落满灰尘的宝箱。
每个宝箱里都躺着一件道具——开启它，带走其中一件。"""

const HERO_DESC := """一块巨大的告示牌立在路中央，上面龙飞凤舞地写着五个大字：绝赞五换一！
交出卡组里 5 张**不同名**的卡（随机挑 5 种，每种各 1 张），
就能换回一位「英雄」——5 费 5 力 25 血，只是它上场时，
你必须额外丢弃 4 张手牌作为代价。
卡组里凑不出 5 种不同的卡时，这笔买卖做不成，只能转身离开。"""

const HERO_TAKEN_DESC := """告示牌上的字迹已经淡去。
被换走的 5 张卡再也要不回来了——但那位英雄，已经站在你的队伍里。"""

const ARCANE_DESC := """泉眼深处浮着一枚古老的护符，水面映出的星空明明不属于这片天空。
选择1 · 获取护符：获得道具「奥秘护符」——
每回合你的第一张效果牌费用 -1（已拥有时不再重复给予）。
选择2 · 喝下泉水：从随机 3 张效果 / 技能牌中选一张加入卡组
（稀有度概率与普通卡牌奖励一致，也可以一张都不选，转身离开）。"""

const ARCANE_CHARM_TAKEN_DESC := """护符已经贴着心口，泉水的星光在指尖回落。
从今往后，每个回合的第一张效果牌都会轻上一分。"""

const OBLIVION_DESC := """泉水不映星光，也不照人脸——你把脸凑近，连卡组的模样都在水里淡去。
选择遗忘：从卡组中挑一张卡，永久删除它（不打算删的话也可以就此离开）。
（这一眼看过之后，泉水便再也不会为你重绘任何东西。）"""

const OBLIVION_DONE_DESC := """什么意思都没有的那张脸，又浮了上来——
卡组里少了些什么，可你再也想不起那是什么了。"""

const STRUGGLE_DESC := """体内的血液在翻涌，某种东西正挣扎着想要破体而出……
若你愿意献出生命，它会听见你——
失去 21 点生命，将一张「金属龙」加入你的卡组；
也可以按住这股躁动，转身离开。"""

const STRUGGLE_TAKEN_DESC := """「这就是为了胜利我的挣扎。」
金属巨兽破体而出，臣服于你——「金属龙」已加入卡组。"""

func _rest_desc() -> String:
	## 休息处文案：回复百分比按当前难度档位走（0 / 1 档 = 40%，2 档 = 25%）。
	return """前路的战斗还在等着你。
在篝火旁休息，恢复 %d%% 最大生命；
也可以烤一块肉带在身上，留到 Boss 战前享用。
（两样只能挑一样——选完这一处就到头了。）""" % int(round(RunState.rest_pct() * 100.0))

var _font: SystemFont
var sfx: Sfx
var _rested := false          # 是否已休息（休息后按钮变「继续」）
var _gained := 0              # 本次实际回复量
var _whisper_taken := false   # 鸭鸭低语：是否已收下道具
var _gaze_taken := false      # 鸭之凝视：是否已收下道具
var _pear_taken := false      # 鸭梨山大：是否已收下道具
var _bluefish_taken := false  # 蓝色大肥鱼：是否已收下「鲸鱼之怒」
var _chest_opened := false    # 宝箱层：是否已开箱
var _chest_relic := -1        # 宝箱层：开出的道具 id（-1 = 未开 / 已无货）
var _struggled := false       # 挣扎：是否已接受（失去生命换金属龙）
var _hero_traded := false     # 绝赞五换一：是否已交易（删 5 张换英雄）
var _hero_removed: Array = [] # 绝赞五换一：本次被换走的卡（[{id,name}]）
var _bbq_taken := false       # 烤肉：本次是否已在休息处烤好（获得道具）
var _arcane_charm_taken := false  # 奥秘之泉：是否已收下道具「奥秘护符」
var _arcane_drunk := false    # 奥秘之泉：是否已选择「喝下泉水」（选卡去了卡牌奖励界面）
var _oblivion_done := false   # 遗忘之泉：是否已经遗忘过一张卡（或已选择去删卡）

@onready var event_name: Label = $Center/EventName
@onready var desc: Label = $Center/Desc
@onready var hp_label: Label = $Center/HPLabel
@onready var rest_btn: Button = $Center/RestBtn
@onready var bbq_btn: Button = $Center/BBQBtn
@onready var leave_btn: Button = $Center/LeaveBtn
@onready var result_label: Label = $Center/ResultLabel


func _is_event_node() -> bool:
	return RunState.run_active and str(RunState.pending_node.get("type", "")) == "event"


func _is_chest_layer() -> bool:
	## 宝箱层（第六层）：地图节点类型为 chest，整层都是宝箱。
	return RunState.run_active and str(RunState.pending_node.get("type", "")) == "chest"


func _is_whisper() -> bool:
	return _is_event_node() and RunState.pending_event == "whisper"


func _is_gaze() -> bool:
	return _is_event_node() and RunState.pending_event == "gaze"


func _is_pear() -> bool:
	## 鸭梨山大（第二层专属事件）：获得事件道具「鸭梨」。
	return _is_event_node() and RunState.pending_event == "pear"


func _is_bluefish() -> bool:
	## 蓝色大肥鱼（第二层专属事件）：可将一张「鲸鱼之怒」（9050）加入卡组。
	return _is_event_node() and RunState.pending_event == "bluefish"


func _is_hero() -> bool:
	## 绝赞五换一（第二层专属）：随机删 5 张不同名的卡 → 得一张「英雄」（9023）。
	return _is_event_node() and RunState.pending_event == "hero"


func _is_arcane() -> bool:
	## 奥秘之泉（第一层专属）：获得道具「奥秘护符」/ 或者喝泉水抽 3 张效果·技能牌选 1。
	return _is_event_node() and RunState.pending_event == "arcane"


func _is_oblivion() -> bool:
	## 遗忘之泉（全层通用事件）：从卡组删一张卡，或离开。
	return _is_event_node() and RunState.pending_event == "oblivion"


func _is_struggle() -> bool:
	return _is_event_node() and RunState.pending_event == "struggle"


func _is_relic_chest() -> bool:
	## 宝箱层开箱：节点类型 chest，或（演示参数）事件节点 + pending_event。
	return _is_chest_layer() \
			or (_is_event_node() and RunState.pending_event == "relic_chest")


func _is_treasure() -> bool:
	## 卡牌宝箱（支付 5 生命换一组卡牌奖励）：事件节点中未被其它子类型认领的情况。
	return _is_event_node() and not _is_whisper() and not _is_struggle() \
			and not _is_gaze() and not _is_pear() and not _is_hero() \
			and not _is_bluefish() and not _is_relic_chest() \
			and not _is_arcane() and not _is_oblivion()


func _kind() -> String:
	## 当前事件对应的图片名后缀（与 assets/ui/ 的 event_/bg_ 文件名一一对应）。
	if _is_relic_chest():
		return "relic_chest"
	if _is_whisper():
		return "whisper"
	if _is_gaze():
		return "gaze"
	if _is_pear():
		return "pear"
	if _is_hero():
		return "hero"
	if _is_arcane():
		return "arcane"
	if _is_oblivion():
		return "oblivion"
	if _is_bluefish():
		return "bluefish"
	if _is_struggle():
		return "struggle"
	if _is_treasure():
		return "treasure"
	return "rest"


func _apply_ui_assets() -> void:
	## 插图 / 背景：assets/ui/event_<kind>.png 与 bg_<kind>.png，缺图则回退内置绘制。
	## 内置篝火在所有事件界面都显示（与旧版一致）；有自定义插图时才隐藏。
	var kind := _kind()
	var campfire: Control = $Campfire
	campfire.visible = true
	var pic := UiAssets.event_pic(kind)
	if pic != null:
		campfire.visible = false   # 有自定义插图时不再叠内置篝火
		var tr := TextureRect.new()
		tr.name = "EventPic"
		tr.texture = pic
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.anchor_left = 0.5
		tr.anchor_right = 0.5
		tr.offset_left = -160.0
		tr.offset_right = 160.0
		tr.offset_top = 116.0
		tr.offset_bottom = 356.0
		add_child(tr)
	var bg := UiAssets.event_bg(kind)
	if bg != null:
		var trb := TextureRect.new()
		trb.name = "EventBG"
		trb.texture = bg
		trb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		trb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trb.anchor_left = 0.0
		trb.anchor_top = 0.0
		trb.anchor_right = 1.0
		trb.anchor_bottom = 1.0
		trb.offset_left = 0.0
		trb.offset_top = 0.0
		trb.offset_right = 0.0
		trb.offset_bottom = 0.0
		add_child(trb)
		move_child(trb, 0)                              # 压到最底层
		($BG as ColorRect).color = Color(0, 0, 0, 0)    # 让位给自定义背景


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	sfx = Sfx.new()
	add_child(sfx)
	# 牌库任何时候都可以查看（无论在哪个界面）
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	# 演示参数：--dmg N 先扣 N 点生命，方便截图/试玩验证休息效果
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dmg" and i + 1 < args.size():
			RunState.take_damage(maxi(0, int(args[i + 1])))
		if args[i] == "--rested":   # 演示：直接呈现休息后的状态（截图验证）
			_gained = RunState.rest()
			_rested = true
		if args[i] == "--treasure":  # 演示：伪装 run 宝箱节点（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "treasure"
		if args[i] == "--whisper":  # 演示：伪装 run 鸭鸭低语事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "whisper"
		if args[i] == "--struggle":  # 演示：伪装 run 挣扎事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "struggle"
		if args[i] == "--gaze":  # 演示：伪装 run 鸭之凝视事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "gaze"
		if args[i] == "--pear":  # 演示：伪装 run 鸭梨山大事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "pear"
		if args[i] == "--bluefish":  # 演示：伪装 run 蓝色大肥鱼事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "bluefish"
		if args[i] == "--hero":  # 演示：伪装 run 绝赞五换一（卡组 6 种不同名，可交易）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "hero"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
		if args[i] == "--herolow":  # 演示：卡组只有 2 种不同名 → 只能退出事件
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "hero"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002]
		if args[i] == "--herodone":  # 演示：交易完成后的状态（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "hero"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
			var hd := RunState.trade_five_for_one(CardRepo.load_json())
			_hero_traded = true
			_hero_removed = hd.get("removed", [])
		if args[i] == "--struggledone":  # 演示：伪装 run 挣扎事件 + 已接受状态（截图验证新文案）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "struggle"
			RunState.hp = 50
			_struggled = true
		if args[i] == "--arcane":  # 演示：伪装 run 奥秘之泉事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "arcane"
		if args[i] == "--oblivion":  # 演示：伪装 run 遗忘之泉事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "oblivion"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
		if args[i] == "--chest":  # 演示：伪装 run 宝箱层节点（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "chest"}
		if args[i] == "--bbq":  # 演示：已在休息处烤好肉（截图验证取走后的状态）
			RunState.gain_relic(RunState.BARBECUE_RELIC_ID)
			_bbq_taken = true
	bbq_btn.visible = false   # 「烤肉」只在休息处出现，事件节点隐藏
	if _is_whisper():
		event_name.text = "鸭鸭低语"
		desc.text = WHISPER_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		if RunState.has_relic(WHISPER_ID):
			_whisper_taken = true
			rest_btn.text = "继续"
			$Center/LeaveBtn.text = "已获得"
			$Center/LeaveBtn.disabled = true
			desc.text = WHISPER_TAKEN_DESC
			result_label.text = "你已经听见过低语了——前路仍由命运决定。"
			result_label.add_theme_color_override("font_color", Color("a86ad8"))
		else:
			rest_btn.text = "获得「鸭之低语」"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "放弃（不受低语影响）"
			result_label.text = ""
	elif _is_gaze():
		event_name.text = "鸭之凝视"
		desc.text = GAZE_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		if RunState.has_relic(RICE_ID):
			_gaze_taken = true
			rest_btn.text = "继续"
			$Center/LeaveBtn.text = "已获得"
			$Center/LeaveBtn.disabled = true
			desc.text = GAZE_TAKEN_DESC
			result_label.text = "那袋米你已经扛在肩上了——鸭眼仍在注视，却不再给你更多。"
			result_label.add_theme_color_override("font_color", Color("d7a54a"))
		else:
			rest_btn.text = "获得「一袋米抗几楼」"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "别过头去（放弃）"
			result_label.text = ""
	elif _is_pear():
		event_name.text = "鸭 梨 山 大"
		desc.text = PEAR_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		if RunState.has_relic(PEAR_ID):
			_pear_taken = true
			rest_btn.text = "继续"
			$Center/LeaveBtn.text = "已获得"
			$Center/LeaveBtn.disabled = true
			desc.text = PEAR_TAKEN_DESC
			result_label.text = "鸭梨已经背在肩上了——往后的每一次受伤，都会让你更「强大」一点。"
			result_label.add_theme_color_override("font_color", Color("8a9a2f"))
		else:
			rest_btn.text = "获得「鸭梨」"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "把梨推开（放弃）"
			result_label.text = ""
	elif _is_bluefish():
		event_name.text = "蓝 色 大 肥 鱼"
		desc.text = BLUEFISH_TAKEN_DESC if _bluefish_taken else BLUEFISH_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		if _bluefish_taken:
			rest_btn.text = "继续"
			$Center/LeaveBtn.text = "已获得"
			$Center/LeaveBtn.disabled = true
			result_label.text = "「鲸鱼之怒」已加入卡组——用掉之后本场战斗里不再出现。"
			result_label.add_theme_color_override("font_color", Color("1f5fbf"))
		else:
			rest_btn.text = "收下「鲸鱼之怒」（加入卡组）"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "不捡（放弃）"
			result_label.text = ""
	elif _is_hero():
		event_name.text = "绝赞五换一"
		desc.text = HERO_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		if _hero_traded:
			rest_btn.text = "继续"
			$Center/LeaveBtn.text = "已完成"
			$Center/LeaveBtn.disabled = true
			desc.text = HERO_TAKEN_DESC
			result_label.text = "交易完成：「英雄」已加入卡组（换走 %d 张）" % _hero_removed.size()
			result_label.add_theme_color_override("font_color", Color("b8860b"))
		else:
			var repo_h := CardRepo.load_json()
			var kinds_h: int = RunState.deck_distinct_names(repo_h)
			if RunState.can_trade_five(repo_h):
				rest_btn.text = "换！交出 5 张不同名的卡，获得「英雄」"
				rest_btn.disabled = false
				$Center/LeaveBtn.text = "不换（退出事件）"
				result_label.text = "卡组现有 %d 种不同的卡——够换。" % kinds_h
				result_label.add_theme_color_override("font_color", Color("1b5e20"))
			else:
				# 卡组不足 5 种不同名 → 只能退出事件
				rest_btn.text = "凑不出 %d 种不同的卡" % HERO_TRADE_NEED
				rest_btn.disabled = true
				$Center/LeaveBtn.text = "退出事件"
				result_label.text = "卡组只有 %d 种不同的卡，这笔买卖做不成（只能退出）。" % kinds_h
				result_label.add_theme_color_override("font_color", Color("9a968c"))
	elif _is_arcane():
		_setup_arcane()
	elif _is_oblivion():
		event_name.text = "遗 忘 之 泉"
		desc.text = OBLIVION_DONE_DESC if _oblivion_done else OBLIVION_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		if _oblivion_done:
			rest_btn.text = "继续"
			$Center/LeaveBtn.text = "已完成"
			$Center/LeaveBtn.disabled = true
			result_label.text = "你已经在泉里遗忘过一张卡了。"
			result_label.add_theme_color_override("font_color", Color("5a6a8a"))
		else:
			rest_btn.text = "遗忘：从卡组中选择一张卡删除"
			rest_btn.disabled = RunState.deck_ids.is_empty()
			$Center/LeaveBtn.text = "离开（不删卡）"
			result_label.text = ""
	elif _is_relic_chest():
		event_name.text = "宝 箱 层"
		desc.text = CHEST_LAYER_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		rest_btn.text = "开启宝箱（获得 1 个随机奖励道具）"
		rest_btn.disabled = false
		$Center/LeaveBtn.text = "空手离开"
		result_label.text = ""
	elif _is_treasure():
		event_name.text = "宝  箱"
		desc.text = "路旁放着一只落满灰尘的宝箱……\n支付 5 生命打开它，获得一组卡牌奖励（选 1 张加入卡组）；\n也可以转身离开，分文不取。"
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		rest_btn.text = "支付 5 生命，打开宝箱"
		rest_btn.disabled = RunState.hp <= 5   # 至少保留 1 点生命
		$Center/LeaveBtn.text = "跳过（不支付生命）"
		result_label.text = ""
	elif _is_struggle():
		event_name.text = "挣  扎"
		desc.text = STRUGGLE_TAKEN_DESC if _struggled else STRUGGLE_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		rest_btn.text = "继续" if _struggled else "接受挣扎（失去 %d 生命，获得「金属龙」）" % STRUGGLE_LIFE
		rest_btn.disabled = (not _struggled) and RunState.hp <= STRUGGLE_LIFE   # 至少保留 1 点生命
		$Center/LeaveBtn.text = "已完成" if _struggled else "转身离开（保持现状）"
		result_label.text = ""
	else:
		# 休息处：休息 与 烤肉 两个选项（烤肉是新增选项）
		bbq_btn.visible = true
		event_name.text = "休息处"
		desc.text = _rest_desc()
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
	$Center/LeaveBtn.pressed.connect(func(): _ui_leave())
	rest_btn.pressed.connect(func(): _ui_main())
	bbq_btn.pressed.connect(func(): _ui_bbq())
	_apply_ui_assets()
	_refresh()
	_fit_center()   # 布局就位后先校准一次
	_fit_center.call_deferred()   # 字体异步就位后最小尺寸可能再变 → 延迟一帧补一次
	# 回放模式：自动执行下一条事件决策（R46）
	if ReplayLog.playing:
		var rt := Timer.new()
		rt.wait_time = 0.5
		rt.timeout.connect(_replay_tick)
		add_child(rt)
		rt.start()
	# 命令行 -- --screenshot：打开后自动截图退出（视觉验证用）
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_event.png"))
			get_tree().quit())
		add_child(t)
		t.start()


func _redraw() -> void:
	## 文案变化后的统一出口：先重排中间一列，再重绘。
	_fit_center()
	queue_redraw()


func _fit_center() -> void:
	## 中间一列按内容实际高度排布：默认位置不变；放不下时先收紧间距、藏起空的结果行，
	## 再整体上移（上不越过插图下沿约 356），保证「离开 / 继续前进」这类末位选项永远完整可见。
	var c: VBoxContainer = $Center
	var vh: float = get_viewport_rect().size.y
	result_label.visible = result_label.text != ""
	var top_floor := 360.0
	var bottom := vh - 10.0
	var h := 0.0
	for sep in [12, 8, 5]:
		c.add_theme_constant_override("separation", sep)
		h = c.get_combined_minimum_size().y
		if top_floor + h <= bottom:
			break
	var top: float = clampf(bottom - h, top_floor, vh * 0.5 + 60.0)
	c.offset_top = top - vh * 0.5
	c.offset_bottom = c.offset_top + h


func _on_main() -> void:
	## 主按钮：宝箱 → 支付 5 生命后转交卡牌奖励；鸭鸭低语 / 鸭之凝视 → 收下事件道具；
	## 宝箱层 → 开箱获得 1 个随机奖励道具；休息 → 休息（或休息后离开）。
	ReplayLog.ev("event_main")   # 录像：事件主选项
	sfx.play("click")
	if _is_whisper():
		if _whisper_taken:
			_on_leave()
			return
		RunState.gain_relic(WHISPER_ID)
		_whisper_taken = true
		var rel := RelicRepo.load_json().get_relic(WHISPER_ID)
		rest_btn.text = "继续"
		$Center/LeaveBtn.text = "已获得"
		$Center/LeaveBtn.disabled = true
		desc.text = WHISPER_TAKEN_DESC
		result_label.text = "「鸭之低语」已加入道具栏：%s" % (rel.desc if rel != null else "")
		result_label.add_theme_color_override("font_color", Color("a86ad8"))
		_redraw()
		return
	if _is_gaze():
		if _gaze_taken:
			_on_leave()
			return
		RunState.gain_relic(RICE_ID)
		_gaze_taken = true
		var rel_g := RelicRepo.load_json().get_relic(RICE_ID)
		rest_btn.text = "继续"
		$Center/LeaveBtn.text = "已获得"
		$Center/LeaveBtn.disabled = true
		desc.text = GAZE_TAKEN_DESC
		result_label.text = "「一袋米抗几楼」已加入道具栏：%s" \
				% (rel_g.desc if rel_g != null else "")
		result_label.add_theme_color_override("font_color", Color("d7a54a"))
		_redraw()
		return
	if _is_pear():
		if _pear_taken:
			_on_leave()
			return
		RunState.gain_relic(PEAR_ID)
		_pear_taken = true
		var rel_p := RelicRepo.load_json().get_relic(PEAR_ID)
		rest_btn.text = "继续"
		$Center/LeaveBtn.text = "已获得"
		$Center/LeaveBtn.disabled = true
		desc.text = PEAR_TAKEN_DESC
		result_label.text = "「鸭梨」已加入道具栏：%s" % (rel_p.desc if rel_p != null else "")
		result_label.add_theme_color_override("font_color", Color("8a9a2f"))
		_redraw()
		return
	if _is_bluefish():
		if _bluefish_taken:
			_on_leave()
			return
		RunState.add_card(WHALE_CARD_ID)
		_bluefish_taken = true
		var wcard := CardRepo.load_json().get_card(WHALE_CARD_ID)
		var wname := wcard.card_name if wcard != null else "鲸鱼之怒"
		rest_btn.text = "继续"
		$Center/LeaveBtn.text = "已获得"
		$Center/LeaveBtn.disabled = true
		desc.text = BLUEFISH_TAKEN_DESC
		result_label.text = "「%s」已加入卡组：%s" % [wname,
				wcard.effect_text if wcard != null else ""]
		result_label.add_theme_color_override("font_color", Color("1f5fbf"))
		_redraw()
		return
	if _is_hero():
		if _hero_traded:
			_on_leave()
			return
		var repo_t := CardRepo.load_json()
		if not RunState.can_trade_five(repo_t):
			return    # 卡组不足 5 种不同名：按钮本就是禁用的，这里再兜一次
		var res: Dictionary = RunState.trade_five_for_one(repo_t)
		if not bool(res.get("ok", false)):
			return
		_hero_traded = true
		_hero_removed = res.get("removed", [])
		var names_t: Array[String] = []
		for r: Variant in _hero_removed:
			names_t.append(str((r as Dictionary).get("name", "?")))
		var hero_card := repo_t.get_card(HERO_CARD_ID)
		var hname := hero_card.card_name if hero_card != null else "英雄"
		rest_btn.text = "继续"
		$Center/LeaveBtn.text = "已完成"
		$Center/LeaveBtn.disabled = true
		desc.text = HERO_TAKEN_DESC
		result_label.text = "换走 %d 张（%s）——「%s」已加入卡组" % [
				_hero_removed.size(), "、".join(names_t), hname]
		result_label.add_theme_color_override("font_color", Color("b8860b"))
		_redraw()
		return
	if _is_arcane():
		if _arcane_charm_taken:
			_on_leave()
			return
		RunState.gain_relic(ARCANE_CHARM_ID)
		_arcane_charm_taken = true
		var rel_a := RelicRepo.load_json().get_relic(ARCANE_CHARM_ID)
		rest_btn.text = "继续（已戴护符）"
		rest_btn.disabled = true
		# R71：拿到护符**之后**仍然保留「喝下泉水」—— 这次点击只是把「拿护符」这一步用掉了，
		# 玩家还可以转向第二个选项。原代码在这里 `bbq_btn.visible = false` 直接把路堵死。
		bbq_btn.visible = true
		bbq_btn.text = "喝下泉水：随机 3 张效果 / 技能牌中选 1 张加入卡组"
		bbq_btn.disabled = false
		leave_btn.text = "离开（不要新的牌）"
		leave_btn.disabled = false
		desc.text = ARCANE_CHARM_TAKEN_DESC
		result_label.text = "「奥秘护符」已加入道具栏：%s（还可以喝泉水）" \
				% (rel_a.desc if rel_a != null else "")
		result_label.add_theme_color_override("font_color", Color("2f7fa8"))
		_redraw()
		return
	if _is_oblivion():
		if _oblivion_done:
			_on_leave()
			return
		if RunState.deck_ids.is_empty():
			return
		# 删卡由卡组编辑场景完成（RunState.pending_deck_edit 是它的待办标记）；
		# 事件节点在这里就算走完 —— 回地图后不会再被送回同一个事件。
		_oblivion_done = true
		RunState.complete_current()
		RunState.pending_deck_edit = "delete"
		get_tree().change_scene_to_file("res://scenes/deck_edit.tscn")
		return
	if _is_relic_chest():
		if _chest_opened:
			_on_leave()
			return
		_chest_opened = true
		_chest_relic = RunState.roll_reward_relic()
		rest_btn.text = "继续"
		$Center/LeaveBtn.text = "已开启"
		$Center/LeaveBtn.disabled = true
		if _chest_relic < 0:
			desc.text = "箱底只剩一层灰——奖励道具你已经全都拿到了。"
			result_label.text = "宝箱是空的（奖励道具已全部拥有）"
			result_label.add_theme_color_override("font_color", Color("9a968c"))
		else:
			RunState.gain_relic(_chest_relic)
			var rc := RelicRepo.load_json().get_relic(_chest_relic)
			var rname := rc.relic_name if rc != null else str(_chest_relic)
			desc.text = "箱盖吱呀一声打开——里面躺着一件道具。\n你把「%s」收进了道具栏。" % rname
			result_label.text = "开出道具「%s」：%s" % [rname,
					rc.desc if rc != null else ""]
			result_label.add_theme_color_override("font_color",
					rc.source_color() if rc != null else Color("d89a2e"))
		_redraw()
		return
	if _is_treasure():
		if RunState.hp <= 5:
			return
		RunState.take_damage(5)
		get_tree().change_scene_to_file("res://scenes/card_reward.tscn")
		return
	if _is_struggle():
		if _struggled:
			_on_leave()
			return
		if RunState.hp <= STRUGGLE_LIFE:
			return
		RunState.take_damage(STRUGGLE_LIFE)
		RunState.add_card(STRUGGLE_CARD_ID)
		_struggled = true
		var card := CardRepo.load_json().get_card(STRUGGLE_CARD_ID)
		var cname := card.card_name if card != null else "金属龙"
		desc.text = STRUGGLE_TAKEN_DESC
		hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
		rest_btn.text = "继续"
		$Center/LeaveBtn.text = "已完成"
		$Center/LeaveBtn.disabled = true
		result_label.text = "失去 %d 生命（当前 %d/%d）——「%s」已加入卡组" % [
				STRUGGLE_LIFE, RunState.hp, RunState.max_hp, cname]
		result_label.add_theme_color_override("font_color", Color("a44ad0"))
		_redraw()
		return
	if _rested or _bbq_taken:
		_on_leave()
		return
	_gained = RunState.rest()
	_rested = true
	rest_btn.disabled = false
	_refresh()
	_redraw()


func _setup_arcane() -> void:
	## 奥秘之泉的选项铺排（从 _ready 的分支里抽出来，好让回归能单独重跑）。
	## R71：**已经戴过奥秘护符也照样能「喝下泉水」** ——
	## 原来「已有护符」那条分支把 bbq_btn 一起 `visible = false` 了 → 玩家只能点「继续」，
	## 第二个选项形同虚设。护符不重复给，但「从 3 张效果/技能牌里选 1 张加入卡组」永远可用。
	event_name.text = "奥 秘 之 泉"
	hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
	bbq_btn.visible = true
	bbq_btn.text = "喝下泉水：随机 3 张效果 / 技能牌中选 1 张加入卡组"
	bbq_btn.disabled = false
	if RunState.has_relic(ARCANE_CHARM_ID):
		_arcane_charm_taken = true
		desc.text = ARCANE_CHARM_TAKEN_DESC
		rest_btn.text = "继续（已戴护符）"
		rest_btn.disabled = true
		leave_btn.text = "离开（不要新的牌）"
		leave_btn.disabled = false
		result_label.text = "「奥秘护符」你已经戴在身上了——不过泉水还是可以喝。"
		result_label.add_theme_color_override("font_color", Color("2f7fa8"))
	else:
		desc.text = ARCANE_DESC
		rest_btn.text = "获取护符：获得道具「奥秘护符」"
		rest_btn.disabled = false
		leave_btn.text = "离开（两个都不要）"
		leave_btn.disabled = false
		result_label.text = ""


func _refresh() -> void:
	if _is_treasure() or _is_whisper() or _is_struggle() \
			or _is_gaze() or _is_pear() or _is_hero() or _is_bluefish() \
			or _is_relic_chest() or _is_arcane() or _is_oblivion():
		return
	hp_label.text = "当前生命 %d / 最大生命 %d" % [RunState.hp, RunState.max_hp]
	_refresh_bbq()
	# 需求：休息处二选一 —— 选过「休息」或「烤肉」任意一个，另一个就收起来
	if _rested or _bbq_taken:
		bbq_btn.visible = false
	leave_btn.text = "继续前进" if (_rested or _bbq_taken) else "离开（不休息）"
	var gain: int = RunState.rest_heal_amount()   # 按难度档位（0/1 档 40%、2 档 25%）
	if _rested:
		rest_btn.text = "继续"
		result_label.text = "篝火的温暖涌上心头……生命回复 +%d（当前 %d/%d）" % [
				_gained, RunState.hp, RunState.max_hp]
		result_label.add_theme_color_override("font_color", Color("1b5e20"))
	elif _bbq_taken:
		# 选过烤肉 → 本次休息处到此为止（不能再休息，只能继续前进）
		rest_btn.text = "继续"
		result_label.text = "「烤肉」已收进道具栏——进入 Boss 战时自动享用，回复 25% 最大生命。"
		result_label.add_theme_color_override("font_color", Color("d89a2e"))
	else:
		rest_btn.text = "在这里休息（回复 %d 生命）" % mini(gain, RunState.max_hp - RunState.hp)
		result_label.text = ""


func _refresh_bbq() -> void:
	## 烤肉选项状态：持有「烤肉」时不可再选；被 Boss 战消耗掉后即可再次烤制。
	if RunState.has_relic(RunState.BARBECUE_RELIC_ID):
		bbq_btn.text = "已持有「烤肉」（Boss 战时自动消耗）"
		bbq_btn.disabled = true
	else:
		bbq_btn.text = "烤肉（获得「烤肉」，留到 Boss 战）"
		bbq_btn.disabled = false


func _on_bbq() -> void:
	## 休息处「烤肉」：获得事件道具「烤肉」（进入 Boss 战时自动消耗 → 回复 25% 生命）。
	## 奥秘之泉：这一路是「选择2 · 喝下泉水」→ 去卡牌奖励界面（限定效果 / 技能）。
	ReplayLog.ev("event_bbq")   # 录像：烤肉 / 喝泉水
	sfx.play("click")
	if _is_arcane():
		# R71：判断「能不能喝泉水」用**独立的 `_arcane_drunk`**，
		# 不用 `_arcane_charm_taken` —— 后者只是「护符已到手」，
		# 拿它当闸门会让「已戴护符的玩家」连泉水都喝不到（等于第二个选项失效）。
		if _arcane_drunk:
			return
		_arcane_drunk = true
		RunState.reward_type = "normal"
		RunState.reward_context = "event"
		RunState.reward_kinds = ["效果", "技能"]
		get_tree().change_scene_to_file("res://scenes/card_reward.tscn")
		return
	if RunState.has_relic(RunState.BARBECUE_RELIC_ID):
		return
	RunState.gain_relic(RunState.BARBECUE_RELIC_ID)
	_bbq_taken = true
	_refresh()
	_redraw()


func _ui_main() -> void:
	if ReplayLog.playing:
		return   # 回放模式：选项由驱动执行
	_on_main()


func _ui_bbq() -> void:
	if ReplayLog.playing:
		return
	_on_bbq()


func _ui_leave() -> void:
	if ReplayLog.playing:
		return
	_on_leave()


func _replay_tick() -> void:
	## 回放模式：按录像执行事件选项。
	if not ReplayLog.playing:
		return
	var e := ReplayLog.peek()
	if e.is_empty():
		return
	match str(e.get("k", "")):
		"event_main":
			ReplayLog.advance()
			_on_main()
		"event_bbq":
			ReplayLog.advance()
			_on_bbq()
		"event_leave":
			ReplayLog.advance()
			_on_leave()


func _on_leave() -> void:
	ReplayLog.ev("event_leave")   # 录像：离开事件
	if RunState.run_active:
		RunState.complete_current()   # 事件/休息完成 → 节点标记完成
		get_tree().change_scene_to_file("res://scenes/map.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
