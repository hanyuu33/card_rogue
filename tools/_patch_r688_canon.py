# -*- coding: utf-8 -*-
"""R688：把 cards.json 的效果卡文案同步进 i18n/zh_canonical.json（原文不动格式，LF 保持）。"""
import json
import re

ROOT = "E:/work/card_rogue/"
CANON = ROOT + "i18n/zh_canonical.json"

cards = {c["id"]: c for c in json.load(open(ROOT + "cards.json", encoding="utf-8-sig"))["cards"]}
eff = [cid for cid, c in cards.items() if c.get("kind") == "效果"]

raw = open(CANON, "rb").read().decode("utf-8")
assert raw.count("\r\n") == 0, "canonical 不是 LF"


def blink(txt, cid):
    m = re.search(r'\n  "%d": \{' % cid, txt)
    if not m:
        return None
    start = txt.index("{", m.start())
    depth = 0
    i = start
    in_str = False
    esc = False
    while i < len(txt):
        ch = txt[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return start, i + 1
        i += 1
    return None


changed = 0
for cid in eff:
    span = blink(raw, cid)
    if span is None:
        raise SystemExit("canonical 缺卡 %d" % cid)
    a, b = span
    blk = raw[a:b]
    old = json.loads(blk)
    nm = cards[cid]["name"]
    tx = cards[cid]["effect_text"]
    if old.get("name") == nm and old.get("effect_text") == tx and "changed" not in old:
        continue
    blk2 = re.sub(r'("name": ")((?:[^"\\]|\\.)*)(")',
                  lambda m: m.group(1) + json.dumps(nm, ensure_ascii=False)[1:-1] + m.group(3), blk, count=1)
    blk2 = re.sub(r'("effect_text": ")((?:[^"\\]|\\.)*)(")',
                  lambda m: m.group(1) + json.dumps(tx, ensure_ascii=False)[1:-1] + m.group(3), blk2, count=1)
    flag = "true" if (old.get("name") != nm or old.get("effect_text") != tx) else "false"
    blk2 = re.sub(r'("changed": )(true|false)', r"\g<1>" + flag, blk2, count=1)
    raw = raw[:a] + blk2 + raw[b:]
    changed += 1

d = json.loads(raw)
print("canonical 解析 OK，卡数 %d，本次同步 %d 张效果卡" % (len(d["cards"]), changed))
print("CRLF %d / LF %d" % (raw.count("\r\n"), raw.count("\n")))
open(CANON, "wb").write(raw.encode("utf-8"))
print("已写入 zh_canonical.json")
