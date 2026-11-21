# -*- coding: utf-8 -*-
"""R847：场地标记改用边框素材（battle_scene.gd，CRLF 保持）。

只动 `_draw_field_markers()` 里「斜纹 + 描边」那三行：改成「有素材贴素材、缺图才画斜纹」。
"""
import io
import sys

P = r"E:\work\card_rogue\scripts\battle_scene.gd"

OLD = (
    '\t\t# 斜纹底（4 条45° 短线）\r\n'
    '\t\tfor k in 4:\r\n'
    '\t\t\tvar off := float(k) * CELL / 4.0\r\n'
    '\t\t\tdraw_line(rect.position + Vector2(off, 0),\r\n'
    '\t\t\t\t\trect.position + Vector2(0, off), Color(col.r, col.g, col.b, 0.30), 2.0)\r\n'
    '\t\tdraw_rect(rect, col, false, 2.0)\r\n'
)

NEW = (
    '\t\t# R847：优先用**每张场地自己的边框素材**（`FieldArt`，文件名带 id）；\r\n'
    '\t\t# 缺图才回落到「45° 斜纹 + 冷色描边」这套程序化画法。\r\n'
    '\t\t# 两套**互斥不叠加**：斜纹是「这格挂着个效果」的兜底语汇，有了真边框之后再叠\r\n'
    '\t\t# 一层斜纹只会把画面弄脏（而且斜纹只画左上三角，本来就没盖满格）。\r\n'
    '\t\t# 店长口径（R847）：场地要有真边框素材，且「漩涡和清泉不该一样」→ 按 id 分图。\r\n'
    '\t\tif not FieldArt.draw_frame(self, rect, card.id):\r\n'
    '\t\t\t# 斜纹底（4 条45° 短线）\r\n'
    '\t\t\tfor k in 4:\r\n'
    '\t\t\t\tvar off := float(k) * CELL / 4.0\r\n'
    '\t\t\t\tdraw_line(rect.position + Vector2(off, 0),\r\n'
    '\t\t\t\t\t\trect.position + Vector2(0, off), Color(col.r, col.g, col.b, 0.30), 2.0)\r\n'
    '\t\t\tdraw_rect(rect, col, false, 2.0)\r\n'
)


def main() -> int:
    raw = io.open(P, "rb").read().decode("utf-8")
    assert raw.count("\r\n") > 1000, "文件不是 CRLF？"
    n = raw.count(OLD)
    if n != 1:
        print("锚点命中 %d 次（期望 1）" % n)
        return 2
    io.open(P, "wb").write(raw.replace(OLD, NEW, 1).encode("utf-8"))
    print("PATCH ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
