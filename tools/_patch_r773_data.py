# -*- coding: utf-8 -*-
"""R773 呼唤（9266，吟游诗人普通技能）：cards.json 追加一张卡 + 三语 i18n 同步。

cards.json 是 CRLF，原样保留；i18n 是 LF + indent=1，末尾是否带换行按原文件走。
"""
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(p):
    with io.open(os.path.join(ROOT, p), "rb") as f:
        return f.read().decode("utf-8")


def save(p, s):
    with io.open(os.path.join(ROOT, p), "wb") as f:
        f.write(s.encode("utf-8"))


# ── ① cards.json（CRLF）────────────────────────────────────────────────────
EFFECT = "费用本局 +1。将一张随机比这张卡费用高 1 的其他职业盟友加入手卡，其费用本局变为 0。"
CARD_SRC = (
    '    {\r\n'
    '      "id": 9266,\r\n'
    '      "name": "呼唤",\r\n'
    '      "kind": "技能",\r\n'
    '      "cost": 0,\r\n'
    '      "power": 0,\r\n'
    '      "health": 0,\r\n'
    '      "attack_range": 0,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 0,\r\n'
    '      "group": "player",\r\n'
    '      "class": "吟游诗人",\r\n'
    '      "traits": [],\r\n'
    '      "affixes": [],\r\n'
    '      "effect_text": "%s",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    }' % EFFECT
)
cards_raw = load("cards.json")
anchor = (
    '      "effect_text": "选弃牌区一张其他职业卡消失。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "value": 0,\r\n'
    '      "color": "暗影",\r\n'
    '      "image": ""\r\n'
    '    }\r\n'
    '  ]\r\n'
    '}\r\n'
)
assert cards_raw.count(anchor) == 1, "cards.json 锚点不唯一：%d" % cards_raw.count(anchor)
repl = anchor.replace(
    '    }\r\n  ]\r\n}\r\n',
    '    },\r\n' + CARD_SRC + '\r\n  ]\r\n}\r\n'
)
assert repl != anchor
cards_raw = cards_raw.replace(anchor, repl)
save("cards.json", cards_raw)

d = json.loads(load("cards.json"))
new = [c for c in d["cards"] if c["id"] == 9266]
assert len(new) == 1, "9266 未写入"
c = new[0]
assert c["name"] == "呼唤" and c["kind"] == "技能" and c["cost"] == 0
assert c["rarity"] == 0 and c["class"] == "吟游诗人" and c["group"] == "player"
assert c["effect_text"] == EFFECT and c["color"] == "水风"
assert c["target_mode"] == "none" and c["image"] == ""
assert len(d["cards"]) == 327, "总卡数 %d" % len(d["cards"])
assert load("cards.json").count("\r\n") > 0 and "\n" not in load("cards.json").replace("\r\n", "")
print("[ok] cards.json 9266 呼唤（共 %d 张，CRLF 保留）" % len(d["cards"]))

# ── ② i18n：cards_en / cards_ja / zh_canonical ────────────────────────────
EN_NAME = "Call"
EN_EFFECT = ("Gain +1 Energy for the rest of this battle. Add a random Ally of another "
             "class that costs 1 more than this card to your Hand; its cost becomes 0 "
             "for the rest of this battle.")
JA_NAME = "呼び声"
JA_EFFECT = ("この戦闘中、費用 +1。このカードより費用が 1 高い他クラスの味方 1 枚を"
             "ランダムで手札に加える。そのカードの費用はこの戦闘中 0 になる。")


def add_entry(path, payload, stamp=None):
    raw = load(path)
    data = json.loads(raw)
    assert "9266" not in data["cards"], "%s 已有 9266" % path
    data["cards"]["9266"] = payload
    data["cards"] = {k: data["cards"][k]
                     for k in sorted(data["cards"], key=lambda x: int(x))}
    if "count" in data:
        # R766 加 9265 时漏更新（325 → 326），这里一并校正为实际条数
        data["count"] = len(data["cards"])
    if stamp is not None and "updated" in data:
        data["updated"] = stamp
    out = json.dumps(data, ensure_ascii=False, indent=1)
    if raw.endswith("\n"):
        out += "\n"
    save(path, out)
    print("[ok] %-28s → %d 条" % (path, len(data["cards"])))


add_entry("i18n/cards_en.json", {"name": EN_NAME, "effect_text": EN_EFFECT})
add_entry("i18n/cards_ja.json", {"name": JA_NAME, "effect_text": JA_EFFECT})
add_entry("i18n/zh_canonical.json",
          {"name": "呼唤", "effect_text": EFFECT, "changed": False},
          stamp="2026-11-16")

for p in ["i18n/cards_en.json", "i18n/cards_ja.json", "i18n/zh_canonical.json"]:
    dd = json.loads(load(p))
    assert "9266" in dd["cards"], p
    print("  %-28s 9266 = %s" % (p, dd["cards"]["9266"]["name"]))
print("[done] R773 data")
