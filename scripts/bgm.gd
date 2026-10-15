class_name Bgm
extends Node
## BGM 播放器（R176）—— **全局唯一入口**。
##
## 用法（场景脚本只调这几个静态口）：
##   Bgm.play("title")                       # 直接点名槽位
##   Bgm.play_map(RunState.current_layer)    # 地图：按层自动选 map / map2
##   Bgm.play_battle(int(lvl["tier"]))       # 战斗：按关卡分级自动选
##
## 槽位（文件 = `assets/audio/bgm/<槽位>.ogg`，全部 PeriTune 官方 loop 版，
## 已按无缝循环导入 —— `.import` 里 `loop=true`）：
##
## | 槽位 | 场景 | 曲目 |
## |---|---|---|
## | `title`        | 标题页       | PerituneMaterial_Holy_Place |
## | `class_pick`   | 角色选择     | PerituneMaterial_Piano_Refreshing |
## | `map`          | 第一层地图   | PerituneMaterial_Poema |
## | `map2`         | 第二层地图   | PerituneMaterial_Strategy4 |
## | `battle`       | 一般战斗     | PerituneMaterial_Dramatic |
## | `battle_elite` | 精英战斗     | PerituneMaterial_EpicBattle |
## | `battle_boss`  | Boss 战斗    | PerituneMaterial_Raid_FolkMetal |
##
## ⚠️ **为什么不用 autoload**（R176 踩过的坑，别改回去）：
## autoload 的「全局标识符」要等主循环对象建好、由 `Main::start()` 把节点
## 注册成命名全局之后才可解析。而 `--script` 跑测试时，test_engine 是在
## `_init()` 里 `load("res://scripts/battle_scene.gd")` 的 —— 那一步还没发生
## → 编译直接报 `Identifier not found: Bgm`，battle_scene 变成「加载成功但
## 空壳」的脚本，后面所有 `intro_pose()` / `_grid_scroll_max()` 断言全崩，
## 而且**不报失败、只是卡住**（`_init` 抛错后 SceneTree 无事可做）。
## 改用 `class_name` + 静态入口：全局类名来自脚本类缓存，`_init()` 阶段就认。
## 节点自己在**第一次调用时**挂到 `root` 下，不再依赖 autoload 的注册顺序。
##
## 纪律：
##   * **同一槽位重复调用不重启** —— 切场景回到同一首时不打断（否则每进一次
##     地图就从头再放一遍）。判「是否同一首」只看 `current`。
##   * 切换 = `FADE_SEC` 交叉淡入淡出（两个 AudioStreamPlayer 轮换）；
##     淡出音量从**当时实际音量**续着走，连续切歌不会跳变。
##   * 音量统一 `BGM_VOLUME_DB`（-12dB）：比音效低一档，别盖过打击感。
##   * **缺文件 → 静默返回**，不崩（方便缺素材时先跑逻辑）。
##   * `PROCESS_MODE_ALWAYS`：Esc 菜单暂停时不掐音乐。
##   * `--nomusic`（用户参数）：整局禁音 —— 跑测试/截图演示时别外放。

const BGM_DIR := "res://assets/audio/bgm/"
const BGM_VOLUME_DB := -12.0
const FADE_SEC := 0.6
const SILENT_DB := -60.0

## 槽位 → 曲目名（仅供 credits / 自检对照；实际播放只认同名 ogg 文件）
const SLOT_TRACKS := {
	"title": "PerituneMaterial_Holy_Place",
	"class_pick": "PerituneMaterial_Piano_Refreshing",
	"map": "PerituneMaterial_Poema",
	"map2": "PerituneMaterial_Strategy4",
	"battle": "PerituneMaterial_Dramatic",
	"battle_elite": "PerituneMaterial_EpicBattle",
	"battle_boss": "PerituneMaterial_Raid_FolkMetal",
}

static var _inst: Bgm = null                       # 唯一实例（惰性创建）

var enabled := true
var current := ""                                  # 当前（含正在淡入）的槽位
var _pending := ""                                 # 节点还没进树时先记下想放的槽位

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _active: AudioStreamPlayer = null              # 正在播 / 正在淡入的
var _out: AudioStreamPlayer = null                 # 正在淡出的
var _out_from_db := BGM_VOLUME_DB                  # 淡出起点音量
var _fade_t := 0.0
var _fading := false


# ============================================================ 静态入口

## 取（必要时创建）唯一实例 —— **第一次调用时挂到 `root` 下**。
## ⚠️ 用 `add_child.call_deferred()`：主场景的 `_ready()` 里首次调用时，
## `root` 正忙着装配子节点，直接 `add_child` 会报
## 「Parent node is busy setting up children, add_child() failed」。
static func instance() -> Bgm:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var t := Engine.get_main_loop() as SceneTree
	if t == null or t.root == null:
		return null
	_inst = Bgm.new()
	t.root.add_child.call_deferred(_inst)
	return _inst


