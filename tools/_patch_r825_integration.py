# -*- coding: utf-8 -*-
"""R825：存档返回入口的轮号、四语文案与计数整合；保留原行尾。"""
from pathlib import Path
import hashlib
import json

ROOT = Path(r"E:/work/card_rogue")
OWN_CODE = [
    "scripts/battle_scene.gd", "scripts/reward_panel.gd", "scripts/shop_scene.gd",
    "scripts/map_scene.gd", "scripts/ui_theme.gd", "tools/_patch_r825_save.py",
]


def read(path):
    p = ROOT / path
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    return p, text.replace("\r\n", "\n") if crlf else text, crlf


def write(p, text, crlf):
    p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


def replace(path, old, new, count=1):
    p, text, crlf = read(path)
    actual = text.count(old)
    assert actual == count, "%s anchor count=%d expected=%d\n%s" % (path, actual, count, old[:160])
    text = text.replace(old, new)
    write(p, text, crlf)
    print("PATCH", path)


for path in OWN_CODE:
    p, text, crlf = read(path)
    assert "R823" in text, path + " 没有待改轮号"
    write(p, text.replace("R823", "R825"), crlf)
    print("ROUND R825", path)

replace("scripts/reward_panel.gd", '"← 返回待领奖励 %d"', '"返回待领奖励 %d"')
replace("scripts/map_scene.gd", '"← 返回同一间商店"', '"返回同一间商店"')
replace("scripts/reward_panel.gd", """\t_btn.size = Vector2(152, 32)
\t_btn.custom_minimum_size = Vector2(152, 32)
""", """\t_btn.size = Vector2(196, 46)
\t_btn.custom_minimum_size = Vector2(196, 46)
""")

replace("i18n/interface_zh_canonical.json", '"updated": "2026-11-18"', '"updated": "2026-11-19"')
replace("i18n/interface_zh_canonical.json", '"zh": "✦ 待领奖励 %d"', '"zh": "返回待领奖励 %d"')
replace("i18n/interface_zh_canonical.json", '"source": "scripts/reward_panel.gd:267",\n        "zh": "返回待领奖励 %d"',
        '"source": "scripts/reward_panel.gd",\n        "zh": "返回待领奖励 %d"')
replace("i18n/interface_zh_canonical.json", '"map": 244,', '"map": 245,')
replace("i18n/interface_zh_canonical.json", """      "MAP_REWARD_FORFEIT": {
        "source": "scripts/map_scene.gd",
        "zh": "离开上一格：%d 件没领的奖励已作废（要拿就得在进新格子之前回去）"
      }
""", """      "MAP_REWARD_FORFEIT": {
        "source": "scripts/map_scene.gd",
        "zh": "离开上一格：%d 件没领的奖励已作废（要拿就得在进新格子之前回去）"
      },
      "MAP_RETURN_TO_SHOP": {
        "source": "scripts/map_scene.gd",
        "zh": "返回同一间商店"
      }
""")

for lang, old_reward, new_reward, shop in [
    ("en", "✦ Pending Rewards %d", "Pending Rewards %d", "Return to Shop"),
    ("ja", "✦ 未受取報酬 %d", "未受取報酬 %d", "同じ商店へ戻る"),
    ("es", "✦ Recompensas pendientes: %d", "Recompensas: %d", "Volver a la tienda"),
]:
    path = "i18n/interface_%s.json" % lang
    replace(path, '"REWARD_PENDING_ENTRY": "%s"' % old_reward,
            '"REWARD_PENDING_ENTRY": "%s"' % new_reward)
    p, text, crlf = read(path)
    data = json.loads(text)
    old_forfeit = data["scopes"]["map"]["MAP_REWARD_FORFEIT"]
    old = '      "MAP_REWARD_FORFEIT": %s\n' % json.dumps(old_forfeit, ensure_ascii=False)
    new = old.rstrip("\n") + ',\n      "MAP_RETURN_TO_SHOP": %s\n' % json.dumps(shop, ensure_ascii=False)
    assert text.count(old) == 1, path + " map insertion anchor"
    write(p, text.replace(old, new), crlf)
    print("PATCH", path, "MAP_RETURN_TO_SHOP")

replace("i18n/validate_spanish.py", """check(len(interface_zh_rows) == 835,
      "interface 共 835 条（R822 +鸭绅士 7 条事件文案）")""",
        """check(len(interface_zh_rows) == 836,
      "interface 共 836 条（R822 +鸭绅士 7 条事件文案；R825 +返回同一间商店）")""")

# source_hashes 是审计索引，虽然当前校验器不读取，也保持与真源一致。
p, text, crlf = read("i18n/interface_zh_canonical.json")
data = json.loads(text)
for scope, source in [("reward", "scripts/reward_panel.gd"), ("map", "scripts/map_scene.gd")]:
    old_hash = data["source_snapshots"][scope][source]
    new_hash = hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
    assert text.count(old_hash) == 1, (scope, source, old_hash)
    text = text.replace(old_hash, new_hash)
write(p, text, crlf)
print("R825 I18N INTEGRATION OK")
