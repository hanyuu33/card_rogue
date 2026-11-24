# -*- coding: utf-8 -*-
from pathlib import Path
import hashlib
root = Path(r"E:/work/card_rogue")
p = root / "scripts/map_scene.gd"
raw = p.read_bytes()
crlf = b"\r\n" in raw
text = raw.decode("utf-8").replace("\r\n", "\n")
old = "RewardPanel.attach(self, Vector2(318, 10))"
new = "RewardPanel.attach(self, Vector2(300, 10))"
assert text.count(old) == 1
text = text.replace(old, new)
p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
cp = root / "i18n/interface_zh_canonical.json"
raw = cp.read_bytes()
crlf = b"\r\n" in raw
text = raw.decode("utf-8").replace("\r\n", "\n")
import json
data = json.loads(text)
old_hash = data["source_snapshots"]["map"]["scripts/map_scene.gd"]
new_hash = hashlib.sha256(p.read_bytes()).hexdigest()
assert text.count(old_hash) == 1
text = text.replace(old_hash, new_hash)
cp.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
print("R825 TOPBAR CLEARANCE OK")
