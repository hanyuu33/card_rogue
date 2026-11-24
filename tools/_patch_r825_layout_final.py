# -*- coding: utf-8 -*-
"""R825：顶栏双入口最终几何与测试声明顺序；保留原行尾与源码快照。"""
from pathlib import Path
import hashlib

ROOT = Path(r"E:/work/card_rogue")


def read(path):
    p = ROOT / path
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    return p, text.replace("\r\n", "\n") if crlf else text, crlf


def write(p, text, crlf):
    p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


def replace(path, old, new):
    p, text, crlf = read(path)
    count = text.count(old)
    assert count == 1, "%s anchor count=%d\n%s" % (path, count, old[:160])
    write(p, text.replace(old, new), crlf)
    print("PATCH", path)


replace("scripts/reward_panel.gd", """\t_btn.size = Vector2(196, 46)
\t_btn.custom_minimum_size = Vector2(196, 46)
""", """\t_btn.size = Vector2(154, 46)
\t_btn.custom_minimum_size = Vector2(154, 46)
""")
replace("scripts/map_scene.gd", """\t_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
""", """\t# R825：两个入口收进顶栏天然空档，不压首领条、标记工具、信物或地图格。
\t_reward_panel = RewardPanel.attach(self, Vector2(318, 10))
""")
replace("scripts/map_scene.gd", """\t_shop_return_btn.position = Vector2(12, 90)
\t_shop_return_btn.size = Vector2(196, 46)
\t_shop_return_btn.custom_minimum_size = Vector2(196, 46)
""", """\t_shop_return_btn.position = Vector2(size.x - 462, 10)
\t_shop_return_btn.size = Vector2(154, 46)
\t_shop_return_btn.custom_minimum_size = Vector2(154, 46)
""")
replace("scripts/test_smoke.gd", """\tif rr.intersects(sr) or rr.size.x < 196.0 or sr.size.x < 196.0:
\t\t_smoke_fail("R825 地图按钮：矩形重叠或宽度不足（%s / %s）" % [str(rr), str(sr)])
""", """\tvar title_left := scene.MAP_X0 + scene.MAP_W / 2.0 - 150.0
\tvar title_right := scene.MAP_X0 + scene.MAP_W / 2.0 + 150.0
\tif rr.intersects(sr) or rr.size.x < 154.0 or sr.size.x < 154.0 \
\t\t\tor rr.end.y > 62.0 or sr.end.y > 62.0 or rr.end.x > title_left \
\t\t\tor sr.position.x < title_right or sr.end.x > scene._choco_panel_rect().position.x:
\t\t_smoke_fail("R825 地图按钮：重叠 / 越出顶栏空档 / 压到首领条（%s / %s）" % [str(rr), str(sr)])
""")
replace("scripts/test_engine.gd", """\tvar r825_reward_src := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
""", """\tvar r825_reward_src := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
\tvar r825_shop_src := FileAccess.get_file_as_string("res://scripts/shop_scene.gd")
""")
replace("scripts/test_engine.gd", """\tvar r825_shop_src := FileAccess.get_file_as_string("res://scripts/shop_scene.gd")
\tvar r825_trap_fn := r825_shop_src.find("func _buy_trap")
""", """\tvar r825_trap_fn := r825_shop_src.find("func _buy_trap")
""")

# 审计索引与最终真源逐字节一致。
p, text, crlf = read("i18n/interface_zh_canonical.json")
import json
data = json.loads(text)
for scope, source in [("reward", "scripts/reward_panel.gd"), ("map", "scripts/map_scene.gd")]:
    old_hash = data["source_snapshots"][scope][source]
    new_hash = hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
    assert text.count(old_hash) == 1, (scope, old_hash)
    text = text.replace(old_hash, new_hash)
write(p, text, crlf)
print("R825 FINAL LAYOUT OK")
