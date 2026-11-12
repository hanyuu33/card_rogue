# -*- coding: utf-8 -*-
"""R628 ② 独行演出重写：删文字框，改成纯素材特效（光柱 / 漩涡 / 光环）。"""
P = r"E:\work\card_rogue\scripts\battle_scene.gd"
CRLF = "\r\n"

b = open(P, "rb").read()
t = b.decode("utf-8")

# ---------- ① 整段替换 _draw_lone_fx ----------
i = t.find("func _draw_lone_fx() -> void:")
assert i > 0
j = t.find("func _rev_art_phase(p: Placement) -> int:")
assert j > i

new_fn = CRLF.join([
    "func _draw_lone_fx() -> void:",
    "\t## R628：独行（9189）的「吞卡」演出 —— 全部走 codex 出的素材图：",
    "\t## `assets/fx/fx_lone_column.png`（竖直吸取光柱，绞股灵魂光 + 白芯）／",
    "\t## `fx_lone_maw.png`（虚空漩涡，吞噬点）／`fx_lone_ring.png`（收束光环）。",
    "\t## 店长口径：「不要用这种文字特效，委托 codex 生成素材图，然后用素材图做特效」",
    "\t## → 原来贴着目标卡的「{卡名} 并入 +N」文字框**整段删除**，只留画面。",
    "\t## 时序：0 ~ `hold` = 吸取段（手卡处收束环 → 光柱沿路径长出 → 头部漩涡前推）；",
    "\t##      `hold` 之后 = 吞噬段（漩涡张开收拢 + 冲击光环 + 命中爆点）。",
    "\t## `hold` 正是 fx_impact 被推后的量 → 「独行 -N」与吞噬同帧落地，因果不反。",
    "\t## ⚠️ 本函数在**屏幕空间**被调用（排在 `--draw_meteors()` 那一段），所以可以临时",
    "\t##    `draw_set_transform` 把光柱旋到 from→to 方向；用完必须还原成 `_shake_cur`。",
    "\tif _lone_fx.is_empty():",
    "\t\treturn",
    "\tvar n := _now()",
    "\tfor f: Dictionary in _lone_fx:",
    "\t\tvar t0 := n - int(f[\"start\"])",
    "\t\tif t0 < 0:",
    "\t\t\tcontinue",
    "\t\tvar hold := int(f.get(\"hold\", 0))",
    "\t\tvar to: Vector2 = _fx_pos(f)",
    "\t\tvar from: Vector2 = f[\"from\"]",
    "\t\tvar dir := to - from",
    "\t\tvar dist: float = maxf(dir.length(), 1.0)",
    "\t\t# 精灵的「上」是 -Y，要转到 from→to：R(θ)(0,1) = dir ⇒ θ = atan2(-dir.x, dir.y)",
    "\t\tvar ang := atan2(-dir.x, dir.y)",
    "\t\tvar prog := clampf(float(t0) / float(maxi(hold, 1)), 0.0, 1.0)",
    "\t\t# ---- 吸取段 ----",
    "\t\tif t0 <= hold:",
    "\t\t\t# ① 起手：手卡处一圈光被抽走（由外向内收，越收越淡）",
    "\t\t\tif _fx_lone_ring_tex != null:",
    "\t\t\t\tvar r0 := lerpf(104.0, 22.0, pow(prog, 0.75))",
    "\t\t\t\tdraw_texture_rect(_fx_lone_ring_tex,",
    "\t\t\t\t\t\tRect2(from - Vector2(r0, r0), Vector2(r0, r0) * 2.0), false,",
    "\t\t\t\t\t\tColor(1, 1, 1, (1.0 - prog) * 0.9))",
    "\t\t\t# ② 光柱：从 from 沿 from→to 长出来（素材下端在 from，上端朝 to）",
    "\t\t\tif _fx_lone_col_tex != null:",
    "\t\t\t\tvar tw := 84.0          # 屏幕上画多宽（素材本身很细，靠它定粗细）",
    "\t\t\t\tvar cut: float = maxf(prog, 0.05)",
    "\t\t\t\tvar tex_w := float(_fx_lone_col_tex.get_width())",
    "\t\t\t\tvar tex_h := float(_fx_lone_col_tex.get_height())",
    "\t\t\t\tdraw_set_transform(from, ang, Vector2.ONE)",
    "\t\t\t\tdraw_texture_rect_region(_fx_lone_col_tex,",
    "\t\t\t\t\t\tRect2(-tw * 0.5, -dist * cut, tw, dist * cut),",
    "\t\t\t\t\t\tRect2(0.0, tex_h * (1.0 - cut), tex_w, tex_h * cut),",
    "\t\t\t\t\t\tColor(1, 1, 1, clampf(prog * 2.4, 0.0, 1.0)))",
    "\t\t\t\tdraw_set_transform(_shake_cur, 0.0, Vector2.ONE)",
    "\t\t\t# ③ 头部：漩涡球往前顶，读成「这张卡正被吸过去」",
    "\t\t\tvar head: Vector2 = from.lerp(to, prog)",
    "\t\t\tif _fx_lone_maw_tex != null:",
    "\t\t\t\tvar hs := lerpf(30.0, 54.0, prog)",
    "\t\t\t\tdraw_texture_rect(_fx_lone_maw_tex,",
    "\t\t\t\t\t\tRect2(head - Vector2(hs, hs) * 0.5, Vector2(hs, hs)), false,",
    "\t\t\t\t\t\tColor(1, 1, 1, 0.95))",
    "\t\t\tif _fx_glow_tex != null:",
    "\t\t\t\tdraw_texture_rect(_fx_glow_tex,",
    "\t\t\t\t\t\tRect2(head - Vector2(18, 18), Vector2(36, 36)), false,",
    "\t\t\t\t\t\tColor(0.95, 0.88, 1.0, 0.7))",
    "\t\t# ---- 吞噬段（时间零点 = hold）----",
    "\t\tif t0 < hold:",
    "\t\t\tcontinue",
    "\t\tvar bt := clampf(float(t0 - hold) / 540.0, 0.0, 1.0)",
    "\t\tif bt >= 1.0:",
    "\t\t\tcontinue",
    "\t\t# ④ 虚空漩涡：张开到最大再收拢熄灭",
    "\t\tif _fx_lone_maw_tex != null:",
    "\t\t\tvar ms := lerpf(0.55, 1.35, pow(bt, 0.42))",
    "\t\t\tdraw_texture_rect(_fx_lone_maw_tex,",
    "\t\t\t\t\tRect2(to - Vector2(96.0, 96.0) * ms, Vector2(192.0, 192.0) * ms), false,",
    "\t\t\t\t\tColor(1, 1, 1, pow(1.0 - bt, 1.4)))",
    "\t\t# ⑤ 收束光环：吞下去的一瞬间向外炸一圈紫环",
    "\t\tif _fx_lone_ring_tex != null:",
    "\t\t\tvar rs := lerpf(0.55, 1.5, pow(bt, 0.55))",
    "\t\t\tdraw_texture_rect(_fx_lone_ring_tex,",
    "\t\t\t\t\tRect2(to - Vector2(78.0, 78.0) * rs, Vector2(156.0, 156.0) * rs), false,",
    "\t\t\t\t\tColor(1, 0.82, 1.0, pow(1.0 - bt, 1.8) * 0.85))",
    "\t\tif _fx_hit_burst_tex != null:",
    "\t\t\tvar bs := lerpf(0.55, 1.15, pow(bt, 0.45))",
    "\t\t\tdraw_texture_rect(_fx_hit_burst_tex,",
    "\t\t\t\t\tRect2(to - Vector2(88.0, 88.0) * bs, Vector2(176.0, 176.0) * bs), false,",
    "\t\t\t\t\tColor(0.9, 0.8, 1.0, pow(1.0 - bt, 1.6) * 0.8))",
    "",
    "",
])

