extends Node
## R763：桌面版单实例锁（Steam A6）。
##
## 为什么需要：`run_save.sav` / `run_records.json` / `save_trace.log` 都写在同一个
## `user://`。两个窗口同时开一局时，后写的进程可能把先写的检查点覆盖，出现「半截档」。
## 这里在**主场景实例化之前**抢一个 `user://instance.lock/` 目录：目录创建是原子的，
## 第二个进程看到活着的 owner PID 就提示并退出，不碰任何存档。
##
## 不依赖 Steam，也不依赖第三方库；headless / 截图探针 / Android 自动跳过，
## 避免回归套件和出图脚本被互相挡掉。
##
## 锁目录里只有一个 `owner` 文本文件（纯 PID）。进程崩溃留下的锁会在下次启动时
## 通过 `OS.is_process_running()` 判定为 stale 后回收。

const LOCK_DIR := "user://instance.lock"
const OWNER_FILE := "owner"
const ALERT_TITLE := "Quackill"

static var _owned_dir := ""


func _ready() -> void:
	if not _should_guard():
		return
	if acquire():
		return
	var msg := "Quackill 已经在运行。\n\n请切换到现有窗口；如果它已经无响应，请先结束该进程再启动。"
	OS.alert(msg, ALERT_TITLE)
	get_tree().quit(1)


func _exit_tree() -> void:
	release_lock()


static func _should_guard() -> bool:
	## 只守桌面真窗口。headless（回归 / 工具）和截图探针不能互相抢锁；
	## Android 本身只允许一个前台 Activity，不需要这层。
	if DisplayServer.get_name() == "headless":
		return false
	if OS.get_name() not in ["Windows", "macOS", "Linux"]:
		return false
	var args := OS.get_cmdline_user_args()
	if "--screenshot" in args or "--allow-multiple-instances" in args:
		return false
	return true


static func acquire(lock_dir := LOCK_DIR, owner_pid := -1) -> bool:
	## 抢锁；返回 false 表示已有活实例。`owner_pid` 仅供回归注入，生产不传。
	var dir := _absolute(lock_dir)
	var pid := owner_pid if owner_pid > 0 else OS.get_process_id()
	if DirAccess.dir_exists_absolute(dir):
		var existing := _read_owner(dir)
		if existing <= 0:
			# 目录已出现但 owner 还没写完：另一个进程正在创建，保守地让出。
			return false
		if existing == pid:
			_owned_dir = dir
			return true
		if _process_alive(existing):
			return false
		# 上次异常退出留下的目录：确认 PID 不在了才回收。
		_remove_lock_files(dir)
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return false
	var f := FileAccess.open(dir.path_join(OWNER_FILE), FileAccess.WRITE)
	if f == null:
		DirAccess.remove_absolute(dir)
		return false
	f.store_string(str(pid))
	f.close()
	_owned_dir = dir
	return true


static func release_lock(lock_dir := "") -> void:
	## 只释放自己持有的锁；不删别人的目录（避免误删第二个实例的锁）。
	var dir := _absolute(lock_dir) if lock_dir != "" else _owned_dir
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		_owned_dir = ""
		return
	var owner := _read_owner(dir)
	if owner == OS.get_process_id() or owner <= 0:
		_remove_lock_files(dir)
	_owned_dir = ""


static func _absolute(path: String) -> String:
	## 同时接受 `user://...` 和已经 globalize 的绝对路径（回归用后者）。
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _read_owner(dir: String) -> int:
	var f := FileAccess.open(dir.path_join(OWNER_FILE), FileAccess.READ)
	if f == null:
		return 0
	var text := f.get_as_text().strip_edges()
	f.close()
	if text.is_valid_int():
		return int(text)
	return 0


static func _process_alive(pid: int) -> bool:
	## Godot 4.3 的 OS 有 is_process_running；若某平台没有，保守当作活着。
	if pid <= 0:
		return false
	if OS.has_method("is_process_running"):
		return bool(OS.call("is_process_running", pid))
	return true


static func _remove_lock_files(dir: String) -> void:
	var owner := dir.path_join(OWNER_FILE)
	if FileAccess.file_exists(owner):
		DirAccess.remove_absolute(owner)
	if DirAccess.dir_exists_absolute(dir):
		DirAccess.remove_absolute(dir)
