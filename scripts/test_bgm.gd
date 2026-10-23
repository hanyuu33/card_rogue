extends SceneTree
## headless BGM 测试（R176）—— godot --headless -s scripts/test_bgm.gd
##
## 覆盖：
##   * 7 个槽位素材在位、可载入为 Ogg、loop 已开、时长合理；
##   * 分级（普通/精英/Boss）与分层（一/二层）→ 槽位的映射（纯函数）；
##   * 播放语义：切槽位换播放器、同一槽位重复 play **不重启**、
##     切换时确有淡出播放器（交叉淡入）、缺槽位静默不崩、stop 清干净；
##   * 场景挂点源码守卫（title / class_pick / map / battle）+ .import loop=true；
##   * `_audition/.gdignore` 在位 —— 否则 485MB 候选曲会被 Godot 导入进发布包。
##
## ⚠️ `Bgm` 是 `class_name`（不是 autoload），全局类名在 `_init()` 阶段就能解析。

const SLOTS := ["title", "class_pick", "map", "map2",
		"battle", "battle_elite", "battle_boss"]

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		fails += 1
		printerr("  ✗ ", msg)


## ⚠️ 必须跑在 `_process` 里，**不能**放在 `_initialize()` 里：
## `--script` 模式下 `_initialize()` 时 `root.is_inside_tree()` 还是 false，
## 那时挂节点既不触发 `_ready()`，AudioStreamPlayer 也会报
## 「Playback can only happen when a node is inside the scene tree」。
## 并且 `Bgm.instance()` 是 `add_child.call_deferred()` 挂上去的 →
## 第 1 帧只负责触发创建，第 2 帧确认已进树后才跑断言。
var _stage := 0


func _process(_delta: float) -> bool:
	_stage += 1
	if _stage == 1:
		Bgm.instance()                     # 触发惰性创建（deferred 挂到 root）
		return false                       # 先让消息队列把它真的挂上去
	var b := Bgm.instance()
	if b == null or not b.is_inside_tree():
		if _stage > 5:
			fails += 1
			printerr("  ✗ Bgm 节点迟迟没挂上 root")
			quit(1)
			return true
		return false
	_run(b)
	return true


