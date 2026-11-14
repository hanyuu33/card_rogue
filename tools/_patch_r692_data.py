# -*- coding: utf-8 -*-
"""R692 数据补丁：飓风咆哮 / 幽深回响 / 鸭蛋 / 效果卡文案清理 / 鸭妈妈 + 小鸭。

用法：python tools/_patch_r692_data.py [--write]
不带 --write 只打印计数与摘要（干跑）。
"""
import json
import re
import sys

ROOT = "E:/work/card_rogue/"
CARDS = ROOT + "cards.json"
CANON = ROOT + "i18n/zh_canonical.json"

WRITE = "--write" in sys.argv


def load(path):
    raw = open(path, "rb").read().decode("utf-8")
    crlf = raw.count("\r\n") == raw.count("\n")
    return raw, crlf


def save(path, txt, crlf):
    data = txt.replace("\r\n", "\n")
    if crlf:
        data = data.replace("\n", "\r\n")
    open(path, "wb").write(data.encode("utf-8"))


# ── ① 文案清理：具体句 → 空（顺序敏感：长的先来） ──
SPECIFIC = [
    # 破绽 9154：这句里「本场对战不再出现」是它独有的后果，保留
    ("字段「次元」：打出后消失，不进弃牌区，本场对战不再出现。", "本场对战不再出现。"),
    # 次元字段说明（29 张）
    ("字段「次元」：打出后消失，不进弃牌区。", ""),
    ("字段「次元」：离场即消失，不进弃牌区。", ""),
    # 来源描述（由「XXX」…）
    ("由「生蛋鸭」在每场战斗开始时放置到己方前排中央。", ""),
    ("由「魔像术」召唤。", ""),
    ("由「鸭蛋」孵出。", ""),
    # 字段定义复述
    ("嘲讽：敌方单位必须优先攻击它。", ""),
    (
        "**嘲讽**。**超负荷**：生命降到 0 或以下时不会立即死亡，会以负数血量继续存活"
        "（伤害不会溢出）；在自己回合结束时若生命仍是负数则死亡。",
        "**嘲讽**。**超负荷**。",
    ),
    (
        "**超负荷**：生命降到 0 或以下时不会立即死亡，会以负数血量继续存活"
        "（伤害不会溢出）；在自己回合结束时若生命仍是负数则死亡。",
        "**超负荷**。",
    ),
    ("交换：也可以放在已有友方单位的格子上，原本在那个格子上的友方单位返回手卡。", ""),
    ("每回合可以行动两次。", ""),
    ("一回合可以行动两次。", ""),
    ("一回合行动两次。", ""),
]

# zh_canonical 里 1011 等用的是「力量」而不是「攻击力」，超负荷的措辞也略有差别
CANON_SPECIFIC = SPECIFIC + [
    (
        "**超负荷**：生命降到 0 或以下时不会立即死亡，会以负数生命继续存活"
        "（伤害不会溢出）；在自己回合结束时若生命仍是负数则死亡。",
        "**超负荷**。",
    ),
]

# ── ② 鸭蛋 9022：回合结束 → 我方回合开始 ──
EGG_OLD = "回合结束时若它仍存活"
EGG_NEW = "我方回合开始时若存活"

ROAR_NEW = "每次使用效果卡时，对所有敌人造成 4 点伤害，重复 X 次。使用此卡本身不会触发。X 为本卡在效果区的张数。"


def block(txt, cid):
    """返回 cards.json 里某个 id 的 `{...}` 块（含花括号）在字符串中的 (start, end)。"""
    i = txt.find('"id": %d,' % cid)
    assert i > 0, "找不到 id=%d" % cid
    start = txt.rfind("{", 0, i)
    depth = 0
    j = start
    while j < len(txt):
        if txt[j] == "{":
            depth += 1
        elif txt[j] == "}":
            depth -= 1
            if depth == 0:
                return start, j + 1
        j += 1
    raise AssertionError("块没闭合 id=%d" % cid)


def set_field(txt, cid, key, old, new):
    a, b = block(txt, cid)
    seg = txt[a:b]
    o = '"%s": %s' % (key, old)
    assert seg.count(o) == 1, "id=%d key=%s 命中 %d 次" % (cid, key, seg.count(o))
    return txt[:a] + seg.replace(o, '"%s": %s' % (key, new)) + txt[b:]


def apply_specific(txt, pairs, tag, counts):
    for old, new in pairs:
        n = txt.count(old)
        counts[tag].append((n, old[:24]))
        txt = txt.replace(old, new)
    return txt


def tidy(txt):
    """清掉删除后留下的空句 / 双句号 / 首尾空白。"""
    txt = re.sub(r"(。)\s*。", "。", txt)
    txt = re.sub(r"^\s*。", "", txt)
    txt = re.sub(r"\s{2,}", " ", txt)
    return txt.strip()


counts = {"cards": [], "canon": []}

# ── cards.json ──
raw, crlf = load(CARDS)
assert crlf, "cards.json 应为纯 CRLF"
out = apply_specific(raw, SPECIFIC, "cards", counts)

# 9022 时机
assert out.count(EGG_OLD) == 1, "鸭蛋时机句命中 %d" % out.count(EGG_OLD)
out = out.replace(EGG_OLD, EGG_NEW)

# 9002 幽深回响：6 → 8
a, b = block(out, 9002)
blk = out[a:b]
assert blk.count('"value": 6') == 1, "9002 value 不是 6"
assert blk.count("造成 6 点伤害") == 1, "9002 文案不是 6 点"
blk = blk.replace('"value": 6', '"value": 8').replace("造成 6 点伤害", "造成 8 点伤害")
out = out[:a] + blk + out[b:]

