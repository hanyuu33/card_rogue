# -*- coding: utf-8 -*-
"""R777b 疾风乐章（9270，吟游诗人 2 费史诗效果卡）：cards.json + 三语 i18n。

cards.json 是 CRLF、手工维护 → 按字节原文插在文件末尾（路径与 R777 彩虹诗同一个锚点）。
"""
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(p):
    return io.open(os.path.join(ROOT, p), "rb").read().decode("utf-8")


def save(p, s):
    io.open(os.path.join(ROOT, p), "wb").write(s.encode("utf-8"))


EFFECT = "所有盟友移动速度 +1；若为其他职业盟友，改为一回合行动两次。"
CARD_SRC = (
    '    {\r\n'
    '      "id": 9270,\r\n'
    '      "name": "疾风乐章",\r\n'
    '      "kind": "效果",\r\n'
    '      "cost": 2,\r\n'
    '      "power": 0,\r\n'
    '      "health": 0,\r\n'
    '      "attack_range": 0,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 2,\r\n'
    '      "group": "player",\r\n'
    '      "class": "吟游诗人",\r\n'
    '      "traits": [\r\n'
    '        "疾风乐章"\r\n'
    '      ],\r\n'
    '      "affixes": [],\r\n'
    '      "effect_text": "%s",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    }' % EFFECT
)
raw = load("cards.json")
assert '"id": 9270' not in raw, "9270 已存在"
before = len(json.loads(raw)["cards"])
anchor = '"image": ""\r\n    }\r\n  ]\r\n}\r\n'
assert raw.count(anchor) == 1, "末尾锚点命中 %d 次" % raw.count(anchor)
save("cards.json", raw.replace(anchor, '"image": ""\r\n    },\r\n' + CARD_SRC + '\r\n  ]\r\n}\r\n'))

d = json.loads(load("cards.json"))
new = [c for c in d["cards"] if c["id"] == 9270]
assert len(new) == 1, "9270 未写入"
c = new[0]
assert c["name"] == "疾风乐章" and c["kind"] == "效果" and c["cost"] == 2
assert c["rarity"] == 2 and c["class"] == "吟游诗人" and c["group"] == "player"
assert c["effect_text"] == EFFECT and c["color"] == "水风"
assert c["target_mode"] == "none" and c["image"] == "" and c["traits"] == ["疾风乐章"]
assert len(d["cards"]) == before + 1, "总卡数 %d" % len(d["cards"])
txt = load("cards.json")
assert "\n" not in txt.replace("\r\n", ""), "cards.json 出现裸 LF"
print("[ok] cards.json 9270 疾风乐章（%d → %d 张，CRLF 保留）" % (before, len(d["cards"])))

EN_NAME = "Wind Song"
EN_EFFECT = ("All Allies gain +1 Move Speed. Allies of another class instead act "
             "twice each turn.")
JA_NAME = "疾風の楽章"
JA_EFFECT = ("味方すべての移動速度 +1。他クラスの味方は代わりに毎ターン 2 回行動する。")


def add_entry(path, payload, stamp=None):
    raw_txt = load(path)
    data = json.loads(raw_txt)
    assert "9270" not in data["cards"], "%s 已有 9270" % path
    data["cards"]["9270"] = payload
    data["cards"] = {k: data["cards"][k]
                     for k in sorted(data["cards"], key=lambda x: int(x))}
    if "count" in data:
        data["count"] = len(data["cards"])
    if stamp is not None and "updated" in data:
        data["updated"] = stamp
    out = json.dumps(data, ensure_ascii=False, indent=1)
    if raw_txt.endswith("\n"):
        out += "\n"
    save(path, out)
    print("[ok] %-28s → %d 条" % (path, len(data["cards"])))


add_entry("i18n/cards_en.json", {"name": EN_NAME, "effect_text": EN_EFFECT})
add_entry("i18n/cards_ja.json", {"name": JA_NAME, "effect_text": JA_EFFECT})
add_entry("i18n/zh_canonical.json",
          {"name": "疾风乐章", "effect_text": EFFECT, "changed": False},
          stamp="2026-11-16")

for p in ["i18n/cards_en.json", "i18n/cards_ja.json", "i18n/zh_canonical.json"]:
    dd = load(p)
    assert "9270" in json.loads(dd)["cards"], p
    assert "\r\n" not in dd, "%s 出现 CRLF" % p
    print("  %-28s 9270 = %s" % (p, json.loads(dd)["cards"]["9270"]["name"]))
print("[done] R777b data")
