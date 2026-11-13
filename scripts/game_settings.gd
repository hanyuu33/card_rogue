class_name GameSettings
extends RefCounted
## 全局设置（R215）—— 音效 / 音乐 / 全屏，落盘 `user://settings.cfg`。
## R246：音效 / 音乐各加一档**音量**（0~1，10% 一档）；`Sfx` / `Bgm` 建好时读它。
##
## 为什么要有它：标题页原来**没有设置入口**，音效开关只散在各场景的 Esc 菜单里，
## 而且关掉之后一换场景就恢复默认（每个场景新建 Sfx 都是 `enabled = true`）。
## 现在三项设置集中在这里：
##   * `Sfx` 建好时读 `sfx_on`，节点退出时把当前值写回 —— 老的「音效：开/关」菜单项
##     一行不改也变成了「记住」的；
##   * `Bgm` 建好时读 `music_on`（`--nomusic` 仍优先于它）；
##   * 全屏在启动时应用一次，设置页切换时立即应用。
##
## 纪律：`save()` 只在**值真的变了**时写盘（`Sfx` 每个场景都会建一次，
## 退出时无条件写会让每次切场景都动一次文件）。

const PATH := "user://settings.cfg"

static var sfx_on := true
static var music_on := true
static var fullscreen := false
## R246 音量（0.0 ~ 1.0，线性）：100% = 原来的音量（音效 0dB / 音乐 -12dB）。
static var sfx_volume := 1.0
static var music_volume := 1.0
## R241 / R261「下一局种子」：空 = 每局随机；非空 = **10 位大写字母 / 数字**的种子码
## （新开一局就用它 —— 复现某一局用）。旧版存的是 int（`run/seed`）→ `ensure_loaded` 时
## 迁移成同值的 10 位码，复现结果不变。
## R261 起角色选择页也有种子输入框（那里更贴近「开局前」），这里是跨进程保留的默认值。
static var next_seed_code := ""
## R388：战斗内「敌方动画倍速」—— 1.0 / 1.5 / 2.0 三档，顶栏按钮循环切换。
## 它只作用在**敌方回合的演出时钟**上（见 battle_scene 的 `_foe_phase`）：
## 玩家自己的出牌 / 拖拽 / 飘字一律照常，敌人那套走位、攻击、击破按 1.5× / 2× 播。
static var foe_speed := 1.0
## R660：界面语言。存 code（zh / en / ja…），不认识的值交给 L10n 回退，
## 本文件**不做语言白名单** —— 以后加语言只改 `scripts/l10n.gd` 的注册表。
static var language := "zh"
## 是否已经完成过「首次语言选择」。正式版第一次进首页前会看这一位；
## 老玩家（已有档案 / 存档 / 对战记录）视为已选择，不拿一次弹窗打断他们。
static var language_chosen := false

## R388：合法档位 —— 按钮就是在这三个值里循环（1 → 1.5 → 2 → 1）。
const FOE_SPEEDS := [1.0, 1.5, 2.0]

static var _loaded := false


