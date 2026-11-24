# -*- coding: utf-8 -*-
"""R752 补丁：test_traps 的两条失败修正。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:160])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


patch("scripts/test_traps.gd", [
    (
        """	check(battle_src.contains("is_usable") and battle_src.contains("点一下就能用"),
			"R690：使用型工具拒绝进入拖放（轻点即用）")""",
        """	check(battle_src.contains("is_usable") and battle_src.contains("点两下就能用"),
			"R690：使用型工具拒绝进入拖放（R752 起是「点两下」）")""",
    ),
    (
        """	RunState.traps = [7010, -1, 7010]
	var duck_eng := _engine()""",
        """	# 起始只放一件且放在槽 1：用掉它之后三格都空，才验得出「填满 = 3/3」。
	RunState.traps = [7010, -1, -1]
	var duck_eng := _engine()""",
    ),
])

print("OK")
