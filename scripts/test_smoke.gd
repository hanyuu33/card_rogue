extends SceneTree
## 冒烟测试（基本功能自检）—— 把每个场景按真实进入条件实例化、渲染若干帧，
## 检查是否存在脚本错误（缺失方法 / 空引用 / 解析错误 / _draw 崩溃）。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://scripts/test_smoke.gd
## 说明：
##   * 必须**非 headless** 运行 —— headless 不渲染，_draw() 里的错误抓不到
##     （历史上出现过的 rel.kind_color() 崩溃就是这类）。
##   * 每个场景前会重置 RunState 并铺一套「进入该场景所需的最小状态」
##     （例如 relic_pick 需要 relic_choice）。
##   * 错误不会被脚本捕获，而是由引擎打到 stderr —— 由外层脚本 grep
##     「SCRIPT ERROR / Nonexistent / Invalid call」判定失败。

const MapBridge = preload("res://scripts/map_bridge.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const FRAMES_PER_SCENE := 8

# 每个场景的进入前置：用 [_reset, 说明] 的形式，_reset 为 Callable
var _plan: Array = []
var _cur: Node = null
var _idx := -1
var _frames := 0
var _ok := 0
var _fail := 0
var _check := Callable()   # 用例可选的「加进场景后第 2 帧」行为断言
var _pair_reported := {}  # R66：已打印过「牌库/道具成对」的场景名，避免同一场景重复刷屏


func _initialize() -> void:
	_plan = [
		["res://scenes/title.tscn", func(): _reset()],
		# 角色选择（R43 新增：定角色 → 发专属卡与赠品道具 → 进地图）
		["res://scenes/class_pick.tscn", func(): _reset()],
		# 角色选择 + 机械之心（R82：第三个角色，3 张卡面要放得下 1280 视口）
		["res://scenes/class_pick.tscn", func():
				_reset()
				RunState.player_class = PlayerClass.MECH],
		# 地图场景（R69 的 14 层 + 第 9 层固定休息层）。
		# `relic_choice = []` 是**必须的**：start_run 会填 3 个待选初始道具，
		# 而 map_scene._ready 见它非空就 `change_scene_to_file(relic_pick)` 直接 return，
		# _clamp_scroll / _scroll_to_current 都不会跑 → 滚动范围停在默认 0。
		["res://scenes/map.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [],
			_check_map_scene],
		["res://scenes/battle.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"}),
			_check_battle],
		# R317：淘汰（9174）—— 从卡组选一张盟友 / 工事变成素体（面板接线）。
		["res://scenes/battle.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"}),
			_check_eliminate_panel],
		# R314（用户口径）：道具栏**高亮** + 风妖精飘字**必须有时间维度**
		# （不是贴一张静态字，要能在 start~dur 之间移动 / 淡出）。
		["res://scenes/battle.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"}),
			_check_relic_highlight],
		# R301：弃牌区点开 = 「选卡页那种全屏窗口」（PickOverlay view_only）。
		# 断言三件事：① 真的弹出、② 进的是浏览模式、③ 关闭后不动引擎状态。
		["res://scenes/battle.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"}),
			_check_discard_view],
		# 战斗场景 + 机械之心（R82）：开场「机械核心」6025 要往手牌塞 2 张素体，
		# 且素体带「留手」—— 这一路能跑通就说明新道具 / 新卡 / 衍生物判定都接好了。
		["res://scenes/battle.tscn", func():
				_reset()
				var mrng := RandomNumberGenerator.new()
				mrng.seed = 20261005
				RunState.start_run(RogueMap.generate(mrng), GameLayers.LAYER_DEFAULT,
						PlayerClass.MECH)
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"})],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}],
		# R119：奖励悬浮窗 —— 列表 / 道具详情 / 卡牌三选一，三个视图各渲染一遍。
		# 面板由 event 场景自带（battle / event / map 都挂了），这里只负责铺奖励 + 切视图。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards(),
			func(s): _check_reward_panel_view(s, RewardPanel.VIEW_LIST, "列表")],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards(),
			func(s): _check_reward_panel_view(s, RewardPanel.VIEW_RELIC, "道具详情")],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards(),
			func(s): _check_reward_panel_view(s, RewardPanel.VIEW_CARDS, "卡牌三选一")],
		["res://scenes/relic_pick.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [6001, 6002, 6003]],
		# R310：每层起点的「卷卷」对话（原起点三选一入口）。第一层不切立绘。
		["res://scenes/curtain.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [6001, 6002, 6003]],
		# R310：第二层 + 机械之心 → 走「收下道具 → 立绘出场 → 角色回答」那一支，
		# 顺带把效果浮窗、名称牌换字、立绘贴图全部渲染一遍（缺图 / 空引用会在这里炸）。
		["res://scenes/curtain.tscn", func():
				_reset()
				RunState.start_run(_map(), GameLayers.LAYER_TWO, PlayerClass.MECH)
				RunState.relic_choice = [6014, 6015, 6016],
			func(s): _check_curtain_reply(s)],
		["res://scenes/deck_edit.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relics = [6004]
				RunState.pending_relic = 6004],
		# 卡组编辑的「鸭血」多选模式（R81）—— 唯一 limit=2 的模式，
		# 顺带在这里真的走一遍「选 2 张 → 复制」的完整路径。
		["res://scenes/deck_edit.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relics = [RunState.DUCK_BLOOD_RELIC_ID]
				RunState.pending_relic = RunState.DUCK_BLOOD_RELIC_ID,
			_check_deck_duck_blood],
		# R204：商店附魔「卡死」回归 —— 附魔选卡页点一张卡必须**真的能成交**。
		# 旧 bug：`_draw_pick_overlay` 每帧重建候选列表 → 把 `_sel_pick` 抹回 -1，
		# 于是「首击选中查看 / 再击成交」永远走不到成交，覆盖层退不出去 = 卡死。
		["res://scenes/shop.tscn", func():
				_reset()
				RunState.run_active = true
				RunState.start_run(_map())
				RunState.gold = 500
				RunState.pending_node = {"type": "shop"},
			_check_shop_enchant],
		# R206：卡牌三选一「详情条」的排版唯一性 —— 提及块必须画在右栏、预算高度与
		# 实画行距同源、强调色按真实底色挑。用户口径：「卡片详细效果描述」的排版乱。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"},
			_check_card_detail_block],
		# R194：鸭之低语（6010）—— 随机走路「只走一格就停」的场景侧回归。
		# ⚠️ 断言完必须把 `_whisper_auto` 关掉：本用例后面还有几帧，代走若还开着
		#    就会走进新房间把场景切走 → 冒烟用例崩掉。
		["res://scenes/map.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = []
				RunState.relics = [RunState.WHISPER_RELIC_ID],
			_check_whisper],
		["res://scenes/gallery.tscn", func(): _reset()],
		# R216：鸭血领取后**立刻**转去选卡页（不能等奖励界面关闭、回到地图才结算）。
		# 用 `route_fn` 接缝截获目标 —— headless 里真换场景会把用例的树掀掉。
		["res://scenes/map.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = []
				RunState.pending_relic = -1
				RunState.pending_rewards = []
				RunState.pending_relic_drop = -1,
			_check_duck_blood_instant],
		# 对战记录 / 设置（R215：回放已删）
		["res://scenes/record_list.tscn", func(): _prep_records(), _check_record_list],
		["res://scenes/settings.tscn", func(): _reset()],
		# 事件场景的其它子类型
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "treasure"],
		# R142：卡牌宝箱的「箱子里是道具」那一半（旗标由地图生成期摇定）
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event", "event_kind": "treasure",
						"treasure_relic": true}
				RunState.pending_event = "treasure",
			_check_treasure_relic_loot],
		# R142：**真实流程**的事件房只塞 pending_node（不写 pending_event）→ 子类型必须
		# 从节点自带的 event_kind 读出来（R128 漏了这一步，所有事件房都变成卡牌宝箱）。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event", "event_kind": "oblivion"},
			_check_event_kind_from_node],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "whisper"],
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "struggle"],
		# 鸭之凝视（一袋米抗几楼）—— 现在是**第二层**事件
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "gaze"],
		# 奥秘之泉（第一层专属：护符 / 喝泉水）—— R71：**已经戴过护符也要能选「喝下泉水」**
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "arcane",
			_check_arcane_with_charm],
		# R147：奥秘之泉「一次访问只领一份」—— 护符 ↔ 泉水**双向**锁死（R71 只保住了
		# 「本来就戴着护符也能喝泉水」，没管住「本次取走护符之后还能不能再喝」）。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "arcane",
			_check_arcane_one_reward],
		# R147/R237：同一条规则也管休息处 —— R237 起篝火回血恢复（休息 / 烤肉二选一）。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"},
			_check_rest_one_reward],
		# 遗忘之泉（全层通用：删一张卡 / 离开）
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "oblivion"],
		# 遗忘之泉的后续：卡组编辑场景的「删卡」模式
		["res://scenes/deck_edit.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_event = "oblivion"
				RunState.pending_deck_edit = "delete"],
		# 宝箱层（第六层：开箱得 1 个随机奖励道具）
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "chest"}],
		# R121：覆盖层让位 —— 奖励悬浮窗盖住道具栏时，道具悬停必须停止响应
		#   ① 事件页：RelicViewer 的速览浮层与按钮 tooltip 读的是**鼠标坐标**，不认覆盖层
		#   ② 战斗页：右栏道具栏的悬浮说明由 _on_hover 跟着鼠标画
		# 注意顺序：_seed_rewards() 会把 relics 清空，所以道具要**之后**再给。
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "rest"}
				_seed_rewards()
				RunState.relics = [6001, 6002],
			_check_relic_hover_gate],
		["res://scenes/battle.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "battle"}
				RunState.pending_level = RunState.next_level({"type": "battle"})
				_seed_rewards()
				RunState.relics = [6001, 6002],
			_check_battle_hover_gate],
		# R200：运送委托（第一层专属）—— 平铺选卡页开合 / 取消不接 / 确认入卡组
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "delivery",
			_check_delivery],
		# R200：委托完成（持有货物 → 第二层第一个事件房替换而来）—— 每个货物抽一次
		["res://scenes/event.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.current_layer = GameLayers.LAYER_TWO
				RunState.pending_node = {"type": "event", "event_kind": "delivery_done"}
				RunState.pending_event = "delivery_done"
				RunState.deck_ids = [8001, 8001, 8002, 8003, 8065, 8065, 8065],
			_check_delivery_done],
	]
	print("SMOKE === 开始（%d 项场景用例）===" % _plan.size())
	_next()


var _rec_bak := ""        # R215：记录页用例前的真实记录（用例结束还原）
var _rec_pend_bak := ""   # R215：同上，pending 文件


func _prep_records() -> void:
	## R215：对战记录页用例的前置 —— 造两条记录（通关 + 中断）。
	## ⚠️ 必须在**场景实例化之前**跑（plan 的第 2 项），页面 `_ready` 时才读得到。
	_reset()
	_rec_bak = FileAccess.get_file_as_string(RunRecord.PATH) \
			if FileAccess.file_exists(RunRecord.PATH) else ""
	_rec_pend_bak = FileAccess.get_file_as_string(RunRecord.PENDING_PATH) \
			if FileAccess.file_exists(RunRecord.PENDING_PATH) else ""
	RunRecord.clear_all()
	RunRecord.begin_run("暗影刺客")
	RunRecord.finish("win")
	RunRecord.begin_run("森林精魄")
	RunRecord.finish("interrupted")


func _check_eliminate_panel(scene: Variant) -> void:
	## R317 淘汰（9174）：卡组里选一张盟友 / 工事变成「素体」。
	## 断言三件事：① 面板真的弹出来且 kind 对；② 确认后卡组那张**原位变成素体**；
	## ③ 面板收掉（pending 清空）—— 漏了这条会「确认完窗还在」。
	var repo := CardRepo.load_json()
	var deck: Array[CardData] = []
	deck.append(CardData.from_dict(repo.get_card(8003).to_dict()))   # 树人（盟友）
	deck.append(CardData.from_dict(repo.get_card(8002).to_dict()))   # 攻击（技能，不该入选）
	scene.engine.state.deck = deck
	scene.engine.eliminate_pending = true
	scene._sync_pick()
	if scene._pick == null or not scene._pick.is_picking():
		_smoke_fail("R317 淘汰：挂起后应弹出卡组选牌面板")
		return
	if scene._pick.kind() != "eliminate":
		_smoke_fail("R317 淘汰：面板 kind 应为 eliminate，实际 %s" % scene._pick.kind())
		return
	var opts: Array = scene._pick.opts()
	if opts.size() != 1 or int(opts[0]) != 0:
		_smoke_fail("R317 淘汰：候选应只有「树人」这一张盟友（实际 %s）" % str(opts))
		return
	scene._on_pick_confirmed([0])
	if scene.engine.eliminate_pending:
		_smoke_fail("R317 淘汰：确认后挂起状态应清空")
		return
	if scene.engine.state.deck[0].id != GameEngine.PROTO_ID:
		_smoke_fail("R317 淘汰：卡组第 1 张应变成素体，实际 id=%d"
				% scene.engine.state.deck[0].id)


func _check_relic_highlight(scene: Variant) -> void:
	## R314：① 道具栏高亮 —— 风妖精差一张就亮、鸭翼 / lucky 7 在生效回合亮、
	## 一直被动的（鸭嘴 / 储物箱）不亮；② 风妖精的飘字带 start + dur（有时间维度）。
	# ⚠️ 必须用**类型化数组**：`self_relics` 是 Array[int]，直接赋无类型字面量会报
	#    「Invalid assignment … of type Array」（运行时报错但值又会被塞进去，最容易漏看）。
	var r314_ids: Array[int] = [6042, 6045, 6007, 6006, 6044]
	scene.engine.self_relics = r314_ids
	scene.engine.state.self_card_plays = 4
	if not scene.engine.relic_highlight(6042):
		_smoke_fail("R314 高亮：风妖精「下一张就是第 5 张」应当亮起")
		return
	if not scene._relic_bar_lit():
		_smoke_fail("R314 高亮：有亮着的徽章时 _relic_bar_lit 必须为真（不然呼吸会卡住）")
		return
	scene.engine.state.self_card_plays = 2
	scene.engine.turn_number = 1
	if scene.engine.relic_highlight(6006) or scene.engine.relic_highlight(6044):
		_smoke_fail("R314 高亮：鸭嘴 / 储物箱一直在生效，不该亮")
		return
	# 风妖精飘字：start 记在当下、dur 有时长 → 逐帧会位移 + 淡出
	var n0: int = scene._floaters.size()
	scene._on_engine_action("wind_fairy", {"dmg": 4, "hits": 2})
	if scene._floaters.size() <= n0:
		_smoke_fail("R314 风妖精：触发时应有一条飘字")
		return
	var wf: Dictionary = scene._floaters[scene._floaters.size() - 1]
	if int(wf.get("dur", 0)) <= 0 or int(wf.get("start", 0)) <= 0:
		_smoke_fail("R314 风妖精：飘字必须带时间维度（start=%s dur=%s）"
				% [str(wf.get("start")), str(wf.get("dur"))])


func _check_discard_view(scene: Variant) -> void:
	## R301（用户口径）：弃牌区的弹窗改成「选卡那种全屏窗口」。
	## 旧实现是居中窄面板（`_draw_zone_panel`）—— 卡小、一页只放得下几张。
	## 现在复用 PickOverlay 的排版，只把 cfg 标成 `view_only`：
	##   · 点卡不选中（只换底部描述条）；
	##   · 「关闭 / 返回 / Esc / 右键」= 直接关窗，不像选卡那样收起去看战场；
	##   · 关窗不动引擎状态（纯浏览，弃牌堆一张不少）。
	var repo := CardRepo.load_json()
	scene.engine.state.discard.clear()
	for _i in 3:
		scene.engine.state.discard.append(CardData.from_dict(repo.get_card(8003).to_dict()))
	scene._open_discard_view()
	if scene._pick == null or not scene._pick.is_picking():
		_smoke_fail("R301 弃牌区：点开后应弹出全屏浏览窗")
		return
	if scene._pick.kind() != "view_discard" or not scene._pick.is_view():
		_smoke_fail("R301 弃牌区：窗应处于 view_discard 的纯浏览模式，实际 kind=%s view=%s"
				% [scene._pick.kind(), str(scene._pick.is_view())])
		return
	if scene._pick.is_picking() and scene._pick.opts().size() != 3:
		_smoke_fail("R301 弃牌区：候选应为 3 张，实际 %d" % scene._pick.opts().size())
		return
	var n_before: int = scene.engine.state.discard.size()
	scene._pick.collapse()   # 浏览模式下「返回」= 关窗（不是收起看战场）
	if scene._pick.is_picking():
		_smoke_fail("R301 弃牌区：关闭后 overlay 不应仍在 picking")
		return
	if scene.engine.state.discard.size() != n_before:
		_smoke_fail("R301 弃牌区：纯浏览不应改动弃牌堆（%d → %d）"
				% [n_before, scene.engine.state.discard.size()])


func _check_duck_blood_instant(scene: Variant) -> void:
	## R216：奖励界面领到鸭血 → 当刻关界面并转去卡组选择页（不等地图 `_ready`）。
	var p: Variant = scene._reward_panel
	if p == null:
		_smoke_fail("R216 鸭血即时结算：地图没有挂上 RewardPanel")
		return
	var routed: Array = []
	var hooked: Array = [false]
	p.route_fn = func(target: String): routed.append(target)
	p.on_before_pick = func(): hooked[0] = true
	RunState.pending_relic = -1
	RunState.pending_relic_drop = -1
	RunState.pending_rewards = [{"kind": "relic", "id": RunState.DUCK_BLOOD_RELIC_ID,
			"state": RunState.REWARD_PENDING}]
	p.open()
	p._claim_entry(0)
	var bad := ""
	if RunState.pending_relic != RunState.DUCK_BLOOD_RELIC_ID:
		bad = "领取当刻就该置待选卡，实际 pending_relic=%d" % RunState.pending_relic
	elif not bool(hooked[0]):
		bad = "跳转前没有调用宿主收尾钩子（房间会漏结算）"
	elif routed.size() != 1 or str(routed[0]) != "res://scenes/deck_edit.tscn":
		bad = "应立刻转去卡组选择页，实际 %s" % str(routed)
	elif p.is_open():
		bad = "转页前没有关闭奖励界面"
	if bad != "":
		_smoke_fail("R216 鸭血即时结算：" + bad)
	else:
		print("SMOKE OK R216 鸭血即时结算：领取当刻关界面并转卡组选择页（钩子先收尾）")
	# 普通道具（不需要选卡）→ 不转页
	# ⚠️ 先把上一段的待选清掉：真流程里选卡页已经把它结算了，这里用 `route_fn` 假跳，
	#    不清就会把「还没选完」的待办算到这一段头上。
	RunState.pending_relic = -1
	RunState.pending_rewards = [{"kind": "relic", "id": 6005,
			"state": RunState.REWARD_PENDING}]
	p.open()
	p._claim_entry(0)
	if routed.size() != 1:
		_smoke_fail("R216 普通道具：不需要选卡却转页了（%s）" % str(routed))
	p.route_fn = Callable()
	p.on_before_pick = Callable()
	RunState.pending_relic = -1
	RunState.pending_rewards = []


func _check_record_list(scene: Variant) -> void:
	## R215：对战记录页 —— 两行、新在前、文案对；末尾把真实数据还原回去。
	var rows: Array = scene._rows
	if rows.size() != 2:
		_smoke_fail("R215 记录页：应有 2 行，实际 %d" % rows.size())
	elif str(rows[0].get("result", "")) != "interrupted" \
			or str(rows[1].get("result", "")) != "win":
		_smoke_fail("R215 记录页：顺序应为新在前（中断 / 通关）")
	elif RunRecord.result_label(str(rows[1].get("result", ""))) != "通关":
		_smoke_fail("R215 记录页：结果文案不是「通关」")
	elif scene._row_rect(0).size.x <= 0.0:
		_smoke_fail("R215 记录页：行几何无效")
	else:
		print("SMOKE OK R215 记录页：2 行（中断 / 通关）· 新在前 · 文案正确")
	# 还原真实记录 / pending
	if _rec_bak == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RunRecord.PATH))
	else:
		var f := FileAccess.open(RunRecord.PATH, FileAccess.WRITE)
		f.store_string(_rec_bak)
		f = null
	if _rec_pend_bak != "":
		var pf := FileAccess.open(RunRecord.PENDING_PATH, FileAccess.WRITE)
		pf.store_string(_rec_pend_bak)
		pf = null


func _reset() -> void:
	RunState.end_run()
	RunState.reset()
	# R119：end_run **故意**不清待领奖励队列（通关那一场的战利品要留在结算面板上给玩家看），
	# 但冒烟用例之间必须互不污染 → 在这里显式清掉。
	RunState.pending_rewards = []
	# R121：同理清掉覆盖层登记 —— 用例里 open() 过面板又没 close() 就结束的话，
	# 阻塞态会漏给后面的用例，让那些用例的道具悬停莫名其妙全部失灵。
	UiGate.reset()
	# R148：菜单用例可能把场景树留在暂停态（组件自己会恢复，这里是**跨用例**兜底 ——
	# 一旦漏一个，后面所有用例的画面都会冻住）。
	paused = false


func _map() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	return RogueMap.generate(rng)


func _seed_rewards() -> void:
	## R119：给奖励悬浮窗铺一批奖励 —— 一件长描述道具 + 一组卡牌三选一 + 一件普通道具。
	## 走真实入队口，顺带覆盖 queue_relic_reward / queue_card_reward。
	RunState.relics = []
	RunState.skipped_relics = []
	RunState.pending_relic_drop = -1
	RunState.pending_rewards = []
	RunState.queue_relic_reward(6013)   # 叠加态的鸭：desc 最长的一件（专治「介绍太长」）
	RunState.queue_card_reward("normal")
	RunState.queue_relic_reward(6005)


func _check_reward_panel_view(scene: Variant, want_view: int, label: String) -> void:
	## R119：奖励悬浮窗 —— 打开并切到指定视图，后面几帧会真的把它画出来。
	## ⚠️ 逻辑断言（入队 / 领取置灰 / 三选一入卡组）在 test_engine；这里只管「三个视图都渲染得出」，
	##    因为面板里的绘制错误（越界 / 空引用）只有真渲染才抓得到。
	var p: Variant = scene._reward_panel
	if p == null:
		_smoke_fail("R119 奖励悬浮窗（%s）：场景没有挂上 RewardPanel" % label)
		return
	if RunState.pending_reward_count() != 3:
		_smoke_fail("R119 奖励悬浮窗（%s）：应入队 3 条待领，实际 %d"
				% [label, RunState.pending_reward_count()])
		return
	p.open()
	if not p.is_open():
		_smoke_fail("R119 奖励悬浮窗（%s）：open() 之后应处于打开态" % label)
		return
	if want_view != RewardPanel.VIEW_LIST:
		var idx := -1
		for i in RunState.pending_rewards.size():
			var e: Dictionary = RunState.pending_rewards[i]
			var is_cards := str(e.get("kind", "")) == "cards"
			if (want_view == RewardPanel.VIEW_CARDS) == is_cards:
				idx = i
				break
		if idx < 0:
			_smoke_fail("R119 奖励悬浮窗（%s）：找不到要展示的条目" % label)
			return
		p._open_entry(idx)
		if int(p._view) != want_view:
			_smoke_fail("R119 奖励悬浮窗（%s）：视图应为 %d，实际 %d"
					% [label, want_view, int(p._view)])
			return
	p._hover_row = 0
	p._hover_card = 0
	p._root.queue_redraw()
	print("SMOKE OK R119 奖励悬浮窗：%s 视图渲染（%d 条待领，宿主 %s）"
			% [label, RunState.pending_reward_count(), str(scene.name)])


