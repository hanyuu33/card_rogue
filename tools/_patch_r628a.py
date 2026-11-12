# -*- coding: utf-8 -*-
"""R628 ① 独行特效贴图：成员声明 + 加载口。"""
import io

P = r"E:\work\card_rogue\scripts\battle_scene.gd"
CRLF = "\r\n"

b = open(P, "rb").read()
t = b.decode("utf-8")

# ① 成员声明（挂在 _fx_wave_tex 后面，和其它 fx 贴图放一起）
a = "var _fx_wave_tex: Texture2D = null     # 冲击波环（清场）" + CRLF
assert t.count(a) == 1, ("anchor1", t.count(a))
add = (
    "## R628：独行（9189）吞卡演出专用贴图 —— 店长口径「不要文字特效，用素材图做」。"
    + CRLF
    + "## 三张都由 codex 纯文生图出（黑底 → 亮度转 alpha），管线见 art_src/2026-11-12_独行特效_R628/。"
    + CRLF
    + "var _fx_lone_col_tex: Texture2D = null   # 竖直吸取光柱（底端在图的底部，顶端在顶部）"
    + CRLF
    + "var _fx_lone_maw_tex: Texture2D = null   # 虚空漩涡（圆形，吞噬点）"
    + CRLF
    + "var _fx_lone_ring_tex: Texture2D = null  # 收束光环（圆形，空心）"
    + CRLF
)
t = t.replace(a, a + add, 1)

# ② 加载口
c = '\t_fx_arc_elec_tex = load("res://assets/fx/fx_arc_elec.png")' + CRLF
assert t.count(c) == 1, ("anchor2", t.count(c))
t = t.replace(
    c,
    c
    + '\t_fx_lone_col_tex = load("res://assets/fx/fx_lone_column.png")' + CRLF
    + '\t_fx_lone_maw_tex = load("res://assets/fx/fx_lone_maw.png")' + CRLF
    + '\t_fx_lone_ring_tex = load("res://assets/fx/fx_lone_ring.png")' + CRLF,
    1,
)

open(P, "wb").write(t.encode("utf-8"))
b2 = open(P, "rb").read()
print("CRLF", b2.count(b"\r\n"), "bareLF", b2.count(b"\n") - b2.count(b"\r\n"))
