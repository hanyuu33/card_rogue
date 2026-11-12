# -*- coding: utf-8 -*-
"""R629：独行吞卡演出改成「吸取过半就开吞」+ 吞噬段提速，整体压到 1 秒内。

店长口径：「太慢了，能不能吸取到一半就开始吞噬，减少吞噬时间，让总体在1秒内」

原来：吸取 0~430ms（走满）→ 吞噬 430~850ms，两拍之间有明显停顿。
现在：吞噬零点从 430 挪到 170（= 吸取段的一半），吞噬段 420 → 260ms；
      两段重叠成一次连贯动作，170 + 260 = 430ms 演完。
"""
import io

p = "scripts/battle_scene.gd"
b = open(p, "rb").read()
t = b.decode("utf-8")
CRLF = chr(13) + chr(10)


def rep(old, new, tag):
    global t
    assert t.count(old) == 1, (tag, t.count(old))
    t = t.replace(old, new, 1)


# ① 常量：吸取 430 → 340，新增吞噬零点 / 吞噬段长
rep(
    "## 吞卡段时长（ms）：流光走完 + 目标处炸开，之后才轮到伤害数字与降力飘字。" + CRLF
    + "const LONE_ABSORB_MS := 430" + CRLF,
    "## 吸取段总长（ms）：光柱走到目标位的那一刻。" + CRLF
    + "const LONE_ABSORB_MS := 340" + CRLF
    + "## R629（店长：「吸取到一半就开始吞噬，减少吞噬时间，让总体在1秒内」）：" + CRLF
    + "## 吞噬**不等吸取演完** —— 吸取过半（= 本常量）就张嘴：光柱还在往上吸，" + CRLF
    + "## 目标处已经开始收拢。两段重叠成一次连贯动作，而不是「吸完 → 停 → 再吞」两拍。" + CRLF
    + "const LONE_BITE_MS := 170" + CRLF
    + "## 吞噬段时长（ms）：420 → 260。配合上面的 170，整体 430ms 演完。" + CRLF
    + "const LONE_SWALLOW_MS := 260" + CRLF,
    "const",
)

# ② 事件分支：dur 按新口径算；伤害数字压在「嘴张开之后」
rep(
    "\t\t\t\t\t\t" + '"dur": LONE_ABSORB_MS + 430, "hold": LONE_ABSORB_MS})' + CRLF
    + "\t\t\t\t_lone_hit_cell = lw_cell2" + CRLF
    + "\t\t\t\t_lone_hit_at = n + LONE_ABSORB_MS" + CRLF,
    "\t\t\t\t\t\t" + '"dur": LONE_BITE_MS + LONE_SWALLOW_MS + 120,' + CRLF
    + "\t\t\t\t\t\t" + '"hold": LONE_ABSORB_MS})' + CRLF
    + "\t\t\t\t_lone_hit_cell = lw_cell2" + CRLF
    + "\t\t\t\t# 伤害数字压到「嘴张开之后」——比吞噬零点晚 90ms，" + CRLF
    + "\t\t\t\t# 读起来仍是「吞进去 → 打出去」，因果不反（R625 定下的顺序）。" + CRLF
    + "\t\t\t\t_lone_hit_at = n + LONE_BITE_MS + 90" + CRLF,
    "event",
)

# ③ 函数头注释：时序说明改成重叠版
rep(
    "\t## 时序：0 ~ `hold` = 吸取段（手卡处收束环 → 光柱沿路径长出 → 头部漩涡前推）；" + CRLF
    + "\t##      `hold` 之后 = 吞噬段（漩涡张开收拢 + 冲击光环 + 命中爆点）。" + CRLF
    + "\t## `hold` 正是 fx_impact 被推后的量 → 「独行 -N」与吞噬同帧落地，因果不反。" + CRLF,
    "\t## 时序（R629 重叠版）：吸取段 0 ~ `hold`；吞噬段从 `LONE_BITE_MS`（= hold 的一半）" + CRLF
    + "\t## 就起手 —— 光柱还在往上吸，目标处已经开始张嘴，两段叠成一次连贯动作。" + CRLF
    + "\t## 伤害数字压到 `_lone_hit_at`（= 吞噬零点 + 90ms）落地，仍是「先吞、后打」。" + CRLF,
    "doc",
)

