# -*- coding: utf-8 -*-
"""R764：设置里的音效开关 / 音量改成「硬闸」—— 战斗中开浮层关声音也必须立刻静默。

三个改动点（全部 exact-replace + assert count==1）：
  A. scripts/sfx.gd            加 settings_silent() 判据口 + sync_all() 广播 + play() 硬闸
                               + _exit_tree 只写回「本实例真被改过」的开关
  B. scripts/settings_scene.gd 开关 / 音量两处都 sync_all(get_tree())
  C. scripts/test_engine.gd    R764 回归断言

行尾：sfx.gd / settings_scene.gd = LF，test_engine.gd = CRLF（一律 bytes 读写）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def patch(rel, pairs, nl):
    path = ROOT + rel
    raw = open(path, "rb").read()
    for old, new in pairs:
        ob = old.replace("\n", nl).encode("utf-8")
        nb = new.replace("\n", nl).encode("utf-8")
        cnt = raw.count(ob)
        assert cnt == 1, "%s: 锚点命中 %d 次（应为 1）:\n%s" % (rel, cnt, old[:120])
        raw = raw.replace(ob, nb)
    open(path, "wb").write(raw)
    print("OK %s (%d 处)" % (rel, len(pairs)))


# ---------------------------------------------------------------- A. sfx.gd
A = [
    (
        """var enabled := true
## R246：音量（0.0~1.0 线性）。100% = 0dB（原音量）；每次播放时落到播放器上。
var volume := 1.0
var _streams := {}""",
        """const GROUP := "sfx"

var enabled := true
## R246：音量（0.0~1.0 线性）。100% = 0dB（原音量）；每次播放时落到播放器上。
## R764：它只是**本实例**这一层上限 —— 真正的静音判据是 `settings_silent()`。
var volume := 1.0
## R764：进树那一刻的开关快照 —— `_exit_tree` 只在**本实例真被改过**时才写回设置。
var _enabled_boot := true
var _streams := {}""",
    ),
    (
        """\tenabled = GameSettings.sfx_on
\tvolume = GameSettings.sfx_volume
\tfor i in VOICES:""",
        """\tenabled = GameSettings.sfx_on
\t_enabled_boot = enabled
\tvolume = GameSettings.sfx_volume
\tadd_to_group(GROUP)   # R764：设置一改，sync_all 就能把所有活着的实例对齐
\tfor i in VOICES:""",
    ),
    (
        """func _exit_tree() -> void:
\t## R215：离场时把当前开关写回设置 —— 「音效：开/关」从此跨场景记住。
\tGameSettings.set_sfx_on(enabled)""",
        """func _exit_tree() -> void:
\t## R215：离场时把当前开关写回设置 —— 「音效：开/关」从此跨场景记住。
\t## R764：**只写「本实例真被改过」的那种**。设置页是浮层（R655），在战斗里关掉音效时
\t## 改的是浮层自己那份实例，战斗场景这份根本没动；它退出时若照旧无条件写回，
\t## 就把玩家刚关掉的开关又打开 —— 现象正是「关了所有声音，下一场战斗又有提示音」。
\t## Esc 菜单那条路自己改 `enabled`，与快照不同，所以那个记忆功能仍然保留。
\tif enabled != _enabled_boot:
\t\tGameSettings.set_sfx_on(enabled)""",
    ),
    (
        """func play(name: String) -> void:
\tif not enabled or not _streams.has(name):
\t\treturn
\tvar p := _players[_next]
\t_next = (_next + 1) % VOICES
\tp.stream = _streams[name]
\tp.pitch_scale = randf_range(0.96, 1.04)
\t# R246：音量 0 = 直接不播（linear_to_db(0) 是 -inf，别让它进到播放器里）
\tif volume <= 0.001:
\t\treturn
\tp.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
\tp.play()""",
        """static func settings_silent() -> bool:
\t## R764：**全局静音的唯一判据口** —— 每次都现问设置，不信实例里的缓存。
\t## 为什么必须有它：Sfx 是「各场景一份」（`TopBar` 那份还是 autoload，活到进程结束），
\t## 实例的 `enabled` 只在 `_ready` 那一刻与设置对齐。战斗里开设置浮层（R655）关音效，
\t## 改的是浮层自己那份实例 → 战斗那份照旧 `enabled = true`，于是「关了还在响」。
\tGameSettings.ensure_loaded()
\treturn (not GameSettings.sfx_on) or GameSettings.sfx_volume <= 0.001


static func sync_all(tree: SceneTree) -> void:
\t## R764：设置一改就把**所有活着的实例**对齐（浮层里关声音时，宿主战斗那份也要跟上）。
\t## 只对齐「开关」与「音量上限」；真正的静音判据始终是 `settings_silent()`。
\tif tree == null:
\t\treturn
\tfor n in tree.get_nodes_in_group(GROUP):
\t\tvar s := n as Sfx
\t\tif s != null:
\t\t\ts.enabled = GameSettings.sfx_on
\t\t\ts.volume = GameSettings.sfx_volume