# 9063 飓风咆哮：文案
a, b = block(out, 9063)
blk = out[a:b]
m = re.search(r'"effect_text": "((?:[^"\\]|\\.)*)"', blk)
assert m, "9063 没有 effect_text"
blk = blk[: m.start(1)] + ROAR_NEW + blk[m.end(1):]
out = out[:a] + blk + out[b:]

# 新增 9250 鸭妈妈 / 9251 小鸭
NEW_BLOCKS = [
    {
        "id": 9250,
        "name": "鸭妈妈",
        "kind": "盟友",
        "cost": 4,
        "power": 3,
        "health": 15,
        "attack_range": 1,
        "move_speed": 1,
        "rarity": 1,
        "group": "player",
        "class": "森林精魄",
        "traits": ["鸭妈妈"],
        "affixes": [],
        "effect_text": "使用时，在这张卡两边各召唤一只「小鸭」（如果可能）。",
        "target_mode": "none",
        "color": "绿",
        "image": "",
    },
    {
        "id": 9251,
        "name": "小鸭",
        "kind": "盟友",
        "cost": 0,
        "power": 1,
        "health": 1,
        "attack_range": 1,
        "move_speed": 1,
        "rarity": 5,
        "group": "player",
        "class": "森林精魄",
        "traits": ["小鸭", "离场消失"],
        "affixes": ["次元"],
        "effect_text": "入场时，随机使手卡里的一张效果卡费用 -1。",
        "target_mode": "none",
        "color": "绿",
        "image": "",
    },
]


def block_text(d):
    L = ["{"]
    keys = list(d.items())
    for idx, (k, v) in enumerate(keys):
        comma = "," if idx < len(keys) - 1 else ""
        if k == "traits":
            L.append('      "traits": [')
            for ti, t in enumerate(v):
                L.append('        "%s"%s' % (t, "," if ti < len(v) - 1 else ""))
            L.append("      ]," if idx < len(keys) - 1 else "      ]")
            continue
        if k == "affixes":
            if not v:
                L.append('      "affixes": []%s' % comma)
            else:
                L.append('      "affixes": [' + ", ".join('"%s"' % x for x in v) + "]" + comma)
            continue
        if isinstance(v, str):
            L.append('      "%s": "%s"%s' % (k, v.replace("\\", "\\\\").replace('"', '\\"'), comma))
        else:
            L.append('      "%s": %s%s' % (k, json.dumps(v, ensure_ascii=False), comma))
    L.append("    }")
    return "\r\n".join(L)


existing = {c["id"] for c in json.loads(out)["cards"]}
for nb in NEW_BLOCKS:
    assert nb["id"] not in existing, "id %d 已存在" % nb["id"]

tail = "\r\n  ]\r\n}\r\n"
i = out.rindex(tail)
head = out[:i].rstrip()
assert head.endswith("}")
out = head + ",\r\n    " + ",\r\n    ".join(block_text(b) for b in NEW_BLOCKS) + tail

data = json.loads(out)
assert len(data["cards"]) == 319, len(data["cards"])

# 清理残留的「字段「」」/「由「」」/ 空句
left = [c["id"] for c in data["cards"] if "字段「" in (c.get("effect_text") or "")]
assert not left, "还有卡残留字段说明：%s" % left

# ── zh_canonical ──
rawc, crlfc = load(CANON)
outc = apply_specific(rawc, CANON_SPECIFIC, "canon", counts)
assert outc.count(EGG_OLD) == 1
outc = outc.replace(EGG_OLD, EGG_NEW)
outc = outc.replace('"effect_text": "回合开始时，对随机敌人造成 6 点伤害，重复 X 次。',
                    '"effect_text": "回合开始时，对随机敌人造成 8 点伤害，重复 X 次。')
old_roar = '"effect_text": "每回合前 X 次使用效果卡时，对所有敌人造成 4 点伤害。使用此卡本身不会触发。X 为本卡在效果区的张数。"'
assert outc.count(old_roar) == 1, "canonical 9063 锚点命中 %d" % outc.count(old_roar)
outc = outc.replace(old_roar, '"effect_text": "%s"' % ROAR_NEW)

# 追加 9250 / 9251
add = ""
for nb in NEW_BLOCKS:
    add += (
        ',\n  "%d": {\n   "name": "%s",\n   "effect_text": "%s",\n   "changed": true\n  }'
        % (nb["id"], nb["name"], nb["effect_text"])
    )
end = outc.rindex("\n }\n}")
outc = outc[:end] + add + outc[end:]
canon = json.loads(outc)
assert len(canon["cards"]) == 319, len(canon["cards"])

# ── 报告 ──
print("== 替换计数 ==")
for tag, rows in counts.items():
    print(" [%s]" % tag)
    for n, s in rows:
        print("   %2d × %s" % (n, s))
print("== 关键卡 ==")
byid = {c["id"]: c for c in data["cards"]}
for cid in (9022, 9080, 9177, 1011, 8050, 8052, 8056, 9012, 9002, 9063, 9154, 9250, 9251):
    c = byid[cid]
    print("  %d %s | %s" % (cid, c["name"], c.get("effect_text")))
print("卡数", len(data["cards"]), "canon", len(canon["cards"]))

if WRITE:
    save(CARDS, out, crlf)
    save(CANON, outc, crlfc)
    for p in (CARDS, CANON, ):
        b = open(p, "rb").read()
        print("  %s → CRLF %d / LF %d" % (p.split("/")[-1], b.count(b"\r\n"), b.count(b"\n")))
    print("WROTE")
else:
    print("DRY-RUN（加 --write 落盘）")
