# -*- coding: utf-8 -*-
"""R757 回归段：追加到 test_engine.gd 末尾（与 R744 段同缩进）。

盯四件事：
  1. 发布版闸门（测试版不写、test_mode 一关连发布版也不写）；
  2. 入队即记「候选组 id」—— 选择率的分母有没有真的落下；
  3. 五个埋点口有没有接线（提议 / 选择 / 跳过 / 战斗起止）；
  4. 追加必须用 READ_WRITE —— `WRITE_READ` 实测会从头覆盖（这条是血换来的）。
"""
import io

P = "scripts/test_engine.gd"

s = io.open(P, encoding="utf-8", newline="").read()
crlf = "\r\n" in s
if crlf:
    s = s.replace("\r\n", "\n")

BLOCK = """
\t# ---------------------------------------------------------------- R757 遥测
\t# ① 闸门：测试版**不写**事件流（这套是发布版独有的功能）。
\tGameBuild.set_test_release(0)
\tTelemetry.set_test_mode(false)
\tcheck(not Telemetry.is_enabled(), "R757 遥测：测试版不写事件流（发布版独有）")
\t# ② 发布版才开。
\tGameBuild.set_test_release(1)
\tcheck(Telemetry.is_enabled(), "R757 遥测：发布版闸门打开后才记录")
\t# ③ test_mode 一关，发布版也不写（回归 / 出图不许产出数据）。
\tTelemetry.set_test_mode(true)
\tcheck(not Telemetry.is_enabled(), "R757 遥测：test_mode 一关，发布版也闭嘴")
\tGameBuild.set_test_release(-1)
\t# ④ 入队即记「候选组 id」—— 选择率的分母只在这一刻存在。
\tRunState.reset(40)
\tRunState.reward_context = "battle"
\tvar r757_i := RunState.queue_card_reward("normal")
\tcheck(r757_i >= 0 and (RunState.pending_rewards[r757_i] as Dictionary).has("tel"),
\t\t\t"R757 埋点：卡牌奖励入队时带候选组 id（选择率的分母）")
\tRunState.clear_pending_rewards()
\tRunState.reward_context = ""
\t# ⑤ 五个埋点口的源码锁（这些是「忘了接一处就整批数据失真」的位置）。
\tvar r757_rs := FileAccess.get_file_as_string("res://scripts/run_state.gd")
\tvar r757_bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
\tcheck_src(r757_rs.contains("Telemetry.note_card_offer")
\t\t\tand r757_rs.contains("Telemetry.note_pick")
\t\t\tand r757_rs.contains("Telemetry.note_skip")
\t\t\tand r757_bs.contains("Telemetry.note_battle_start")
\t\t\tand r757_bs.contains("Telemetry.note_battle_end"),
\t\t\t"R757 接线：提议 / 选择 / 跳过 / 战斗起止 五个口都在")
\t# ⑥ 追加方式：必须 READ_WRITE。`WRITE_READ + seek_end()` 实测会从 0 覆盖，
\t#    表现是「每次启动把整份事件流重写一遍」——上一整局的数据成批消失。
\tvar r757_tel := FileAccess.get_file_as_string("res://scripts/telemetry.gd")
\tcheck_src(r757_tel.contains("FileAccess.open(_path, FileAccess.READ_WRITE)")
\t\t\tand not r757_tel.contains("FileAccess.open(_path, FileAccess.WRITE_READ)"),
\t\t\t"R757 源码锁：事件流用 READ_WRITE 追加（WRITE_READ 会从头覆盖）")
\t# ⑦ 「本局实际打出过哪些卡」走 card_play 差集 —— 不必在出牌热路径埋点。
\tcheck_src(r757_tel.contains("ProfileData.K_CARD_PLAY") and r757_tel.contains("\\"played\\""),
\t\t\t"R757 分析口径：本局打出的卡由 card_play 差集算出")
\t# ⑧ 隐私：测试版一律不许上传（opt_in 只对发布版生效）。
\tGameSettings.ensure_loaded()
\tcheck(not GameSettings.telemetry_upload_allowed(),
\t\t\t"R757 隐私：测试版一律不许上传")
"""

if "R757 遥测" in s:
    print("already present, skip")
else:
    s = s.rstrip("\n") + "\n" + BLOCK
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(P, "w", encoding="utf-8", newline="").write(s)
    print("appended. crlf=%s" % crlf)