func _run(b: Bgm) -> void:
	print("== BGM 测试（R176） ==")
	check(b == Bgm.instance() and b.is_inside_tree(),
			"Bgm.instance() 唯一实例、且已挂到 root")

	# ---- 素材在位 ----
	var missing := []
	for slot: String in SLOTS:
		# ⚠️ 判存走 ResourceLoader.exists：导出包里没有源 .ogg（只有 .import + oggvorbisstr），FileAccess 恒假。
		if not ResourceLoader.exists("res://assets/audio/bgm/%s.ogg" % slot):
			missing.append(slot)
	check(missing.is_empty(), "7 个 BGM 槽位素材齐全（缺 %s）" % str(missing))

	# ---- 载入 + loop + 时长 ----
	var bad_stream := []
	var short_stream := []
	for slot: String in SLOTS:
		var s: AudioStream = b.stream_for(slot)
		if s == null or not (s is AudioStreamOggVorbis):
			bad_stream.append(slot)
			continue
		if not (s as AudioStreamOggVorbis).loop:
			bad_stream.append(slot)
		if s.get_length() < 10.0:
			short_stream.append(slot)
	check(bad_stream.is_empty(),
			"7 首全部载入为 Ogg 且 loop=on（异常 %s）" % str(bad_stream))
	check(short_stream.is_empty(),
			"7 首时长都 > 10s（异常 %s）" % str(short_stream))

	# ---- 分级 → 战斗槽位（纯函数） ----
	check(Bgm.battle_slot(GameLevels.TIER_NORMAL_EASY) == "battle"
			and Bgm.battle_slot(GameLevels.TIER_NORMAL_HARD) == "battle",
			"普通敌人（简单/困难）→ battle")
	check(Bgm.battle_slot(GameLevels.TIER_ELITE_EASY) == "battle_elite"
			and Bgm.battle_slot(GameLevels.TIER_ELITE_HARD) == "battle_elite",
			"精英敌人（简单/困难）→ battle_elite")
	check(Bgm.battle_slot(GameLevels.TIER_BOSS) == "battle_boss",
			"Boss → battle_boss")
	check(Bgm.battle_slot(-1) == "battle",
			"无 tier（-1）→ battle（兜底，不炸）")

	# ---- 播放语义 ----
	b.play("title")
	var st: Dictionary = b.debug_state()
	check(st["current"] == "title", "play(title) → current=title")
	var id1 := int(st["active_id"])
	check(int(st["out_id"]) != 0, "切入时确有第二个播放器在淡出（交叉淡入）")

	b.play("title")                        # 同一首：不该换播放器 / 不该重启
	st = b.debug_state()
	check(int(st["active_id"]) == id1 and st["current"] == "title",
			"同一槽位重复 play **不重启**（播放器实例未换）")

	# 手动推进淡入淡出（headless 里不跑帧，只能自己喂时间）
	b._process(0.3)
	check(bool(b.debug_state()["fading"]), "0.3s 时仍在淡入（< FADE_SEC 0.6s）")
	b._process(0.4)
	var stf: Dictionary = b.debug_state()
	# ⚠️ 终点音量读 `Bgm.target_db()`，**不要硬写 `BGM_VOLUME_DB`**：
	# `Bgm._ready()` 会把玩家 `settings.cfg` 的 `music_volume` 读进来（R246），
	# 本机把音乐调到 30% 时 target_db = -22.46dB —— 硬写 -12 会因为「玩家设置」
	# 而假失败（R326 修）。
	check(not bool(stf["fading"]) and int(stf["out_id"]) == 0
			and is_equal_approx(float(stf["active_db"]), Bgm.target_db()),
			"0.7s 后淡入完成：淡出播放器已停、在播音量 = 目标 %.2fdB" % Bgm.target_db())

	b.play("battle")
	st = b.debug_state()
	check(st["current"] == "battle" and int(st["active_id"]) != id1,
			"换槽位 → 轮到另一台播放器")
	var id2 := int(st["active_id"])
	b.play("battle")
	check(int(b.debug_state()["active_id"]) == id2,
			"新槽位重复 play 同样不重启")

	# ---- 地图按层 ----
	b.play_map(GameLayers.LAYER_DEFAULT)
	check(str(b.debug_state()["current"]) == "map", "play_map(第一层) → map")
	b.play_map(GameLayers.LAYER_TWO)
	check(str(b.debug_state()["current"]) == "map2", "play_map(第二层) → map2")

	# ---- 战斗按分级 ----
	b.play_battle(GameLevels.TIER_BOSS)
	var st3: Dictionary = b.debug_state()
	check(str(st3["current"]) == "battle_boss", "play_battle(TIER_BOSS) → battle_boss")
	check(int(st3["active_id"]) != id2,
			"连续切歌仍能轮换播放器（两台够用，不叠音）")

	# ---- 缺槽位：静默不崩 ----
	var before := str(b.debug_state()["current"])
	b.play("no_such_slot")
	check(str(b.debug_state()["current"]) == before, "缺槽位 play 静默返回（current 不变）")
	b.play("")
	check(str(b.debug_state()["current"]) == before, "空槽位 play 静默返回")

	# ---- stop ----
	b.halt()
	var st4: Dictionary = b.debug_state()
	check(str(st4["current"]) == "" and not bool(st4["active_playing"]),
			"halt() 停播且清空 current")

	# ---- 音量口径 ----
	check(is_equal_approx(Bgm.BGM_VOLUME_DB, -12.0),
			"BGM 音量 = -12dB（比音效低一档）")

	# ---- 源码守卫（打包环境读不到源文本 → 跳过） ----
	if not FileAccess.file_exists("res://export_presets.cfg"):
		print("    · R176 源码守卫：打包环境读不到源文本 → 跳过（只在 dev 工程/门禁生效）")
	else:
		var proj := FileAccess.get_file_as_string("res://project.godot")
		# ⚠️ 反向守卫：Bgm **必须不是** autoload —— autoload 的全局标识符要等
		# 主循环建好才注册，test_engine 在 `_init()` 里 load battle_scene.gd 会
		# 报 `Identifier not found: Bgm`（整条套件静默卡死）。见 bgm.gd 顶部说明。
		check(proj.find('Bgm="*res://scripts/bgm.gd"') < 0,
				"project.godot **没有**把 Bgm 注册成 autoload（否则测试套件会编译失败）")
		var bgm_src := FileAccess.get_file_as_string("res://scripts/bgm.gd")
		check(bgm_src.find("class_name Bgm") >= 0
				and bgm_src.find("static func instance()") >= 0,
				"bgm.gd 用 `class_name Bgm` + 静态 instance() 惰性建节点")
		var ts := FileAccess.get_file_as_string("res://scripts/title_scene.gd")
		check(ts.find('Bgm.play("title")') >= 0, "title_scene 挂 title 槽位")
		var cps := FileAccess.get_file_as_string("res://scripts/class_pick_scene.gd")
		check(cps.find('Bgm.play("class_pick")') >= 0,
				"class_pick_scene 挂 class_pick 槽位")
		var ms := FileAccess.get_file_as_string("res://scripts/map_scene.gd")
		check(ms.find("Bgm.play_map(RunState.current_layer)") >= 0,
				"map_scene 按 RunState.current_layer 自动取 map / map2")
		var bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
		check(bs.find("Bgm.play_battle(") >= 0,
				"battle_scene 按关卡 tier 自动取战斗曲")
		var bad_loop := []
		for slot2: String in SLOTS:
			var imp := FileAccess.get_file_as_string(
					"res://assets/audio/bgm/%s.ogg.import" % slot2)
			if imp.find("loop=true") < 0:
				bad_loop.append(slot2)
		check(bad_loop.is_empty(),
				"7 个 .ogg.import 都是 loop=true（异常 %s）" % str(bad_loop))
		check(FileAccess.file_exists("res://assets/audio/_audition/.gdignore"),
				"assets/audio/_audition/.gdignore 在位（候选曲不进导入表/发布包）")

	print("== 结果：", "全部通过" if fails == 0 else "%d 项失败" % fails, " ==")
	quit(1 if fails > 0 else 0)
