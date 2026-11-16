extends SceneTree
## R764 探针：模拟「战斗中打开设置浮层、关掉音效 / 音量拉到 0」，
## 验证战斗场景那份 Sfx 是否立刻静默，以及它退出时会不会把玩家的「关」写回成「开」。
## 跑法：godot --headless --path . --script tools/_probe_r764_mute.gd
##
## 判据用「下一个要用的播放器有没有被赋值 stream」，不用 `playing`：
## click 只有 60ms，上一发还在响的时候测 `playing` 会把残响当成新声音（第一版就踩了）。

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSettings.ensure_loaded()
	var on0 := GameSettings.sfx_on
	var vol0 := GameSettings.sfx_volume
	var fail := 0

	# ---- 基线：音效开着时确实会播出声音（证明探针本身抓得到发声）----
	GameSettings.sfx_on = true
	GameSettings.sfx_volume = 1.0
	var battle := Sfx.new()
	root.add_child(battle)
	await process_frame
	print("[probe] battle.enabled@boot = ", battle.enabled, " / volume = ", battle.volume)
	battle.play("click")
	await process_frame
	var base := _stream_set(battle, 0)
	print("[probe] 基线（音效开）voice0 已赋值 = ", base)
	if not base:
		fail += 1

	# ---- 模拟设置浮层里关掉音效（R655 那条路）----
	GameSettings.set_sfx_on(false)
	Sfx.sync_all(self)
	battle.play("click")
	await process_frame
	var muted_ok := not _stream_set(battle, 1)
	print("[probe] 关音效后 battle.enabled = ", battle.enabled,
			" / voice1 已赋值 = ", not muted_ok, " → ", "拦住" if muted_ok else "还在响")
	if not muted_ok:
		fail += 1

	# ---- 硬闸：别处没同步实例、只改了设置，也必须拦住 ----
	battle.enabled = true                 # 假装这个实例的缓存没被 sync_all 摸到
	battle.play("click")
	await process_frame
	var hard_ok := not _stream_set(battle, 2)
	print("[probe] 只改设置（实例 enabled=true）voice2 已赋值 = ",
			not hard_ok, " → ", "硬闸拦住" if hard_ok else "漏了")
	if not hard_ok:
		fail += 1

	# ---- 战斗场景退出：不许把设置改回「开」----
	battle.queue_free()
	await process_frame
	print("[probe] 场景退出后 GameSettings.sfx_on = ", GameSettings.sfx_on)
	if GameSettings.sfx_on:
		fail += 1

	# ---- 音量拉到 0 也要静默 ----
	GameSettings.set_sfx_on(true)
	var battle2 := Sfx.new()
	root.add_child(battle2)
	await process_frame
	GameSettings.set_sfx_volume(0.0)
	Sfx.sync_all(self)
	battle2.play("click")
	await process_frame
	var vol_ok := not _stream_set(battle2, 0)
	print("[probe] 音量 0 时 voice0 已赋值 = ", not vol_ok,
			" → ", "拦住" if vol_ok else "还在响")
	if not vol_ok:
		fail += 1

	# ---- 恢复音量后必须还能响（别把嘴永久缝上）----
	GameSettings.set_sfx_volume(1.0)
	Sfx.sync_all(self)
	battle2.play("click")
	await process_frame
	# 注意：被拦住时 `_next` 不前进（return 在轮转之前），所以成功这发仍落在 voice0
	var back_ok := _stream_set(battle2, 0)
	print("[probe] 恢复音量后 voice0 已赋值 = ", back_ok)
	if not back_ok:
		fail += 1
	battle2.queue_free()
	await process_frame

	GameSettings.sfx_on = on0
	GameSettings.sfx_volume = vol0
	GameSettings.save()

	print("[probe] 结果 = ", "PASS" if fail == 0 else "FAIL(%d)" % fail)
	quit(0 if fail == 0 else 1)


func _stream_set(s: Sfx, idx: int) -> bool:
	return s._players[idx].stream != null
