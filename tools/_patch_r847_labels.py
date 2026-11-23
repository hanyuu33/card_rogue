# -*- coding: utf-8 -*-
"""R847b：有边框素材时不再叠名字角标（battle_scene.gd，CRLF 保持）。"""
import io
import sys

P = r"E:\work\card_rogue\scripts\battle_scene.gd"

PAIRS = [
    (
        '\t\tif not FieldArt.draw_frame(self, rect, card.id):\r\n',
        '\t\tvar framed := FieldArt.draw_frame(self, rect, card.id)\r\n'
        '\t\tif not framed:\r\n',
    ),
    (
        '\t\t# 右下角小标签（场地名，缩到能塞进角里）\r\n'
        '\t\t# R503/R562：标记角标直接写当前加伤数值 —— 现在固定 +1，但照旧读 `mark_bonus`\r\n'
        '\t\t# （数值出口只有一个，将来若调档位/加变体，画法不用跟着改）。\r\n'
        '\t\tvar tag := card.card_name\r\n'
        '\t\tif card.id == GameEngine.MARK_ID:\r\n'
        '\t\t\ttag = "标记 +%d" % engine.state.mark_bonus\r\n'
        '\t\tvar px := 10\r\n'
        '\t\twhile px > 7 and _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > CELL_W - 10.0:\r\n'
        '\t\t\tpx -= 1\r\n'
        '\t\t_draw_string_box_nw(_font_bold, px, tag, rect.position + Vector2(5, CELL - 6), col)\r\n',
        '\t\t# 名字角标：**有边框素材时不画**（R847）。边框本身就是「这是哪张场地」的答案，\r\n'
        '\t\t# 再叠一行字只会压在卡面数值行上（实机核验：标签有一半被卡框吃掉）。\r\n'
        '\t\t# 缺素材（mod 去图 / 旧包没带图）时照旧写出来 —— 那种情况下文字是唯一辨识手段。\r\n'
        '\t\t# R503/R562：标记角标直接写当前加伤数值 —— 现在固定 +1，但照旧读 `mark_bonus`\r\n'
        '\t\t# （数值出口只有一个，将来若调档位/加变体，画法不用跟着改）。\r\n'
        '\t\tif not framed:\r\n'
        '\t\t\tvar tag := card.card_name\r\n'
        '\t\t\tif card.id == GameEngine.MARK_ID:\r\n'
        '\t\t\t\ttag = "标记 +%d" % engine.state.mark_bonus\r\n'
        '\t\t\tvar px := 10\r\n'
        '\t\t\twhile px > 7 and _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > CELL_W - 10.0:\r\n'
        '\t\t\t\tpx -= 1\r\n'
        '\t\t\t_draw_string_box_nw(_font_bold, px, tag, rect.position + Vector2(5, CELL - 6), col)\r\n',
    ),
]


def main() -> int:
    raw = io.open(P, "rb").read().decode("utf-8")
    for old, new in PAIRS:
        n = raw.count(old)
        if n != 1:
            print("锚点命中 %d 次：%r..." % (n, old[:40]))
            return 2
        raw = raw.replace(old, new, 1)
    io.open(P, "wb").write(raw.encode("utf-8"))
    print("PATCH ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
