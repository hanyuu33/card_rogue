# -*- coding: utf-8 -*-
"""R752：test_trap_input 在 _initialize 阶段手动补挂 PickOverlay / AssembleOverlay。"""
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


patch("scripts/test_trap_input.gd", [
    (
        """	check(_sc.engine != null, "战斗场景实例化成功且注入的 engine 就绪")
""",
        """	# ⚠️ `_initialize()` 阶段节点的 `_ready` 还没跑（Godot 把它推迟到第一帧），
	#    所以 battle.tscn 里的 `_pick` / `_assemble_overlay` 此刻都还是 null。
	#    R752 的用例要真验「第二下弹出选卡页 / 确认才摘槽」，这里按 `_ready` 里
	#    同样的几行补挂上（只挂界面件，不碰任何游戏逻辑）。
	_sc._pick = PickOverlay.new()
	_sc._pick.confirmed.connect(_sc._on_pick_confirmed)
	_sc._pick.cancelled.connect(_sc._on_pick_cancelled)
	_sc.add_child(_sc._pick)
	_sc._assemble_overlay = AssembleOverlay.new()
	_sc.add_child(_sc._assemble_overlay)

	check(_sc.engine != null, "战斗场景实例化成功且注入的 engine 就绪")
	check(_sc._pick != null and _sc._assemble_overlay != null,
			"选卡页 / 组合页已补挂（headless 下 `_ready` 未跑，靠测试自己挂）")
""",
    ),
])

print("OK")
