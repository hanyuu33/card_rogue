# -*- coding: utf-8 -*-
"""R777 彩虹诗（9269，吟游诗人 2 费稀有技能）：cards.json 追加一张卡 + 三语 i18n 同步。

cards.json 是 CRLF、手工维护（json 往返不保序）→ 一律按字节原文插入。
锚点用**文件末尾**那张卡的收尾（不依赖任何具体卡的内容），
所以并行线（R776 激励乐章 9267 / 管风琴 9268）先插几张都不影响。
"""
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(p):
    return io.open(os.path.join(ROOT, p), "rb").read().decode("utf-8")


def save(p, s):
    io.open(os.path.join(ROOT, p), "wb").write(s.encode("utf-8"))


# ── ① cards.json（CRLF）────────────────────────────────────────────────────
EFFECT = "随机 3 个不同其他职业，各将一张随机盟友或技能卡加入手卡，其费用本局 -1。"
CARD_SRC = (
    '    {\r\n'
    '      "id": 9269,\r\n'
    '      "name": "彩虹诗",\r\n'
    '      "kind": "技能",\r\n'
    '      "cost": 2,\r\n'
    '      "power": 0,\r\n'
    '      "health": 0,\r\n'
    '      "attack_range": 0,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 1,\r\n'
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
raw = load("cards.json")
assert '"id": 9269' not in raw, "9269 已存在"
before = len(json.loads(raw)["cards"])

anchor = '"image": ""\r\n    }\r\n  ]\r\n}\r\n'
assert raw.count(anchor) == 1, "cards.json 末尾锚点命中 %d 次" % raw.count(anchor)
repl = '"image": ""\r\n    },\r\n' + CARD_SRC + '\r\n  ]\r\n}\r\n'
save("cards.json", raw.replace(anchor, repl))

d = json.loads(load("cards.json"))
new = [c for c in d["cards"] if c["id"] == 9269]
assert len(new) == 1, "9269 未写入"
c = new[0]
assert c["name"] == "彩虹诗" and c["kind"] == "技能" and c["cost"] == 2
assert c["rarity"] == 1 and c["class"] == "吟游诗人" and c["group"] == "player"
assert c["effect_text"] == EFFECT and c["color"] == "水风"
assert c["target_mode"] == "none" and c["image"] == "" and c["traits"] == []
assert c["power"] == 0 and c["health"] == 0
assert len(d["cards"]) == before + 1, "总卡数 %d（期望 %d）" % (len(d["cards"]), before + 1)
txt = load("cards.json")
assert txt.count("\r\n") > 0 and "\n" not in txt.replace("\r\n", ""), "cards.json 出现裸 LF"
print("[ok] cards.json 9269 彩虹诗（%d → %d 张，CRLF 保留）" % (before, len(d["cards"])))

# ── ② i18n：cards_en / cards_ja / zh_canonical ────────────────────────────
EN_NAME = "Rainbow Verse"
EN_EFFECT = ("Pick 3 different other classes at random. Add one random Ally or Skill "
             "card of each to your Hand; its cost is reduced by 1 for the rest of "
             "this battle.")
JA_NAME = "虹の詩"
JA_EFFECT = ("ランダムな他クラス 3 つを選び、それぞれの味方またはスキルカードを 1 枚ずつ"
             "ランダムで手札に加える。それらの費用はこの戦闘中 -1 される。")


def add_entry(path, payload, stamp=None):
    raw_txt = load(path)
    data = json.loads(raw_txt)
    assert "9269" not in data["cards"], "%s 已有 9269" % path
    data["cards"]["9269"] = payload
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
          {"name": "彩虹诗", "effect_text": EFFECT, "changed": False},
          stamp="2026-11-16")

for p in ["i18n/cards_en.json", "i18n/cards_ja.json", "i18n/zh_canonical.json"]:
    dd = load(p)
    assert "9269" in json.loads(dd)["cards"], p
    assert "\r\n" not in dd, "%s 出现 CRLF（应为 LF）" % p
    print("  %-28s 9269 = %s" % (p, json.loads(dd)["cards"]["9269"]["name"]))
print("[done] R777 data")
