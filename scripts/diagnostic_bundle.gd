extends RefCounted
## R763：本地诊断包（Steam A8）。
##
## 玩家点「导出诊断包」时，把**本机必要文件**打成一个 zip，放在 `user://diagnostics/`：
##   * 环境摘要：系统 / 版本 / Steam 状态 / 存档目录（不含 IP、账号、硬件序列号）
##   * settings.cfg / profile.json / run_records.json / run_save.sav / run_cleared.sav
##   * save_trace.log / logs/godot.log（存在才收）
##
## **不收集** `telemetry.jsonl`：那是平衡数据，不是崩溃诊断，且玩家可能已选择不上传。
## 也不上传任何内容；文件只留在玩家本机，由玩家自行发给作者。

const OUT_DIR := "user://diagnostics"
const MAX_LOG_BYTES := 4 * 1024 * 1024

const REAL_FILES := [
	"settings.cfg",
	"profile.json",
	"run_records.json",
	"run_save.sav",
	"run_cleared.sav",
	"save_trace.log",
	"daily_challenge.json",
]
const TEST_FILES := [
	"settings.cfg",
	"profile_test.json",
	"run_records_test.json",
	"run_save_test.sav",
	"save_trace_test.log",
	"daily_challenge_test.json",
]
const LOG_FILES := ["logs/godot.log", "logs/godot.log.1"]

static var _test_mode := false


static func set_test_mode(on := true) -> void:
	## 回归只能收测试文件，绝不许把玩家真实存档打进测试包。
	_test_mode = on


static func create(out_dir := OUT_DIR) -> Dictionary:
	## 返回 `{ok, path, entries, error}`。失败不会抛出，由调用方显示错误。
	var dir := _absolute(out_dir)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return {"ok": false, "path": "", "entries": 0, "error": "无法创建诊断目录"}
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace(" ", "_")
	var zip_path := dir.path_join("Quackill_diagnostics_%s.zip" % stamp)
	var packer := ZIPPacker.new()
	if packer.open(zip_path) != OK:
		return {"ok": false, "path": "", "entries": 0, "error": "无法创建诊断 zip"}
	var entries := 0
	if _add_text(packer, "system_info.txt", _system_info()):
		entries += 1
	for name: String in (TEST_FILES if _test_mode else REAL_FILES):
		if _add_file(packer, name, "user://" + name):
			entries += 1
	for name: String in LOG_FILES:
		if _add_file(packer, name, "user://" + name, MAX_LOG_BYTES):
			entries += 1
	packer.close()
	if entries == 0:
		DirAccess.remove_absolute(zip_path)
		return {"ok": false, "path": "", "entries": 0, "error": "没有可打包的诊断文件"}
	return {"ok": true, "path": zip_path, "entries": entries, "error": ""}


static func _system_info() -> String:
	var lines: Array[String] = []
	lines.append("Quackill diagnostic bundle")
	lines.append("generated_utc=%s" % Time.get_datetime_string_from_system(true))
	lines.append("game=%s / %s" % [GameBrand.NAME_CN, GameBrand.NAME_EN])
	lines.append("version=%s" % GameBrand.VERSION)
	lines.append("release_build=%s" % str(GameBuild.is_release()))
	lines.append("os=%s %s" % [OS.get_name(), OS.get_version()])
	lines.append("processor=%s" % OS.get_processor_name())
	lines.append("locale=%s" % OS.get_locale())
	lines.append("display=%s" % DisplayServer.get_name())
	lines.append("screen=%s" % str(DisplayServer.screen_get_size()))
	lines.append("steam=%s" % SteamAchievements.status_text())
	lines.append("user_dir=%s" % ProjectSettings.globalize_path("user://"))
	lines.append("run_active=%s" % str(RunState.run_active))
	lines.append("run_seed=%s" % RunState.seed_text())
	lines.append("run_layer=%d" % RunState.current_layer)
	lines.append("run_difficulty=%d" % RunState.difficulty)
	lines.append("save_content_version=%d" % RunSave.CONTENT_VERSION)
	lines.append("record_format=%d" % RunRecord.FORMAT)
	return "\n".join(lines) + "\n"


static func _add_file(packer: ZIPPacker, zip_name: String, source: String, max_bytes := 0) -> bool:
	var data := FileAccess.get_file_as_bytes(source)
	if data.is_empty():
		return false
	if max_bytes > 0 and data.size() > max_bytes:
		data = data.slice(data.size() - max_bytes)
	return _add_bytes(packer, zip_name, data)


static func _add_text(packer: ZIPPacker, zip_name: String, text: String) -> bool:
	return _add_bytes(packer, zip_name, text.to_utf8_buffer())


static func _add_bytes(packer: ZIPPacker, zip_name: String, data: PackedByteArray) -> bool:
	if packer.start_file(zip_name) != OK:
		return false
	packer.write_file(data)
	packer.close_file()
	return true


static func _absolute(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path
