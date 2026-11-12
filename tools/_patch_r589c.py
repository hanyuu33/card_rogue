# -*- coding: utf-8 -*-
"""R589 第三批：八张素材卡入池 + 两处原文对齐 + 产物不吃本体专属判定。

用法：
    python tools/_patch_r589c.py --check-only
    python tools/_patch_r589c.py
"""
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv


def read(rel):
    with io.open(os.path.join(ROOT, rel), "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(rel, text):
    with io.open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as f:
        f.write(text)


# ── cards.json：八张卡的上下半（用户 R589 逐张点名）───────────────────────
# 上半一律只有钩子（R569 池形状：`upper.effects` 必须为空），效果全在下半。
CARDS = [
    (8004,  # 熊
     {"trigger": "active", "effects": []},
     {"effects": [{"type": "heal", "value": 6}], "note": "代替行动"}),
    (9222,  # 忒修斯奇械
     {"trigger": "lethal", "effects": [], "extra_affixes": ["超负荷", "次元"]},
     {"effects": [{"type": "add_card", "card_id": 9145, "value": 1}]}),
    (9074,  # 小精灵
     {"trigger": "use_after", "effects": []},
     {"effects": [{"type": "next_effect_discount", "value": 2}]}),
    (9052,  # 斑鸠
     {"trigger": "use_after", "effects": []},
     {"effects": [{"type": "next_ally_discount", "value": 1}]}),
    (9068,  # 水元素
     {"trigger": "use", "effects": []},
     {"effects": [{"type": "add_effect_from_deck", "value": 1, "discount": 2}]}),
    (8007,  # 影魔
     {"trigger": "use", "effects": []},
     {"effects": [{"type": "hand_skill_discount", "value": 1},
                  {"type": "hp_per_zero_skill", "value": 3}]}),
    (9046,  # 巨鼠
     {"trigger": "use_after", "effects": []},
     {"effects": [{"type": "fetch_cheapest_ally"}]}),
    (9039,  # 乌鸦
     {"trigger": "use_after", "effects": []},
     {"effects": [{"type": "recall_ally_from_discard"}]}),
]

# ── 原文对齐（用户 R589 点名）────────────────────────────────────────────
TEXT_FIX = [
    # 斑鸠：「那在原文本上加上使用后」
    ("9052", "本回合使用下一个盟友时，费用 -1。",
     "使用后，本回合使用下一个盟友时，费用 -1。"),
    # 影魔：「原文改为使用时」
    ("8007", "打出时，手卡中所有技能牌本回合费用 -1；",
     "使用时，手卡中所有技能牌本回合费用 -1；"),
]


def patch_cards(text):
    """在每张卡块的最后一个键（image）之后追加 upper_effect / lower_effect。"""
    for cid, up, lo in CARDS:
        marker = '"id": %d,' % cid
        if text.count(marker) != 1:
            raise SystemExit("[FAIL] cards.json：id %d 命中 %d 次" % (cid, text.count(marker)))
        i = text.index(marker)
        j = text.index("\r\n    }", i)
        block = text[i:j]
        if '"upper_effect"' in block:
            raise SystemExit("[FAIL] cards.json：id %d 已经有 upper_effect（补丁重复？）" % cid)
        if not block.rstrip().endswith('"image": ""'):
            raise SystemExit("[FAIL] cards.json：id %d 块尾不是 image（实际 %r）"
                             % (cid, block.rstrip().split("\r\n")[-1]))
        ins = ("%s\r\n      \"upper_effect\": %s,\r\n      \"lower_effect\": %s"
               % (",", json.dumps(up, ensure_ascii=False),
                  json.dumps(lo, ensure_ascii=False)))
        text = text[:j] + ins + text[j:]
    for cid_s, old, new in TEXT_FIX:
        cid = int(cid_s)
        i = text.index('"id": %d,' % cid)
        j = text.index("\r\n    }", i)
        block = text[i:j]
        if block.count(old) != 1:
            raise SystemExit("[FAIL] cards.json：%d 的原文锚点命中 %d 次"
                             % (cid, block.count(old)))
        text = text[:i] + block.replace(old, new, 1) + text[j:]
    return text


PATCHES = [
    # ── 产物只吃自己的 assemble 段，不吃被克隆过来的本体专属判定（R588 继承坑的局部缓解）──
    ("scripts/game_engine.gd",
     '''\tif not card.assemble.is_empty() and str(card.assemble.get("trigger", "")) == "active":
\t\treturn true
\treturn card.traits.has(BEAR_TRAIT)''',
     '''\t# ⚠️ 组合产物**只看 assemble**：属性槽是熊时 `build()` 会把「回春」trait 一起克隆过来
\t# （R588 记的那个继承坑），这里若放行 trait，产物会凭空多出一次主动发动。
\tif not card.assemble.is_empty():
\t\treturn str(card.assemble.get("trigger", "")) == "active"
\treturn card.traits.has(BEAR_TRAIT)''',
     "主动发动：产物只看 assemble"),

    ("scripts/game_engine.gd",
     '''\tif not p.card.assemble.is_empty() \\
\t\t\tand str(p.card.assemble.get("trigger", "")) == "lethal":
\t\t_assemble_execute(p, _cell_of(p), "lethal")
\t\treturn
\tif p.card.id != THESEUS_ID:
\t\treturn''',
     '''\tif not p.card.assemble.is_empty():
\t\t# 产物只吃自己的 assemble 段：属性槽是忒修斯时 id/traits 会被克隆（R588），
\t\t# 不让它凭空多送一张炮击。
\t\tif str(p.card.assemble.get("trigger", "")) == "lethal":
\t\t\t_assemble_execute(p, _cell_of(p), "lethal")
\t\treturn
\tif p.card.id != THESEUS_ID:
\t\treturn''',
     "lethal：产物只看 assemble"),
]


def main():
    ok = True
    files = {}
    for rel, old, new, note in PATCHES:
        if rel not in files:
            files[rel] = read(rel)
        cnt = files[rel].count(old)
        use_old, use_new = old, new
        if cnt == 0:
            crlf_old = old.replace("\n", "\r\n")
            if files[rel].count(crlf_old) == 1:
                use_old, use_new = crlf_old, new.replace("\n", "\r\n")
                cnt = 1
        if cnt != 1:
            print("[FAIL] %s：锚点命中 %d 次（要求 1）—— %s" % (rel, cnt, note))
            ok = False
            continue
        files[rel] = files[rel].replace(use_old, use_new, 1)
        print("[ok] %s：%s" % (rel, note))
    if not ok:
        print("\n有锚点没命中，未写任何文件。")
        return 1

    raw = files.get("cards.json") or read("cards.json")
    try:
        files["cards.json"] = patch_cards(raw)
        print("[ok] cards.json：八张卡写入 upper/lower + 两处原文对齐")
    except SystemExit as e:
        print(str(e))
        return 1

    if CHECK:
        print("\n--check-only：锚点全中，未写文件。")
        return 0
    for rel, text in files.items():
        write(rel, text)
        print("[write] %s" % rel)
    # 写完立刻复核：能解析、行尾没被洗、字段真的进去了
    d = json.loads(io.open(os.path.join(ROOT, "cards.json"), encoding="utf-8").read())
    by = {c["id"]: c for c in d["cards"]}
    for cid, up, lo in CARDS:
        got_u = by[cid].get("upper_effect")
        got_l = by[cid].get("lower_effect")
        assert got_u == up, (cid, got_u)
        assert got_l == lo, (cid, got_l)
    b = open(os.path.join(ROOT, "cards.json"), "rb").read()
    print("[check] json 解析通过；CRLF %d / bareLF %d" % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