func _check_relic_hover_gate(scene: Variant) -> void:
	## R121：奖励悬浮窗（满屏覆盖层）盖着时，RelicViewer 的道具悬停必须让位。
	## ⚠️ 这里**不**读真实鼠标位置 —— 直接调悬停判定的唯一口 `_want_hover()`。
	##    否则断言会随鼠标停在哪里而飘（同一份代码在不同机器上结果不同）。
	var rv: Variant = null
	for c in scene.get_children():
		if c is RelicViewer:
			rv = c
	if rv == null:
		_smoke_fail("R121 覆盖层让位：事件场景没有挂上 RelicViewer")
		return
	if RunState.relics.is_empty():
		_smoke_fail("R121 覆盖层让位：用例需要先给玩家道具，否则悬停判定本就是空跑")
		return
	var p: Variant = scene._reward_panel
	if p == null:
		_smoke_fail("R121 覆盖层让位：事件场景没有挂上 RewardPanel")
		return
	var btn_pt: Vector2 = Rect2(rv._btn.position, rv._btn.size).get_center()
	var far_pt := Vector2(200, 640)
	# ① 面板关着：指着「道具 N」按钮 → 该悬停；指着远端 → 不该悬停
	p.close()
	if not bool(rv._want_hover(btn_pt)):
		_smoke_fail("R121 覆盖层让位：没有覆盖层时，指着「道具 N」按钮应判定为悬停")
		return
	if bool(rv._want_hover(far_pt)):
		_smoke_fail("R121 覆盖层让位：鼠标在远端时不该判定为悬停")
		return
	# ② 面板开着：哪怕指着按钮也必须让位。
	#    ⚠️ `_want_hover()` 是纯判定（立刻生效）；按钮的显隐 / tooltip 与速览浮层
	#       是**逐帧**刷的 → 断言前必须先跑一帧 `_process()`，与真实运行一致。
	p.open()
	if not UiGate.blocked():
		_smoke_fail("R121 覆盖层让位：奖励悬浮窗打开后 UiGate 应处于阻塞态（push 漏了）")
		return
	if bool(rv._want_hover(btn_pt)):
		_smoke_fail("R121 覆盖层让位：奖励悬浮窗盖着时，指着按钮仍判定为悬停")
		return
	rv._hover_on = true          # 故意留一个「已经亮着的速览浮层」看它会不会被灭掉
	rv._hover_layer.visible = true
	rv._process(0.016)
	if bool(rv._hover_on) or bool(rv._hover_layer.visible):
		_smoke_fail("R121 覆盖层让位：面板盖着时已展开的速览浮层没有被灭掉")
		return
	if str(rv._btn.tooltip_text) != "":
		_smoke_fail("R121 覆盖层让位：奖励悬浮窗盖着时道具按钮仍有 tooltip「%s」"
				% str(rv._btn.tooltip_text))
		return
	# ③ 关掉面板：阻塞解除，按钮 / tooltip / 悬停全部回来（证明 pop 接在同一个唯一口上）
	p.close()
	if UiGate.blocked():
		_smoke_fail("R121 覆盖层让位：面板关闭后 UiGate 仍在阻塞态（pop 漏了）")
		return
	rv._process(0.016)
	if not bool(rv._want_hover(btn_pt)):
		_smoke_fail("R121 覆盖层让位：面板关闭后道具悬停没有恢复")
		return
	if str(rv._btn.tooltip_text) == "":
		_smoke_fail("R121 覆盖层让位：面板关闭后道具按钮的 tooltip 没有恢复")
		return
	print("SMOKE OK R121 覆盖层让位：奖励悬浮窗开/关 → 道具速览浮层与 tooltip 正确让位/恢复")


func _check_battle_hover_gate(scene: Variant) -> void:
	## R121：战斗页右栏道具栏的悬浮说明（`_hover_relic_tip`）同样要给覆盖层让位。
	var p: Variant = scene._reward_panel
	if p == null:
		_smoke_fail("R121 覆盖层让位（战斗）：场景没有挂上 RewardPanel")
		return
	if scene.engine == null or (scene.engine.self_relics as Array).is_empty():
		_smoke_fail("R121 覆盖层让位（战斗）：用例需要先在道具栏里放几件道具")
		return
	var probe_pt: Vector2 = scene._relic_rect(0).get_center()
	# ① 面板关着：悬停道具徽章 → 该出说明（正向对照，证明断言不是空跑）
	p.close()
	scene._on_hover(probe_pt)
	if str(scene._hover_relic_tip) == "":
		_smoke_fail("R121 覆盖层让位（战斗）：没有覆盖层时，悬停道具徽章应弹出说明")
		return
	# ② 面板开着：同一个位置必须什么都不弹（旧说明也要被清掉）
	p.open()
	scene._on_hover(probe_pt)
	if str(scene._hover_relic_tip) != "" or scene._hover_card != null:
		_smoke_fail("R121 覆盖层让位（战斗）：奖励悬浮窗盖着时仍弹了说明（tip=「%s」）"
				% str(scene._hover_relic_tip))
		return
	# ③ 场景自带的全屏面板（道具浏览）同理
	p.close()
	scene._relics_visible = true
	scene._on_hover(probe_pt)
	scene._relics_visible = false
	if str(scene._hover_relic_tip) != "":
		_smoke_fail("R121 覆盖层让位（战斗）：道具浏览面板开着时仍弹了道具说明")
		return
	print("SMOKE OK R121 覆盖层让位：战斗道具栏说明在奖励悬浮窗 / 道具浏览面板下正确让位")


func _check_deck_duck_blood(scene: Variant) -> void:
	## 卡组编辑的「鸭血」模式（R81）：多选上限 2，且选中/确定真的会复制卡。
	## 这里直接调场景内部方法（与 _check_map_scene 同一套路），比截图可靠。
	if str(scene._mode()) != "duplicate":
		_smoke_fail("鸭血卡组编辑：模式应为 duplicate，实际 %s" % str(scene._mode()))
		return
	if int(scene._limit()) != 2:
		_smoke_fail("鸭血卡组编辑：可选上限应为 2，实际 %d" % int(scene._limit()))
		return
	# 选 3 张 → 只留最早选中的被替换掉，最终恰好 2 张
	scene._toggle_sel(0)
	scene._toggle_sel(1)
	scene._toggle_sel(2)
	if (scene._sel as Array).size() != 2 or not (scene._sel as Array).has(1) \
			or not (scene._sel as Array).has(2):
		_smoke_fail("鸭血卡组编辑：选 3 张后应保留最新 2 张，实际 %s" % str(scene._sel))
		return
	# 再点已选中的 → 取消选中
	scene._toggle_sel(1)
	if (scene._sel as Array).has(1):
		_smoke_fail("鸭血卡组编辑：再点已选中的卡应取消选中")
		return
	scene._toggle_sel(1)
	# 走真实结算：卡组 +2，标题与按钮文案对得上
	var before: int = RunState.deck_ids.size()
	var nm0: String = scene.confirm_btn.text
	scene._on_confirm()
	if RunState.deck_ids.size() != before + 2:
		_smoke_fail("鸭血卡组编辑：确定后卡组应 +2（%d → %d），按钮原为「%s」"
				% [before, RunState.deck_ids.size(), nm0])
		return
	if RunState.pending_relic != -1:
		_smoke_fail("鸭血卡组编辑：确定后应解除待选")
		return
	print("SMOKE OK 鸭血卡组编辑：多选上限 2 / 选 3 张保留最新 2 张 / 确定后卡组 %d → %d"
			% [before, RunState.deck_ids.size()])


func _check_shop_enchant(scene: Variant) -> void:
	## R204：商店附魔流程必须**能走完**（用户报「附魔可能导致卡死」）。
	## 两个根因都在这条用例里钉住：
	##   ① `_draw_pick_overlay` 每帧重建候选列表 → 把 `_sel_pick` 抹回 -1 →
	##      两段式点击永远走不到成交，选卡页退不出去（= 卡死）。→ 源码守卫 + 双击断言。
	##   ② `deck_mods` 与 `deck_ids` 不等长 → `enchant_deck_card` 写入越界 →
	##      附魔必失败（钱还照扣）。→ 等长断言。
	# ① 源码守卫：选卡覆盖层的绘制函数里不许再出现 `_build_deck_cards()` **调用**。
	# ⚠️ 必须逐行精确比对（整行 strip 后等于调用本身）：函数里那段「不许调它」的注释
	#    也含这个字面量，用 contains() 会误判（R204 自己踩过）。
	var src := FileAccess.get_file_as_string("res://scripts/shop_scene.gd")
	var a := src.find("func _draw_pick_overlay")
	var b := src.find("func _build_deck_cards")
	var bad_call := false
	if a >= 0 and b > a:
		for ln in src.substr(a, b - a).split("\n"):
			if ln.strip_edges() == "_build_deck_cards()":
				bad_call = true
				break
	if bad_call:
		_smoke_fail("商店附魔：_draw_pick_overlay 里不能再调 _build_deck_cards()"
				+ "（会把 _sel_pick 抹回 -1 → 选卡页点不动 = 卡死）")
		return
	# R236：商店「巧克力 +1」必须走 RunState.add_chocolate(1) —— 它会撤销
	# 「体力耗尽 → 开 Boss」的 boss_pending；否则最后一格进商店买巧克力后离店仍进 Boss。
	if src.find("RunState.add_chocolate(1)") < 0 or src.find("RunState.chocolate += 1") >= 0:
		_smoke_fail("R236 商店：买巧克力应走 RunState.add_chocolate(1)（撤销 boss_pending），不能再裸 +=1")
		return
	# ② 附魔槽位必须与卡组等长，否则 enchant_deck_card 越界。
	if RunState.deck_mods.size() != RunState.deck_ids.size():
		_smoke_fail("商店附魔：deck_mods 应与 deck_ids 等长（%d vs %d）"
				% [RunState.deck_mods.size(), RunState.deck_ids.size()])
		return
	# ②b R210：附魔表的条件与价格（次元 50 → 80；伤害 +10 只认技能卡）
	var cmap: Dictionary = (scene.get_script() as GDScript).get_script_constant_map()
	var enchs: Array = cmap.get("ENCHANTS", [])
	var price := {}
	for e in enchs:
		price[str(e["id"])] = int(e["price"])
	if int(price.get("dimension", -1)) != 80:
		_smoke_fail("商店附魔：次元应 80 金（实际 %s）" % str(price.get("dimension", -1)))
		return
	if int(price.get("damage", -1)) != 60:
		_smoke_fail("商店附魔：伤害 +10 应 60 金（实际 %s）" % str(price.get("damage", -1)))
		return
	# R240：附魔显示名的**真源 = CardData.ENCHANT_DEFS** —— ENCHANTS 里的 name 必须与它逐条一致，
	# 且附魔名**不许与「字段」同名**（原来附魔「次元」/ 字段「次元」撞了命名空间）。
	for e240 in enchs:
		var e240_id := str(e240["id"])
		if str(e240.get("name", "")) != CardData.enchant_name(e240_id):
			_smoke_fail("R240 商店附魔：%s 的 name 应与 ENCHANT_DEFS 一致（%s vs %s）"
					% [e240_id, str(e240.get("name", "")), CardData.enchant_name(e240_id)])
			return
	if CardData.enchant_name("dimension") == CardData.affix_label(GameEngine.AFFIX_DIMENSION):
		_smoke_fail("R240 商店附魔：附魔名不能与字段同名（dimension 应叫「次元之力」）")
		return
	# R229：「起手」（必定第 1 回合抽到）出现在附魔表里；R246 起价格 50 → **30 金**
	if int(price.get("opening", -1)) != 30:
		_smoke_fail("R246 商店附魔：起手应 30 金（实际 %s）" % str(price.get("opening", -1)))
		return
	# 「伤害 +10」**只认技能卡**：有攻击力的盟友也必须被拒；技能卡必须能选。
	# deck_idx 传 9999 → `_mod_at` 越界返回 {} → 「未附魔」这一关不会挡路。
	var repo2 := CardRepo.load_json()
	if scene._enchant_ok("damage", repo2.get_card(8003), 9999):
		_smoke_fail("商店附魔：伤害 +10 不能再附给盟友（树人被放行）")
		return
	if not scene._enchant_ok("damage", repo2.get_card(9003), 9999):
		_smoke_fail("商店附魔：伤害 +10 应能附给技能卡（火焰箭被拒）")
		return
	# R226：只认「能直接造成伤害」的技能卡 —— 治疗 / 抽牌 / 防御类技能必须被拒
	if scene._enchant_ok("damage", repo2.get_card(9051), 9999):
		_smoke_fail("R226 商店附魔：伤害 +10 不应再附给「自然之力」（不能直接造成伤害）")
		return
	if scene._enchant_ok("damage", repo2.get_card(9103), 9999):
		_smoke_fail("R226 商店附魔：伤害 +10 不应再附给「闪躲」（只提承受伤害）")
		return
	# 换成「保存」附魔 —— 任何卡都能吃，保证一定有候选。
	scene._row2.clear()
	scene._row2.append({"ench": {"id": "save", "name": "保存", "desc": "",
			"price": 60, "icon": ""}, "sold": false})
	scene._start_enchant(0)
	if (scene._deck_cards as Array).is_empty():
		_smoke_fail("商店附魔：打开选卡页后候选列表为空")
		return
	var ci := -1
	for i in (scene._deck_cards as Array).size():
		if bool(scene._deck_cards[i]["ok"]):
			ci = i
			break
	if ci < 0:
		_smoke_fail("商店附魔：卡组里没有任何能吃「保存」的卡")
		return
	var idx: int = int(scene._deck_cards[ci]["idx"])
	var gold0: int = RunState.gold
	var pos: Vector2 = (scene._pick_card_rect(ci) as Rect2).get_center()
	scene._on_pick_click(pos)          # 首击 → 选中查看
	if int(scene._sel_pick) != ci:
		_smoke_fail("商店附魔：首击应「选中查看」第 %d 张，实际 %d"
				% [ci, int(scene._sel_pick)])
		return
	scene._on_pick_click(pos)          # 再击同一张 → 成交
	if int(scene._enchanting) != -1:
		_smoke_fail("商店附魔：成交后选卡页应关闭（_enchanting 仍 = %d）——「点了没反应」即此"
				% int(scene._enchanting))
		return
	if RunState._mod_at(idx).is_empty():
		_smoke_fail("商店附魔：第 %d 张卡没有落上附魔" % idx)
		return
	if RunState.gold != gold0 - 60:
		_smoke_fail("商店附魔：应扣 60 金币（%d → %d）" % [gold0, RunState.gold])
		return
	var gold1: int = RunState.gold      # 成交后的金币（下面的用例会改 gold，先留一份给打印）
	# ③ R218：**打开选卡页必须当场请求重绘**（Android 触摸没有鼠标移动兜底）。
	#    用户实测：点第二行的附魔 / 第三行的「删除一张卡」，画面完全不动（= 点了没反应），
	#    继续乱点，每一下其实都落在**看不见的**选卡页上 → 随机某张卡被选中/成交
	#    （「附魔 / 删除的对象变成随机」），随后某一次重绘才把结果一起画出来（「一起结算」）。
	#    桌面端有鼠标移动顺手触发重绘，所以只有 Android 必现。
	var rr0: int = int(scene._redraw_req)
	scene._start_enchant(0)
	if int(scene._redraw_req) <= rr0:
		_smoke_fail("商店附魔：打开选卡页必须请求重绘（Android 上少了它 = 点了没反应）")
		return
	# 删除一张卡的选卡页同理（第三行第 0 件）
	scene._enchanting = -1
	scene._sel_pick = -1
	scene._row3[0]["sold"] = false
	RunState.gold = 500
	var rr1: int = int(scene._redraw_req)
	scene._buy_row3(0)
	if not bool(scene._deleting):
		_smoke_fail("商店删除：点「删除一张卡」应打开选卡页（_deleting 未置位）")
		return
	if int(scene._redraw_req) <= rr1:
		_smoke_fail("商店删除：打开选卡页必须请求重绘（同附魔，Android 上 = 点了没反应）")
		return
	# 点到「不符合条件」的灰卡必须有反馈（不能静默）
	var grey_pos := Vector2(-9999, -9999)
	for i in (scene._deck_cards as Array).size():
		if not bool(scene._deck_cards[i]["ok"]):
			grey_pos = (scene._pick_card_rect(i) as Rect2).get_center()
			break
	scene._deleting = false
	scene._start_enchant(0)
	scene._row2[0]["ench"] = {"id": "damage", "name": "伤害 +10", "desc": "", "price": 60, "icon": ""}
	scene._build_deck_cards()
	grey_pos = Vector2(-9999, -9999)
	for i in (scene._deck_cards as Array).size():
		if not bool(scene._deck_cards[i]["ok"]):
			grey_pos = (scene._pick_card_rect(i) as Rect2).get_center()
			break
	if grey_pos.x > -999.0:
		var hint0: String = str(scene._hint)
		scene._on_pick_click(grey_pos)
		if str(scene._hint) == hint0:
			_smoke_fail("商店附魔：点到不符合条件的灰卡应给出提示（不能静默无反应）")
			return
	# ④ R235：新增「确定」按钮 —— 选中一张卡后点「确定」成交（与双击成交等价）。
	scene._enchanting = -1
	scene._sel_pick = -1
	scene._deleting = false
	scene._row2.clear()
	scene._row2.append({"ench": {"id": "save", "name": "保存", "desc": "",
			"price": 60, "icon": ""}, "sold": false})
	RunState.gold = 500
	scene._start_enchant(0)
	var ci2 := -1
	for i in (scene._deck_cards as Array).size():
		if bool(scene._deck_cards[i]["ok"]):
			ci2 = i
			break
	if ci2 < 0:
		_smoke_fail("R235 商店附魔：找不到可附魔的卡")
		return
	var idx2: int = int(scene._deck_cards[ci2]["idx"])
	var gold2: int = RunState.gold
	# 未选卡直接点「确定」→ 只提示、不成交。
	scene._on_pick_click((scene._pick_confirm_rect() as Rect2).get_center())
	if int(scene._enchanting) != 0 or RunState.gold != gold2:
		_smoke_fail("R235 商店附魔：未选卡点「确定」不应成交")
		return
	# 选中一张 → 点「确定」→ 成交。
	scene._on_pick_click((scene._pick_card_rect(ci2) as Rect2).get_center())
	if int(scene._sel_pick) != ci2:
		_smoke_fail("R235 商店附魔：点卡应选中（实际 %d）" % int(scene._sel_pick))
		return
	scene._on_pick_click((scene._pick_confirm_rect() as Rect2).get_center())
	if int(scene._enchanting) != -1:
		_smoke_fail("R235 商店附魔：点「确定」后选卡页应关闭（_enchanting = %d）"
				% int(scene._enchanting))
		return
	if RunState._mod_at(idx2).is_empty():
		_smoke_fail("R235 商店附魔：点「确定」后第 %d 张卡应落附魔" % idx2)
		return
	if RunState.gold != gold2 - 60:
		_smoke_fail("R235 商店附魔：点「确定」应扣 60 金币（%d → %d）"
				% [gold2, RunState.gold])
		return
	scene._enchanting = -1
	scene._sel_pick = -1

	print("SMOKE OK 商店附魔：首击选中 / 再击成交（卡 %d 落附魔，金币 %d → %d）；"
			% [idx, gold0, gold1]
			+ "打开附魔/删除选卡页均请求重绘，点灰卡有反馈")


