# -*- coding: utf-8 -*-
"""R781：每日修饰五条文案改写（巧克力 ±3→±2、温暖→火堆选两项、阴冷→火堆变战斗、滞涩→抽卡−1）
四语同步 + zh_canonical 的 zh 底本；顺带刷新被改脚本的哈希（底本要对应同一版源码）。

en/ja/es 走 JSON round-trip；zh_canonical 是底本、格式不保形，按 key 定位做文本替换。
"""
import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# key -> (zh, en, ja, es)
DESCS = {
    "MODDESC_RATIONS": ("每层巧克力 +2", "Chocolate +2 per layer",
                        "階層ごとにチョコ +2", "Chocolate +2 por piso"),
    "MODDESC_WARM": ("火堆可以选两个选项", "Campfire: pick two options",
                     "焚き火で2つ選べる", "Hoguera: elige dos opciones"),
    "MODDESC_HUNGRY": ("每层巧克力 −2", "Chocolate −2 per layer",
                       "階層ごとにチョコ −2", "Chocolate −2 por piso"),
    "MODDESC_COLD": ("火堆全部变为战斗", "All campfires become battles",
                     "焚き火がすべて戦闘になる", "Todas las hogueras se vuelven combates"),
    "MODDESC_DRAINED": ("每回合抽卡 −1", "−1 card drawn per turn",
                        "毎ターンのドロー −1", "−1 carta robada por turno"),
}

# ---------- en / ja / es ----------
for path, col in (("i18n/interface_en.json", 1), ("i18n/interface_ja.json", 2),
                  ("i18n/interface_es.json", 3)):
    raw = open(path, encoding="utf-8").read()
    d = json.loads(raw)
    scope = d["scopes"]["daily"]
    changed = 0
    for key, vals in DESCS.items():
        if key not in scope:
            sys.exit("[R781] %s 缺 %s" % (path, key))
        new = vals[col]
        if scope[key] != new:
            scope[key] = new
            changed += 1
    out = json.dumps(d, ensure_ascii=False, indent=2)
    if not out.endswith("\n"):
        out += "\n"
    open(path, "w", encoding="utf-8", newline="\n").write(out)
    print("  %s 改 %d 条" % (path, changed))

# ---------- zh_canonical ----------
P = "i18n/interface_zh_canonical.json"
raw = open(P, encoding="utf-8").read()
for key, vals in DESCS.items():
    # 命中该 key 的整块（source + zh 各一行），只换 zh 的值
    pat = re.compile(
        r'("' + key + r'": \{\s*\n\s*"source": "[^"]*",\s*\n\s*"zh": )"(?:[^"\\]|\\.)*"(\s*\n\s*\})')
    hits = pat.findall(raw)
    if len(hits) != 1:
        sys.exit("[R781] zh_canonical 的 %s 命中 %d 处" % (key, len(hits)))
    raw = pat.sub(lambda m: m.group(1) + json.dumps(vals[0], ensure_ascii=False) + m.group(2), raw, count=1)

# 刷新被改脚本的哈希（底本 = 同一版源码）
for rel in ("scripts/run_state.gd", "scripts/event_scene.gd", "scripts/daily_modifiers.gd"):
    digest = hashlib.sha256(open(rel, "rb").read()).hexdigest()
    before = raw
    raw = re.sub(r'("' + re.escape(rel) + r'": ")[0-9a-f]{64}(")',
                 lambda m: m.group(1) + digest + m.group(2), raw)
    print("  hash %s -> %s (%s)" % (rel, digest[:12], "更新" if raw != before else "无该条目，跳过"))

open(P, "w", encoding="utf-8", newline="\n").write(raw)
json.loads(open(P, encoding="utf-8").read())
print("  zh_canonical JSON 合法")