t = t[:i] + new_fn + t[j:]

# ---------- ② 调用点从棋盘区挪到屏幕空间 ----------
call_old = "\t_draw_bursts()" + CRLF + "\t_draw_lone_fx()          # R625：独行吞卡演出（素材驱动）" + CRLF
assert t.count(call_old) == 1, ("call", t.count(call_old))
t = t.replace(call_old, "\t_draw_bursts()" + CRLF, 1)

anchor = "\t_draw_grid_mask()" + CRLF + "\t_draw_meteors()"
assert t.count(anchor) == 1, ("anchor", t.count(anchor))
t = t.replace(
    anchor,
    "\t_draw_grid_mask()" + CRLF
    + "\t_draw_lone_fx()     # R628：独行吞卡演出（光柱要斜着拉，必须在屏幕空间）" + CRLF
    + "\t_draw_meteors()",
    1,
)

# ---------- ③ 删掉手卡区那条文字飘字 ----------
hand_old = "\t\t\t\t_floaters.append({\"pos\": Vector2(WINDOW_W / 2.0, OWN_HAND_Y - 44.0)," + CRLF
assert t.count(hand_old) == 1, ("hand", t.count(hand_old))
k = t.find(hand_old)
end = t.find("})", k) + 2
# 连上面那行注释一起删
comment = "\t\t\t\t# 手卡侧先说一句「这张没了，换来什么」——否则手卡凭空少一张" + CRLF
if t.rfind(comment, 0, k) == k - len(comment):
    k -= len(comment)
t = t[:k] + t[end:]

open(P, "wb").write(t.encode("utf-8"))
b2 = open(P, "rb").read()
print("CRLF", b2.count(b"\r\n"), "bareLF", b2.count(b"\n") - b2.count(b"\r\n"))