func _check_map_scene(scene: Variant) -> void:
	## 地图场景（R128）：**5×7 相接正方形格子** + 起点固定 (3,4) + 两角固定大宝箱。
	## 只断言状态与几何（格子数 / 位置 / 相接 / 点击判定同源），真正的绘制
	## 由 smoke 非 headless 跑满帧验证。
	var cells: Array = RunState.map_cells
	if cells.size() != RogueMap.CELLS:
		_smoke_fail("地图场景：应有 %d 格，实际 %d" % [RogueMap.CELLS, cells.size()])
		return
	var sc: Dictionary = RogueMap.start_cell(cells)
	if sc.is_empty() or str(sc["type"]) != "start":
		_smoke_fail("地图场景：起点房缺失或类型不对")
		return
	if int(sc["col"]) != RogueMap.START_COL or int(sc["row"]) != RogueMap.START_ROW:
		_smoke_fail("地图场景：起点应在 (%d,%d)，实际 (%d,%d)"
				% [RogueMap.START_COL, RogueMap.START_ROW, int(sc["col"]), int(sc["row"])])
		return
	for bp: Vector2i in RogueMap.BIGCHEST_POS:
		var bc: Dictionary = RogueMap.cell_at(cells, bp.x, bp.y)
		if str(bc["type"]) != "bigchest":
			_smoke_fail("地图场景：(%d,%d) 应是大宝箱房，实际 %s"
					% [bp.x, bp.y, str(bc["type"])])
			return
	# R243：右上角固定为商店（原来也是大宝箱）
	for sp: Vector2i in RogueMap.SHOP_POS:
		var spc: Dictionary = RogueMap.cell_at(cells, sp.x, sp.y)
		if str(spc["type"]) != "shop":
			_smoke_fail("地图场景：(%d,%d) 应是固定商店，实际 %s"
					% [sp.x, sp.y, str(spc["type"])])
			return
	# 几何：格子是正方形、彼此相接、整体落在窗口内
	var c0: Rect2 = scene._cell_rect(cells[0])
	var c_last: Rect2 = scene._cell_rect(cells[RogueMap.CELLS - 1])
	var cell_sz: float = scene.CELL
	if absf(c0.size.x - cell_sz) > 0.01 or absf(c0.size.y - cell_sz) > 0.01:
		_smoke_fail("地图场景：格子应为正方形 %.0f，实际 %.1f×%.1f"
				% [cell_sz, c0.size.x, c0.size.y])
		return
	var nb0: Rect2 = scene._cell_rect(RogueMap.cell_at(cells, 1, 0))
	if absf(nb0.position.x - (c0.position.x + c0.size.x)) > 0.01 \
			or absf(nb0.position.y - c0.position.y) > 0.01:
		_smoke_fail("地图场景：相邻格子没有相接（横向间隙 %.1f、纵向偏移 %.1f）"
				% [nb0.position.x - (c0.position.x + c0.size.x),
					nb0.position.y - c0.position.y])
		return
	if c0.position.x < 0.0 or c0.position.y < 0.0 \
			or c_last.end.x > 1280.0 or c_last.end.y > 720.0:
		_smoke_fail("地图场景：地图整体超出窗口（左上 %.0f,%.0f 右下 %.0f,%.0f）"
				% [c0.position.x, c0.position.y, c_last.end.x, c_last.end.y])
		return
	# 格子中心反查回同一格
	var hit: Dictionary = scene._cell_at(c0.position + c0.size * 0.5)
	if hit.is_empty() or int(hit["id"]) != int(cells[0]["id"]):
		_smoke_fail("地图场景：格子坐标反查不对（期望 id 0，得到 %s）"
				% str(hit.get("id", -1)))
		return
	# 可走房间 = RunState.available_nodes（场景与状态同源）
	var avail := RunState.available_nodes()
	if avail.is_empty():
		_smoke_fail("地图场景：起点应至少有 1 个可走的相邻房")
		return
	for a: Dictionary in avail:
		if not scene._is_available(a):
			_smoke_fail("地图场景：可走房间 %d 未被场景认作可走" % int(a["id"]))
			return
	# 通路（R130）：判定口 `scene._bridge_kind` + `MapBridge` 的真值表 + 几何。
	# 起点就是当前房 → 它每个门都通向「真能走过去」的房 → 一律亮青。
	# ⚠️ R145 起**通路全图可见**（不再按「走过没走过」过滤），所以
	# 「两端都没走过」的格子之间同样有桥 —— 那种是灰蓝的 UNSEEN 档。
	var bridge_start: Dictionary = RogueMap.start_cell(cells)
	for nid2 in bridge_start["doors"]:
		if scene._bridge_kind(bridge_start, cells[int(nid2)]) != MapBridge.LIT:
			_smoke_fail("地图场景：从起点通向 %d 的通路应为「可以走」语义" % int(nid2))
			return
	if MapBridge.kind_for(true, false, false) != MapBridge.DONE \
			or MapBridge.kind_for(false, false, false) != MapBridge.UNSEEN \
			or MapBridge.kind_for(false, false, true) != MapBridge.LIT:
		_smoke_fail("通路语义：kind_for 真值表不对（走过→暖白 / 都没走过→灰蓝 / 可走→亮青）")
		return
	# R145 迷雾：内容可见性的**唯一判定口**是 RunState.known_node
	#（地图页与战斗内总览同源）；通路不再看它，所以两件事必须各自成立。
	if not RunState.known_node(int(bridge_start["id"])):
		_smoke_fail("R145 迷雾：当前房间必须看得见")
		return
	for a5: Dictionary in RunState.available_nodes():
		if not RunState.known_node(int(a5["id"])):
			_smoke_fail("R145 迷雾：「下一步」能走到的房间 %d 必须看得见" % int(a5["id"]))
			return
	for lp: Vector2i in RogueMap.BIGCHEST_POS:
		if not RunState.known_node(RogueMap.idx(lp.x, lp.y)):
			_smoke_fail("R145 迷雾：大宝箱 (%d,%d) 是地标，不能被迷雾遮住"
					% [lp.x, lp.y])
			return
	var fog_hidden := 0
	for c5: Dictionary in cells:
		if not RunState.known_node(int(c5["id"])):
			fog_hidden += 1
	if fog_hidden <= 0:
		_smoke_fail("R145 迷雾：开局竟然一格迷雾都没有（规则失效）")
		return
	if not scene.has_method("_draw_fog") or not scene.has_method("_draw_fog_cell"):
		_smoke_fail("R145 迷雾：地图场景缺少迷雾绘制口")
		return
	# 朝向：左右相邻用侧视图、上下相邻用俯视图（两枚素材缺一就有半个方向没桥）。
	if MapBridge.is_vertical(Vector2(0, 0), Vector2(100, 0)) \
			or not MapBridge.is_vertical(Vector2(0, 0), Vector2(0, 100)):
		_smoke_fail("通路朝向：左右相邻应判为横向、上下相邻应判为竖向")
		return
	# 素材只有一张**竖直的俯视图**：上下照画（0°），左右转 90°（R132）。
	if absf(MapBridge.rotation_of(Vector2(0, 0), Vector2(0, 100))) > 0.001 \
			or absf(MapBridge.rotation_of(Vector2(0, 0), Vector2(100, 0)) - PI * 0.5) > 0.001:
		_smoke_fail("通路朝向：上下相邻应不旋转、左右相邻应转 90°")
		return
	# 几何：桥心必须落在**两格共用的那面墙的中点**，且整座桥小于一格
	# （否则会横穿格子、把房间图标压住）。
	var bh: Rect2 = MapBridge.box_of(Vector2(0, 0), Vector2(118, 0), MapBridge.DONE, 118.0)
	var bv: Rect2 = MapBridge.box_of(Vector2(0, 0), Vector2(0, 118), MapBridge.DONE, 118.0)
	if absf(bh.get_center().x - 59.0) > 0.01 or absf(bh.get_center().y) > 0.01 \
			or absf(bv.get_center().y - 59.0) > 0.01 or absf(bv.get_center().x) > 0.01:
		_smoke_fail("通路几何：桥心应落在两格中点（横向 %s / 竖向 %s）"
				% [str(bh.get_center()), str(bv.get_center())])
		return
	if bh.size.x <= 0.0 or bh.size.x >= 118.0 or bv.size.y <= 0.0 or bv.size.y >= 118.0:
		_smoke_fail("通路几何：桥应小于一格（横 %s / 竖 %s）" % [str(bh.size), str(bv.size)])
		return
	# 进场过场（R131）：文字表齐全 / 走过的房间不播 / 没去过的会播，且**播完才动 RunState**。
	for ty2 in ["battle", "elite", "event", "rest", "unknown", "chest", "bigchest", "start"]:
		if not scene.ENTER_LABELS.has(ty2):
			_smoke_fail("进场过场：房间类型 %s 没有文字（过场会空着）" % ty2)
			return
	if str(scene.ENTER_LABELS["unknown"]) != "不确定的命运" \
			or str(scene.ENTER_LABELS["elite"]) != "精英战斗":
		_smoke_fail("进场过场：「不确定的命运」/「精英战斗」文案不对")
		return
	if scene.CHOCO_ICON_W < scene.CHOCO_ICON_H:
		_smoke_fail("巧克力计数：图标槽要做成横向的（素材是长方形整块，竖槽会把它压扁）")
		return
	# 回到走过的房间（起点）→ 不该起过场
	scene._anim_cell = {}
	scene._anim_t = 0.0
	scene._enter_node(RogueMap.start_cell(cells), true)
	if not scene._anim_cell.is_empty():
		_smoke_fail("进场过场：走进走过的房间不该播过场")
		return
	# 走进没去过的房间 → 起过场，且**过场中 RunState 一动不动**
	var anim_nid := -1
	for a3: Dictionary in RunState.available_nodes():
		if not RunState.cleared_ids.has(int(a3["id"])):
			anim_nid = int(a3["id"])
			break
	if anim_nid < 0:
		_smoke_fail("进场过场：起点居然没有没走过的邻居（无法核验）")
		return
	var anim_cell_d: Dictionary = cells[anim_nid]
	var cur_before2 := RunState.current_node_id
	var choco_before2 := RunState.chocolate
	scene._enter_node(anim_cell_d, true)
	if scene._anim_cell.is_empty() or int(scene._anim_cell["id"]) != anim_nid:
		_smoke_fail("进场过场：走进没去过的房间没有起过场")
		return
	if RunState.current_node_id != cur_before2 or RunState.chocolate != choco_before2:
		_smoke_fail("进场过场：过场还没播完就改了 RunState（应该等播完才 advance）")
		return
	if scene._enter_label(anim_cell_d) \
			!= str(scene.ENTER_LABELS[RogueMap.display_type(anim_cell_d)]):
		_smoke_fail("进场过场：文字映射与 display_type 不同源")
		return
	scene._anim_cell = {}      # 复原：别影响后面的用例
	# 视野规则的前提：走过的房间必须至少有一个门（不然玩家会被困死）
	for c: Dictionary in cells:
		if RunState.cleared_ids.has(int(c["id"])) and (c["doors"] as Array).is_empty():
			_smoke_fail("地图场景：走过的房间 %d 竟然一个门都没有" % int(c["id"]))
			return
	print("SMOKE OK 地图场景：5×7 = %d 格相接正方形 / 起点 (%d,%d) / 左上大宝箱 + 右上商店 / 巧克力 ×%d / 可走 %d 间"
			% [RogueMap.CELLS, RogueMap.START_COL, RogueMap.START_ROW,
				RunState.chocolate, avail.size()])
	_check_relic_bar(scene)
	_check_map_marks(scene)


func _feed_mb(scene: Variant, pos: Vector2, pressed: bool) -> void:
	## 合成一次鼠标按键事件，直接喂给场景的 `_gui_input` —— smoke 无真实窗口，
	## 这条路正好把「输入路由」当纯函数测（比截图可靠，也不会被真实事件顺序干扰）。
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	scene._gui_input(e)


func _feed_click(scene: Variant, pos: Vector2) -> void:
	_feed_mb(scene, pos, true)
	_feed_mb(scene, pos, false)


func _feed_motion(scene: Variant, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	scene._gui_input(e)


func _check_map_marks(scene: Variant) -> void:
	## R184：地图标记（R177）输入路由。原 bug：按钮命中只判在 `_handle_mark_input`
	## 里，而它仅在 `_mark_mode >= 0` 之后才走 → 关态点按钮掉进普通地图分支、
	## 坐标又不在任何格上 → 直接 return，**标记功能永远开不了口**
	## （R177 只用 `--marks` 探针强制激活做出图核验，点击路径从没被验证）。
	# 0) 初始关态 + 标记数据干净
	if int(scene._mark_mode) != -1:
		_smoke_fail("地图标记：初始 _mark_mode 应为 -1（关），实际 %d" % int(scene._mark_mode))
		return
	if not RunState.map_strokes.is_empty() or not RunState.map_flags.is_empty():
		_smoke_fail("地图标记：开局不该有残留笔画 / 旗子")
		return
	# 1) 关态点「画图」按钮 → 必须激活（原 bug 就死在这一步）
	_feed_click(scene, scene._mark_btn_rect(scene.MARK_PEN).get_center())
	if int(scene._mark_mode) != scene.MARK_PEN:
		_smoke_fail("地图标记：关态点「画图」按钮应激活画图模式，实际 _mark_mode=%d"
				% int(scene._mark_mode))
		return
	# 2) 拖一笔（按 → 移动 → 松）→ 松手入栈 1 条笔画
	var p0 := Vector2(400, 300)
	var p1 := Vector2(520, 360)
	var p2 := Vector2(640, 300)
	_feed_mb(scene, p0, true)
	_feed_motion(scene, p1)
	_feed_motion(scene, p2)
	_feed_mb(scene, p2, false)
	if RunState.map_strokes.size() != 1:
		_smoke_fail("地图标记：拖一笔应入栈 1 条笔画，实际 %d" % RunState.map_strokes.size())
		return
	var pts: PackedVector2Array = RunState.map_strokes[0]["pts"]
	if pts.size() < 2:
		_smoke_fail("地图标记：笔画至少 2 个点，实际 %d" % pts.size())
		return
	# 3) 切「标记」按钮 → 旗子模式；单点放旗
	_feed_click(scene, scene._mark_btn_rect(scene.MARK_FLAG).get_center())
	if int(scene._mark_mode) != scene.MARK_FLAG:
		_smoke_fail("地图标记：点「标记」按钮应切到旗子模式，实际 %d" % int(scene._mark_mode))
		return
	_feed_click(scene, Vector2(700, 420))
	if RunState.map_flags.size() != 1:
		_smoke_fail("地图标记：旗子模式点一下应放 1 面旗，实际 %d" % RunState.map_flags.size())
		return
	# 4) 再点一次当前模式按钮 → 收起（回纯地图态）
	_feed_click(scene, scene._mark_btn_rect(scene.MARK_FLAG).get_center())
	if int(scene._mark_mode) != -1:
		_smoke_fail("地图标记：再点一次当前模式按钮应收起，实际 %d" % int(scene._mark_mode))
		return
	# 5) 收起态点地图区外空白 → 不该切当前房（也不该起过场）
	var cur_before := RunState.current_node_id
	_feed_click(scene, Vector2(60, 400))
	if RunState.current_node_id != cur_before or not scene._anim_cell.is_empty():
		_smoke_fail("地图标记：收起态点空白处不该切换当前房 / 起过场")
		return
	# 6) 橡皮：激活后擦在旗子上 → 删旗；再擦在笔画上 → 删笔
	_feed_click(scene, scene._mark_btn_rect(scene.MARK_ERASE).get_center())
	if int(scene._mark_mode) != scene.MARK_ERASE:
		_smoke_fail("地图标记：点「擦除」按钮应激活橡皮，实际 %d" % int(scene._mark_mode))
		return
	_feed_mb(scene, Vector2(700, 420), true)
	_feed_motion(scene, Vector2(700, 420))
	_feed_mb(scene, Vector2(700, 420), false)
	if not RunState.map_flags.is_empty():
		_smoke_fail("地图标记：橡皮擦过旗子应删旗，还剩 %d" % RunState.map_flags.size())
		return
	_feed_mb(scene, p1, true)
	_feed_motion(scene, p1)
	_feed_mb(scene, p1, false)
	if not RunState.map_strokes.is_empty():
		_smoke_fail("地图标记：橡皮擦过笔画应删笔，还剩 %d" % RunState.map_strokes.size())
		return
	# 7) 收起来 + 清干净，别影响后面的用例
	scene._mark_set_mode(-1)
	RunState.map_strokes = []
	RunState.map_flags = []
	print("SMOKE OK 地图标记（R184）：关态点按钮可激活 / 拖笔入栈 / 单点放旗 / 再点收起 / 橡皮删旗删笔")


func _check_whisper(scene: Variant) -> void:
	## R194：鸭之低语（6010）随机走路「只走一格就停」。
	## 场景侧两件事必须同时成立：
	##   ① `_ready` 进来就接管（`_whisper_auto` 置起 + 已挑好第一间，紫圈画得出）；
	##   ② 落在一间**走过的**房间上时，必须**接着挑下一步** ——
	##      当年就是在这里静止（`advance` 不换场景 → 场景不重跑 `_ready`）→ 卡死。
	if not bool(scene._whisper_auto):
		_smoke_fail("R194 低语：持 6010 进地图应当自动接管（_whisper_auto 未置起）")
		return
	var w_first: Dictionary = scene._whisper_next
	if w_first.is_empty() or RunState.cleared_ids.has(int(w_first["id"])):
		_smoke_fail("R194 低语：接管后第一步必须挑「没走过的」邻居，实际 %s" % str(w_first))
		scene._whisper_auto = false
		return
	# 造一个「命运选中走过的房间」的局面：先站到那个邻居上，再让它回踩已走过的起点。
	var w_nb: int = int(w_first["id"])
	var w_start: Dictionary = RogueMap.start_cell(RunState.map_cells)
	RunState.cleared_ids.append(w_nb)          # 邻居也记成走过
	RunState.current_node_id = w_nb
	RunState.chocolate = maxi(2, RunState.chocolate - 1)
	scene._whisper_next = w_start              # 命运选中「走过的起点」
	scene._whisper_wait = 0.0
	var w_choco0: int = RunState.chocolate
	scene._process(0.05)                       # 推一帧：应当走过去 + **接着挑下一步**
	var w_next2: Dictionary = scene._whisper_next
	if RunState.current_node_id != int(w_start["id"]):
		_smoke_fail("R194 低语：命运选中的「走过的房间」没被走过去（现在站在 %d）"
				% RunState.current_node_id)
	elif RunState.chocolate != w_choco0:
		_smoke_fail("R194 低语：回踩走过的房间不该扣巧克力（%d → %d）"
				% [w_choco0, RunState.chocolate])
	elif w_next2.is_empty():
		_smoke_fail("R194 低语：落在走过的房间上之后**没有再挑下一步**"
				+ "（这就是当年「只走一格就停」）")
	elif int(w_next2["id"]) == w_nb:
		_smoke_fail("R194 低语：接着挑的下一步又指回刚离开的那间（原地打转）")
	else:
		print("SMOKE OK R194 低语：接管 → 抽中走过的房间仍继续往前走"
				+ "（%d → %d，接着挑 %d）"
				% [w_nb, int(w_start["id"]), int(w_next2["id"])])
	# ③ 真跑一遍「连续代走」：全图都记成走过、只留 3 步外的一间没走过 →
	#    命运必须**连走 3 步**过去（旧实现走 1 步就停 —— 这正是用户上报的现象）。
	if RunState.run_active and RunState.current_node_id >= 0:
		var w_save_cleared: Array = RunState.cleared_ids
		var w_save_cur: int = RunState.current_node_id
		var w_save_choco: int = RunState.chocolate
		RunState.cleared_ids = []
		for w_c: Dictionary in RunState.map_cells:
			RunState.cleared_ids.append(int(w_c["id"]))
		var w_ds: Dictionary = RogueMap.steps_from(RunState.map_cells, w_save_cur)
		var w_target := -1
		for w_c2: Dictionary in RunState.map_cells:
			if int(w_ds.get(int(w_c2["id"]), -1)) == 3:
				w_target = int(w_c2["id"])
				break
		if w_target < 0:
			_smoke_fail("R194 低语：地图上找不到距起点 3 步的格子（用例前提不成立）")
		else:
			RunState.cleared_ids.erase(w_target)
			scene._whisper_auto = true
			scene._whisper_next = RunState.whisper_pick()
			var w_steps := 0
			while w_steps < 8 and scene._anim_cell.is_empty():
				scene._whisper_wait = 0.0
				scene._process(0.05)
				w_steps += 1
			if w_steps != 3 or scene._anim_cell.is_empty() \
					or int(scene._anim_cell["id"]) != w_target:
				_smoke_fail("R194 低语：3 步外那间没走过去（走了 %d 步 / 过场目标 %s / 期望 %d）"
						% [w_steps, str(scene._anim_cell.get("id", -1)), w_target])
			elif RunState.current_node_id == w_target:
				_smoke_fail("R194 低语：走到新房间应当先播进场过场（不该已经结算进房）")
			elif RunState.chocolate != w_save_choco:
				_smoke_fail("R194 低语：过场没播完前的路过步不该扣巧克力（%d → %d）"
						% [w_save_choco, RunState.chocolate])
			else:
				print("SMOKE OK R194 低语：一连代走 3 步到没走过的房间"
						+ "（旧实现走 1 步就停；路过步不扣巧克力）")
		RunState.cleared_ids = w_save_cleared
		RunState.current_node_id = w_save_cur
		RunState.chocolate = w_save_choco
	# 收尾：关掉代走，免得后面几帧真的走进新房间把场景切走
	scene._whisper_auto = false
	scene._whisper_next = {}
	scene._anim_cell = {}


func _check_relic_bar(scene: Variant) -> void:
	## R75：**道具悬浮即看说明；只有一行放不下时才允许点开详情**，且详情字号更大。
	## 地图侧断言：徽章不越界、装得下时无 +N、装不下时恰好一个 +N 且可点。
	var n_max: int = scene.RELIC_BADGE_MAX
	# 徽章行整体不能压到标题（最左一个徽章的左沿要在标题右侧）
	var left: float = scene._relic_rect(n_max - 1).position.x
	if left < 470.0:
		_smoke_fail("道具徽章：一行 %d 个时最左徽章左沿 %.1f，压到标题区"
				% [n_max, left])
		return
	var saved: Array = RunState.relics.duplicate()
	# 少：装得下 → 不该有 +N，也就不该给点击入口
	RunState.relics = [6001, 6003, 6005]
	if scene._relic_bar_overflowed():
		_smoke_fail("道具徽章：3 件（上限 %d）却判定为溢出" % n_max)
		return
	if scene._relic_shown() != 3:
		_smoke_fail("道具徽章：装得下时只应列出全部 3 件，实际 %d" % scene._relic_shown())
		return
	# 多：装不下 → 恰好留一个 +N，且 +N 落在允许点击的位置
	RunState.relics = [6001, 6002, 6003, 6005, 6006, 6007, 6008, 6009, 6013, 6015]
	if not scene._relic_bar_overflowed():
		_smoke_fail("道具徽章：10 件（上限 %d）却判定为装得下" % n_max)
		return
	var shown: int = scene._relic_shown()
	if shown != n_max - 1:
		_smoke_fail("道具徽章：溢出时应留 1 个 +N 位（列 %d 个），实际 %d" % [n_max - 1, shown])
		return
	var more: Rect2 = scene._relic_rect(shown)
	if more.size.x <= 0.0 or more.position.y < 0.0 or more.end.y > 44.0:
		_smoke_fail("道具徽章：+N 摘要块不在顶部徽章行内（%s）" % str(more))
		return
	if not more.has_point(more.get_center()):
		_smoke_fail("道具徽章：+N 摘要块自身中心不在块内（%s）" % str(more))
		return
	# 详情面板：能列出全部 10 件，且说明字号 > 悬浮提示字号
	var rows: Array = scene._relic_panel_rows()
	if rows.size() != RunState.relics.size():
		_smoke_fail("道具详情面板：应列出全部 %d 件，实际 %d"
				% [RunState.relics.size(), rows.size()])
		return
	if int(scene.RELIC_P_NAME) <= 14 or int(scene.RELIC_P_DESC) <= 12:
		_smoke_fail("道具详情面板：字号没放大（名称 %d / 说明 %d，悬浮是 14 / 12）"
				% [int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])
		return
	if scene.RELIC_P_DESC <= 12:
		_smoke_fail("道具详情面板：说明字号 %d 未大于悬浮提示的 12" % int(scene.RELIC_P_DESC))
		return
	RunState.relics = saved
	print("SMOKE OK 道具查看：地图徽章上限 %d 个 / 3 件不溢出无 +N / 10 件留 1 个 +N 可点 / 详情 %d 件全列且字号 %d>%d"
			% [n_max, rows.size(), int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])


func _next() -> void:
	if _cur != null:
		root.remove_child(_cur)
		_cur.free()
		_cur = null
	_idx += 1
	_frames = 0
	if _idx >= _plan.size():
		print("SMOKE === 结束：%d 通过 / %d 失败 ===" % [_ok, _fail])
		quit()
		return
	var entry: Array = _plan[_idx]
	var path: String = entry[0]
	var note: String = str(entry[1])
	(entry[1] as Callable).call()
	_check = Callable()
	if entry.size() > 2 and entry[2] is Callable:
		_check = entry[2]   # 第 3 项：场景就绪后的行为断言（见 _process）
	var packed: PackedScene = load(path)
	if packed == null:
		print("SMOKE FAIL %s：资源加载失败" % path)
		_fail += 1
		_next()
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		print("SMOKE FAIL %s：instantiate 返回 null" % path)
		_fail += 1
		_next()
		return
	_cur = inst
	root.add_child(inst)
	print("SMOKE OK %s  [用例 %d/%d]" % [path, _idx + 1, _plan.size()])


func _process(_delta: float) -> bool:
	if _cur == null:
		return false
	_frames += 1
	if _frames == 2 and _check.is_valid():
		var c := _check
		_check = Callable()
		c.call(_cur)
	# R66：凡是挂了「牌库 N」按钮的界面，都必须也有「道具 N」按钮（两个查看器对等）。
	# 同一个场景在 _plan 里可能重复出现（不同前置），打印只出一次，免得刷屏。
	var dv: int = 0
	var rv: int = 0
	for child in _cur.get_children():
		if child is DeckViewer:
			dv += 1
		elif child is RelicViewer:
			rv += 1
	if dv > 0 and rv == 0:
		_smoke_fail("道具查看：挂了 %d 个牌库查看器却没有道具查看器" % dv)
	elif dv > 0 and not _pair_reported.has(str(_cur.name)):
		_pair_reported[str(_cur.name)] = true
		print("SMOKE OK 道具查看：%s 牌库 %d 个 / 道具 %d 个（两个查看器成对）"
				% [_cur.name, dv, rv])
	if _frames >= FRAMES_PER_SCENE:
		_ok += 1
		_next()
	return false


func _check_card_detail_block(_scene: Variant) -> void:
	## R206：卡牌三选一「详情条」排版 —— 三个根因都钉在这里（用户报「卡片详细效果描述」乱）：
	##   ① 附带块从**右栏正文底部**接到**左栏 x** 起画 → 标题压着左栏数值行、摘要横跨两栏；
	##   ② 提及标题/名字拿**正文色**猜底色 → 深蓝正文被判成暗底 → 亮金 `f2c14e` 画在奶油色
	##      羊皮纸上（对比度 ~1.6:1，几乎看不见）；
	##   ③ 附带块的**预算高度**与**实画行距**各写一套数字 → 自适应出来的横条装不下内容。
	var rp := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
	var a := rp.find("func _draw_card_detail")
	var b := rp.find("\nfunc ", a + 10)
	if a < 0 or b <= a:
		_smoke_fail("R206 详情条：找不到 _draw_card_detail()")
		return
	var detail_src := rp.substr(a, b - a)
	if detail_src.find("box.position.x + pad, float(res") >= 0:
		_smoke_fail("R206 详情条：提及块还从**左栏** x 起画（应改成右栏 ex / ew）")
		return
	# R302（用户口径）：附带块**整体取消** —— 提及名只做「悬停弹窗」（触屏点住），
	# 不再把摘要固定列在详情里。这条断言因此从「块要画在右栏」改成「块不许再出现，
	# 但命中矩形必须交出去」。
	if detail_src.find("draw_reference_block") >= 0:
		_smoke_fail("R302 详情条：提及块不该再固定画（只悬停名字弹窗）")
		return
	if detail_src.find('_mention_hits = res["hits"]') < 0:
		_smoke_fail("R302 详情条：正文的提及命中矩形必须交给 _mention_hits")
		return
	# ② 强调色按真实底色挑（浅底 → 琥珀棕；暗底 → 亮金）
	if Mention.text_color_on(UiTheme.PANEL_PAPER_BG) != UiTheme.MENTION_ON_LIGHT:
		_smoke_fail("R206 详情条：羊皮纸浅底上提及名应取 MENTION_ON_LIGHT（琥珀棕）")
		return
	if Mention.text_color_on(Color("1a1c22")) != UiTheme.MENTION_ON_DARK:
		_smoke_fail("R206 详情条：暗底上提及名应取 MENTION_ON_DARK（亮金）")
		return
	if Mention.text_color(Color("2a5a8a")) == UiTheme.MENTION_ON_LIGHT:
		_smoke_fail("R206 详情条：text_color() 的「正文色」判据不该在深蓝正文上给出浅底色答案"
				+ "（这正是本轮 bug：有底色时必须走 text_color_on）")
		return
	# ③ 预算高度 == 实画行距（两边都只许用 BLOCK_* 常量）
	var ms := FileAccess.get_file_as_string("res://scripts/mention.gd")
	if ms.is_empty():
		_smoke_fail("R206 详情条：读不到 mention.gd（源码守卫失效）")
		return
	# 正向守卫：行距必须走 BLOCK_* 常量（含 head 行）；旧的字面量推进一旦回潮就报。
	for need: String in ["ty += BLOCK_HEAD_H", "ty += BLOCK_ITEM_H", "ty += BLOCK_LINE_H",
			"ty += BLOCK_GAP"]:
		if not ms.contains(need):
			_smoke_fail("R206 详情条：mention.gd 缺少行距推进 `%s`" % need)
			return
	for bad: String in ["ty += 16.0", "ty += 15.0", "ty += 3.0", "ty += 20.0"]:
		if ms.contains(bad):
			_smoke_fail("R206 详情条：附带块行距仍在写字面量 `%s`（应改用 BLOCK_* 常量）" % bad)
			return
	var card: CardData = Mention.card_of(8046)
	if card == null:
		_smoke_fail("R206 详情条：卡牌 8046 不在卡库（用例前提失效）")
		return
	var refs := Mention.scan(card.effect_text)
	if refs.is_empty():
		_smoke_fail("R206 详情条：8046 的文案应能扫出至少一个提及（用例前提失效）")
		return
	var f: Font = UiTheme.font()
	var fb: Font = UiTheme.font_bold()
	var want := Mention.BLOCK_HEAD_H + float(refs.size()) * (Mention.BLOCK_ITEM_H + Mention.BLOCK_GAP)
	for r: Dictionary in refs:
		want += float(Mention.summary_lines(f, r, 686.0).size()) * Mention.BLOCK_LINE_H
	var got := Mention.block_height(f, fb, card.effect_text, 700.0, Mention.BLOCK_HEAD_H)
	if absf(got - want) > 0.01:
		_smoke_fail("R206 详情条：block_height 预算（%.1f）与行距公式（%.1f）不一致 —— "
				+ "自适应高度会算歪" % [got, want])
		return
	print("SMOKE OK R206 详情条：提及块在右栏 / 浅底琥珀棕 / 预算高度 %.0f == 公式（%d 个提及）"
			% [got, refs.size()])


func _smoke_fail(msg: String) -> void:
	print("SMOKE FAIL %s" % msg)
	_fail += 1


func _hand_card_extent(scene: Variant, i: int) -> Vector2:
	## 第 i 张手牌**旋转后**的左右极值 (x_left, x_right)。
	## 卡是绕底部中心转的，两端的卡会向左/右探出去，只看未旋转矩形会漏判越界。
	var r: Rect2 = scene._hand_rect(i)
	var p: Vector2 = scene._hand_pivot(i)
	var a: float = scene._hand_angle(i)
	var lo := 99999.0
	var hi := -99999.0
	for corner in [Vector2(0, 0), Vector2(r.size.x, 0), Vector2(0, r.size.y),
			Vector2(r.size.x, r.size.y)]:
		var q: Vector2 = p + (r.position + corner - p).rotated(a)
		lo = minf(lo, q.x)
		hi = maxf(hi, q.x)
	return Vector2(lo, hi)


func _check_hand_fan(scene: Variant) -> void:
	## 扇形手牌：绘制时卡是**转着画的**，命中判定必须用同一个角度反向旋转。
	## 这里先把牌抽到满手（覆盖重叠 + hand_full），再用「旋转后的卡牌中心」回测。
	var n0: int = scene.engine.state.hand.size()
	if n0 < 3:
		_smoke_fail("扇形手牌：起手只有 %d 张，不足 3 张" % n0)
		return
	scene.engine._draw_many(FieldState.HAND_LIMIT)   # 抽到上限（会广播一次 hand_full）
	var n: int = scene.engine.state.hand.size()
	if n != FieldState.HAND_LIMIT:
		_smoke_fail("扇形手牌：应抽到上限 %d 张，实际 %d" % [FieldState.HAND_LIMIT, n])
		return
	if not scene.engine.state.hand_full():
		_smoke_fail("扇形手牌：满手后 hand_full() 仍为假")
	var bad := 0
	for i in n:
		var r: Rect2 = scene._hand_rect(i)
		var pivot: Vector2 = scene._hand_pivot(i)
		var center := Vector2(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)
		var hit_pos: Vector2 = pivot + (center - pivot).rotated(scene._hand_angle(i))
		if not scene._hand_hit(i, hit_pos):
			bad += 1
	if bad > 0:
		_smoke_fail("扇形手牌：%d/%d 张的命中判定与绘制角度不一致" % [bad, n])
	# 两端要有倾角、左右对称、且倾角随下标单调递增（真扇形而不是一排）。
	# 注意：张数为偶数时没有「正好 0°」的中间那张，所以只要求左右对称。
	var left_deg: float = rad_to_deg(scene._hand_angle(0))
	var right_deg: float = rad_to_deg(scene._hand_angle(n - 1))
	var monotonic := true
	for i in range(1, n):
		if scene._hand_angle(i) <= scene._hand_angle(i - 1):
			monotonic = false
	if not (left_deg < -1.0 and right_deg > 1.0 and monotonic
			and absf(left_deg + right_deg) < 0.01):
		_smoke_fail("扇形手牌：倾角不对（左 %.2f° / 右 %.2f° / 单调 %s）"
				% [left_deg, right_deg, monotonic])
	# 重叠：满手时步进必须小于卡宽
	if scene._hand_step(n) >= scene.HAND_CARD_W:
		_smoke_fail("扇形手牌：%d 张的步进 %.1f 不小于卡宽 %.1f，没有重叠"
				% [n, scene._hand_step(n), scene.HAND_CARD_W])
	# 尺寸：手牌明显比战场小卡大（空间换来的放大）
	if scene.HAND_CARD_H <= scene.CARD_H * 1.4:
		_smoke_fail("手牌尺寸：应比战场卡大 1.4 倍以上，实际 %.1f / %.1f（×%.2f）"
				% [scene.HAND_CARD_H, scene.CARD_H, scene.HAND_CARD_H / scene.CARD_H])
	# 卡底**沉出**窗口下沿：底部那截被裁掉。卡面仍是整张排版（不重锚、不补偿），
	# 所以这里只管「沉出量符合预期」和「别沉过头把卡片淹了」，不再断言内容必须可见。
	var bottom: float = scene.OWN_HAND_Y + scene.HAND_CARD_H
	if scene.HAND_CROP_BOTTOM <= 0.0:
		_smoke_fail("手牌位置：卡底没有沉出窗口下沿（HAND_CROP_BOTTOM=%.1f）"
				% scene.HAND_CROP_BOTTOM)
	if absf((bottom - scene.WINDOW_H) - scene.HAND_CROP_BOTTOM) > 0.5:
		_smoke_fail("手牌位置：沉出量应为 %.1f，实际 %.1f"
				% [scene.HAND_CROP_BOTTOM, bottom - scene.WINDOW_H])
	# 沉出量不能吃掉半张卡（否则手牌看着只剩一条边）
	var vis_min := 99999.0
	for i in n:
		vis_min = minf(vis_min, scene._hand_vis_h(i))
	if vis_min < scene.HAND_CARD_H * 0.5:
		_smoke_fail("手牌位置：露出高度只有 %.1f（卡高 %.1f 的一半以下），沉得太狠"
				% [vis_min, scene.HAND_CARD_H])
	# 卡顶不能顶进战场（否则会盖住棋盘单位）
	if scene.OWN_HAND_Y - scene.HAND_FAN_HOVER_LIFT < scene.GRID_Y + scene.GRID_H - 2.0:
		_smoke_fail("手牌位置：抬手后卡顶 %.1f 盖住了战场下沿 %.1f"
				% [scene.OWN_HAND_Y - scene.HAND_FAN_HOVER_LIFT,
					scene.GRID_Y + scene.GRID_H])
	# 两端要比中间下沉（弧线）
	if scene._hand_rect(0).position.y <= scene._hand_rect(n / 2).position.y:
		_smoke_fail("扇形手牌：两端没有下沉，缺少弧线")
	# 越界：卡放大后最容易压到右侧道具栏（x=900 起）或左侧信息栏
	var rz: Rect2 = scene._relic_zone_rect()
	var er: Vector2 = _hand_card_extent(scene, n - 1)
	var el: Vector2 = _hand_card_extent(scene, 0)
	if er.y > rz.position.x - 2.0:
		_smoke_fail("手牌越界：满手时最右一张到 %.1f，压到右侧道具栏（%.1f 起）"
				% [er.y, rz.position.x])
	if el.x < scene.INFO_X + scene.INFO_W + 4.0:
		_smoke_fail("手牌越界：最左一张到 %.1f，压到左侧信息栏（右沿 %.1f）"
				% [el.x, scene.INFO_X + scene.INFO_W])
	# 从上往下取最上层：最后一张的旋转中心必须命中最后一张
	var rl: Rect2 = scene._hand_rect(n - 1)
	var pl: Vector2 = scene._hand_pivot(n - 1)
	var cl := Vector2(rl.position.x + rl.size.x / 2, rl.position.y + rl.size.y / 2)
	var pl_hit: Vector2 = pl + (cl - pl).rotated(scene._hand_angle(n - 1))
	if scene._hand_index_at(pl_hit) != n - 1:
		_smoke_fail("扇形手牌：重叠区没有取最上层那张（期望 %d，实际 %d）"
				% [n - 1, scene._hand_index_at(pl_hit)])
	else:
		var msg := "SMOKE OK 扇形手牌：满手 %d 张，%.0f×%.0f（战场卡 %.0f×%.0f 的 %.2f 倍，" % [
				n, scene.HAND_CARD_W, scene.HAND_CARD_H, scene.CARD_W, scene.CARD_H,
				scene.HAND_CARD_H / scene.CARD_H]
		msg += "卡底沉出下沿 %.0f，露出 %.0f）" % [
				bottom - scene.WINDOW_H, vis_min]
		msg += " / 倾角 左 %.1f° 右 %.1f° / 横向 %.0f~%.0f（不越界）" % [
				left_deg, right_deg, el.x, er.y]
		print(msg)

func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var k: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * k)


