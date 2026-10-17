class_name GameSettings
extends RefCounted
## 全局设置（R215）—— 音效 / 音乐 / 全屏，落盘 `user://settings.cfg`。
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

static var _loaded := false


static func ensure_loaded() -> void:
	## 首次访问时读盘（静默：没有配置文件 = 全默认）。
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	sfx_on = bool(cf.get_value("audio", "sfx", true))
	music_on = bool(cf.get_value("audio", "music", true))
	fullscreen = bool(cf.get_value("display", "fullscreen", false))


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "sfx", sfx_on)
	cf.set_value("audio", "music", music_on)
	cf.set_value("display", "fullscreen", fullscreen)
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


static func set_fullscreen(v: bool) -> void:
	ensure_loaded()
	if v == fullscreen:
		return
	fullscreen = v
	apply_display()
	save()


static func apply_display() -> void:
	## 把 `fullscreen` 落到窗口上（headless / 无窗口时不碰 DisplayServer）。
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)
