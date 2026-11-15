class_name TelemetryUploader
extends Node
## R757：把本机攒下的匿名事件流**增量**发出去（只发一次成功过的部分）。
##
## 三条硬约束：
##   1. **只在同意后发** —— 判据 `GameSettings.telemetry_upload_allowed()`，
##      即「发布版 + 玩家点过同意」。测试版 / 没同意 / 没配端点，一律什么都不做。
##   2. **只发一次** —— `user://telemetry.sent` 记「已成功发送的字节偏移」，
##      下次从那个位置往后发。失败就把偏移留在原处，下个进程重试，不重复计。
##   3. **只发完整的行** —— 事件流是一行一条 JSON。按字节切会把一行 JSON 从中间劈开，
##      服务端解析不了、作者还得手工捞；这里一律切到最后一个换行符。
##
## 为什么不做「发送成功就删本地」：本地事件流是玩家自己的东西（也是作者的地面真值），
## 删了就没法在玩家机器上复查「为什么这条统计长这样」。偏移文件很小，留着没有代价。
##
## 触发点：标题页 `_ready` 调 `maybe_start()` —— 一局游戏期间不发，
## 免得在战斗 / 转场时抢带宽，也让「上传」这件事和「正在玩」错开。

const SENT_PATH := "user://telemetry.sent"
const CHUNK := 256 * 1024        ## 单批上限：一次最多发这么多字节（约几千条事件）

static var _running := false

var _pending_bytes := 0          ## 本批实际覆盖了多少字节（POST 成功后写进偏移）


static func maybe_start() -> void:
	## 唯一入口。任何一条不满足就安静返回 —— 这条路径上不允许有弹窗 / 报错。
	if _running:
		return
	if Telemetry.UPLOAD_ENDPOINT == "":
		return
	if not GameSettings.telemetry_upload_allowed():
		return
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	# ⚠️ `load()` 而不是 `TelemetryUploader.new()`：静态函数引用自身 class_name 在
	#    `--check-only` 单文件解析时会报 Identifier not found（项目里统一这么绕）。
	tree.root.add_child(load("res://scripts/telemetry_uploader.gd").new())
	_running = true


func _ready() -> void:
	call_deferred("_pump")


func _pump() -> void:
	var payload := _read_chunk()
	if payload.is_empty():
		_finish()
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.request_completed.connect(_on_done.bind(http))
	var headers := PackedStringArray([
		"Content-Type: text/plain; charset=utf-8",
		"X-Quackill-Schema: %d" % Telemetry.SCHEMA,
	])
	var err := http.request(Telemetry.UPLOAD_ENDPOINT, headers,
			HTTPClient.METHOD_POST, payload)
	if err != OK:
		_finish()


func _on_done(result: int, code: int, _headers: PackedStringArray,
		_body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_write_offset(_read_offset() + _pending_bytes)
		call_deferred("_pump")      # 还有剩余就接着发（一次进程最多把存量清完）
	else:
		## 失败就停手：偏移不动，下次启动从头重试这一批。连不上比丢数据可接受得多。
		_finish()


func _finish() -> void:
	_running = false
	queue_free()


# ------------------------------------------------------------ 读

func _read_chunk() -> String:
	## 返回「这一批要发的完整行」（可能为空 = 没有新的完整行）。
	## ⚠️ 只切到最后一个换行符：事件流是一行一条 JSON，按字节切会把一条劈成两半，
	##    服务端解析不了，作者还得手工捞。
	if not FileAccess.file_exists(Telemetry.PATH):
		return ""
	var probe := FileAccess.open(Telemetry.PATH, FileAccess.READ)
	if probe == null:
		return ""
	var total := probe.get_length()
	probe.close()
	var off := _read_offset()
	if off >= total:
		## 文件被轮转 / 清空后偏移会超过长度 —— 从头来过，别把自己卡死在文件尾。
		if off > total:
			_write_offset(0)
			off = 0
		else:
			return ""
	var f := FileAccess.open(Telemetry.PATH, FileAccess.READ)
	if f == null:
		return ""
	f.seek(off)
	var n := mini(CHUNK, total - off)
	var raw := f.get_buffer(n)
	f.close()
	var txt := raw.get_string_from_utf8()
	var cut := txt.rfind("\n")
	if cut < 0:
		return ""                   # 半行都没有：等下一次追加
	txt = txt.substr(0, cut + 1)
	_pending_bytes = txt.to_utf8_buffer().size()
	return txt


func _read_offset() -> int:
	if not FileAccess.file_exists(SENT_PATH):
		return 0
	var s := FileAccess.get_file_as_string(SENT_PATH).strip_edges()
	return int(s) if s.is_valid_int() else 0


func _write_offset(v: int) -> void:
	var f := FileAccess.open(SENT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(str(maxi(0, v)))