func play(name: String) -> void:
\tif not enabled or not _streams.has(name):
\t\treturn
\t# R764：设置是**硬闸** —— 别处（设置浮层 / 顶栏）改过开关或把音量拉到 0，
\t# 本实例立刻静默，不必等下一次 `_ready`。
\tif settings_silent():
\t\treturn
\tvar vol := minf(volume, GameSettings.sfx_volume)
\t# R246：音量 0 = 直接不播（linear_to_db(0) 是 -inf，别让它进到播放器里）
\tif vol <= 0.001:
\t\treturn
\tvar p := _players[_next]
\t_next = (_next + 1) % VOICES
\tp.stream = _streams[name]
\tp.pitch_scale = randf_range(0.96, 1.04)
\tp.volume_db = linear_to_db(clampf(vol, 0.001, 1.0))
\tp.play()""",
    ),
]

# ---------------------------------------------------------------- B. settings_scene.gd
B = [
    (
        """\t\t\"sfx\":
\t\t\tGameSettings.set_sfx_on(not GameSettings.sfx_on)
\t\t\tsfx.enabled = GameSettings.sfx_on
\t\t\tif sfx.enabled:
\t\t\t\tsfx.play(\"click\")""",
        """\t\t\"sfx\":
\t\t\tGameSettings.set_sfx_on(not GameSettings.sfx_on)
\t\t\tsfx.enabled = GameSettings.sfx_on
\t\t\t# R764：浮层模式下宿主（战斗）那份 Sfx 还活着 —— 一起对齐，
\t\t\t# 否则「关了声音、战斗里还在响」（硬闸在 Sfx.settings_silent）
\t\t\tSfx.sync_all(get_tree())
\t\t\tif sfx.enabled:
\t\t\t\tsfx.play(\"click\")""",
    ),
    (
        """\tif id == \"sfx_vol\":
\t\tGameSettings.set_sfx_volume(nv)
\t\tsfx.volume = nv
\t\tif nv > 0.0:
\t\t\tsfx.play(\"click\")   # 当场听到新音量""",
        """\tif id == \"sfx_vol\":
\t\tGameSettings.set_sfx_volume(nv)
\t\tsfx.volume = nv
\t\tSfx.sync_all(get_tree())   # R764：音量同样要落到宿主那份实例上
\t\tif nv > 0.0:
\t\t\tsfx.play(\"click\")   # 当场听到新音量""",
    ),
]

# ---------------------------------------------------------------- C. test_engine.gd（插入）
C_ANCHOR = """\tr246_sfx.free()"""
C_INSERT = """\tr246_sfx.free()

\t# ---- R764：设置是硬闸 —— 浮层里关掉声音，战斗里那份 Sfx 也必须立刻静默 ----

\tvar r764_sfx_src := FileAccess.get_file_as_string(\"res://scripts/sfx.gd\")

\tcheck_src(r764_sfx_src.contains(\"static func settings_silent\")

\t\t\tand r764_sfx_src.contains(\"if settings_silent():\")

\t\t\tand r764_sfx_src.contains(\"if enabled != _enabled_boot\")

\t\t\tand r764_sfx_src.contains(\"static func sync_all\"),

\t\t\t\"R764 源码：静音走 settings_silent 硬闸 + 退出只写回本实例改过的开关\")

\tvar r764_set_src := FileAccess.get_file_as_string(\"res://scripts/settings_scene.gd\")

\tcheck_src(r764_set_src.count(\"Sfx.sync_all(get_tree())\") >= 2,

\t\t\t\"R764 源码：设置页的开关与音量都广播到宿主那份 Sfx\")

\tvar r764_on0 := GameSettings.sfx_on

\tvar r764_vol0 := GameSettings.sfx_volume

\tGameSettings.set_sfx_on(false)

\tcheck(Sfx.settings_silent(), \"R764 硬闸：设置关音效 → 全局静默判据为真\")

\tGameSettings.set_sfx_on(r764_on0)

\tGameSettings.set_sfx_volume(0.0)

\tcheck(Sfx.settings_silent(), \"R764 硬闸：音效音量 0 → 全局静默判据为真\")

\tGameSettings.set_sfx_volume(r764_vol0)

\tGameSettings.set_sfx_on(r764_on0)

\tcheck(not Sfx.settings_silent(), \"R764 硬闸：开关与音量恢复后不再误判静默\")"""


def main():
    patch("scripts/sfx.gd", A, "\n")
    patch("scripts/settings_scene.gd", B, "\n")

    path = ROOT + "scripts/test_engine.gd"
    raw = open(path, "rb").read()
    old = C_ANCHOR.replace("\n", "\r\n").encode("utf-8")
    new = C_INSERT.replace("\n", "\r\n").encode("utf-8")
    cnt = raw.count(old)
    assert cnt == 1, "test_engine 锚点命中 %d 次（应为 1）" % cnt
    open(path, "wb").write(raw.replace(old, new))
    print("OK scripts/test_engine.gd (1 处插入)")

    # 行尾复核
    for p in ["scripts/sfx.gd", "scripts/settings_scene.gd", "scripts/test_engine.gd"]:
        b = open(ROOT + p, "rb").read()
        print(p, "CRLF" if b"\r\n" in b else "LF", "| 混行" if (b"\r\n" in b and b.replace(b"\r\n", b"").count(b"\n") > 0) else "")


if __name__ == "__main__":
    sys.exit(main())
