class_name Net
extends RefCounted
## 局域网联机网络层（对应 Python 版 cardtool/online.py 的网络部分）。
##
## 范围与限制（与 Python 版一致）：
## * 只做**同一局域网内**对战：房间发现走 UDP 广播，对局数据走 TCP。
## * 跨互联网需要 ZeroTier / Tailscale 等虚拟局域网，装好后手动输 IP 即可。
##
## 协议（TCP，4 字节大端长度 + JSON UTF-8）：
## * 握手：客户端发 ``hello``（昵称、卡组张数、协议版本）→ 房主回 ``welcome``。
## * 行动：``{"type":"action","act":"play|spell|move|attack|hp",...}``
## * 回合：``{"type":"end_turn"}``；离开：``{"type":"bye"}``
##
## 实现说明：Python 版用后台线程 + 队列；GDScript 这里改为**轮询式**——
## 每帧调 :meth:`poll`（场景 _process 里），收到的消息进入 :attr:`inbox`。
## 无需线程，headless 测试也能手动循环 poll。

const DISCOVER_PORT := 47812
const DISCOVER_MAGIC := "CARDDUEL-DISCOVER-v1"
const PROTOCOL_VERSION := 1
const HANDSHAKE_TIMEOUT := 10.0
const MAX_PACKET := 8 * 1024 * 1024   # 防御：超大包直接断开（同 Python 版）
const NET_GAP_MS := 1650               # 对方两条动作之间的回放间隔（看清对方做了什么）


# ================================================================ NetLink

class NetLink:
	extends RefCounted
	## 一条 TCP 连接的轮询封装。
	## * send(obj)：发送任意可 JSON 化对象（4 字节长度前缀 + JSON UTF-8）；
	## * poll()：从 socket 收包进 inbox；断线时往 inbox 放 null 哨兵；
	## * get_nowait()：界面每帧取用。

	var peer: StreamPeerTCP
	var alive := true
	var inbox: Array = []
	var _rx := PackedByteArray()

	func _init(peer_: StreamPeerTCP = null) -> void:
		peer = peer_

	static func connect_to(host: String, port: int, timeout_ms := 5000) -> NetLink:
		## 阻塞式连接（等待直到 STATUS_CONNECTED 或超时）。
		var tcp := StreamPeerTCP.new()
		if tcp.connect_to_host(host, port) != OK:
			return null
		var deadline := Time.get_ticks_msec() + timeout_ms
		while Time.get_ticks_msec() < deadline:
			tcp.poll()
			if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				return NetLink.new(tcp)
			if tcp.get_status() == StreamPeerTCP.STATUS_ERROR:
				return null
			OS.delay_msec(20)
		return null

	func poll() -> void:
		if not alive:
			return
		peer.poll()
		var st := peer.get_status()
		if st != StreamPeerTCP.STATUS_CONNECTED:
			# 已连接的对端掉线后状态变为 ERROR / NONE
			alive = false
			inbox.append(null)   # 断线哨兵
			return
		var avail := peer.get_available_bytes()
		if avail > 0:
			var res := peer.get_partial_data(avail)
			if res[0] != OK:
				alive = false
				inbox.append(null)
				return
			_rx.append_array(res[1])
		_parse_rx()

	func _parse_rx() -> void:
		## 从接收缓冲切出完整帧：4 字节大端长度 + JSON。
		while alive and _rx.size() >= 4:
			var length: int = (_rx[0] << 24) | (_rx[1] << 16) | (_rx[2] << 8) | _rx[3]
			if length > MAX_PACKET:
				alive = false
				inbox.append(null)
				return
			if _rx.size() < 4 + length:
				return
			var payload := _rx.slice(4, 4 + length)
			_rx = _rx.slice(4 + length)
			var data: Variant = JSON.parse_string(payload.get_string_from_utf8())
			inbox.append(data)

	func send(obj) -> bool:
		## 发送 JSON 消息；失败返回 false（调用方应按断线处理）。
		if not alive:
			return false
		var data := JSON.stringify(obj).to_utf8_buffer()
		if data.size() > MAX_PACKET:
			return false
		var head := PackedByteArray()
		head.resize(4)
		var n := data.size()
		head[0] = (n >> 24) & 0xFF
		head[1] = (n >> 16) & 0xFF
		head[2] = (n >> 8) & 0xFF
		head[3] = n & 0xFF
		var err := peer.put_data(head)
		if err == OK:
			err = peer.put_data(data)
		if err != OK:
			alive = false
			inbox.append(null)
			return false
		return true

	func get_nowait():
		if inbox.is_empty():
			return null
		return inbox.pop_front()

	func drain_into(queue: Array) -> bool:
		## 把 inbox 全部搬进 queue；返回是否遇到断线哨兵（None）。
		while not inbox.is_empty():
			var msg = inbox.pop_front()
			if msg == null:
				return true
			queue.append(msg)
		return false

	func close() -> void:
		alive = false
		if peer != null:
			peer.disconnect_from_host()


