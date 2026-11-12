# -*- coding: utf-8 -*-
"""R629b：吞噬段提速后每帧都更「挤」，把尺寸/亮度收一档，让卡面信息透出来。

四个时点实测（120/200/300/430ms）：时序全对（430ms 清干净、-15 与力量 -4 都在），
但 200~300ms 那两帧紫色糊满整格，敌人卡的血量 / 力量读不出来。
收缩：主漩涡 / 收束环 / 命中爆点各收一档，头部漩涡在吞噬起手后 80ms 内让位。
"""
p = "scripts/battle_scene.gd"
b = open(p, "rb").read()
t = b.decode("utf-8")
CRLF = chr(13) + chr(10)


def rep(old, new, tag):
    global t
    assert t.count(old) == 1, (tag, t.count(old))
    t = t.replace(old, new, 1)


# ① 头部漩涡：吞噬起手后 80ms 内让位（原来按 tsink 线性淡出要 170ms，两团球叠太久）
rep(
    "\t\t\t\tColor(1, 1, 1, 0.95 * (1.0 - tsink)))" + CRLF,
    "\t\t\t\tColor(1, 1, 1, 0.95 * clampf(1.0 - tsink * 2.2, 0.0, 1.0)))" + CRLF,
    "head",
)
rep(
    "\t\t\t\tColor(0.95, 0.88, 1.0, 0.7 * (1.0 - tsink)))" + CRLF,
    "\t\t\t\tColor(0.95, 0.88, 1.0, 0.7 * clampf(1.0 - tsink * 2.2, 0.0, 1.0)))" + CRLF,
    "core",
)

# ② 主漩涡：220 base + 1.55 顶到 308px，铺满一格还糊 → 196 base / 1.30 顶 255px，压亮度
rep(
    "\t\tif _fx_lone_maw_tex != null:" + CRLF
    + "\t\t\tvar ms := lerpf(0.75, 1.55, pow(bt, 0.45))" + CRLF
    + "\t\t\tdraw_texture_rect(_fx_lone_maw_tex," + CRLF
    + "\t\t\t\t\tRect2(to - Vector2(110.0, 110.0) * ms, Vector2(220.0, 220.0) * ms), false,"
    + CRLF
    + "\t\t\t\t\tColor(1, 1, 1, pow(1.0 - bt, 0.55)))" + CRLF,
    "\t\t# R629b：提速后每一帧都更挤 —— 220→196、顶到 1.30（原 1.55），" + CRLF
    + "\t\t# 并压一档亮度：否则 200~300ms 那两帧紫色糊满整格，敌人卡的血量读不出来。" + CRLF
    + "\t\tif _fx_lone_maw_tex != null:" + CRLF
    + "\t\t\tvar ms := lerpf(0.66, 1.30, pow(bt, 0.45))" + CRLF
    + "\t\t\tdraw_texture_rect(_fx_lone_maw_tex," + CRLF
    + "\t\t\t\t\tRect2(to - Vector2(98.0, 98.0) * ms, Vector2(196.0, 196.0) * ms), false,"
    + CRLF
    + "\t\t\t\t\tColor(1, 1, 1, pow(1.0 - bt, 0.7) * 0.88))" + CRLF,
    "maw",
)

# ③ 收束环：192 base / 顶 2.0 → 176 base / 顶 1.72
rep(
    "\t\t\tvar rs := lerpf(0.85, 2.0, pow(bt, 0.6))" + CRLF
    + "\t\t\tdraw_texture_rect(_fx_lone_ring_tex," + CRLF
    + "\t\t\t\t\tRect2(to - Vector2(96.0, 96.0) * rs, Vector2(192.0, 192.0) * rs), false,"
    + CRLF,
    "\t\t\tvar rs := lerpf(0.80, 1.72, pow(bt, 0.6))" + CRLF
    + "\t\t\tdraw_texture_rect(_fx_lone_ring_tex," + CRLF
    + "\t\t\t\t\tRect2(to - Vector2(88.0, 88.0) * rs, Vector2(176.0, 176.0) * rs), false,"
    + CRLF,
    "ring",
)

# ④ 命中爆点：176 base / 顶 1.15 → 160 base / 顶 1.02
rep(
    "\t\t\tvar bs := lerpf(0.55, 1.15, pow(bt, 0.45))" + CRLF
    + "\t\t\tdraw_texture_rect(_fx_hit_burst_tex," + CRLF
    + "\t\t\t\t\tRect2(to - Vector2(88.0, 88.0) * bs, Vector2(176.0, 176.0) * bs), false,"
    + CRLF,
    "\t\t\tvar bs := lerpf(0.50, 1.02, pow(bt, 0.45))" + CRLF
    + "\t\t\tdraw_texture_rect(_fx_hit_burst_tex," + CRLF
    + "\t\t\t\t\tRect2(to - Vector2(80.0, 80.0) * bs, Vector2(160.0, 160.0) * bs), false,"
    + CRLF,
    "burst",
)

open(p, "wb").write(t.encode("utf-8"))
b2 = open(p, "rb").read()
print("CRLF", b2.count(b"\r\n"), "bareLF", b2.count(b"\n") - b2.count(b"\r\n"))