# ④ 吸取段：加一个「让位系数」，吞起来之后光柱/环/头部漩涡逐步淡出交棒
rep(
    "\t\tvar prog := clampf(float(t0) / float(maxi(hold, 1)), 0.0, 1.0)" + CRLF
    + "\t\t# ---- 吸取段 ----" + CRLF,
    "\t\tvar prog := clampf(float(t0) / float(maxi(hold, 1)), 0.0, 1.0)" + CRLF
    + "\t\t# R629：吞噬一旦张嘴，吸取这边就逐步「交棒」——`tsink` 从吞噬零点起 0→1，" + CRLF
    + "\t\t# 光柱 / 收束环 / 头部漩涡按它淡出，视觉重心自然挪到目标处的吞噬上。" + CRLF
    + "\t\tvar tsink := clampf(float(t0 - LONE_BITE_MS)"
    + " / float(maxi(LONE_ABSORB_MS - LONE_BITE_MS, 1)), 0.0, 1.0)" + CRLF
    + "\t\t# ---- 吸取段 ----" + CRLF,
    "tsink",
)

rep(
    "\t\t\t\t\t\tColor(1, 1, 1, (1.0 - prog) * 0.9))" + CRLF,
    "\t\t\t\t\t\tColor(1, 1, 1, (1.0 - prog) * 0.9 * (1.0 - tsink * 0.7)))" + CRLF,
    "ring_alpha",
)

rep(
    "\t\t\t\t\t\tColor(1, 1, 1, grow * 0.95))" + CRLF,
    "\t\t\t\t\t\tColor(1, 1, 1, grow * 0.95 * (1.0 - tsink * 0.45)))" + CRLF,
    "col_alpha",
)

rep(
    "\t\t\t\tvar hs := lerpf(56.0, 96.0, prog)" + CRLF,
    "\t\t\t\t# 头部漩涡在吞噬起手后快速淡出 —— 否则目标处会同时挂着「半路的头」" + CRLF
    + "\t\t\t\t# 和「张嘴的漩涡」两个球，读起来是两团东西。到 hold 时正淡到 0。" + CRLF
    + "\t\t\t\tvar hs := lerpf(56.0, 96.0, prog)" + CRLF,
    "head_doc",
)

rep(
    "\t\t\t\t\t\tRect2(head - Vector2(hs, hs) * 0.5, Vector2(hs, hs)), false," + CRLF
    + "\t\t\t\t\t\tColor(1, 1, 1, 0.95))" + CRLF,
    "\t\t\t\t\t\tRect2(head - Vector2(hs, hs) * 0.5, Vector2(hs, hs)), false," + CRLF
    + "\t\t\t\t\t\tColor(1, 1, 1, 0.95 * (1.0 - tsink)))" + CRLF,
    "head_alpha",
)

rep(
    "\t\t\t\t\t\tRect2(head - Vector2(18, 18), Vector2(36, 36)), false," + CRLF
    + "\t\t\t\t\t\tColor(0.95, 0.88, 1.0, 0.7))" + CRLF,
    "\t\t\t\t\t\tRect2(head - Vector2(18, 18), Vector2(36, 36)), false," + CRLF
    + "\t\t\t\t\t\tColor(0.95, 0.88, 1.0, 0.7 * (1.0 - tsink)))" + CRLF,
    "core_alpha",
)

# ⑤ 吞噬段：零点 hold → LONE_BITE_MS，时长 420 → LONE_SWALLOW_MS
rep(
    "\t\t# ---- 吞噬段（时间零点 = hold）----" + CRLF
    + "\t\tif t0 < hold:" + CRLF
    + "\t\t\tcontinue" + CRLF
    + "\t\tvar bt := clampf(float(t0 - hold) / 420.0, 0.0, 1.0)" + CRLF,
    "\t\t# ---- 吞噬段（时间零点 = LONE_BITE_MS —— 吸取过半就开吞，不等 hold）----" + CRLF
    + "\t\tif t0 < LONE_BITE_MS:" + CRLF
    + "\t\t\tcontinue" + CRLF
    + "\t\tvar bt := clampf(float(t0 - LONE_BITE_MS) / float(LONE_SWALLOW_MS), 0.0, 1.0)" + CRLF,
    "swallow",
)

open(p, "wb").write(t.encode("utf-8"))
b2 = open(p, "rb").read()
print("CRLF", b2.count(b"\r\n"), "bareLF", b2.count(b"\n") - b2.count(b"\r\n"))