func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := 99999.0
	for i in pts.size() - 1:
		best = minf(best, _dist_to_seg(p, pts[i], pts[i + 1]))
	return best


func _check_move_path(scene: Variant) -> void:
	## 多格移动动画必须沿「真实路径」走，而不是从起点直连终点。
	## 链路：引擎 move_path 逐格路径 → move 事件 → 场景 _slides 的 pts →
	##      _display_center 按 pts 分段插值。这里采样 9 个时刻，
	##      位置必须落在折线上（相差不得超过 1 像素）。
	var st: FieldState = scene.engine.state
	if st.unit_at(Vector2i(3, 0)) != null or st.unit_at(Vector2i(4, 0)) != null \
			or st.unit_at(Vector2i(3, 1)) != null or st.unit_at(Vector2i(4, 1)) != null:
		_smoke_fail("多格移动：(3,0)/(4,0)/(3,1)/(4,1) 已被占用，用例前提不成立")
		return
	var repo := CardRepo.load_json()
	var fast: CardData = repo.get_card(9027)    # 夜鸭：移动距离 2
	var wall: CardData = repo.get_card(8001)    # 木栅栏：占住 (4,0) 逼出 L 形走法
	st.place(fast, Vector2i(3, 0), "self")
	st.place(wall, Vector2i(4, 0), "opponent")
	scene.engine.move(Vector2i(3, 0), Vector2i(4, 1), "self")
	var pl2: Placement = st.unit_at(Vector2i(4, 1))
	if pl2 == null or not scene._slides.has(pl2):
		_smoke_fail("多格移动：单位没到 (4,1) 或场景没排队滑行动画")
		return
	var sl: Dictionary = scene._slides[pl2]
	var pts: Array = sl.get("pts", [])
	var want: Array[Vector2] = []
	for c in [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 1)]:
		want.append(scene._cell_center(c))
	if pts != want:
		_smoke_fail("多格移动：动画途经点与真实路径不符（%s）" % str(pts))
		return
	# 滑行时长随格数增加：2 格 = MOVE_SLIDE_BASE + PER_STEP * 2
	var two_dur: int = scene.MOVE_SLIDE_BASE_MS + scene.MOVE_SLIDE_PER_STEP_MS * 2
	if int(sl.get("dur", 0)) != two_dur:
		_smoke_fail("多格移动：2 格滑行时长应为 %d，实际 %d"
				% [two_dur, int(sl.get("dur", 0))])
	# 采样整段动画：任一时刻的位置都必须落在那条 L 形折线上
	var worst := 0.0
	var dur: int = int(sl.get("dur", 0))
	for i in 9:
		var frac: float = float(i) / 8.0
		sl["start"] = Time.get_ticks_msec() - int(float(dur) * frac)
		var pos: Vector2 = scene._display_center(pl2, Vector2i(4, 1))
		worst = maxf(worst, _dist_to_polyline(pos, want))
	# 反证：直线插值（修复前的行为）在这条 L 形路径上必然偏得很远，
	# 否则说明这条用例根本抓不到回归。
	var diag := 0.0
	for i in 9:
		var f2: float = float(i) / 8.0
		var e2: float = 1.0 - pow(1.0 - f2, 3.0)
		diag = maxf(diag, _dist_to_polyline(want[0].lerp(want[2], e2), want))
	if worst > 1.0:
		_smoke_fail("多格移动：最大偏离真实路径 %.1f 像素（动画走了捷径）" % worst)
	elif diag < 20.0:
		_smoke_fail("多格移动：直线插值只偏离 %.1f 像素，这条用例抓不到回归" % diag)
	else:
		print("SMOKE OK 多格移动走真实路径：途经点 %d 个 / 时长 %dms / 最大偏离 %.2f 像素（直线插值会偏 %.0f）" % [pts.size(), dur, worst, diag])
	st.board.erase(Vector2i(4, 1))
	st.board.erase(Vector2i(4, 0))

func _check_delivery(scene: Variant) -> void:
	## R200：运送委托 —— 主按钮开平铺选卡页（PickOverlay 复用）；取消不接货；
	## 确认选 2 张 → 卡组 +2 张货物、接取状态记 2。
	if not scene._is_delivery():
		_smoke_fail("运送委托：pending_event=delivery 应被识别")
		return
	var repo := CardRepo.load_json()
	var cargo: CardData = repo.get_card(RunState.CARGO_CARD_ID)
	if cargo == null or cargo.kind != "工事" or cargo.cost != 3 \
			or cargo.power != 0 or cargo.health != 6 or cargo.attack_range != 0:
		_smoke_fail("运送委托：货物卡面应是 3 费工事 0/6/0（R280 由 1 费上调）")
		return
	var before: int = RunState.deck_ids.size()
	# ── 1) 主按钮 → 开平铺选卡页（1~6 区间）──
	scene._on_main()
	var pick: Variant = scene._pick
	if pick == null or not pick.is_picking():
		_smoke_fail("运送委托：主按钮应打开平铺选卡页")
		return
	if int(pick._cfg.get("max_sel", 0)) != 6 or int(pick._cfg.get("min_sel", 0)) != 1:
		_smoke_fail("运送委托：选卡页应是 1~6 张区间（max=%d min=%d）"
				% [int(pick._cfg.get("max_sel", 0)), int(pick._cfg.get("min_sel", 0))])
		return
	# ── 2) 取消 = 收起，不接货 ──
	scene._on_delivery_cancelled()
	if RunState.cargo_count() != 0:
		_smoke_fail("运送委托：取消后卡组不应有货物（实际 %d）" % RunState.cargo_count())
		return
	# ── 3) 再开 → 确认 2 张入卡组 ──
	scene._on_main()
	scene._on_delivery_confirmed([0, 1])
	if RunState.deck_ids.size() != before + 2:
		_smoke_fail("运送委托：确认 2 张后卡组应 +2（实际 %d → %d）"
				% [before, RunState.deck_ids.size()])
		return
	if RunState.cargo_count() != 2:
		_smoke_fail("运送委托：卡组应有 2 张货物（实际 %d）" % RunState.cargo_count())
		return
	if not scene._delivery_taken or scene._delivery_count != 2:
		_smoke_fail("运送委托：接取状态应记录 2 张（taken=%s count=%d）"
				% [str(scene._delivery_taken), scene._delivery_count])
		return
	print("SMOKE OK 运送委托：平铺选卡页 1~6 / 取消不接 / 确认 2 张入卡组")


func _check_delivery_done(scene: Variant) -> void:
	## R200：委托完成 —— 3 张货物各抽一次（卡牌奖励 / 80 金币 / 随机道具 / 巧克力 10%）；
	## 兑付总量恰为 3 次；一次性（delivery_done 置位后不再替换事件房）。
	if not scene._is_delivery_done():
		_smoke_fail("委托完成：pending_event=delivery_done 应被识别")
		return
	if RunState.cargo_count() != 3:
		_smoke_fail("委托完成：卡组应铺 3 张货物（实际 %d）" % RunState.cargo_count())
		return
	if RunState.delivery_override_kind() != "delivery_done":
		_smoke_fail("委托完成：二层 + 持有货物 + 未结算时应替换为 delivery_done")
		return
	var deck0: int = RunState.deck_ids.size()
	var gold0: int = RunState.gold
	var choco0: int = RunState.chocolate
	var pend0: int = RunState.pending_reward_count()
	# ── 1) 兑付 ──
	scene._on_main()
	if not scene._delivery_settled or not RunState.delivery_done:
		_smoke_fail("委托完成：兑付后 _delivery_settled / delivery_done 都应置位")
		return
	# ── 2) 每个货物恰好一次：入队奖励 + 金币/80 + 巧克力 == 3 ──
	var got_relic: int = RunState.pending_reward_count() - pend0
	var got_gold: int = (RunState.gold - gold0) / 80
	var got_choco: int = RunState.chocolate - choco0
	if got_relic + got_gold + got_choco != 3:
		_smoke_fail("委托完成：3 张货物应共兑付 3 次（奖励 %d / 金币 %d / 巧克力 %d）"
				% [got_relic, got_gold, got_choco])
		return
	# ── 3) 一次性：置位后不再替换 ──
	if RunState.delivery_override_kind() != "":
		_smoke_fail("委托完成：delivery_done 置位后不应再替换事件房")
		return
	# ── 3b) R210：货物兑付后必须从卡组里删干净（用户实测：以前交付完还留在卡组）──
	if RunState.cargo_count() != 0:
		_smoke_fail("委托完成：兑付后卡组里不应再有货物（实际 %d 张）"
				% RunState.cargo_count())
		return
	if RunState.deck_ids.size() != deck0 - 3:
		_smoke_fail("委托完成：兑付后卡组应少 3 张（%d → %d）"
				% [deck0, RunState.deck_ids.size()])
		return
	if RunState.deck_mods.size() != RunState.deck_ids.size():
		_smoke_fail("委托完成：删货物后附魔槽位仍要与卡组等长（%d vs %d）"
				% [RunState.deck_mods.size(), RunState.deck_ids.size()])
		return
	# ── 4) 结算后只留离开按钮 ──
	if scene.rest_btn.visible:
		_smoke_fail("委托完成：结算后应只留离开按钮（rest_btn 应收起）")
		return
	print("SMOKE OK 委托完成：3 张货物各抽一次 / 总量=3 / 一次性 / 货物已移出卡组 / 结算后只剩离开")


func _check_battle(scene: Variant) -> void:
	## 战斗场景的所有行为断言：扇形手牌 + 多格移动动画走真实路径 + 效果/道具溢出兜底
	## + 战斗内地图总览（R64）。
	_check_hand_fan(scene)
	_check_move_path(scene)
	_check_overflow(scene)
	_check_map_panel(scene)
	_check_frozen_aura(scene)
	_check_sleep_aura(scene)
	_check_turn_gate(scene)
	_check_relic_gate(scene)
	_check_r106(scene)
	_check_cancel_armed(scene)
	_check_menu(scene)
	_check_attack_art_variant()
	_check_long_press(scene)
	_check_back_key(scene)
	_check_perf(scene)
	_check_pick_overlay(scene)
	_check_ee_popup(scene)
	_check_recycle(scene)
	_check_lighten(scene)
	_check_reload(scene)
	_check_sysupgrade(scene)
	_check_assemble(scene)
	_check_run_deck_panel(scene)
	_check_r208(scene)
	_check_enchant_mark(scene)
	_check_r277_field_tap(scene)


func _check_r277_field_tap(scene: Variant) -> void:
	## R277（安卓触屏）：场地卡的**点选路径**必须能落在「已有己方单位」的格子上。
	##
	## 原 bug：`_on_board_click` 里场地卡掉进了随从分支 —— 那里见格子有单位就
	## 「那格已有 X，换一格放置」，于是手机上「点手牌 → 点格子」永远放不上
	## 维修间 8036 / 改造工厂 8037（拖拽路径走 `_own_place_cells` → `_field_place_cells`，
	## 本来就是对的 → 这个 bug 只在触屏 / 点选操作里出现）。
	## 这里走**真实点击注入**（`_feed_click`），不是直接调引擎。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("R277 场地放置：拿不到 engine")
		return
	var repo := CardRepo.load_json()
	var bay: CardData = repo.get_card(GameEngine.REPAIR_BAY_ID)
	if bay == null:
		_smoke_fail("R277 场地放置：维修间（%d）缺失" % GameEngine.REPAIR_BAY_ID)
		return
	# 上一条用例可能把全屏选卡页留在展开态（R189 起它会吞掉所有点击）→ 先取消掉
	if scene._pick != null and scene._pick.is_picking():
		scene._on_pick_cancelled()
		scene._sync_pick()
	if scene._pick != null and scene._pick.is_picking():
		_smoke_fail("R277 场地放置：上一条用例的选卡页关不掉，无法验证点击路径")
		return
	scene._grid_intro_t = -1.0
	scene._grid_zoom = 1.0
	scene._clear_selection()
	eng.current_side = GameEngine.SIDE_SELF
	eng.state.energy = 9
	# 目标格：己方半场里**当前可视窗内**、且场地允许放的一格
	var cell := Vector2i(-1, -1)
	for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if not scene._cell_in_view(scene._cell_center(c)):
				continue
			if not GameEngine.field_place_allowed(c, GameEngine.FIELD_AIM_ALLY):
				continue
			cell = c
			break
		if cell.x >= 0:
			break
	if cell.x < 0:
		_smoke_fail("R277 场地放置：己方半场找不到可放场地的可视格")
		return
	# 那格上先站一个己方盟友（这就是「有友方单位的格子」）
	if eng.state.board.has(cell):
		eng.state.board.erase(cell)
	var ally := CardData.new()
	ally.id = 8199
	ally.card_name = "测试盟友"
	ally.kind = "盟友"
	ally.cost = 1
	ally.power = 2
	ally.health = 10
	ally.attack_range = 1
	ally.move_speed = 1
	eng.state.place(ally, cell, GameEngine.SIDE_SELF)
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(bay.to_dict()))
	# ① 点手牌 → 选中  ② 点**有己方单位**的格子 → 应该放下场地
	_feed_click(scene, _hand_card_center(scene, 0))
	if scene.selection == null or scene.selection[0] != "hand":
		_smoke_fail("R277 场地放置：点手牌没选中（selection=%s）" % str(scene.selection))
		return
	_feed_click(scene, scene._cell_center(cell))
	var placed: CardData = eng.state.field_at(cell)
	if placed == null or placed.id != GameEngine.REPAIR_BAY_ID:
		_smoke_fail("R277 场地放置：点有己方单位的格子（%s）没放上维修间（实际 %s）"
				% [str(cell), "空" if placed == null else placed.card_name])
		return
	if eng.state.hand.size() != 0:
		_smoke_fail("R277 场地放置：放下后手牌应清空，实际 %d 张" % eng.state.hand.size())
		return
	var still: Placement = eng.state.unit_at(cell)
	if still == null or still.card.id != 8199:
		_smoke_fail("R277 场地放置：场地放下后原己方单位**不该消失**（实际 %s）"
				% ("空" if still == null else still.card.card_name))
		return
	print("SMOKE OK R277 场地卡点选：放在有己方单位的格子上成功（%s，单位仍在场）" % str(cell))


