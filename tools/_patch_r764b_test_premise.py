# -*- coding: utf-8 -*-
"""R764b：把 R764 的音量/开关断言改成「先置前提」，不再依赖玩家档里音效恰好是开的。

原写法直接从玩家档的 sfx_on 起步：若玩家关过音效（settings.cfg 里 sfx=false），
`settings_silent()` 恒真 → 最后一条 `check(not settings_silent())` 必红。
engine 套的口径是「任何机器上都绿」，所以必须自己把前提摆好。
"""
import sys

ROOT = "E:/work/card_rogue/"
PATH = ROOT + "scripts/test_engine.gd"

OLD = """\tvar r764_on0 := GameSettings.sfx_on

\tvar r764_vol0 := GameSettings.sfx_volume

\tGameSettings.set_sfx_on(false)

\tcheck(Sfx.settings_silent(), \"R764 硬闸：设置关音效 → 全局静默判据为真\")

\tGameSettings.set_sfx_on(r764_on0)

\tGameSettings.set_sfx_volume(0.0)

\tcheck(Sfx.settings_silent(), \"R764 硬闸：音效音量 0 → 全局静默判据为真\")

\tGameSettings.set_sfx_volume(r764_vol0)

\tGameSettings.set_sfx_on(r764_on0)

\tcheck(not Sfx.settings_silent(), \"R764 硬闸：开关与音量恢复后不再误判静默\")"""

NEW = """\tvar r764_on0 := GameSettings.sfx_on

\tvar r764_vol0 := GameSettings.sfx_volume

\t# 前提自己摆：玩家档里音效可能就是关的 / 音量就是 0，不能拿它当"开"的基准。
\tGameSettings.set_sfx_on(true)

\tGameSettings.set_sfx_volume(1.0)

\tcheck(not Sfx.settings_silent(), \"R764 硬闸：开 + 满音量 → 不静默\")

\tGameSettings.set_sfx_on(false)

\tcheck(Sfx.settings_silent(), \"R764 硬闸：关音效 → 静默\")

\tGameSettings.set_sfx_on(true)

\tcheck(not Sfx.settings_silent(), \"R764 硬闸：重新打开 → 恢复发声\")

\tGameSettings.set_sfx_volume(0.0)

\tcheck(Sfx.settings_silent(), \"R764 硬闸：音效音量 0 → 静默\")

\tGameSettings.set_sfx_volume(1.0)

\tcheck(not Sfx.settings_silent(), \"R764 硬闸：音量恢复 → 恢复发声\")

\tGameSettings.set_sfx_on(r764_on0)

\tGameSettings.set_sfx_volume(r764_vol0)"""


def main():
    raw = open(PATH, "rb").read()
    old = OLD.replace("\n", "\r\n").encode("utf-8")
    new = NEW.replace("\n", "\r\n").encode("utf-8")
    cnt = raw.count(old)
    assert cnt == 1, "锚点命中 %d 次（应为 1）" % cnt
    raw = raw.replace(old, new)
    open(PATH, "wb").write(raw)
    b = open(PATH, "rb").read()
    print("OK test_engine.gd | CRLF=%s | 裸LF=%d" % (
        b"\r\n" in b, b.replace(b"\r\n", b"").count(b"\n")))


if __name__ == "__main__":
    sys.exit(main())
