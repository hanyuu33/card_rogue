# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"E:/work/card_rogue/scripts/test_smoke.gd")
raw = p.read_bytes()
text = raw.decode("utf-8").replace("\r\n", "\n")
for name in ["title_left", "title_right"]:
    old = "\tvar %s := scene.MAP_" % name
    new = "\tvar %s: float = scene.MAP_" % name
    assert text.count(old) == 1, name
    text = text.replace(old, new)
p.write_bytes(text.replace("\n", "\r\n").encode("utf-8"))
print("R825 SMOKE TYPES OK")