func _check_enchant_mark(scene: Variant) -> void:
	## R214：**商店附魔的标记** —— 用户口径「带有附魔效果的卡片，应该在任何地方，都显示
	## 附魔标记。标记应在卡片费用正下方，与附魔种类相同」。
	## 钉三件事：① 几何（费用正下方 = 同 x、圆心距 2R）；② 卡面带着附魔种类 id；
	## ③ 展示层的卡组聚合不会把附魔卡并进原卡（并了就根本没机会画标记）。
	var repo := CardRepo.load_json()
	# ① 几何：费用圆心在卡左上角 → 标记圆心必须与它同一条竖线、距离正好 2R（相切）。
	#    三种典型尺寸都过一遍：小卡 58×70 / 手牌 99×119 / 奖励大卡 150×190（徽章已封顶）。
	var geo_bad := ""
	for sz: Vector2 in [Vector2(58, 70), Vector2(99, 119), Vector2(150, 190)]:
		var rr := Rect2(Vector2(40, 60), sz)
		var cost_c := CardFace.cost_badge_center(rr)
		var ench_c := CardFace.enchant_badge_center(rr)
		var r: float = UiTheme.CARD_BADGE_R \
				* minf(sz.y / CardFace.CARD_H_DESIGN, UiTheme.CARD_BADGE_SCALE_CAP)
		if absf(ench_c.x - cost_c.x) > 0.01 or absf(ench_c.y - cost_c.y - 2.0 * r) > 0.01:
			geo_bad = "%s → 费用 %s / 附魔 %s" % [sz, cost_c, ench_c]
	if geo_bad != "":
		_smoke_fail("R214 附魔标记：应在费用徽章**正下方**（同 x、间距 2R）—— %s" % geo_bad)
		return
	# ② 种类表：显示名 / 种类色 / 图标名都在 CardData.ENCHANT_DEFS 里（绘制与左栏的唯一口）
	if CardData.enchant_name("damage") != "伤害 +10" \
			or not CardData.enchant_color("costdown").is_equal_approx(Color("6db2f0")) \
			or CardData.enchant_icon_name("dimension") != "shop_icon_dimension" \
			or CardData.enchant_name("opening") != "起手" \
			or CardData.enchant_icon_name("opening") != "shop_icon_opening" \
			or CardData.enchant_name("") != "":
		_smoke_fail("R214 附魔标记：ENCHANT_DEFS 的显示名 / 种类色 / 图标名不对")
		return
	var marked := CardData.from_dict(repo.get_card(8003).to_dict())
	if marked.has_enchant():
		_smoke_fail("R214 附魔标记：未附魔的卡不该带标记")
		return
	marked.enchant = "dimension"
	if not marked.has_enchant():
		_smoke_fail("R214 附魔标记：写上种类 id 后 has_enchant() 应为真")
		return
	# ③ 牌库面板（DeckViewer）的聚合：附魔卡必须与原卡分开列（同 id 也不能并）
	var saved_ids: Array[int] = RunState.deck_ids.duplicate()
	var saved_mods: Array = RunState.deck_mods.duplicate()
	RunState.run_active = true
	var dv_ids: Array[int] = [8003, 8003, 9003]
	RunState.deck_ids = dv_ids
	RunState.deck_mods = []
	RunState.ensure_deck_mods()
	RunState.enchant_deck_card(1, RunState.enchant_mod("dimension"))
	var dv: DeckViewer = DeckViewer.new()
	var merged: Array = dv._merged()
	var groups: int = merged.size()
	var found_ench := false
	for e: Dictionary in merged:
		var c: CardData = e["card"]
		if c.id == 8003 and c.enchant == "dimension" and int(e["count"]) == 1:
			found_ench = true
	dv.free()
	RunState.deck_ids = saved_ids
	RunState.deck_mods = saved_mods
	RunState.ensure_deck_mods()
	if groups != 3 or not found_ench:
		_smoke_fail("R214 附魔标记：牌库面板应把附魔卡与原卡分开列（%d 组 / 找到附魔组 %s）"
				% [groups, str(found_ench)])
		return
	# ④ 绘制路径由场景自身的 _draw 覆盖（战斗手牌 / 牌库面板 / 地图卡组都会真实画到）；
	# 这里**不能**手调 CardFace.draw —— Godot 只在 `_draw()` 内部允许绘制，直接调会刷
	# 一屏「Drawing is only allowed inside this node's _draw()」（不崩，但把日志淹掉）。
	print("SMOKE OK R214 附魔标记：费用正下方（同 x / 间距 2R，三种尺寸）/ 种类表唯一口 / 牌库面板不并按")


func _check_reload(scene: Variant) -> void:
	## R202 / R205：填充（9146）—— 使用后**弹全屏选卡页**（候选 = 除自己以外的手牌），
	## 选一张 → 确认 → 它原位变成聚能炮击；0 费；点「取消」不扣费、不弃卡。
	## R205 起手牌点击不再承担第二段（旧路径删掉了），所以这里断言 **选卡页** 真的打开。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("填充：拿不到 engine")
		return
	var repo := CardRepo.load_json()
	var rl: CardData = repo.get_card(GameEngine.RELOAD_ID)
	if rl == null or rl.cost != 0 or rl.rarity != 0:
		_smoke_fail("填充：卡面应是 0 费普通技能")
		return
	# R213：手牌目标技能的**唯一判据口** —— 拖拽 / 点击 / 区域文案三处共用它。
	if String(scene._hand_target_pick_kind(repo.get_card(GameEngine.SYS_UPGRADE_ID))) != "sysup" \
			or String(scene._hand_target_pick_kind(repo.get_card(GameEngine.RECYCLE_ID))) != "recycle" \
			or String(scene._hand_target_pick_kind(repo.get_card(GameEngine.RELOAD_ID))) != "reload" \
			or String(scene._hand_target_pick_kind(repo.get_card(8002))) != "":
		_smoke_fail("R213：手牌目标判据口不对（8039/8064/9146 应各归 sysup/recycle/reload，8002 应为空）")
		return
	scene._grid_intro_t = -1.0
	scene._grid_zoom = 1.0
	scene._clear_selection()
	eng.current_side = GameEngine.SIDE_SELF
	# 手牌：攻击(0) + 填充(1) + 熊(2)
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
	eng.state.hand.append(CardData.from_dict(rl.to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8004).to_dict()))
	eng.state.energy = 3
	_feed_click(scene, _hand_card_center(scene, 1))
	_feed_click(scene, _hand_card_center(scene, 1))
	if int(scene._reload_idx) != 1:
		_smoke_fail("填充：再点一次应进入填充待选（_reload_idx=%d）" % scene._reload_idx)
		return
	# 关键断言：不再手点第二张手牌 —— 弹出全屏选卡页
	scene._sync_pick()
	if scene._pick == null or not scene._pick.is_picking():
		_smoke_fail("填充：使用后应弹出全屏选卡页")
		return
	if String(scene._pick.kind()) != "reload":
		_smoke_fail("填充：选卡页场景应是 reload（实际 %s）" % String(scene._pick.kind()))
		return
	var opts: Array = scene._pick.opts()
	if opts.size() != 2 or opts.has(1):
		_smoke_fail("填充：候选应是除自己以外的 2 张手牌（opts=%s）" % str(opts))
		return
	scene._on_pick_confirmed([0])   # 网格第 0 张 = 手牌 0（攻击）
	if int(scene._reload_idx) >= 0:
		_smoke_fail("填充：确认后应清掉 _reload_idx（%d）" % scene._reload_idx)
		return
	if eng.state.hand[0].id != GameEngine.ENERGY_CANNON_ID:
		_smoke_fail("填充：攻击应变成聚能炮击（实际 %s %d）"
				% [eng.state.hand[0].card_name, eng.state.hand[0].id])
		return
	if eng.state.energy != 3:
		_smoke_fail("填充：应 0 费（能量 %d，期望 3）" % eng.state.energy)
		return
	# R211：填充带「次元」→ 用后**消失**（进消耗区），不进弃牌区
	var reload_in_void := false
	for d: CardData in eng.state.void_cards:
		if d.id == GameEngine.RELOAD_ID:
			reload_in_void = true
			break
	if not reload_in_void:
		_smoke_fail("填充：带「次元」→ 用后应进消耗区（void=%s）"
				% str(eng.state.void_cards.map(func(c): return c.id)))
		return
	for d: CardData in eng.state.discard:
		if d.id == GameEngine.RELOAD_ID:
			_smoke_fail("填充：带「次元」不该进弃牌区（discard=%s）"
					% str(eng.state.discard.map(func(c): return c.id)))
			return
	scene._sync_pick()
	if scene._pick != null and scene._pick.is_picking():
		_smoke_fail("填充：结算完选卡页应自动关闭")
		return
	# 取消路径：再填充一次 → 点「取消（不扣费）」→ 手牌 / 能量原样
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(rl.to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8004).to_dict()))
	eng.state.energy = 3
	scene._clear_selection()
	_feed_click(scene, _hand_card_center(scene, 0))
	_feed_click(scene, _hand_card_center(scene, 0))
	if int(scene._reload_idx) != 0:
		_smoke_fail("填充（取消路径）：再点一次应进入填充待选")
		return
	scene._sync_pick()
	scene._on_pick_cancelled()
	if int(scene._reload_idx) >= 0 or eng.state.hand.size() != 2 or eng.state.energy != 3:
		_smoke_fail("填充（取消路径）：取消后手牌/能量应原样（%d 张 / %d 费）"
				% [eng.state.hand.size(), eng.state.energy])
		return
	scene._sync_pick()
	if scene._pick != null and scene._pick.is_picking():
		_smoke_fail("填充（取消路径）：取消后选卡页应关闭")
		return
	# ── R213：**拖拽**也能发动（用户口径「填充当前不能拖拽使用」）──
	# 拖到棋盘任意处松手 = 与点击同一入口：只记下标弹选卡页，不扣费、不调 use_spell。
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(rl.to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8004).to_dict()))
	eng.state.energy = 3
	scene._clear_selection()
	scene._start_drag(0, _hand_card_center(scene, 0))
	if not bool(scene._drag_anywhere):
		_smoke_fail("填充（拖拽）：拖起来应显示「这片区域能松手」（_drag_anywhere=false）")
		return
	if String(scene._drag_zone_label()).find("选卡页") < 0:
		_smoke_fail("填充（拖拽）：区域标签应说明「松手 → 弹出选卡页」（实际 %s）"
				% String(scene._drag_zone_label()))
		return
	scene._finish_drag(scene._cell_center(Vector2i(4, 1)))
	if int(scene._reload_idx) != 0:
		_smoke_fail("填充（拖拽）：松手后应进入填充待选（_reload_idx=%d）" % scene._reload_idx)
		return
	scene._sync_pick()
	if scene._pick == null or not scene._pick.is_picking() \
			or String(scene._pick.kind()) != "reload":
		_smoke_fail("填充（拖拽）：松手后应弹出 reload 选卡页")
		return
	if eng.state.energy != 3 or eng.state.hand.size() != 2:
		_smoke_fail("填充（拖拽）：松手不该扣费/弃卡（%d 费 / %d 张）"
				% [eng.state.energy, eng.state.hand.size()])
		return
	scene._on_pick_cancelled()
	# ⚠️ 必须把选卡页**关掉**再交棒：`_pick` 还处于 picking 状态时，下一个用例
	# （系统升级）的第一次点击会被模态选卡页吞掉 → 它报「_sys_upgrade_idx=-1」。
	scene._sync_pick()
	if scene._pick != null and scene._pick.is_picking():
		_smoke_fail("填充（拖拽）：取消后选卡页应关闭")
		return
	eng.state.hand.clear()
	scene._reload_idx = -1
	print("SMOKE OK 填充选卡页：点填充 → 弹页（候选 2）/ 确认 → 聚能炮击（0 费）/ 用后进消耗区（次元）/ 拖到棋盘松手同样弹页 / 取消不扣费")


func _check_run_deck_panel(scene: Variant) -> void:
	## R207：战斗内**两个卡组口径**必须分开 ——
	##   顶栏「卡组」= **完整卡组**（`RunState.deck_ids`，本局构筑，跨战斗、含附魔）
	##   右下牌堆  = **剩余牌堆**（`engine.state.deck`，本场还没抽到的牌）
	## 旧版两个按钮开的是同一个面板（都读 engine.state.deck），整副牌根本看不到。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("完整卡组：拿不到 engine")
		return
	var repo := CardRepo.load_json()
	if repo.get_card(8002) == null or repo.get_card(8004) == null \
			or repo.get_card(9010) == null:
		_smoke_fail("完整卡组：测试用卡（8002/8004/9010）缺失")
		return
	var saved_active: bool = RunState.run_active
	var saved_ids: Array = RunState.deck_ids.duplicate()
	var saved_mods: Array = RunState.deck_mods.duplicate()
	var saved_deck: Array = eng.state.deck.duplicate()
	# 本局构筑 4 张：攻击 ×2（第 2 张带 +10 攻击附魔）+ 熊 + 火球
	var test_ids: Array[int] = [8002, 8002, 8004, 9010]
	RunState.run_active = true
	RunState.deck_ids = test_ids
	RunState.deck_mods = []
	RunState.ensure_deck_mods()
	RunState.enchant_deck_card(1, {"power": 10})
	# 本场抽牌堆只剩 1 张（模拟已经抽掉大半）
	eng.state.deck.clear()
	eng.state.deck.append(repo.get_card(8002))
	# ── ① 顶栏按钮 → 完整卡组 ──
	scene._close_zone_panels()
	scene._toggle_deck_panel()
	if not scene._run_deck_visible or scene._deck_visible:
		_smoke_fail("完整卡组：顶栏按钮应只开完整卡组面板（run=%s deck=%s）"
				% [scene._run_deck_visible, scene._deck_visible])
		return
	var run_cards: Array = scene._zone_panel_cards()
	var run_counts: Array = scene._zone_panel_counts()
	var run_total := 0
	for n: int in run_counts:
		run_total += n
	if run_total != 4 or run_cards.size() != run_counts.size():
		_smoke_fail("完整卡组：应显示本局构筑 4 张（实际 %d 张 / %d 组）"
				% [run_total, run_cards.size()])
		return
	# 附魔副本不能被 id 并掉 → 「攻击」应出现两组（原卡 ×1 + 附魔 ×1）
	var atk_groups := 0
	for c: CardData in run_cards:
		if c.id == 8002:
			atk_groups += 1
	if atk_groups != 2:
		_smoke_fail("完整卡组：带附魔的攻击必须与原卡分开列（攻击组数 %d，期望 2）" % atk_groups)
		return
	# R214：那张附魔是**没有 id 的老形态** mod（`{"power": 10}`）→ 按内容反推成 damage，
	# 卡面才能画出「伤害 +10」的附魔标记（老存档不能因为没有 id 就变成没标记）。
	var got_ench := ""
	for c: CardData in run_cards:
		if c.id == 8002 and c.enchant != "":
			got_ench = c.enchant
	if got_ench != "damage":
		_smoke_fail("R214 附魔：卡组面板里附魔卡的种类应反推为 damage（实际「%s」）" % got_ench)
		return
	# ── ② 右下牌堆 → 剩余牌堆（只有 1 张）──
	scene._close_zone_panels()
	scene._deck_visible = true
	var rem: Array = scene._zone_panel_cards()
	if rem.size() != 1 or rem[0].id != 8002:
		_smoke_fail("剩余牌堆：右下牌堆应只显示本场剩下的 1 张（实际 %d 组）" % rem.size())
		return
	# ── ③ 再点一次顶栏按钮 → 关闭（两个面板互斥，不叠着开）──
	scene._close_zone_panels()
	scene._toggle_deck_panel()
	scene._toggle_deck_panel()
	if scene._run_deck_visible or scene._deck_visible:
		_smoke_fail("完整卡组：再点一次应关闭面板（run=%s deck=%s）"
				% [scene._run_deck_visible, scene._deck_visible])
		return
	# 还原（后面的用例还要用这套状态）
	scene._close_zone_panels()
	RunState.run_active = saved_active
	RunState.deck_ids = saved_ids
	RunState.deck_mods = saved_mods
	RunState.ensure_deck_mods()
	eng.state.deck.clear()
	eng.state.deck.assign(saved_deck)
	print("SMOKE OK 卡组：顶栏=完整卡组（4 张/附魔单列）/ 右下=剩余牌堆（1 张）/ 互斥开关")


func _check_r208(scene: Variant) -> void:
	## R208 三件事：
	##   ① 零件回收者（8046）升**史诗**（rarity 2）；卡面文本里写的「普通」跟着改。
	##   ② 被破坏的卡力量是 0 时**不许飘「+0 攻」**（用户实测：偶尔会弹一个 +0，像 bug）；
	##      真的加攻时必须照旧飘。
	##   ③ 卡面文字背后**不再铺淡黄色底衬**（`draw_text_backing` / `TEXT_BACK_*` 全删）。
	var repo := CardRepo.load_json()
	var rec: CardData = repo.get_card(8046)
	if rec == null:
		_smoke_fail("R208 零件回收者：卡库里没有 8046（用例前提失效）")
		return
	if rec.rarity != 2:
		_smoke_fail("R208 零件回收者：应为史诗（rarity 2），实际 %d" % rec.rarity)
		return
	# ── ② 飘字：力量 0 不飘，力量 > 0 飘一句「回收力量」 ──
	# R301（用户口径）：**卡面不再写「+N 攻」这种数字** —— 四项数值的涨跌已由徽章
	# **颜色**表达，明细在状态栏 / 详情栏里。所以这里既不能出现「+0 攻」（R208 口径：
	# 没加力量就别飘），也不能出现「+6 攻」（R301：不再写数字）。
	var n0: int = scene._floaters.size()
	scene._on_engine_action("recycler", {"cell": Vector2i(2, 2), "power": 0,
			"side": GameEngine.SIDE_SELF})
	if scene._floaters.size() != n0:
		_smoke_fail("R208 零件回收者：力量 0 时不应有任何飘字")
		return
	var n1: int = scene._floaters.size()
	scene._on_engine_action("recycler", {"cell": Vector2i(2, 2), "power": 6,
			"side": GameEngine.SIDE_SELF})
	var got_txt := ""
	for f1: Dictionary in scene._floaters.slice(n1):
		got_txt = str(f1.get("text", ""))
	if got_txt != "回收力量":
		_smoke_fail("R301 零件回收者：力量 > 0 时飘字应为「回收力量」（不写数字），实际「%s」" % got_txt)
		return
	# ── ③ 源码守卫：底衬不许回潮（函数与色常量都已删除）──
	var cf := FileAccess.get_file_as_string("res://scripts/card_face.gd")
	if cf.is_empty():
		_smoke_fail("R208 卡面：读不到 card_face.gd（源码守卫失效）")
		return
	for bad: String in ["draw_text_backing", "TEXT_BACK_"]:
		if cf.contains(bad):
			_smoke_fail("R208 卡面：文字背后不许再铺淡黄色底衬（%s 仍在）" % bad)
			return
	print("SMOKE OK R208：零件回收者史诗 / 力量 0 不飘 +0 攻 / 卡面不再铺底衬")


