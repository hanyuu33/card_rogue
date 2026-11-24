# -*- coding: utf-8 -*-
"""R825：按真实 Button 最小高度收紧九宫格与两个入口的纵向间距。"""
from pathlib import Path
ROOT = Path(r"E:/work/card_rogue")

def replace(path, old, new, count=1):
    p = ROOT / path
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    if crlf:
        text = text.replace("\r\n", "\n")
    assert text.count(old) == count, (path, text.count(old), old)
    text = text.replace(old, new)
    p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
    print("PATCH", path)

replace("scripts/ui_theme.gd", "sb.texture_margin_top = 14", "sb.texture_margin_top = 6")
replace("scripts/ui_theme.gd", "sb.texture_margin_bottom = 14", "sb.texture_margin_bottom = 6")
replace("scripts/ui_theme.gd", "sb.content_margin_top = 5", "sb.content_margin_top = 2")
replace("scripts/ui_theme.gd", "sb.content_margin_bottom = 5", "sb.content_margin_bottom = 2")
replace("scripts/reward_panel.gd", "Vector2(196, 36)", "Vector2(196, 40)", 2)
replace("scripts/map_scene.gd", "_shop_return_btn.position = Vector2(12, 80)", "_shop_return_btn.position = Vector2(12, 84)")
replace("scripts/map_scene.gd", "Vector2(196, 36)", "Vector2(196, 40)", 2)
replace("tools/_patch_r825_save.py", "Vector2(12, 80)", "Vector2(12, 84)")
replace("tools/_patch_r825_save.py", "Vector2(196, 36)", "Vector2(196, 40)", 2)
replace("tools/_patch_r825_save.py", "sb.texture_margin_top = 14", "sb.texture_margin_top = 6")
replace("tools/_patch_r825_save.py", "sb.texture_margin_bottom = 14", "sb.texture_margin_bottom = 6")
replace("tools/_patch_r825_save.py", "sb.content_margin_top = 5", "sb.content_margin_top = 2")
replace("tools/_patch_r825_save.py", "sb.content_margin_bottom = 5", "sb.content_margin_bottom = 2")
replace("tools/_patch_r825_integration.py", "Vector2(196, 36)", "Vector2(196, 40)", 2)
print("R825 LAYOUT OK")
