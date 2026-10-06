class_name Sfx
extends Node
## 代码合成音效（无外部素材）：用 AudioStreamWAV 现场生成 PCM，
## 覆盖 上场/攻击/法术/治疗/击破/胜负/回合/点击 八种提示音。
##
## 用法：
##   var sfx := Sfx.new(); add_child(sfx)
##   sfx.play("attack")     # 播放（带轻微随机音高变化）
##   sfx.enabled = false    # 静音开关

const RATE := 22050
const VOICES := 8

var enabled := true
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams = {
		"click": _sfx_click(),
		"place": _sfx_place(),
		"attack": _sfx_attack(),
		"spell": _sfx_spell(),
		"heal": _sfx_heal(),
		"destroy": _sfx_destroy(),
		"win": _sfx_win(),
		"lose": _sfx_lose(),
		"turn": _sfx_turn(),
	}


func play(name: String) -> void:
	if not enabled or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()


# ------------------------------------------------------------ PCM 封装

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav


func _buf(dur: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(RATE * dur))
	return s


# ------------------------------------------------------------ 各音色

func _sfx_click() -> AudioStreamWAV:
	var s := _buf(0.06)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = 0.45 * sin(TAU * 1150.0 * t) * exp(-t * 80.0)
	return _wav(s)


func _sfx_place() -> AudioStreamWAV:
	# 低频「咚」：频率 170→80 快速下滑 + 指数衰减
	var s := _buf(0.18)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 80.0 + 90.0 * exp(-t * 18.0)
		phase += TAU * f / RATE
		s[i] = 0.7 * sin(phase) * exp(-t * 14.0)
	return _wav(s)


func _sfx_attack() -> AudioStreamWAV:
	# 打击感：噪声爆发 + 短促低频冲击
	var s := _buf(0.2)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * (60.0 + 110.0 * exp(-t * 12.0)) / RATE
		var noise := randf_range(-1.0, 1.0) * exp(-t * 24.0) * 0.55
		s[i] = noise + 0.5 * sin(phase) * exp(-t * 15.0)
	return _wav(s)


func _sfx_spell() -> AudioStreamWAV:
	# 上行闪音：两个滑升正弦叠加，带起音包络
	var s := _buf(0.42)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f1 := 500.0 + 900.0 * (t / 0.42)
		var f2 := 750.0 + 1350.0 * (t / 0.42)
		ph1 += TAU * f1 / RATE
		ph2 += TAU * f2 / RATE
		var env: float = minf(t * 30.0, 1.0) * exp(-t * 5.5)
		s[i] = 0.32 * (sin(ph1) + sin(ph2)) * env
	return _wav(s)


func _sfx_heal() -> AudioStreamWAV:
	# 治疗琶音 C5-E5-G5，依次进入
	var s := _buf(0.5)
	var notes := [523.25, 659.25, 783.99]
	var starts := [0.0, 0.11, 0.22]
	for k in notes.size():
		var phase := 0.0
		var i0 := int(RATE * float(starts[k]))
		for i in range(i0, s.size()):
			var t := float(i - i0) / RATE
			phase += TAU * float(notes[k]) / RATE
			s[i] += 0.3 * sin(phase) * exp(-t * 7.0)
	return _wav(s)


func _sfx_destroy() -> AudioStreamWAV:
	# 击破：碎裂噪声 + 深沉低音坠落
	var s := _buf(0.55)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * (45.0 + 40.0 * exp(-t * 8.0)) / RATE
		var noise := randf_range(-1.0, 1.0) * exp(-t * 8.0) * 0.5
		s[i] = noise + 0.55 * sin(phase) * exp(-t * 6.0)
	return _wav(s)


func _sfx_win() -> AudioStreamWAV:
	# 胜利：C4-E4-G4-C5 上行号角
	var s := _buf(1.0)
	var notes := [261.63, 329.63, 392.0, 523.25]
	for k in notes.size():
		var phase := 0.0
		var i0 := int(RATE * 0.13 * k)
		for i in range(i0, s.size()):
			var t := float(i - i0) / RATE
			phase += TAU * float(notes[k]) / RATE
			var env: float = minf(t * 25.0, 1.0) * exp(-t * 2.8)
			s[i] += 0.28 * sin(phase) * env
	return _wav(s)


func _sfx_lose() -> AudioStreamWAV:
	# 失败：A3-F3-D3 下行叹音
	var s := _buf(1.15)
	var notes := [220.0, 174.61, 146.83]
	for k in notes.size():
		var phase := 0.0
		var i0 := int(RATE * 0.28 * k)
		for i in range(i0, s.size()):
			var t := float(i - i0) / RATE
			phase += TAU * float(notes[k]) / RATE
			var env: float = minf(t * 18.0, 1.0) * exp(-t * 2.2)
			s[i] += 0.3 * sin(phase) * env
	return _wav(s)


func _sfx_turn() -> AudioStreamWAV:
	# 回合切换：柔和双音叮咚
	var s := _buf(0.3)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = 0.35 * sin(TAU * 880.0 * t) * exp(-t * 13.0) \
				+ 0.15 * sin(TAU * 1318.5 * t) * exp(-t * 18.0)
	return _wav(s)