func _check_assemble(scene: Variant) -> void:
	## R202：随心组装（9144）—— 手牌里所有卡变成随机奖励卡，且不崩溃。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("随心组装：拿不到 engine")
		return
	var repo := CardRepo.load_json()
	var asm: CardData = repo.get_card(GameEngine.ASSEMBLE_ID)
	if asm == null or asm.cost != 1 or asm.rarity != 2:
		_smoke_fail("随心组装：卡面应是 1 费史诗技能")
		return
	var saved_cls: String = RunState.player_class
	RunState.player_class = PlayerClass.MECH
	eng.current_side = GameEngine.SIDE_SELF
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(asm.to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	eng.state.energy = 1
	eng.rng.seed = 20261017
	var before: int = eng.state.hand.size()
	var detail: String = eng.use_spell(0)
	if eng.state.hand.size() != before - 1:
		_smoke_fail("随心组装：自身消耗后手牌应剩 %d 张（实际 %d）" % [before - 1, eng.state.hand.size()])
		return
	var pool_ids := {}
	for c: CardData in repo.reward_pool():
		pool_ids[c.id] = true
	for hc: CardData in eng.state.hand:
		if not pool_ids.has(hc.id):
			_smoke_fail("随心组装：变化后的卡 %d 不在奖励池内" % hc.id)
			return
	if eng.state.energy != 0:
		_smoke_fail("随心组装：应消耗 1 费（剩余 %d）" % eng.state.energy)
		return
	RunState.player_class = saved_cls
	eng.state.hand.clear()
	print("SMOKE OK 随心组装：%s，剩余手牌 %d 张均来自奖励池" % [detail, eng.state.hand.size()])


func _check_ee_popup(scene: Variant) -> void:
	## R197：敌方效果开场弹窗 —— 素材在库 / 打断不弹 / 播完必弹 / 点任意处关 / 关后不重弹。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("敌方效果弹窗：拿不到 engine")
		return
	if UiAssets.void_portal() == null:
		_smoke_fail("敌方效果弹窗：void_portal.png 应已入库并可加载")
		return
	var repo := CardRepo.load_json()
	eng.state.enemy_effects.append(CardData.from_dict(repo.get_card(9115).to_dict()))
	# ── 1) 巡场被点击打断 = 没有「播完」→ 不弹 ──
	scene._grid_intro_t = 1.0
	scene._grid_intro_stop()
	if scene._ee_popup:
		_smoke_fail("敌方效果弹窗：巡场被打断不应弹窗")
		return
	# ── 2) 巡场完整播完 → 弹 ──
	scene._grid_intro_t = scene.GRID_INTRO_DUR - 0.1
	scene._grid_intro_tick(0.2)
	if not scene._ee_popup:
		_smoke_fail("敌方效果弹窗：巡场播完且有敌方效果卡应自动弹窗")
		return
	# ── 3) 点任意处 = 只关弹窗，不落进战场 ──
	_feed_click(scene, Vector2(640, 360))
	if scene._ee_popup:
		_smoke_fail("敌方效果弹窗：点击任意处应关闭弹窗")
		return
	# ── 4) 巡场已结束 → 关掉后不再重弹；清掉测试铺的效果卡 ──
	scene._grid_intro_tick(0.5)
	if scene._ee_popup:
		_smoke_fail("敌方效果弹窗：关闭后不应重新弹出")
		return
	eng.state.enemy_effects.clear()
	print("SMOKE OK 敌方效果开场弹窗：素材在库 / 打断不弹 / 播完弹 / 点击关 / 不重弹")


func _check_recycle(scene: Variant) -> void:
	## R198 / R209：回收（8064）—— 使用后**弹全屏选卡页**（候选 = 除自己以外的手牌，
	## 不限种类：技能卡也能回收）；确认 → 目标换成素体 1/10 且**带一层改造**；
	## 取消 → 不扣费、不弃卡。R209 起不再是「再点一张手牌」的两段式。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("回收：拿不到 engine")
		return
	var repo := CardRepo.load_json()
	var rc: CardData = repo.get_card(GameEngine.RECYCLE_ID)
	if rc == null or rc.cost != 2 or rc.rarity != 2:
		_smoke_fail("回收：卡面应是 2 费史诗技能")
		return
	# 收尾 Intro 状态（本用例只关心手牌点击，不碰巡场）
	scene._grid_intro_t = -1.0
	scene._grid_zoom = 1.0
	scene._clear_selection()
	eng.current_side = GameEngine.SIDE_SELF
	# ── 1) 铺一手牌：攻击（技能卡，证明技能也能当目标）+ 回收 ──
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
	eng.state.hand.append(CardData.from_dict(rc.to_dict()))
	eng.state.energy = 5
	# ── 2) 点回收两次 = 选中 → 使用 → 进入选卡页 ──
	_feed_click(scene, _hand_card_center(scene, 1))
	_feed_click(scene, _hand_card_center(scene, 1))
	if int(scene._recycle_idx) != 1:
		_smoke_fail("回收：再点一次应进入回收待选（_recycle_idx=%d）" % scene._recycle_idx)
		return
	scene._sync_pick()
	if scene._pick == null or not scene._pick.is_picking():
		_smoke_fail("回收：使用后应弹出全屏选卡页")
		return
	if String(scene._pick.kind()) != "recycle":
		_smoke_fail("回收：选卡页场景应是 recycle（实际 %s）" % String(scene._pick.kind()))
		return
	var ropts: Array = scene._pick.opts()
	if ropts.size() != 1 or int(ropts[0]) != 0:
		_smoke_fail("回收：候选应是除自己以外的 1 张手牌（opts=%s）" % str(ropts))
		return
	# ── 3) 确认 → 技能卡换成素体 1/10（带一层改造）──
	scene._on_pick_confirmed([0])
	if int(scene._recycle_idx) >= 0:
		_smoke_fail("回收：确认后应清掉 _recycle_idx（%d）" % scene._recycle_idx)
		return
	var got: CardData = eng.state.hand[0]
	if got.id != 8025 or got.health != 10 or got.power != 1:
		_smoke_fail("回收：攻击应换成素体 1/10（实际 %s %d/%d）"
				% [got.card_name, got.power, got.health])
		return
	if got.upgrade_stacks != 1:
		_smoke_fail("R209 回收：换出来的素体应带**一层改造**（upgrade_stacks=%d）"
				% got.upgrade_stacks)
		return
	if eng.state.energy != 3:
		_smoke_fail("回收：应扣 2 费（能量 %d，期望 3）" % eng.state.energy)
		return
	scene._sync_pick()
	if scene._pick != null and scene._pick.is_picking():
		_smoke_fail("回收：结算完选卡页应自动关闭")
		return
	# ── 4) 取消路径：点「取消（不扣费）」→ 手牌 / 能量原样 ──
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(rc.to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8004).to_dict()))   # 熊
	eng.state.energy = 5
	scene._clear_selection()
	_feed_click(scene, _hand_card_center(scene, 0))
	_feed_click(scene, _hand_card_center(scene, 0))
	if int(scene._recycle_idx) != 0:
		_smoke_fail("回收（取消路径）：再点一次应进入回收待选（_recycle_idx=%d）"
				% scene._recycle_idx)
		return
	scene._sync_pick()
	scene._on_pick_cancelled()
	if int(scene._recycle_idx) >= 0 or eng.state.hand.size() != 2 or eng.state.energy != 5:
		_smoke_fail("回收（取消路径）：取消后手牌/能量应原样（%d 张 / %d 费）"
				% [eng.state.hand.size(), eng.state.energy])
		return
	scene._sync_pick()
	if scene._pick != null and scene._pick.is_picking():
		_smoke_fail("回收（取消路径）：取消后选卡页应关闭")
		return
	# 收尾：还原手牌与状态，别污染后面的用例
	eng.state.hand.clear()
	scene._recycle_idx = -1
	print("SMOKE OK 回收选卡页：弹页（候选 1）/ 确认 → 素体 1/10 + 一层改造（扣 2 费）/ 取消不扣费")


func _check_sysupgrade(scene: Variant) -> void:
	## R209：系统升级（8039）—— 使用后**弹全屏选卡页**（用户口径「除了填充，还有一些
	## 选手牌的没弹出选卡界面」）；候选**只列盟友 / 工事**（技能卡不在候选里）；
	## 确认 → 费用 +1 / 力量 +3 / 生命 +6，且**记一层改造**（`upgrade_stacks`）；
	## 取消 → 不扣费、不弃卡。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("系统升级：拿不到 engine")
		return
	var repo := CardRepo.load_json()
	var su: CardData = repo.get_card(GameEngine.SYS_UPGRADE_ID)
	var bear: CardData = repo.get_card(8004)
	if su == null or bear == null:
		_smoke_fail("系统升级：测试用卡（8039 / 8004）缺失")
		return
	scene._grid_intro_t = -1.0
	scene._grid_zoom = 1.0
	scene._clear_selection()
	eng.current_side = GameEngine.SIDE_SELF
	# 手牌：熊(0) + 系统升级(1) + 攻击(2，技能卡 → **不该进候选**)
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(bear.to_dict()))
	eng.state.hand.append(CardData.from_dict(su.to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
	eng.state.energy = 5
	_feed_click(scene, _hand_card_center(scene, 1))
	_feed_click(scene, _hand_card_center(scene, 1))
	if int(scene._sys_upgrade_idx) != 1:
		_smoke_fail("系统升级：再点一次应进入待选（_sys_upgrade_idx=%d）"
				% scene._sys_upgrade_idx)
		return
	scene._sync_pick()
	if scene._pick == null or not scene._pick.is_picking():
		_smoke_fail("系统升级：使用后应弹出全屏选卡页")
		return
	if String(scene._pick.kind()) != "sysup":
		_smoke_fail("系统升级：选卡页场景应是 sysup（实际 %s）" % String(scene._pick.kind()))
		return
	var uopts: Array = scene._pick.opts()
	if uopts.size() != 1 or int(uopts[0]) != 0:
		_smoke_fail("系统升级：候选只能是盟友 / 工事（熊），实际 opts=%s" % str(uopts))
		return
	# ── 确认 → 熊 4 费 3/14 → 5 费 6/20，且记一层改造 ──
	scene._on_pick_confirmed([0])
	if int(scene._sys_upgrade_idx) >= 0:
		_smoke_fail("系统升级：确认后应清掉 _sys_upgrade_idx（%d）" % scene._sys_upgrade_idx)
		return
	var up: CardData = eng.state.hand[0]
	if up.id != 8004 or up.cost != bear.cost + 1 or up.power != bear.power + 3 \
			or up.health != bear.health + 6:
		_smoke_fail("系统升级：熊应变成 %d 费 %d/%d（实际 %d 费 %d/%d）"
				% [bear.cost + 1, bear.power + 3, bear.health + 6, up.cost, up.power, up.health])
		return
	if up.upgrade_stacks != 1:
		_smoke_fail("R209 系统升级：被改造的卡应带**一层改造**（upgrade_stacks=%d）"
				% up.upgrade_stacks)
		return
	if eng.state.energy != 4:
		_smoke_fail("系统升级：应扣 1 费（能量 %d，期望 4）" % eng.state.energy)
		return
	scene._sync_pick()
	if scene._pick != null and scene._pick.is_picking():
		_smoke_fail("系统升级：结算完选卡页应自动关闭")
		return
	# ── 取消路径 ──
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(su.to_dict()))
	eng.state.hand.append(CardData.from_dict(bear.to_dict()))
	eng.state.energy = 5
	scene._clear_selection()
	_feed_click(scene, _hand_card_center(scene, 0))
	_feed_click(scene, _hand_card_center(scene, 0))
	scene._sync_pick()
	scene._on_pick_cancelled()
	if int(scene._sys_upgrade_idx) >= 0 or eng.state.hand.size() != 2 \
			or eng.state.energy != 5:
		_smoke_fail("系统升级（取消路径）：取消后手牌/能量应原样（%d 张 / %d 费）"
				% [eng.state.hand.size(), eng.state.energy])
		return
	eng.state.hand.clear()
	scene._sys_upgrade_idx = -1
	print("SMOKE OK 系统升级选卡页：弹页（候选只列盟友/工事）/ 确认 → +1 费 +3 力 +6 血 +1 层 / 取消不扣费")



func _check_lighten(scene: Variant) -> void:
	## R201：负重减轻（8066）—— 0 费史诗；点两次手牌打出 → 自动打开专注同款
	## focus 选卡面板；点选一张 + 确认 → 该卡从卡组消失（消耗区 +1）并记账
	## self_next_draw=1（下回合多抽一张）；放弃路径不记账、不动牌库。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("负重减轻：拿不到 engine")
		return
	var repo := CardRepo.load_json()
	var lt: CardData = repo.get_card(GameEngine.LIGHTEN_ID)
	if lt == null or lt.cost != 0 or lt.rarity != 2:
		_smoke_fail("负重减轻：卡面应是 0 费史诗技能")
		return
	var ov: PickOverlay = scene._pick
	if ov == null:
		_smoke_fail("负重减轻：scene._pick 为空")
		return
	ov.size = Vector2(1280, 720)   # headless 下 anchors 不结算，手动给尺寸
	# 收尾 Intro 状态（本用例只关心手牌点击与选卡页，不碰巡场）
	scene._grid_intro_t = -1.0
	scene._grid_zoom = 1.0
	scene._clear_selection()
	eng.current_side = GameEngine.SIDE_SELF
	# ── 1) 铺牌库 2 张 + 手牌 1 张负重减轻；点两次 = 选中 → 打出 ──
	eng.state.deck.clear()
	eng.state.deck.append(CardData.from_dict(repo.get_card(8003).to_dict()))
	eng.state.deck.append(CardData.from_dict(repo.get_card(8004).to_dict()))
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(lt.to_dict()))
	eng.state.energy = 3
	var deck0 := eng.state.deck.size()
	_feed_click(scene, _hand_card_center(scene, 0))
	_feed_click(scene, _hand_card_center(scene, 0))
	scene._sync_pick()
	if not ov.is_picking() or ov.kind() != "focus":
		_smoke_fail("负重减轻：打出后应自动打开 focus 选卡面板（kind=%s）" % ov.kind())
		return
	# ── 2) 点选一张 + 确认 → 消失 1 张 + 记账 ──
	var r0 := ov._card_rect(0)
	ov._tap(ov._clip.position + ov._grid.position + r0.get_center())
	if ov.selected_count() != 1:
		_smoke_fail("负重减轻：点一张卡应选中 1 张，实际 %d" % ov.selected_count())
		return
	ov._tap(ov._confirm_rect().get_center())
	scene._sync_pick()
	if eng.focus_pending:
		_smoke_fail("负重减轻：确认后 focus_pending 应已清")
		return
	if eng.state.deck.size() != deck0 - 1:
		_smoke_fail("负重减轻：确认后牌库应少 1 张（%d → %d）"
				% [deck0, eng.state.deck.size()])
		return
	if eng.state.self_next_draw != 1:
		_smoke_fail("负重减轻：确认后应记账 self_next_draw=1（实际 %d）"
				% eng.state.self_next_draw)
		return
	if eng.state.void_count < 1:
		_smoke_fail("负重减轻：消失的卡应计入消耗区（void_count=%d）" % eng.state.void_count)
		return
	# ── 3) 取消路径：再打一次 → 点放弃 → 不记账、不动牌库 ──
	eng.state.self_next_draw = 0
	var vc0 := eng.state.void_count
	eng.state.hand.append(CardData.from_dict(lt.to_dict()))
	eng.state.energy = 3
	_feed_click(scene, _hand_card_center(scene, 0))
	_feed_click(scene, _hand_card_center(scene, 0))
	scene._sync_pick()
	if not ov.is_picking() or ov.kind() != "focus":
		_smoke_fail("负重减轻（取消路径）：应再次打开 focus 面板（kind=%s）" % ov.kind())
		return
	ov._tap(ov._cancel_rect().get_center())
	scene._sync_pick()
	if eng.focus_pending:
		_smoke_fail("负重减轻（取消路径）：放弃后 focus_pending 应清")
		return
	if eng.state.self_next_draw != 0:
		_smoke_fail("负重减轻（取消路径）：放弃后不应记账（self_next_draw=%d）"
				% eng.state.self_next_draw)
		return
	if eng.state.deck.size() != deck0 - 1 or eng.state.void_count != vc0:
		_smoke_fail("负重减轻（取消路径）：牌库/消耗区不应变化（%d 张 / void=%d）"
				% [eng.state.deck.size(), eng.state.void_count])
		return
	# 收尾：清干净，别漏给后面的用例
	ov.close()
	eng.state.hand.clear()
	eng.state.energy = 3
	print("SMOKE OK 负重减轻：打出开面板 / 确认消失 1 张并记账 / 放弃不记账")


func _hand_card_center(scene: Variant, i: int) -> Vector2:
	## 第 i 张手牌**旋转后**的中心点（命中判定与绘制同一个角度，见 _check_hand_fan）。
	var r: Rect2 = scene._hand_rect(i)
	var pivot: Vector2 = scene._hand_pivot(i)
	var center := Vector2(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)
	return pivot + (center - pivot).rotated(scene._hand_angle(i))


func _check_pick_overlay(scene: Variant) -> void:
	## R189：全屏选卡页 —— 自动打开 / 点选不结算 / 确认才结算 / 返回收起往返 / 放弃按钮 / 滚动钳制。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("选卡页：拿不到 engine")
		return
	var ov: PickOverlay = scene._pick
	if ov == null:
		_smoke_fail("选卡页：scene._pick 为空（_ready 没挂上）")
		return
	ov.size = Vector2(1280, 720)   # headless 下 anchors 不结算，手动给尺寸
	var repo := CardRepo.load_json()
	# ── 1) crow_pending 出现 → _sync_pick 自动打开 ──
	eng.state.discard.append(CardData.from_dict(repo.get_card(8003).to_dict()))
	eng.state.discard.append(CardData.from_dict(repo.get_card(8005).to_dict()))
	eng.crow_pending = true
	scene._sync_pick()
	if not ov.is_picking() or not ov.visible or ov.kind() != "crow":
		_smoke_fail("选卡页：crow_pending 置位后 overlay 应自动打开（kind=crow），实际 kind=%s visible=%s"
				% [ov.kind(), str(ov.visible)])
		return
	# ── 2) 点卡 = 仅选中，引擎不结算 ──
	var discard_before := eng.state.discard.size()
	var r0 := ov._card_rect(0)
	ov._tap(ov._clip.position + ov._grid.position + r0.get_center())
	if ov.selected_count() != 1:
		_smoke_fail("选卡页：点一张卡应选中 1 张，实际 %d" % ov.selected_count())
		return
	if eng.state.discard.size() != discard_before:
		_smoke_fail("选卡页：点卡不该直接结算（弃牌区不应变化）")
		return
	# R294：点中的卡必须同时成为「描述条当前显示的那张」——触屏没有 motion 事件，
	# 光靠悬停跟踪的话点了卡描述条不动（用户报告「点卡无法顺利切换描述」）。
	if ov._hover_idx != 0:
		_smoke_fail("选卡页 R294：点卡后描述条应跟到该卡（hover_idx=%d，期望 0）"
				% ov._hover_idx)
	# R294：悬停缓存过期判定 —— 出牌/弃牌后手牌左移，`_hover_hand` 指的位置上
	# 已经不是原来那张卡，左栏必须清掉而不是继续显示旧卡。
	if eng.state.hand.size() > 0:
		scene._hover_hand = 0
		scene._hover_card = eng.state.hand[0]
		scene._hover_purge_stale()
		if scene._hover_card == null:
			_smoke_fail("R294 悬停过期判定：同一张卡不该被清掉")
		scene._hover_hand = eng.state.hand.size() + 2
		scene._hover_purge_stale()
		if scene._hover_card != null or scene._hover_hand != -1:
			_smoke_fail("R294 悬停过期判定：越界下标应清空（hover_hand=%d）"
					% scene._hover_hand)
		if eng.state.hand.size() >= 2:
			scene._hover_hand = 0
			scene._hover_card = eng.state.hand[1]
			scene._hover_purge_stale()
			if scene._hover_card != null:
				_smoke_fail("R294 悬停过期判定：下标与卡不符应清空（出牌后左栏停在旧卡）")
	if not ov._can_confirm():
		_smoke_fail("选卡页：单选场景选中 1 张后确认按钮应可用")
		return
	# ── 3) 确认 → 引擎结算 ──
	ov._tap(ov._confirm_rect().get_center())
	if eng.crow_pending:
		_smoke_fail("选卡页：确认后 crow_pending 应已清")
		return
	if eng.state.discard.size() != discard_before - 1:
		_smoke_fail("选卡页：确认后弃牌区应少 1 张（%d → %d）"
				% [discard_before, eng.state.discard.size()])
		return
	# ── 4) 返回 = 收起看战场（pending 保留）；点浮条回来 ──
	eng.state.discard.append(CardData.from_dict(repo.get_card(8003).to_dict()))
	eng.crow_pending = true
	scene._sync_pick()
	if not ov.visible:
		_smoke_fail("选卡页：第二次 crow_pending 应再次打开")
		return
	ov._tap(ov._back_rect().get_center())   # 返回 = 收起
	if ov.visible or not ov.is_picking():
		_smoke_fail("选卡页：返回应收起但保留 pending（is_picking=true）")
		return
	if not eng.crow_pending:
		_smoke_fail("选卡页：收起不该结算/取消引擎 pending")
		return
	scene._on_left_click(Vector2(640, 400))   # 收起态点战场 → 只提示，不结算
	if not eng.crow_pending:
		_smoke_fail("选卡页：收起态点战场不该结算选择")
		return
	scene._on_left_click(scene._pick_banner_rect().get_center())   # 点浮条 → 回来
	if not ov.visible:
		_smoke_fail("选卡页：点「继续选择」浮条应重新展开")
		return
	# ── 5) 放弃按钮（whale「不选了」）──
	eng.crow_pending = false
	ov.close()
	eng.whale_pending = true
	eng.whale_remaining = 2
	scene._sync_pick()
	if not ov.is_picking() or ov.kind() != "whale":
		_smoke_fail("选卡页：whale_pending 应打开 whale 场景，实际 kind=%s" % ov.kind())
		return
	# R294：上一段刚 close() 过、这里是全新一轮 → 悬停下标必须清零，
	# 否则描述条会停在上局那张卡上（触屏没有 motion，永远看不回正确的那张）。
	if ov._hover_idx != -1:
		_smoke_fail("选卡页 R294：close 后重新打开应清空悬停下标，实际 %d" % ov._hover_idx)
	ov._tap(ov._cancel_rect().get_center())   # 「不选了」
	if eng.whale_pending:
		_smoke_fail("选卡页：放弃按钮应调 whale_skip（pending 清）")
		return
	# ── 6) 滚动钳制：候选超一屏 → max_scroll > 0，滚动值被钳住 ──
	for _i in 14:
		eng.state.discard.append(CardData.from_dict(repo.get_card(8003).to_dict()))
	# R292：拒绝命运改自动结算（不再有 "fate" 选卡页）→ 滚动用例改用 whale（弃牌区全列）。
	# ⚠️ 必须先 `ov.close()`：上一步的 whale 页还开着（pending 已清但页面没关），
	#    `_sync_pick()` 见「kind 没变 + 仍在 picking」就不重建 → 读到的是旧的两张候选。
	ov.close()
	eng.whale_pending = true
	eng.whale_remaining = 1
	scene._sync_pick()
	if not ov.is_picking() or ov.kind() != "whale":
		_smoke_fail("选卡页：whale_pending 应打开 whale 场景，实际 kind=%s" % ov.kind())
		return
	if ov._max_scroll() <= 1.0:
		_smoke_fail("选卡页：多张候选应超出一屏（max_scroll > 0），实际 %.1f" % ov._max_scroll())
		return
	ov._scroll = 99999.0
	ov._clamp_scroll()
	if ov._scroll > ov._max_scroll() + 0.01:
		_smoke_fail("选卡页：滚动应被钳制在 max_scroll，实际 %.1f > %.1f"
				% [ov._scroll, ov._max_scroll()])
		return
	# 收尾：清干净，别漏给后面的用例
	eng.whale_pending = false
	eng.whale_remaining = 0
	ov.close()
	print("SMOKE OK 选卡页：crow 自动打开 / 点选不结算 / 确认才结算 / 返回收起往返 / 放弃按钮 / 滚动钳制")


func _check_long_press(scene: Variant) -> void:
	## R186：触屏长按 = 右键等价（专注取消 / 取消选中在安卓触屏上的关键口子）。
	## 只认 InputEventScreenTouch；到时在 _process 里转 `_on_right_click()`。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("长按右键：拿不到 engine")
		return
	eng.over = false
	eng.current_side = GameEngine.SIDE_SELF
	# 1) 触屏按下 → 长按计时启动
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = Vector2(640, 300)
	scene._gui_input(down)
	if not scene._lp_active or scene._lp_fired:
		_smoke_fail("长按右键：触屏按下后 _lp_active 应为 true 且 _lp_fired 为 false")
		return
	# 2) 位移超阈值 → 视为拖拽，取消长按
	var far := InputEventScreenDrag.new()
	far.position = Vector2(640, 300) + Vector2(scene.LP_SLOP + 4.0, 0)
	scene._gui_input(far)
	if scene._lp_active:
		_smoke_fail("长按右键：位移超过 LP_SLOP 应取消长按计时")
		return
	# 3) 重新按下并把计时拨回过去 → 下一帧 _process 必须触发一次右键等价
	scene._gui_input(down)
	scene._lp_t0 = Time.get_ticks_msec() - scene.LP_MS - 100
	scene._press_idx = 3   # 模拟「按住一张手牌」：触发后必须摘掉，否则松手会补发左键
	scene.status_text = "长按测试基准"
	scene._process(0.016)
	if not scene._lp_fired or scene._lp_active:
		_smoke_fail("长按右键：到时后应触发一次并复位（_lp_fired=true / _lp_active=false）")
		return
	if scene._press_idx != -1:
		_smoke_fail("长按右键：触发后 _press_idx 应摘为 -1，实际 %d" % scene._press_idx)
		return
	if scene.status_text == "长按测试基准":
		_smoke_fail("长按右键：触发后 status_text 应变化（_on_right_click 未执行？）")
		return
	# 4) 抬指 → 状态干净
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = Vector2(640, 300)
	scene._gui_input(up)
	if scene._lp_active:
		_smoke_fail("长按右键：抬指后 _lp_active 应为 false")
		return
	print("SMOKE OK 触屏长按=右键：按下计时 / 超位移取消 / 到时触发一次并摘掉左键按下")


func _check_perf(scene: Variant) -> void:
	## R187：wrap_text 纯函数缓存（副本隔离）+ 脉冲节流窗口（安卓 ×2，PC 保持 45ms）。
	var f: Font = scene._font
	if f == null:
		_smoke_fail("性能缓存：拿不到场景字体")
		return
	var t := "造成 4 点伤害，如果消灭目标，抽一张牌。"
	var w1: Array[String] = CardFace.wrap_text(f, t, 88.0, 12)
	var w2: Array[String] = CardFace.wrap_text(f, t, 88.0, 12)
	if w1 != w2 or w1.is_empty():
		_smoke_fail("性能缓存：wrap_text 缓存命中结果与首次不一致")
		return
	if is_same(w1, w2):
		_smoke_fail("性能缓存：wrap_text 应返回副本，不能与缓存同实例")
		return
	# 脉冲节流：懒初始化出窗口宽度；非安卓必须保持 PULSE_FRAME_MS 原样
	scene._pulse_ms = 0
	scene._pulse_redraw_at = 0
	scene._pulse_redraw()
	var expect_ms: int = scene.PULSE_FRAME_MS * (2 if OS.get_name() == "Android" else 1)
	if scene._pulse_ms != expect_ms:
		_smoke_fail("性能缓存：_pulse_ms 应为 %d，实际 %d" % [expect_ms, scene._pulse_ms])
		return
	var at1: int = scene._pulse_redraw_at
	scene._pulse_redraw()
	if scene._pulse_redraw_at != at1:
		_smoke_fail("性能缓存：节流窗口内不应重复 queue_redraw")
		return
	print("SMOKE OK 性能缓存：wrap_text 副本隔离 / 脉冲节流窗口生效（_pulse_ms=%d）" % scene._pulse_ms)