## 切到某槽位。**同一首已在放（含正在淡入）→ 直接返回**：不重启、不打断。
func switch_to(slot: String) -> void:
	if not enabled or slot == "":
		return
	if slot == current and _active != null:
		return
	var s := stream_for(slot)
	if s == null:
		return                                     # 缺素材：静默跳过
	_ensure_players()
	var nxt: AudioStreamPlayer = _players[0] if _active == _players[1] else _players[1]
	_out = _active
	_out_from_db = _out.volume_db                  # 从当前实际音量续淡（连续切歌不跳变）
	nxt.stream = s
	nxt.volume_db = SILENT_DB
	nxt.play()
	_active = nxt
	current = slot
	_fade_t = 0.0
	_fading = true


func halt() -> void:
	current = ""
	_fading = false
	if _out != null:
		_out.stop()
		_out = null
	if _active != null:
		_active.stop()
		_active.volume_db = SILENT_DB


# ------------------------------------------------------------ 静态包装

static func play(slot: String) -> void:
	if slot == "":
		return
	var n := instance()
	if n == null:
		return
	if n.is_inside_tree():
		n.switch_to(slot)
	else:
		n._pending = slot          # 节点这一帧还没挂上 root → `_ready` 里补播


## 地图：第一层 `map` / 第二层及更深 `map2`。
static func play_map(layer: int) -> void:
	play("map" if layer <= GameLayers.LAYER_DEFAULT else "map2")


## 关卡分级 → 战斗槽位。**纯函数**（可单测）：精英 = TIER_ELITE_EASY/HARD，
## Boss = TIER_BOSS，其余（含未知 -1）= 一般战斗。
static func battle_slot(tier: int) -> String:
	if tier == GameLevels.TIER_BOSS:
		return "battle_boss"
	if tier == GameLevels.TIER_ELITE_EASY or tier == GameLevels.TIER_ELITE_HARD:
		return "battle_elite"
	return "battle"


static func play_battle(tier: int) -> void:
	play(battle_slot(tier))


static func stop() -> void:
	var n := instance()
	if n != null:
		n.halt()


# ============================================================ 实例

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--nomusic" in OS.get_cmdline_user_args():
		enabled = false
	_ensure_players()
	if _pending != "":
		var s := _pending
		_pending = ""
		switch_to(s)               # 进树前挂起的第一次播放，这里补上


## 幂等：保证两台播放器已建好 —— 供 `_ready` 与 `switch_to` 共用。
func _ensure_players() -> void:
	if not _players.is_empty():
		return
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	_active = _players[0]


## 退出时摘掉静态引用（避免留下指向已释放节点的悬空引用）。
##
## ⚠️ **别指望在这里消掉 headless 下那两行退出告警**：
## `ObjectDB instances leaked at exit` + `N resources still in use at exit`。
## 实测（R176）那是**引擎侧**的 —— `--headless` 用 dummy 音频驱动，播过音的
## playback 对象由 AudioServer 持有，脚本层 `stop()` + 清 `stream` + 清缓存
## 都回收不掉（`--nomusic` 复跑则完全不出现，证明就是「播过音」这一件事）。
## 只在 headless 进程退出时打、窗口化游玩看不到，也**不影响任何断言**。
func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_t += delta
	var k := clampf(_fade_t / FADE_SEC, 0.0, 1.0)
	if _active != null:
		_active.volume_db = lerpf(SILENT_DB, BGM_VOLUME_DB, k)
	if _out != null:
		_out.volume_db = lerpf(_out_from_db, SILENT_DB, k)
	if k >= 1.0:
		if _out != null:
			_out.stop()
		_out = null
		if _active != null:
			_active.volume_db = BGM_VOLUME_DB
		_fading = false


## 取（并缓存）某槽位的音频流；顺手把 loop 钉成 true。
func stream_for(slot: String) -> AudioStream:
	if _streams.has(slot):
		return _streams[slot]
	var path := BGM_DIR + slot + ".ogg"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	if s is AudioStreamOggVorbis:
		# 兜底：即使 .import 的 loop 被改回 false，运行时也强制循环
		(s as AudioStreamOggVorbis).loop = true
	_streams[slot] = s
	return s


## 只读状态快照（测试 / 调试面板用，**不改任何状态**）。
## `active_id` 是播放器实例号 —— 用来断言「同一槽位重复 play 不换播放器」。
func debug_state() -> Dictionary:
	return {
		"current": current,
		"fading": _fading,
		"active_id": _active.get_instance_id() if _active != null else 0,
		"active_playing": _active.playing if _active != null else false,
		"active_db": _active.volume_db if _active != null else 0.0,
		"out_id": _out.get_instance_id() if _out != null else 0,
		"loaded": _streams.keys(),
	}