# ================================================================ 房间发现

class Discoverer:
	extends RefCounted
	## UDP 广播找房间：start() 发探测包，poll() 收应答，done() 后取 results()。

	var _udp := PacketPeerUDP.new()
	var _deadline := 0
	var rooms := {}   # "host:port" -> {"host","port","name"}

	func start(timeout := 1.8, extra_targets: PackedStringArray = []) -> void:
		_udp.set_broadcast_enabled(true)
		_udp.bind(0)
		var magic := DISCOVER_MAGIC.to_utf8_buffer()
		var dests := PackedStringArray(["255.255.255.255", "127.0.0.1"])
		for ip in extra_targets:
			if not dests.has(ip):
				dests.append(ip)
		for dest in dests:
			_udp.set_dest_address(dest, DISCOVER_PORT)
			_udp.put_packet(magic)
		_deadline = Time.get_ticks_msec() + int(timeout * 1000)

	func poll() -> void:
		while _udp.get_available_packet_count() > 0:
			var pkt := _udp.get_packet()
			var ip := _udp.get_packet_ip()
			var data: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if data is Dictionary and int(data.get("port", 0)) > 0:
				var port := int(data["port"])
				# 同一房间的应答可能来自局域网 IP 和 127.0.0.1 两条路 → 按端口去重
				var key := "room:%d" % port
				if not rooms.has(key):
					rooms[key] = {"host": ip, "port": port,
							"name": str(data.get("name", "未命名房间"))}

	func done() -> bool:
		return Time.get_ticks_msec() >= _deadline

	func results() -> Array:
		return rooms.values()


class RoomServer:
	extends RefCounted
	## 创建房间：TCP 等一个玩家接入 + UDP 广播应答（供「自动匹配」发现）。
	## 轮询式：场景 _process 每帧调 poll()；连上第一个玩家后自动停止广播。

	var room_name: String
	var on_connected: Callable      # (link: NetLink)
	var port := 0
	var _srv := TCPServer.new()
	var _udp := PacketPeerUDP.new()
	var _udp_ok := false
	var _stopped := false

	func _init(name_: String, on_connected_: Callable) -> void:
		room_name = name_
		on_connected = on_connected_

	func start() -> int:
		var err := _srv.listen(0, "*")
		if err != OK:
			return err
		port = _srv.get_local_port()
		_udp_ok = _udp.bind(DISCOVER_PORT) == OK
		return OK

	func poll() -> void:
		if _stopped:
			return
		# Godot 4 的 TCPServer 由主循环自动轮询，直接查可用连接即可
		if _srv.is_connection_available():
			var link := NetLink.new(_srv.take_connection())
			stop()   # 只收一个玩家：进来就停止广播与接入
			on_connected.call(link)
			return
		if not _udp_ok:
			return
		while _udp.get_available_packet_count() > 0:
			var pkt := _udp.get_packet()
			if pkt.get_string_from_utf8() != DISCOVER_MAGIC:
				continue
			var reply := JSON.stringify({"name": room_name, "port": port})
			_udp.set_dest_address(_udp.get_packet_ip(), _udp.get_packet_port())
			_udp.put_packet(reply.to_utf8_buffer())

	func stop() -> void:
		_stopped = true
		_srv.stop()
		_udp.close()


# ================================================================ 工具

static func local_ips() -> Array[String]:
	## 本机在局域网里的 IPv4（排除回环/链路本地；可能多个）。
	var out: Array[String] = []
	for ip in IP.get_local_addresses():
		var s := str(ip)
		if s.contains(":"):
			continue   # IPv6
		if s.begins_with("127.") or s.begins_with("169.254."):
			continue
		if not out.has(s):
			out.append(s)
	return out


static func handshake_payload(name: String, deck_size: int) -> Dictionary:
	## 握手消息公共字段：昵称 / 卡组张数 / 协议版本（同 Python 版结构）。
	return {"name": name, "deck": deck_size, "ver": PROTOCOL_VERSION}


static func wait_msg(link: NetLink, want: String, timeout: float,
		tick: Callable) -> Dictionary:
	## 阻塞等待某类握手消息（只能在调用方自己驱动 poll 的循环里用）。
	## ``tick`` 每次等待间隙被调用（调用方借此刷新 socket）。
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		link.poll()
		while link.inbox.size() > 0:
			var msg = link.inbox.pop_front()
			if msg == null:
				return {}
			if msg is Dictionary and str(msg.get("type")) == want:
				return msg
		if not link.alive:
			return {}
		tick.call()
		OS.delay_msec(20)
	return {}