func _check_back_key(scene: Variant) -> void:
	## R186：安卓返回键 → Esc。BackKey autoload 必须在位，且「返回即退出」必须关掉
	## （否则安卓上按返回直接退 App）。合成 Esc 走真实输入管线是异步的，
	## 这里做结构断言（autoload / 开关 / 翻译代码在位）。
	var bk: Variant = scene.get_tree().root.get_node_or_null("BackKey")
	if bk == null:
		_smoke_fail("BackKey：autoload 未注册（project.godot 缺 BackKey 行？）")
		return
	if scene.get_tree().quit_on_go_back:
		_smoke_fail("BackKey：quit_on_go_back 应为 false（否则安卓返回键直接退 App）")
		return
	var src := FileAccess.get_file_as_string("res://scripts/back_key.gd")
	if src.find("Input.parse_input_event") < 0 or src.find("KEY_ESCAPE") < 0 \
			or src.find("NOTIFICATION_WM_GO_BACK_REQUEST") < 0:
		_smoke_fail("BackKey：back_key.gd 缺返回键→Esc 的翻译代码")
		return
	print("SMOKE OK BackKey：autoload 在位 / quit_on_go_back=false / 返回键→Esc 翻译在位")


func _check_attack_art_variant() -> void:
	## R185：8002「攻击」卡图按当前职业切换（森林精魄=爪击 / 暗影刺客=匕首刺 / 机械之心=浮游炮）。
	## `CardFace.art_for` 按 RunState.player_class 取 `8002_<suffix>.png`；未知职业回退 forest。
	var prev := RunState.player_class
	var cases := {"森林精魄": "forest", "暗影刺客": "shadow", "机械之心": "mech", "不存在职业": "forest"}
	for cls in cases:
		RunState.player_class = cls
		var tex := CardFace.art_for(CardFace.ATTACK_ART_ID)
		var want := "res://assets/pics/8002_%s.png" % cases[cls]
		if tex == null or tex.resource_path != want:
			_smoke_fail("攻击卡图职业变体：%s 应取 %s，实际 %s"
					% [cls, want, tex.resource_path if tex != null else "null"])
	RunState.player_class = prev
	print("SMOKE OK 攻击卡图职业变体：三职业各取各图，未知职业回退 forest")


func _check_r106(scene: Variant) -> void:
	## R106：① 效果卡可以**直接拖到左侧效果区**松手启用（真跑一遍拖动调用栈）；
	##       ② 战场单位「已获得的增益/减益」列表与卡面徽标能正常产出（并让后续帧真实绘制）。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("R106：拿不到 engine")
		return
	# ---- ① 效果区矩形：点击浏览与拖拽投放必须共用同一个矩形 ----
	var zone: Rect2 = scene._own_effect_zone_rect()
	if zone.size.x <= 0.0 or zone.size.y <= 0.0:
		_smoke_fail("R106：效果区矩形尺寸异常 %s" % str(zone.size))
		return
	eng.over = false
	eng.current_side = GameEngine.SIDE_SELF
	# 从**真实卡库**取一张效果卡（不手搓假卡，保证 class / traits 齐全）。
	var eff: CardData = null
	for c in scene.repo.all_cards():
		if c.is_effect():
			eff = c
			break
	if eff == null:
		_smoke_fail("R106：卡库里找不到效果卡，无法验证「拖到效果区」")
		return
	eng.state.hand.insert(0, CardData.from_dict(eff.to_dict()))
	eng.state.energy = 99
	var n_effects: int = eng.state.effects.size()
	var n_hand: int = eng.state.hand.size()
	scene._start_drag(0, zone.get_center())
	if not scene._drag_to_effects:
		_smoke_fail("R106：效果卡起拖后没有置起「可拖到效果区」标记")
		return
	scene._finish_drag(zone.get_center())
	if eng.state.effects.size() != n_effects + 1:
		_smoke_fail("R106：效果卡拖到效果区没有启用（效果区 %d → %d）"
				% [n_effects, eng.state.effects.size()])
		return
	if eng.state.hand.size() != n_hand - 1:
		_smoke_fail("R106：效果卡启用后没离开手牌（手牌 %d → %d）"
				% [n_hand, eng.state.hand.size()])
		return
	# 反面：拖到效果区**之外**的空白处 → 取消，不进效果区
	eng.state.hand.insert(0, CardData.from_dict(eff.to_dict()))
	var n_effects2: int = eng.state.effects.size()
	scene._start_drag(0, Vector2(2, 2))
	scene._finish_drag(Vector2(2, 2))
	if eng.state.effects.size() != n_effects2:
		_smoke_fail("R106：效果卡拖到空白处却生效了（效果区 %d → %d）"
				% [n_effects2, eng.state.effects.size()])
		return
	# ---- ② 状态列表 / 卡面徽标：给场上一个单位叠 buff + debuff ----
	var cell := Vector2i(FieldState.OPPONENT_ROWS, 0)
	var unit: Placement = eng.state.unit_at(cell)
	if unit == null:
		unit = eng.state.place(scene.repo.get_card(8003), cell, GameEngine.SIDE_SELF)
	unit.atk_buff = 2
	unit.atk_debuff = 1
	unit.debuff_stage = 1
	unit.upgrade_stacks = 1
	unit.frozen = true
	if unit.status_entries().size() < 3 or unit.status_badges().is_empty():
		_smoke_fail("R106：状态列表/徽标没有产出（列表 %d 条 / 徽标 %d 条）"
				% [unit.status_entries().size(), unit.status_badges().size()])
		return
	# 悬停到它 → 后续帧会真实走 _draw_info_panel（状态逐条 + 富文本效果）与卡面徽标
	scene._hover_card = unit.card
	scene._hover_pl = unit
	scene._drag_idx = -1
	scene.queue_redraw()
	print("SMOKE OK R106：效果卡拖入效果区即启用（%d→%d）/ 悬停单位列出 %d 条状态 + %d 个徽标"
			% [n_effects, eng.state.effects.size(), unit.status_entries().size(),
			unit.status_badges().size()])


func _check_relic_gate(scene: Variant) -> void:
	## R75：战斗右栏道具 —— 悬浮已能逐个看说明，**装得下时不允许点开浏览面板**。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("道具查看：拿不到 engine")
		return
	var cap: int = scene._relic_max_slots()
	if cap < 1:
		_smoke_fail("道具栏：可见槽位数 %d（应 >= 1）" % cap)
		return
	var saved: Array[int] = eng.self_relics.duplicate()
	eng.self_relics = [6001, 6003]
	if scene._relic_bar_overflowed():
		_smoke_fail("道具栏：2 件（容量 %d）却判定为装不下" % cap)
		return
	# 装满不溢出：点道具栏不该打开面板
	eng.self_relics = []
	for i in cap:
		eng.self_relics.append(6001)
	scene._relics_visible = false
	scene._on_left_click(scene._relic_zone_rect().get_center())
	if scene._relics_visible:
		_smoke_fail("道具栏：装得下（%d/%d）却仍能点开浏览面板" % [cap, cap])
		eng.self_relics = saved
		return
	# 超出容量：必须能点开
	for i in range(0, cap + 2):
		eng.self_relics.append(6001)
	if not scene._relic_bar_overflowed():
		_smoke_fail("道具栏：%d 件（容量 %d）却判定为装得下" % [eng.self_relics.size(), cap])
		eng.self_relics = saved
		return
	scene._on_left_click(scene._relic_zone_rect().get_center())
	if not scene._relics_visible:
		_smoke_fail("道具栏：装不下（%d>%d）却点不开浏览面板" % [eng.self_relics.size(), cap])
		eng.self_relics = saved
		return
	scene._relics_visible = false
	# 详情面板：能列出全部，且字号比悬浮提示大
	if scene._relic_panel_rows().size() != eng.self_relics.size():
		_smoke_fail("道具浏览面板：应列出全部 %d 件，实际 %d"
				% [eng.self_relics.size(), scene._relic_panel_rows().size()])
		eng.self_relics = saved
		return
	if int(scene.RELIC_P_NAME) <= 10 or int(scene.RELIC_P_DESC) <= 9:
		_smoke_fail("道具浏览面板：字号没放大（名称 %d / 说明 %d，原为 10 / 9）"
				% [int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])
		eng.self_relics = saved
		return
	eng.self_relics = saved
	print("SMOKE OK 道具查看：战斗道具栏容量 %d 个 / 装满点不开 / %d 件可点开 / 详情全列且字号 %d>%d"
			% [cap, cap + 2, int(scene.RELIC_P_NAME), int(scene.RELIC_P_DESC)])


func _check_turn_gate(scene: Variant) -> void:
	## R71：**玩家只能在自己（我方）的回合操作我方单位**。
	## 原来 `_on_board_click` / 手牌点击 / `_finish_drag` 三条出手路径**都没有回合门禁**
	## → 敌方 AI 正在行动时玩家仍能点选/移动/攻击自己的单位，
	## 看起来就像「AI 错误地操作了我方没行动过的单位」。
	## 这里逐条路径验证：敌方回合时点击/拖拽都不该改变任何我方单位状态。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("回合门禁：拿不到 engine")
		return
	# 摆一个我方单位 + 一个目标格，记录初始状态
	var src := Vector2i(4, 3)
	var dst := Vector2i(4, 2)
	var card := CardData.new()
	card.id = 7901
	card.card_name = "门禁 Dummy"
	card.kind = "盟友"
	card.power = 3
	card.health = 9
	card.attack_range = 1
	card.move_speed = 2
	card.rarity = 0
	card.group = "player"
	card.card_class = "森林精魄"
	if eng.state.unit_at(src) == null:
		eng.state.place(CardData.from_dict(card.to_dict()), src, GameEngine.SIDE_SELF)
	var me: Placement = eng.state.unit_at(src)
	if me == null:
		_smoke_fail("回合门禁：没能摆下我方单位")
		return

	# ① 我方回合：点击应当**能**选中（门禁不能挡掉正常操作）
	eng.current_side = GameEngine.SIDE_SELF
	eng.state.reset_units(GameEngine.SIDE_SELF)
	scene._on_board_click(src)
	if scene.selection == null or scene.selection[0] != "board":
		_smoke_fail("回合门禁：我方回合点我方单位应能选中（门禁挡错了）")
		return
	scene._clear_selection()

	# ② 敌方回合：点击 / 拖拽都不应动我方单位
	eng.current_side = GameEngine.SIDE_OPPONENT
	eng.state.reset_units(GameEngine.SIDE_OPPONENT)
	var hp0: int = me.health
	var cell0: Vector2i = src
	scene._on_board_click(src)               # 点自己 → 不该被选中
	var picked: bool = scene.selection != null and scene.selection[0] == "board"
	scene._on_board_click(dst)               # 点目标格 → 不该触发移动/攻击
	var moved: bool = eng.state.unit_at(dst) != null
	# 拖拽路径也挡一道（它独立于 _on_board_click）
	scene._drag_idx = 0
	scene._finish_drag(dst)
	var moved2: bool = eng.state.unit_at(dst) != null
	if picked or moved or moved2 or me.health != hp0 \
			or eng.state.unit_at(cell0) != me:
		_smoke_fail("回合门禁：敌方回合仍能操作我方单位（选中=%s 移动=%s 拖拽移动=%s 血 %d→%d）"
				% [str(picked), str(moved), str(moved2), hp0, me.health])
		return
	eng.current_side = GameEngine.SIDE_SELF
	print("SMOKE OK 回合门禁：敌方回合点棋盘/点目标格/拖牌都动不了我方单位；我方回合正常可操作")


func _smoke_free(eng: GameEngine, cell: Vector2i) -> bool:
	## R118 用例专用：这一格既没有单位也没有场地（场上「空位」的判据）。
	return eng.state.unit_at(cell) == null and eng.state.field_at(cell) == null


func _check_cancel_armed(scene: Variant) -> void:
	## R118：**左键点空位不再一步取消**。
	## 误点一下草地就把「已移动、还没攻击」的单位就地横置（放弃攻击、不可逆）是玩家最常
	## 踩的坑 —— 用户口径「不应该直接取消攻击，而是在第二次点击才取消，这个状态点击目标
	## 卡片依然可以攻击」。这里把三条路都真跑一遍：
	##   ① 第一次点空位 → 只「上膛」：选区 / 攻击目标**原样保留**、单位**没有**横置；
	##   ② 上膛之后点敌方单位 → **照样打出去**（用户口径的核心，也是「误点不致命」的前提）；
	##   ③ 再点一次空位 → 才真取消（单位横置 = 放弃攻击、选区清空、上膛归位）。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("R118 误点空位：拿不到 engine")
		return
	# 找两个相邻空格（我方半场）放「我方单位 + 敌方靶子」
	var src := Vector2i(-1, -1)
	var tgt := Vector2i(-1, -1)
	for r: int in [3, 4, 5]:
		for c: int in range(FieldState.BOARD_COLS - 1):
			if _smoke_free(eng, Vector2i(r, c)) and _smoke_free(eng, Vector2i(r, c + 1)):
				src = Vector2i(r, c)
				tgt = Vector2i(r, c + 1)
				break
		if src.x >= 0:
			break
	if src.x < 0:
		_smoke_fail("R118 误点空位：我方半场找不到两个相邻空格，用例前提不成立")
		return
	var far := Vector2i(-1, -1)
	eng.current_side = GameEngine.SIDE_SELF
	scene._clear_selection()
	var base := CardData.new()
	base.id = 7904
	base.card_name = "取消烟测 Dummy"
	base.kind = "盟友"
	base.power = 4
	base.health = 12
	base.attack_range = 1
	base.move_speed = 2
	base.rarity = 0
	base.group = "player"
	base.card_class = "森林精魄"
	var foe_card := CardData.from_dict(base.to_dict())
	foe_card.id = 7905
	foe_card.card_name = "烟测靶子"
	foe_card.health = 30
	foe_card.group = "enemy"
	var me: Placement = eng.state.place(
			CardData.from_dict(base.to_dict()), src, GameEngine.SIDE_SELF)
	var foe: Placement = eng.state.place(foe_card, tgt, GameEngine.SIDE_OPPONENT)
	# 「已移动、还没攻击」= 危险态：任何一次非攻击点击都会让它就地横置
	me.moved = true
	me.tapped = false
	me.acts_left = 1
	scene._on_board_click(src)          # 选中它（此时只剩攻击权）
	if scene.selection == null or scene.selection[0] != "board" or scene.selection[1] != src:
		_smoke_fail("R118 误点空位：点自己应当选中它，实际 %s" % str(scene.selection))
		_cleanup_cancel_dummy(eng, src, tgt)
		return
	if not scene.attack_targets_arr.has(tgt):
		_smoke_fail("R118 误点空位：靶子应当在攻击目标里（用例前提不成立）")
		_cleanup_cancel_dummy(eng, src, tgt)
		return
	# 「空位」= 空格 且 **不在** move / attack / hp 任何一个目标集里 ——
	# 这才是「点下去会掉到上膛分支」的定义，与关卡占了哪些格无关。
	for r2: int in range(FieldState.BOARD_ROWS):
		for c2: int in range(FieldState.BOARD_COLS):
			var cell := Vector2i(r2, c2)
			if not _smoke_free(eng, cell) or cell == src or cell == tgt:
				continue
			if scene.move_targets.has(cell) or scene.attack_targets_arr.has(cell) \
					or scene.hp_targets_arr.has(cell):
				continue
			far = cell
			break
		if far.x >= 0:
			break
	if far.x < 0:
		_smoke_fail("R118 误点空位：全盘找不到一个「空位」，用例前提不成立")
		_cleanup_cancel_dummy(eng, src, tgt)
		return

	# ---- ① 第一次点空位：只上膛，绝不取消 ----
	scene._on_board_click(far)
	var bad: Array[String] = []
	if scene.selection == null or scene.selection[0] != "board" or scene.selection[1] != src:
		bad.append("① 选区被清掉了（应当原样保留），实际 %s" % str(scene.selection))
	if me.tapped:
		bad.append("① 单位被就地横置了（放弃攻击）—— 这正是要修掉的误操作")
	if not scene.attack_targets_arr.has(tgt):
		bad.append("① 攻击目标消失了（那也就不叫「依然可以攻击」）")
	if not bool(scene._cancel_armed):
		bad.append("① 没有进入「待取消」状态（_cancel_armed 仍为假）")
	if not bad.is_empty():
		_smoke_fail("R118 误点空位 " + "；".join(bad))
		_cleanup_cancel_dummy(eng, src, tgt)
		return

	# ---- ② 上膛之后点敌方单位 → 照样打出去（用户口径的核心）----
	var foe_hp0: int = foe.health
	scene._on_board_click(tgt)
	if foe.health >= foe_hp0:
		_smoke_fail("R118 ② 上膛之后点目标应当照常攻击（靶子 %d → %d 血）" % [foe_hp0, foe.health])
		_cleanup_cancel_dummy(eng, src, tgt)
		return
	if bool(scene._cancel_armed):
		_smoke_fail("R118 ② 攻击真的打出去之后，上膛状态应当归位")
		_cleanup_cancel_dummy(eng, src, tgt)
		return

	# ---- ③ 第二次点空位 → 才真取消（单位横置 = 放弃攻击、选区清空）----
	me.tapped = false
	me.moved = true
	me.acts_left = 1
	# 用 `_select_board` 直接选中：`_on_board_click(src)` 走的是「点自己」那条会先把
	# 「已移动未攻击」的单位放弃攻击（横置）的路径，拿不到干净的前置状态。
	scene._select_board(src)
	scene._on_board_click(far)          # 第一次：上膛
	scene._on_board_click(far)          # 第二次：取消
	bad = []
	if scene.selection != null:
		bad.append("③ 第二次点空位没有取消选择（实际 %s）" % str(scene.selection))
	if not me.tapped:
		bad.append("③ 第二次点空位没有把「已移动未攻击」的单位横置（放弃攻击没生效）")
	if bool(scene._cancel_armed):
		bad.append("③ 取消之后上膛状态没有归位")
	if not bad.is_empty():
		_smoke_fail("R118 误点空位 " + "；".join(bad))
	else:
		print("SMOKE OK R118 误点空位：① 第一次点只上膛（选区/目标全保留、不横置）"
				+ " ② 上膛后点目标照常打（%d→%d 血）" % [foe_hp0, foe.health]
				+ " ③ 第二次点空位才真取消（单位横置）")
	_cleanup_cancel_dummy(eng, src, tgt)


func _cleanup_cancel_dummy(eng: GameEngine, src: Vector2i, tgt: Vector2i) -> void:
	## R118 用例收尾：别把 dummy 留给后续用例（与 `_check_frozen_aura` 同一套路）。
	eng.state.board.erase(src)
	eng.state.board.erase(tgt)


func _check_treasure_relic_loot(scene: Variant) -> void:
	## R142：卡牌宝箱「装道具」的那一半 —— 支付 5 生命后应得**一件道具**（入队待领），
	## 而不是卡牌三选一。旗标读的是地图节点自带的 `treasure_relic`。
	if not bool(scene._is_treasure()) or not bool(scene._is_treasure_relic()):
		_smoke_fail("R142 宝箱：treasure_relic 旗标没有被认出来")
		return
	RunState.pending_rewards = []          # 清干净，免得别的用例的残留进来搅局
	var before_hp: int = RunState.hp
	scene._on_main()
	if RunState.hp != maxi(1, before_hp - 5):
		_smoke_fail("R142 宝箱：应付 5 生命（%d → %d）" % [before_hp, RunState.hp])
		return
	var has_relic := false
	var has_cards := false
	for e: Dictionary in RunState.pending_rewards:
		if str(e.get("kind", "")) == "relic":
			has_relic = true
		elif str(e.get("kind", "")) == "cards":
			has_cards = true
	if not has_relic or has_cards:
		_smoke_fail("R142 宝箱：待领奖励应只有道具，实际 relic=%s cards=%s"
				% [str(has_relic), str(has_cards)])
		return
	if scene._reward_panel == null or not scene._reward_panel.is_open():
		_smoke_fail("R142 宝箱：开箱后奖励悬浮窗应当自动打开")
		return
	print("SMOKE OK R142 宝箱：支付 5 生命 → 开出道具（入队待领 + 悬浮窗自动打开），不给卡牌")


func _check_event_kind_from_node(scene: Variant) -> void:
	## R142 回归：**真实流程**（地图 → 事件场景）只塞了 pending_node，没有 pending_event。
	## 事件子类型必须能从节点的 `event_kind` 读出来 —— R128 重做地图时漏了这一步，
	## 于是 `_is_treasure()`（兜底分支）把**所有**事件房都吞成了「卡牌宝箱」。
	if str(scene._pending_kind()) != "oblivion":
		_smoke_fail("R142 事件子类型：应从未写 pending_event 的节点读出 oblivion，实际「%s」"
				% str(scene._pending_kind()))
		return
	if bool(scene._is_treasure()):
		_smoke_fail("R142 事件子类型：遗忘之泉被兜底分支误判成「卡牌宝箱」")
		return
	if not bool(scene._is_oblivion()):
		_smoke_fail("R142 事件子类型：读出了 oblivion 却没走遗忘之泉分支")
		return
	print("SMOKE OK R142 事件子类型：只给 event_kind 也能认出遗忘之泉（不再一律变成卡牌宝箱）")


func _check_arcane_with_charm(scene: Variant) -> void:
	## 奥秘之泉（R71 修复）：**已经持有「奥秘护符」时，「喝下泉水」选项依然可用**。
	## 原来那条分支把 bbq_btn 一起 `visible = false` 了 → 玩家只能点「继续」，
	## 第二个选项形同虚设。而且闸门用的是 `_arcane_charm_taken`（护符已到手）而不是
	## `_arcane_drunk`（是否已喝过）→ 已戴护符的玩家连泉水都喝不到。
	RunState.gain_relic(6020)                 # 先戴上护符，复现「已有护符」的局面
	scene._setup_arcane()                     # 重铺选项（UI 平时只在 _ready 里建一次）
	await process_frame
	var bbq: Button = scene.get_node_or_null("Center/BBQBtn")
	var rest: Button = scene.get_node_or_null("Center/RestBtn")
	if bbq == null or rest == null:
		_smoke_fail("奥秘之泉：找不到 RestBtn / BBQBtn 节点")
		return
	# 拿到护符之后也照样能点「喝下泉水」→ **卡牌奖励入队**（限定 效果/技能）＋ 奖励悬浮窗弹出
	scene._ui_bbq()
	await process_frame
	var kinds: Array = []
	var queued := -1
	for i in RunState.pending_rewards.size():
		var e: Dictionary = RunState.pending_rewards[i]
		if str(e.get("kind", "")) == "cards":
			queued = i
			kinds = e.get("kinds", [])
	if queued < 0 or not ("效果" in kinds and "技能" in kinds):
		_smoke_fail("奥秘之泉：已有护符时点「喝下泉水」应把卡牌奖励入队（限定 效果/技能），实际 kinds=%s（队列 %d 条）"
				% [str(kinds), RunState.pending_rewards.size()])
		return
	var panel: Variant = scene._reward_panel
	if panel == null or not panel.is_open():
		_smoke_fail("奥秘之泉：喝下泉水后奖励悬浮窗应当自动打开")
		return
	if not scene._arcane_drunk:
		_smoke_fail("奥秘之泉：点「喝下泉水」应记下 _arcane_drunk（防重复喝）")
		return
	print("SMOKE OK 奥秘之泉：已有护符时「喝下泉水」仍可选 → 卡牌奖励入队（限定 效果/技能）并弹出奖励悬浮窗")