static func ensure_loaded() -> void:
	## 首次访问时读盘（静默：没有配置文件 = 全默认）。
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		_apply_locale()
		return
	sfx_on = bool(cf.get_value("audio", "sfx", true))
	music_on = bool(cf.get_value("audio", "music", true))
	sfx_volume = clampf(float(cf.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(cf.get_value("display", "fullscreen", false))
	foe_speed = normalize_foe_speed(float(cf.get_value("battle", "foe_speed", 1.0)))
	language = str(cf.get_value("i18n", "language", "zh")).strip_edges().to_lower()
	if language == "":
		language = "zh"
	language_chosen = bool(cf.get_value("i18n", "chosen", false))
	next_seed_code = str(cf.get_value("run", "seed_code", ""))
	if next_seed_code == "":
		# 旧版（R241~R260）的 int 种子 → 迁移成同值的 10 位种子码（复现结果不变）
		var legacy := int(cf.get_value("run", "seed", 0))
		if legacy > 0:
			next_seed_code = RunState.seed_text_of(legacy)
	# 开发 / 出图口：`--lang=en` 只覆盖本次进程的语言，不写盘（正式玩家走设置页）。
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			var ov := a.substr("--lang=".length()).strip_edges().to_lower()
			if ov != "":
				language = ov
	_apply_locale()


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "sfx", sfx_on)
	cf.set_value("audio", "music", music_on)
	cf.set_value("audio", "sfx_volume", sfx_volume)
	cf.set_value("audio", "music_volume", music_volume)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("battle", "foe_speed", foe_speed)
	cf.set_value("i18n", "language", language)
	cf.set_value("i18n", "chosen", language_chosen)
	cf.set_value("run", "seed_code", next_seed_code)
	# 旧键（int 种子）清掉：否则玩家把种子清空后，下次启动又被旧键迁移回来
	if cf.has_section_key("run", "seed"):
		cf.erase_section_key("run", "seed")
	cf.save(PATH)


static func set_sfx_on(v: bool) -> void:
	ensure_loaded()
	if v == sfx_on:
		return
	sfx_on = v
	save()


static func set_music_on(v: bool) -> void:
	ensure_loaded()
	if v == music_on:
		return
	music_on = v
	save()


static func set_sfx_volume(v: float) -> void:
	## R246：0~1 线性音量（调用方负责把它落到正在播的 `Sfx` 实例上）。
	## 只在**真的变了**时写盘 —— 与其它 setter 同一条纪律。
	ensure_loaded()
	var nv := clampf(v, 0.0, 1.0)
	if is_equal_approx(nv, sfx_volume):
		return
	sfx_volume = nv
	save()


static func set_music_volume(v: float) -> void:
	## R246：同上（音乐）。
	ensure_loaded()
	var nv := clampf(v, 0.0, 1.0)
	if is_equal_approx(nv, music_volume):
		return
	music_volume = nv
	save()


static func set_fullscreen(v: bool) -> void:
	ensure_loaded()
	if v == fullscreen:
		return
	fullscreen = v
	apply_display(true)
	save()


static func normalize_foe_speed(v: float) -> float:
	## R388：不认识的数（旧档 / 手改配置文件）一律回落 1× ——
	## 宁可没加速，也不能出现 3.7× 这种玩家没选过的档位。
	for s in FOE_SPEEDS:
		if absf(v - float(s)) < 0.01:
			return float(s)
	return 1.0


static func next_foe_speed(v: float) -> float:
	## R388：点一次按钮的下一个档位：1 → 1.5 → 2 → 1（循环）。
	var cur := normalize_foe_speed(v)
	var i: int = FOE_SPEEDS.find(cur)
	return float(FOE_SPEEDS[(i + 1) % FOE_SPEEDS.size()])


static func set_foe_speed(v: float) -> void:
	## R388：与其它 setter 同一条纪律 —— 只在**真的变了**时写盘
	## （战斗里每点一次都会调到，但点回同一档不该动文件）。
	ensure_loaded()
	var nv := normalize_foe_speed(v)
	if is_equal_approx(nv, foe_speed):
		return
	foe_speed = nv
	save()


static func set_language(code: String, chosen := true) -> void:
	## R660：设置页与首次选择页的**唯一落地点**。空值回落中文；
	## 只改真的变了的字段（同 setter 纪律），然后同步 TranslationServer 的 locale，
	## 以后接 `.translation` 资源时不用再补一条调用链。
	ensure_loaded()
	var nv := code.strip_edges().to_lower()
	if nv == "":
		nv = "zh"
	var dirty := false
	if nv != language:
		language = nv
		dirty = true
	if chosen and not language_chosen:
		language_chosen = true
		dirty = true
	_apply_locale()
	if dirty:
		save()


static func _apply_locale() -> void:
	## 界面文案走 `L10n` 查表，但 locale 仍要同步给引擎：
	## 日期 / 数字格式和以后加载的 Translation 资源都读这一个值。
	match language:
		"zh":
			TranslationServer.set_locale("zh_CN")
		"ja":
			TranslationServer.set_locale("ja")
		"en":
			TranslationServer.set_locale("en")
		_:
			TranslationServer.set_locale(language)


static func needs_language_pick() -> bool:
	## R660：正式版**首次进首页前**是否要开语言选择。
	##   * 测试版默认不弹（开发 / 回归不被挡）；
	##   * `--force-language-pick` 供出图与探针强制打开；
	##   * 老玩家已有档案 / 存档 / 对战记录 → 视为已选择，补写 chosen，不打扰。
	ensure_loaded()
	if "--force-language-pick" in OS.get_cmdline_user_args():
		return true
	if language_chosen or not GameBuild.is_release():
		return false
	if _has_existing_progress():
		language_chosen = true
		save()
		return false
	return true


static func _has_existing_progress() -> bool:
	## 只读探测：任一存在即认为不是「第一次打开正式版」。
	## 不调 ProfileData / RunSave 的加载函数 —— 这一问发生在首页之前，
	## 不该为了判断有没有档就把整套档案读一遍（也避免它们顺手写盘）。
	for p in ["user://profile.json", "user://run_save.sav", "user://run_records.json"]:
		if FileAccess.file_exists(p):
			return true
	return false


static func set_next_seed_code(v: String) -> void:
	## 规范化成 10 位种子码；**非法（长度不对 / 含 A-Z0-9 以外的字符 / 全 0）
	## 一律当「随机」**（存空串）。输入到一半的半截串由界面自己管 ——
	## 落盘的只会是「合法的码」或「空」。
	ensure_loaded()
	var nv := v.strip_edges().to_upper()
	if RunState.seed_value_of(nv) < 0:
		nv = ""
	if nv == next_seed_code:
		return
	next_seed_code = nv
	save()


static func apply_display(force := false) -> void:
	## 把 `fullscreen` 落到窗口上（headless / 无窗口时不碰 DisplayServer）。
	##
	## R635（店长报「开故事界面、关掉回主界面，全屏会变窗口」）：
	## 根因**不在故事界面** —— 探针实测 story → title 全程 FULLSCREEN，是主界面
	## `_ready` 每次都无条件按 `fullscreen` 重设窗口。而玩家的全屏常常不是本设置页
	## 给的（引擎 / 系统层面：F11、`--fullscreen`、窗口管理器），`settings.cfg`
	## 里仍是 `fullscreen=false` → 每回一次主界面就被打回窗口。
	##
	## R672（店长再报同一条）—— R635 只挡住了 FULLSCREEN，**漏了窗口最大化**：
	## 玩家嘴里的「全屏」有两种，Windows 上点右上角最大化视觉上几乎一样。
	## 旧代码走到 `window_set_mode(WINDOWED)`，而设成 WINDOWED **会顺手退出最大化**
	## （探针 `-- --maximized` 实测：故事里 MAXIMIZED → 回主界面 WINDOWED）。
	##
	## 所以 `force = false`（启动 / 回主界面）改成**只补不降**：
	##   * 已经是全屏 → 什么都不做，只把内存值对齐成 true（不写盘）；
	##   * 已经是最大化 → 什么都不做（不许拿「记下来的是关」去否定玩家的窗口现状）；
	##   * 记着要全屏、窗口却不是 → 补成全屏；
	##   * 记着不要全屏、窗口也是普通窗口 → 什么都不做。
	## `force = true`（设置页切换全屏）必须强制落值，否则「关掉全屏」会被现状顶回来。
	if DisplayServer.get_name() == "headless":
		return
	var m := DisplayServer.window_get_mode()
	if force:
		DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)
		return
	if m == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		# 现状就是全屏 → 对齐内存值（设置页要显示成「开」），窗口一动不动
		fullscreen = true
		return
	if m == DisplayServer.WINDOW_MODE_MAXIMIZED:
		# ⚠️ 这一行是 R672 的修复本体。删掉它就退回「每次回主界面全屏掉成小窗」。
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
