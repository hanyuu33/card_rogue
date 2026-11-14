# -*- coding: utf-8 -*-
"""R689 数据补丁：疾风之力触发条件 / 群起攻之口径 / 生命循环改效果卡 / 新卡 9248 种子 + 9249 被眷顾者。

只做**文本级**替换（保留 cards.json 的 CRLF 与 6 空格字段缩进、canonical 的 LF 与 3 空格），
每条锚点断言 count == 1。
"""
import json
import sys

WRITE = "--write" in sys.argv

CJ = "cards.json"
CN = "i18n/zh_canonical.json"

GALE_OLD = "每个己方盟友进入战场时，随机对一个敌人造成 4 点伤害。效果区多张本卡不可叠加。"
GALE_NEW = "每个己方盟友进入战场时，或使用效果卡时，随机对一个敌人造成 4 点伤害。效果区多张本卡不可叠加。"

RALLY_OLD = "**接通**的单位在自己攻击时不计算距离（全场可达）。效果区多张本卡不可叠加。"
RALLY_NEW = "**接通**的己方单位攻击时，可以用与它接通的其他己方单位的位置发起攻击。效果区多张本卡不可叠加。"

LIFE_OLD = "选择一个己方盟友：使它获得「次元」和「死亡」—— 它被破坏时，将一张随机盟友卡加入你的手卡。"
LIFE_NEW = "使用时，己方所有盟友获得「次元」与「死亡」—— 它们被破坏时，将一张种子加入你的手卡。效果区多张本卡不可叠加。"

SEED_TEXT = "回合开始时，破坏此卡：随机获得 1 点费用，或一张随机卡加入手卡。X 为本卡在效果区的张数，每张各结算一次。"
BLESSED_TEXT = "随机将抽牌库的一张效果卡复制并打出。回复等于抽牌库中效果卡张数的费用。"

CARD_BLOCK = """    {
      "id": %d,
      "name": "%s",
      "kind": "%s",
      "cost": %d,
      "power": 0,
      "health": 0,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": %d,
      "group": "player",
      "class": "森林精魄",
      "traits": [
        "%s"
      ],
      "affixes": [],
      "effect_text": "%s",
      "target_mode": "none",
      "value": 0,
      "color": "绿",
      "image": ""
    },
"""

CANON_BLOCK = """  "%d": {
   "name": "%s",
   "effect_text": "%s",
   "changed": true
  },
"""


def load(p):
    raw = open(p, "rb").read().decode("utf-8")
    return raw


def save(p, txt):
    open(p, "wb").write(txt.encode("utf-8"))
    b = open(p, "rb").read()
    print("  写入 %s  CRLF=%d LF=%d" % (p, b.count(b"\r\n"), b.count(b"\n")))


def rep(txt, old, new, tag, crlf=True):
    o = old.replace("\n", "\r\n") if crlf else old
    n = new.replace("\n", "\r\n") if crlf else new
    c = txt.count(o)
    if c != 1:
        raise SystemExit("[%s] 锚点命中 %d 次（预期 1），拒绝写入" % (tag, c))
    return txt.replace(o, n)


cards = load(CJ)
print("== cards.json")
cards = rep(cards, '"effect_text": "%s"' % GALE_OLD, '"effect_text": "%s"' % GALE_NEW, "疾风之力")
cards = rep(cards, '"effect_text": "%s"' % RALLY_OLD, '"effect_text": "%s"' % RALLY_NEW, "群起攻之")
cards = rep(cards, '"effect_text": "%s"' % LIFE_OLD, '"effect_text": "%s"' % LIFE_NEW, "生命循环文案")

# 生命循环：技能 0 费普通 → 效果 1 费史诗；带 trait 便于效果区判定
life_old = '''      "id": 9150,
      "name": "生命循环",
      "kind": "技能",
      "cost": 0,
      "power": 0,
      "health": 0,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": 0,
      "group": "player",
      "class": "森林精魄",
      "traits": [],
      "affixes": [],
      "effect_text": "%s",
      "target_mode": "unit",
      "value": 0,
      "color": "绿",
      "image": ""
''' % LIFE_NEW
life_new = '''      "id": 9150,
      "name": "生命循环",
      "kind": "效果",
      "cost": 1,
      "power": 0,
      "health": 0,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": 2,
      "group": "player",
      "class": "森林精魄",
      "traits": [
        "生命循环"
      ],
      "affixes": [],
      "effect_text": "%s",
      "target_mode": "none",
      "value": 0,
      "color": "绿",
      "image": ""
''' % LIFE_NEW
cards = rep(cards, life_old, life_new, "生命循环字段")

# 新卡：插在 9247 拼装工厂之后（同属 92xx 段），保持 id 邻接
anchor = '      "combo_trigger": "turn_start"\n    },\n    {\n      "id": 9190,'
seed_block = CARD_BLOCK % (9248, "种子", "效果", 0, 5, "种子", SEED_TEXT)
blessed_block = CARD_BLOCK % (9249, "被眷顾者", "技能", 3, 2, "被眷顾者", BLESSED_TEXT)
cards = rep(cards, anchor,
            '      "combo_trigger": "turn_start"\n    },\n' + seed_block + blessed_block
            + '    {\n      "id": 9190,', "新卡插入")

if WRITE:
    save(CJ, cards)
    d = json.loads(cards)
    ids = [c["id"] for c in d["cards"]]
    assert len(ids) == len(set(ids)), "id 重复"
    for cid in (9150, 9248, 9249):
        c = [x for x in d["cards"] if x["id"] == cid][0]
        print("  %d %s %s r%s c%s %s" % (cid, c["name"], c["kind"], c["rarity"], c["cost"], c["traits"]))
    print("  总卡数 %d" % len(ids))

canon = load(CN)
print("== zh_canonical.json")
canon = rep(canon, '"effect_text": "%s"' % GALE_OLD, '"effect_text": "%s"' % GALE_NEW, "canon 疾风", crlf=False)
canon = rep(canon, '"effect_text": "%s"' % RALLY_OLD, '"effect_text": "%s"' % RALLY_NEW, "canon 群起", crlf=False)
# canonical 这一条旧文案写的是「手牌」（cards.json 是「手卡」），R688 没对齐到这张 —— 按各自原文替换
LIFE_OLD_CANON = "选择一个己方盟友：使它获得「次元」和「死亡」—— 它被破坏时，将一张随机盟友卡加入你的手牌。"
canon = rep(canon, '"effect_text": "%s"' % LIFE_OLD_CANON, '"effect_text": "%s"' % LIFE_NEW, "canon 生命循环", crlf=False)

anchor2 = '  "9154": {'
add = (CANON_BLOCK % (9248, "种子", SEED_TEXT)) + (CANON_BLOCK % (9249, "被眷顾者", BLESSED_TEXT))
canon = rep(canon, anchor2, add + anchor2, "canon 新卡", crlf=False)

if WRITE:
    save(CN, canon)
    d2 = json.loads(canon)["cards"]
    for k in ("9150", "9248", "9249"):
        print("  %s %s" % (k, d2[k]["name"]))
    print("  canonical 卡数 %d" % len(d2))
    # canonical 与 cards.json 效果卡文案必须完全一致（R688 口径）
    nc = json.loads(cards)
    by = {c["id"]: c for c in nc["cards"]}
    bad = []
    for c in nc["cards"]:
        if c["kind"] != "效果":
            continue
        k = str(c["id"])
        if k in d2 and d2[k]["effect_text"] != c["effect_text"]:
            bad.append(k)
    print("  效果卡文案不一致：", bad if bad else "无")
else:
    print("干跑通过（未写入）")
