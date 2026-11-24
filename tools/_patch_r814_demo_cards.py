# -*- coding: utf-8 -*-
"""R814 试玩版：card_data.gd 解析 no_demo + cards.json 打标 + 校验。"""
import io, json, sys

REPO = "E:/work/card_rogue"


def load(p):
    return io.open(p, "r", encoding="utf-8", newline="").read()


def save(p, s):
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def patch(text, anchor, block, tag):
    n = text.count(anchor)
    assert n == 1, "anchor %s count=%d" % (tag, n)
    return text.replace(anchor, anchor + block)


# ---------- ① card_data.gd：字段声明 + 解析 + to_dict ----------
p = REPO + "/scripts/card_data.gd"
s = load(p)
assert "\r\n" in s

s = patch(s,
          "var event_only: bool = false\r\n",
          "\r\n## R814：**不进试玩版**（`GameBuild.is_demo()`）—— 试玩切片把每个职业的卡池\r\n"
          "## 裁到 60 张，被裁的卡打这个标记。缺省 false → 老数据一行都不用改；完整版无视它。\r\n"
          "## 判据只在 `CardRepo.obtainable_cards()` 与图鉴的 `demo_allows()` 两处。\r\n"
          "var no_demo: bool = false\r\n",
          "decl")

s = patch(s,
          '\tc.event_only = bool(d.get("event_only", false))\r\n',
          '\t# R814：试玩版裁剪标记（缺省 false → 老卡一行都不用改）\r\n'
          '\tc.no_demo = bool(d.get("no_demo", false))\r\n',
          "parse")

s = patch(s,
          '\t\t"event_only": event_only,\r\n',
          '\t\t# R814：裁剪标记必须随复制通道走，否则试玩包里复制出来的卡会绕过池过滤\r\n'
          '\t\t"no_demo": no_demo,\r\n',
          "to_dict")
save(p, s)

# ---------- ② cards.json：给 13 张卡打 no_demo ----------
CUT = [9077, 9082, 9083, 9062, 9078, 9148, 9150, 9175, 9206, 9249, 9235,   # 森林精魄 11
       9233, 9098]                                                        # 暗影刺客 2

p = REPO + "/cards.json"
raw = load(p)
for cid in CUT:
    key = '      "id": %d,\r\n' % cid
    n = raw.count(key)
    assert n == 1, "card %d anchor count=%d" % (cid, n)
    start = raw.index(key)
    end = raw.index("\r\n    }", start)
    raw = raw[:end] + ',\r\n      "no_demo": true' + raw[end:]
save(p, raw)

# ---------- ③ 校验：JSON 合法 + 条数 + 组合卡齐全 ----------
data = json.loads(load(p))
cards = data["cards"]
assert len(cards) == 337, len(cards)

for cls, want in (("森林精魄", 60), ("暗影刺客", 60)):
    pool = [c for c in cards
            if c.get("class") == cls and c.get("rarity", 9) <= 2
            and not c.get("locked") and not c.get("event_only") and not c.get("no_demo")]
    print(cls, "pool =", len(pool), "want", want)
    assert len(pool) == want, (cls, len(pool))

marked = [c["id"] for c in cards if c.get("no_demo")]
assert sorted(marked) == sorted(CUT), marked

# 组合素材 / 触发卡一张都不许被裁
MATERIAL = [c["id"] for c in cards if "upper_effect" in c]
TRIGGER = [c["id"] for c in cards if c.get("combo_trigger")] + [8084, 8085, 8086, 9191, 9193]
bad = [i for i in MATERIAL + TRIGGER if i in CUT]
assert not bad, "被裁掉的组合卡：%s" % bad
print("materials", len(MATERIAL), "triggers", len(TRIGGER), "cut ok")
print("OK")
