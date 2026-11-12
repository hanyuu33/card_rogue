# -*- coding: utf-8 -*-
"""R614b：给战斗场景加一个出图钩子 `--combohover`。

目的：验证「查看完整卡组」里悬停「传授」时，字段 / 机制词条解释浮窗确实画在
区域面板**之上**（面板会把左栏信息面板整个盖住，见 R614 的 `_draw()` 改动）。

用法：
  battle.tscn -- --screenshot --level 0 --rundeckpanel --combohover --shotframe 60

只改演示分支，不影响正常对局。
"""
import sys

CHECK = "--check-only" in sys.argv
P = "scripts/battle_scene.gd"

OLD_EXTRAS = ('\t\t\tfor extra: int in [8004, 9032, 9010]:\r\n'
              '\t\t\t\tif repo.get_card(extra) != null:\r\n'
              '\t\t\t\t\tdemo_ids.append(extra)\r\n')
NEW_EXTRAS = ('\t\t\tvar extras: Array[int] = [8004, 9032, 9010]\r\n'
              '\t\t\tif "--combohover" in args:\r\n'
              '\t\t\t\textras.append(8084)   # R614：把「传授」塞进完整卡组，供浮窗出图\r\n'
              '\t\t\tfor extra: int in extras:\r\n'
              '\t\t\t\tif repo.get_card(extra) != null:\r\n'
              '\t\t\t\t\tdemo_ids.append(extra)\r\n')

OLD_TICK = ('func _demo_tick() -> void:\r\n'
            '\t_demo_frame += 1\r\n')
NEW_TICK = ('func _demo_tick() -> void:\r\n'
            '\t_demo_frame += 1\r\n'
            '\tif "--combohover" in _demo_args and _run_deck_visible \\\r\n'
            '\t\t\tand _demo_frame == _shot_frame - 30:\r\n'
            '\t\t# 出图（R614）：完整卡组里把「鼠标」钉在「传授」上 —— 验证解释浮窗\r\n'
            '\t\t# 是画在区域面板**之上**的（面板会盖住左栏信息面板，卡组一多就全遮住）。\r\n'
            '\t\t# 用法：--screenshot --level 0 --rundeckpanel --combohover --shotframe 60\r\n'
            '\t\tvar zcards := _zone_panel_cards()\r\n'
            '\t\tvar zlay := _zone_panel_layout(zcards.size())\r\n'
            '\t\tfor zi in zcards.size():\r\n'
            '\t\t\tif (zcards[zi] as CardData).id == 8084:\r\n'
            '\t\t\t\t_hover_card = zcards[zi]\r\n'
            '\t\t\t\t_hover_zone_rect = _zone_card_rect(zi, zlay)\r\n'
            '\t\t\t\tqueue_redraw()\r\n'
            '\t\t\t\tbreak\r\n')


def main():
    s = open(P, "r", encoding="utf-8", newline="").read()
    for old, new in [(OLD_EXTRAS, NEW_EXTRAS), (OLD_TICK, NEW_TICK)]:
        assert s.count(old) == 1, (old[:40], s.count(old))
        s = s.replace(old, new)
    print("[battle_scene.gd] --combohover 钩子 2 处锚点命中")
    if CHECK:
        print("=== dry-run done ===")
        return
    open(P, "w", encoding="utf-8", newline="").write(s)
    b = open(P, "rb").read()
    crlf = b.count(b"\r\n")
    print(f"[battle_scene.gd] crlf={crlf} bare={b.count(chr(10).encode()) - crlf}")
    print("=== done ===")


if __name__ == "__main__":
    main()