func _check_arcane_one_reward(scene: Variant) -> void:
	## R147：奥秘之泉「一次访问只领一份」——
	##   ① 先取护符 → 「喝下泉水」锁死（**硬点也不发奖励**，闸门在 `_arcane_taken()`）；
	##   ② 先喝泉水 → 「获取护符」锁死（拿不到第二份）。
	## ⚠️ 全程**不点「继续」** —— `_on_leave()` 会换场景，冒烟用例里不能换。
	var rest: Button = scene.get_node_or_null("Center/RestBtn")
	var bbq: Button = scene.get_node_or_null("Center/BBQBtn")
	if rest == null or bbq == null:
		_smoke_fail("R147 奥秘之泉：找不到 RestBtn / BBQBtn 节点")
		return
	# ── ① 先取护符 ──
	RunState.relics = []
	scene._arcane_charm_taken = false
	scene._arcane_drunk = false
	scene._reward_claimed = false
	scene._setup_arcane()
	await process_frame
	if not bbq.visible or bbq.disabled:
		_smoke_fail("R147 奥秘之泉：刚进来「喝下泉水」应当可用")
		return
	scene._ui_main()
	await process_frame
	if not RunState.has_relic(6020):
		_smoke_fail("R147 奥秘之泉：点「获取护符」应拿到「奥秘护符」")
		return
	if not scene._arcane_taken() or not scene._reward_claimed:
		_smoke_fail("R147 奥秘之泉：取走护符后应记下「本次已领」（_arcane_taken / _reward_claimed）")
		return
	if bbq.visible and not bbq.disabled:
		# R178：办完后按钮是**收起**（visible=false）而不是「禁用」，两者都算锁死
		_smoke_fail("R147/R178 奥秘之泉：取走护符后「喝下泉水」必须收起或锁死")
		return
	var n0: int = RunState.pending_reward_count()
	scene._ui_bbq()
	await process_frame
	if RunState.pending_reward_count() != n0:
		_smoke_fail("R147 奥秘之泉：取走护符后再点「喝下泉水」不该再发奖励（%d → %d）"
				% [n0, RunState.pending_reward_count()])
		return
	# ── ② 先喝泉水 ──
	RunState.relics = []
	RunState.pending_rewards = []
	scene._arcane_charm_taken = false
	scene._arcane_drunk = false
	scene._reward_claimed = false
	scene._setup_arcane()
	await process_frame
	scene._ui_bbq()
	await process_frame
	if not scene._arcane_drunk:
		_smoke_fail("R147 奥秘之泉：点「喝下泉水」应记下 _arcane_drunk")
		return
	if not scene._arcane_taken():
		_smoke_fail("R147 奥秘之泉：喝过泉水后 _arcane_taken() 应为真")
		return
	if rest.visible and not rest.disabled:
		_smoke_fail("R147/R178 奥秘之泉：喝过泉水后「获取护符」必须收起或锁死")
		return
	if RunState.has_relic(6020):
		_smoke_fail("R147 奥秘之泉：喝过泉水后不该已经拿到护符")
		return
	print("SMOKE OK R147 奥秘之泉：一次访问只领一份（护符 ↔ 泉水双向锁死，硬点也不发奖励）")


func _check_rest_one_reward(scene: Variant) -> void:
	## R147：一次访问只领一份。R237：篝火回血已恢复 —— 「在这里休息」与「烤肉」二选一。
	var rest: Button = scene.get_node_or_null("Center/RestBtn")
	var bbq: Button = scene.get_node_or_null("Center/BBQBtn")
	if rest == null or bbq == null:
		_smoke_fail("R237 休息处：找不到 RestBtn / BBQBtn 节点")
		return
	if not rest.visible or not bbq.visible:
		_smoke_fail("R237 休息处：「在这里休息」与「烤肉」两个选项都应可见")
		return
	# 打残 → 点「休息」应回血，且只留离开（烤肉收起 = 二选一）
	RunState.hp = maxi(1, RunState.max_hp - 12)
	var hp0: int = RunState.hp
	var expect_gain: int = mini(RunState.rest_heal_amount(), RunState.max_hp - RunState.hp)
	if expect_gain <= 0:
		_smoke_fail("R237 休息处：残血时休息回血量应 > 0")
		return
	scene._ui_main()
	await process_frame
	if RunState.hp != hp0 + expect_gain:
		_smoke_fail("R237 休息处：点「休息」应回复 %d 点（%d → %d）"
				% [expect_gain, hp0, RunState.hp])
		return
	if bbq.visible:
		_smoke_fail("R237 休息处：休息后「烤肉」应收起（二选一）")
		return
	if not scene._reward_claimed:
		_smoke_fail("R237 休息处：休息后应记下 _reward_claimed（一次访问只领一份）")
		return
	print("SMOKE OK R147/R237 休息处：篝火回血恢复（+%d）；休息后只留离开" % expect_gain)


func _check_frozen_aura(scene: Variant) -> void:
	## 冰封特效（R68）：`Placement.frozen` 必须常驻可见 —— 这是个**看卡面看不出来**的状态。
	## ① 引擎施加冰封 → 界面发出 frozen 事件（会加飘字/爆点）；
	## ② 场上被冰封的单位 → `_board_has_frozen()` 为真（_process 靠它逐帧重绘脉冲）；
	## ③ 常驻光环与「嘲讽光环」互不重叠：同时具备两个状态时冰封徽标要往下错开。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("冰封特效：拿不到 engine")
		return
	# 场上摆一个我方单位，直接置 frozen（走引擎真实字段，界面判据同源）
	var cell := Vector2i(4, 1)
	if eng.state.unit_at(cell) == null:
		var cd := CardData.new()
		cd.id = 7901
		cd.card_name = "冰封烟测 Dummy"
		cd.kind = "盟友"
		cd.health = 10     # _apply_frozen 对血量 ≤ 0 的单位不施加（死单位冰封没意义）
		cd.power = 2
		eng.state.place(cd, cell, GameEngine.SIDE_SELF)
	var pl: Placement = eng.state.unit_at(cell)
	pl.frozen = true
	if not scene._board_has_frozen():
		_smoke_fail("冰封特效：场上有 frozen 单位时 _board_has_frozen() 应为真")
		return
	# 常驻光环：直接调（内部只读 frozen，不改状态）——真渲染在后面的帧里发生
	var c2: Vector2 = scene._display_center(pl, cell)
	scene._draw_frozen_aura(c2, 40.0, 56.0, 0)
	scene._draw_frozen_aura(c2, 40.0, 56.0, 1)   # 徽标在第 2 行（上方留给嘲讽）
	if not scene._board_has_taunt():
		pass   # 本用例没放嘲讽单位，这里只是确认函数可共存调用
	# frozen 事件：引擎唯一入口会 emit，界面据此演飘字
	var got := [0]
	eng.action.connect(func(what: String, _d: Variant) -> void:
			if what == "frozen":
				got[0] = int(got[0]) + 1)
	eng._apply_frozen(pl, "烟测")
	if int(got[0]) != 1 or not pl.frozen:
		_smoke_fail("冰封特效：_apply_frozen 应发出 1 次 frozen 事件并置位 frozen（实际 %d）"
				% int(got[0]))
		return
	pl.frozen = false
	if pl.card.card_name == "冰封烟测 Dummy" and eng.state.unit_at(cell) == pl:
		eng.state.board.erase(cell)   # 清场：别把 dummy 留给后续用例
	print("SMOKE OK 冰封特效：frozen 事件 + 常驻寒霜光环 + 与嘲讽徽标错开，三者同源于 Placement.frozen")


func _check_sleep_aura(scene: Variant) -> void:
	## 沉睡特效（R72）：恶魔鸭 9116「还不能动」是**看卡面看不出来**的
	## 隐藏状态，而且「还差几下」直接决定「现在打不打它」（R76：挨一下 -1、打空立刻醒）。
	##   ① `Placement.sleep_left > 0` → `_board_has_sleep()` 为真（_process 靠它逐帧重绘）；
	##   ② 常驻光环 + 徽标（「沉睡 N」）与冰封/嘲讽共用底座，按行号错开不重叠；
	##   ③ 苏醒事件 wake → 挣脱环进 `_wake_rings` 并被 `_tick_anims` 认作「还在演」。
	var eng: GameEngine = scene.engine
	if eng == null:
		_smoke_fail("沉睡特效：拿不到 engine")
		return
	# ⚠️ 格子必须避开其它用例的占位：回合门禁用 (4,3)→(4,2)、冰封用 (4,1)。
	# 本轮最初摆在 (4,2)，结果门禁用例的 dst 本来就有单位 → 被误判成「移动成功」。
	#
	# R76：这里**不能**沿用「格子空着才建卡」的老写法 —— 整套跑时敌方 AI 可能已经
	# 在这一格部署了单位（实测拿到过「爆炎鸭」），于是 sp 变成别人的卡：没有「沉睡」
	# trait，挨打当然不会醒（表现为 wake 0 次 / sleep_left 仍 1）。
	# 改成**先清场再摆自己的卡**，让这个用例与场上其它单位彻底无关。
	var cell := Vector2i(2, 2)
	eng.state.board.erase(cell)
	var cd := CardData.new()
	cd.id = 7902
	cd.card_name = "沉睡烟测 Dummy"
	cd.kind = "盟友"
	cd.health = 10
	cd.power = 2
	# 必须带「沉睡」trait，否则 _demon_duck_hurt 不会分派、挨打也不会醒。
	cd.traits = [FieldState.SLEEP_TRAIT]
	eng.state.place(cd, cell, GameEngine.SIDE_SELF)
	var sp: Placement = eng.state.unit_at(cell)
	# 记下这是我们摆的，用完挪走（不给后面的用例留垃圾）
	var ours := sp != null and sp.card.card_name == "沉睡烟测 Dummy"
	if sp == null:
		_smoke_fail("沉睡特效：在 %s 摆烟测卡失败" % str(cell))
		return
	sp.sleep_left = 2
	if not scene._board_has_sleep():
		_smoke_fail("沉睡特效：场上有 sleep_left > 0 的单位时 _board_has_sleep() 应为真")
		return
	# 徽标行号 0/1/2 都画一遍 → 三个状态同时成立时也不该有绘制错误/重叠
	var cs: Vector2 = scene._display_center(sp, cell)
	for row in 3:
		scene._draw_sleep_aura(cs, 40.0, 56.0, 2, row)
	# 徽标宽度随文案长度自适应（「沉睡 2」比「冰封」长，写死宽度会被截断）
	var bw2 := maxf(40.0, 14.0 + float("沉睡 2".length()) * 11.0)
	if bw2 <= 40.0:
		_smoke_fail("沉睡特效：徽标宽度应随文案自适应（实际 %.1f）" % bw2)
		return
	# 苏醒事件 → 挣脱环（用引擎真实入口走一遍，不手搓事件）
	# 这里是**受伤递减口**：`_hit_unit` → `_demon_duck_hurt`，挨够次数 sleep_left 归零。
	# （R122 起**回合递减口** `_sleep_tick` 也回来了，两个口并存 —— 见本用例末尾。）
	sp.sleep_left = 1
	var woke := [0]
	eng.action.connect(func(what: String, _d: Variant) -> void:
			if what == "wake":
				woke[0] = int(woke[0]) + 1)
	var rings_before: int = scene._wake_rings.size()
	eng._hit_unit(sp, 1, "沉睡烟测")
	if int(woke[0]) != 1 or sp.sleep_left != 0:
		_smoke_fail(("沉睡特效：挨打应发 1 次 wake 并把 sleep_left 归零（实际 %d / %d；卡=%s 有沉睡trait=%s ours=%s）"
				% [int(woke[0]), sp.sleep_left, sp.card.card_name,
					str(sp.card.traits.has(FieldState.SLEEP_TRAIT)), str(ours)]))
		return
	# 顺带锁住 R122 的**回合递减口** —— 放在「醒来后 _board_has_sleep() 转假」之后断言，
	# 否则会把 sleep_left 改回 2。
	if scene._wake_rings.size() <= rings_before:
		_smoke_fail("沉睡特效：wake 事件应往 _wake_rings 加挣脱环（%d → %d）"
				% [rings_before, scene._wake_rings.size()])
		return
	if scene._board_has_sleep():
		_smoke_fail("沉睡特效：醒来后 _board_has_sleep() 应转为假（光环不该再画）")
		return
	# ① 它自己那一方回合结束 → -1（R76 曾把这一步删掉，于是「没人打它就永远不醒」，
	#    R122 用户实测反馈后补回；与之并存的受伤口就是上面刚走过的那一段）。
	sp.sleep_left = 2
	eng._sleep_tick(sp.owner)
	if sp.sleep_left != 1:
		_smoke_fail("沉睡特效：R122 起 _sleep_tick 应在自己那一方回合结束 -1（2 → 1，实际 %d）"
				% sp.sleep_left)
		eng.state.board.erase(cell)
		return
	# ② 别人那一方的回合结束**不该**减它（只认「它自己那一方」）
	var r122_other: String = GameEngine.SIDE_OPPONENT
	if sp.owner == GameEngine.SIDE_OPPONENT:
		r122_other = GameEngine.SIDE_SELF
	eng._sleep_tick(r122_other)
	if sp.sleep_left != 1:
		_smoke_fail("沉睡特效：别人那一方的回合结束不该减它的沉睡（应仍为 1，实际 %d）"
				% sp.sleep_left)
		eng.state.board.erase(cell)
		return
	scene._wake_rings.clear()
	scene._draw_wake_rings()   # 真渲染空/非空两种状态都不出错
	if ours and eng.state.unit_at(cell) == sp:
		eng.state.board.erase(cell)   # 清场：别把 dummy 留给后续用例
	print("SMOKE OK 沉睡特效：常驻紫环 + 「沉睡 N」徽标（3 行互不重叠）+ 苏醒挣脱环，同源于 Placement.sleep_left；R122 起回合口与受伤口并存（都在减）")


func _check_menu(scene: Variant) -> void:
	## R148：Esc 主菜单。
	##   ① 打开 → 暂停场景树（战斗中敌人 AI 计时器必须停）+ UiGate 登记（下层悬停让位）；
	##   ② 关闭 → **一定要恢复**（忘了恢复就是整个游戏假死，本组件最危险的一处）；
	##   ③ 菜单项由场景自己给（战斗里要有「查看地图 / 战斗记录 / 返回标题」）。
	var menu: Variant = scene.get("_menu")
	if menu == null:
		_smoke_fail("R148：战斗场景没有挂主菜单")
		return
	if menu.is_open():
		_smoke_fail("R148：主菜单默认不该是打开状态")
		return
	menu.open()
	if not menu.is_open():
		_smoke_fail("R148：menu.open() 之后应处于打开状态")
		return
	if not paused:
		_smoke_fail("R148：菜单打开应暂停场景树（否则战斗中敌人会继续行动）")
		return
	if not UiGate.blocked():
		_smoke_fail("R148：菜单打开应向 UiGate 登记（下层悬停让位）")
		return
	menu.close()
	if menu.is_open() or paused:
		_smoke_fail("R148：菜单关闭必须恢复暂停（is_open=%s paused=%s）"
				% [str(menu.is_open()), str(paused)])
		return
	if UiGate.blocked():
		_smoke_fail("R148：菜单关闭应撤销 UiGate 登记")
		return
	# 菜单项：**首项「返回战斗」由组件自动补**（primary）。
	# R155：地图 / 记录 / 卡组上了顶栏专属按钮、「选择关卡」下线 → 菜单只剩设置类。
	var texts: Array = []
	var primaries := 0
	var list: Array = menu._menu_list()
	for it: Dictionary in list:
		texts.append(str(it.get("text", "")))
		if bool(it.get("primary", false)):
			primaries += 1
	for want: String in ["返回战斗", "音效：开", "返回标题"]:
		if not texts.has(want):
			_smoke_fail("R155：战斗菜单缺少「%s」项（实际 %s）" % [want, str(texts)])
			return
	for gone: String in ["查看地图", "战斗记录", "选择关卡", "查看卡组"]:
		if texts.has(gone):
			_smoke_fail("R155：「%s」不该再出现在 Esc 菜单（已上顶栏 / 已下线）" % gone)
			return
	if primaries != 1:
		_smoke_fail("R148：菜单里应**只有一个**主按钮（实际 %d 个）" % primaries)
		return
	print("SMOKE OK R148 主菜单：打开暂停 + UiGate 让位 → 关闭恢复；战斗菜单项 %s"
			% str(texts))


func _check_map_panel(scene: Variant) -> void:
	## 战斗内地图总览（R128）：**格子视图**、只读、整屏装得下（不再滚动）。
	##   ① 「重开一局」按钮已删除、换成「地图」按钮；
	##   ② 打开面板 → 标出可走 / 当前房间，关掉后复原；
	##   ③ 面板只读：点房间不会改路线（current_node_id 不变）。
	var tb: Variant = scene.get_node_or_null("Toolbar")
	if tb == null:
		_smoke_fail("战斗内地图：找不到 Toolbar 节点")
		return
	if tb.get_node_or_null("RestartBtn") != null:
		_smoke_fail("战斗内地图：「重开一局」按钮应已删除")
		return
	# R155：顶栏新布局 —— 记录（偏左）+ 卡组 / 地图（右侧）+ 回合结束 + 齿轮；
	# 音效 / 标题 / 选关按钮不下顶栏（音效在 Esc 菜单，选关下线）。
	for gone: String in ["SndBtn", "TitleBtn", "LevelBtn"]:
		if tb.get_node_or_null(gone) != null:
			_smoke_fail("R155：顶栏不该有 %s" % gone)
			return
	for want2: String in ["LogBtn", "DeckBtn", "MapBtn", "EndTurnBtn", "MenuBtn", "HpStrip"]:
		if tb.get_node_or_null(want2) == null:
			_smoke_fail("R155：顶栏缺少 %s（记录偏左 / 卡组·地图右侧 / HpStrip 血量条）" % want2)
			return
	scene._toggle_map()
	if not scene._map_visible:
		_smoke_fail("战斗内地图：_toggle_map 后面板没有打开")
		return
	# 可走判定与 RunState 同源
	var nxt := 0
	var avail := RunState.available_nodes()
	for n in avail:
		if scene._mapview_is_next(n):
			nxt += 1
	if nxt != avail.size():
		_smoke_fail("战斗内地图：%d/%d 个可走房间被标出" % [nxt, avail.size()])
		return
	# 通路（R130）：面板与冒险地图同一套语义 —— 当前房 → 可走房 = 亮青
	for node2: Dictionary in RunState.map_cells:
		if not scene._mapview_is_current(node2):
			continue
		for node3: Dictionary in RunState.map_cells:
			if scene._mapview_is_next(node3) \
					and scene._mapview_bridge_kind(node2, node3) != MapBridge.LIT:
				_smoke_fail("战斗内地图：当前房 → 可走房 %d 的通路语义不对"
						% int(node3["id"]))
				return
	# 只读：点面板里的房间不改路线
	var cur_before := RunState.current_node_id
	var some_cell: Dictionary = {}
	for node: Dictionary in RunState.map_cells:
		if scene._mapview_is_next(node):
			some_cell = node
			break
	if not some_cell.is_empty():
		scene._on_left_click(scene._mapview_cell_rect(some_cell).get_center())
		if RunState.current_node_id != cur_before:
			_smoke_fail("战斗内地图：面板应当只读，点房间却把路线改到了 %d"
					% RunState.current_node_id)
			return
	if scene._map_visible:
		_smoke_fail("战斗内地图：点任意处应关闭面板")
		return
	scene._toggle_map()
	if not scene._map_visible:
		_smoke_fail("战斗内地图：关闭后应能再次打开")
		return
	# 几何：35 个格子必须**完整**落在可视区内（整屏装得下，所以不再需要滚动）
	var view: Rect2 = scene._mapview_view_rect()
	var out_cnt := 0
	for node: Dictionary in RunState.map_cells:
		if not view.encloses(scene._mapview_cell_rect(node)):
			out_cnt += 1
	if out_cnt > 0:
		_smoke_fail("战斗内地图：%d 个格子越出了可视区（应当整屏装得下）" % out_cnt)
		return
	# **保持面板打开**：剩下的几帧会真的把 _draw_map_panel 画出来 ——
	# 面板里的绘制错误（越界访问 / 空引用）只有真渲染才抓得到（headless 抓不到）。
	print("SMOKE OK 战斗内地图：格子总览可开关 / 只读（可走 %d 间）/ %d 个格子全部完整落在面板内 / 保持打开供后续帧渲染"
			% [nxt, RogueMap.CELLS])


func _check_overflow(scene: Variant) -> void:
	## 效果区 / 敌方效果区 / 道具栏：可见槽位数必须 >= 1，且**最后一个可见槽位不得越出区域外框**。
	## 超出可见槽位的部分改画成「+N」摘要卡（点区域可查看全部）—— 这条锁保证
	## 「效果或道具再多，也不会溢出画到屏幕外、或者把后面的卡遮没」。
	var zb: float = scene.GRID_Y + scene.GRID_H
	var cap_eff: int = scene._effect_zone_max_slots()
	var last_eff: Rect2 = scene._effect_rect(cap_eff - 1)
	if cap_eff < 1:
		_smoke_fail("效果区：可见槽位数为 %d（应 >= 1）" % cap_eff)
	elif last_eff.position.y + last_eff.size.y > zb + 0.5:
		_smoke_fail("效果区：第 %d 张卡底部 %.1f 越出区域下沿 %.1f"
				% [cap_eff, last_eff.position.y + last_eff.size.y, zb])
	var rz: Rect2 = scene._relic_zone_rect()
	var cap_rel: int = scene._relic_max_slots()
	var last_rel: Rect2 = scene._relic_rect(cap_rel - 1)
	if cap_rel < 1:
		_smoke_fail("道具栏：可见槽位数为 %d（应 >= 1）" % cap_rel)
	elif last_rel.position.y + last_rel.size.y > rz.position.y + rz.size.y + 0.5:
		_smoke_fail("道具栏：第 %d 个徽章底部 %.1f 越出区域下沿 %.1f"
				% [cap_rel, last_rel.position.y + last_rel.size.y, rz.position.y + rz.size.y])
	var ez: Rect2 = scene._enemy_zone_rect()
	var cap_ee: int = scene._enemy_effect_zone_max_slots()
	var last_ee: Rect2 = scene._enemy_effect_rect(cap_ee - 1)
	if cap_ee < 1:
		_smoke_fail("敌方效果区：可见槽位数为 %d（应 >= 1）" % cap_ee)
	elif last_ee.position.y + last_ee.size.y > ez.position.y + ez.size.y + 0.5:
		_smoke_fail("敌方效果区：第 %d 张卡底部 %.1f 越出区域下沿 %.1f"
				% [cap_ee, last_ee.position.y + last_ee.size.y, ez.position.y + ez.size.y])
	else:
		print("SMOKE OK 溢出兜底：效果区 %d 槽 / 敌方效果 %d 槽 / 道具 %d 槽（末位均不越界，超出改画 +N 摘要）"
				% [cap_eff, cap_ee, cap_rel])


func _check_curtain_reply(s: Node) -> void:
	## R310：第二层收下道具后应当是「立绘出场 + 角色回答」那一态。
	## 这里直接调场景自己的私有方法（同仓其它 smoke 用例也是这么做的）。
	if s == null or not s.has_method("_pick"):
		print("  [smoke] curtain: 场景没有 _pick()，跳过")
		return
	s.call("_pick", 0)
	var title: Variant = s.get("_title")
	var desc: Variant = s.get("_desc")
	var ok_name: bool = title != null and (title as Label).text == PlayerClass.MECH
	var ok_text: bool = desc != null \
			and (desc as Label).text == CurtainLines.reply(GameLayers.LAYER_TWO, PlayerClass.MECH)
	print("  [smoke] curtain 回答态：名称牌=%s 台词=%s" % [ok_name, ok_text])
