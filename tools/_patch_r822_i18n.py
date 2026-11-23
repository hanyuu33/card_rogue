# -*- coding: utf-8 -*-
"""R822：鸭绅士事件的文案（四语）+ 条目数 + 校验器写死条数。

口径（店长 2026-11-19 原话）：
    遇到森林精魄 「这次又给你添麻烦了。」→「很高兴能帮到大家。」
    遇到暗影刺客 「能帮我逮住那只该死的猫吗？走私，逃税，偷窃，简直无恶不作。」→「强吗，那家伙？」
    遇到机械之心 「别急着走，我还要很多合作想和你谈。」→「下次一定。」

做四件事：
  ① interface_zh_canonical.json：shell 加 7 条（名字 + 3 句招呼 + 3 句回答），
     expected_counts.shell 215 → 222；顺带把 CURTAIN_* 的 source 行号重算一遍
     （curtain_lines.gd 被重写过，行号漂了）。
  ② interface_en / ja / es：补齐 7 条。
  ③ validate_spanish.py：interface 总条数 828 → 835。
"""
import io
import json
import os
import re

ROOT = r"E:\work\card_rogue"
I18N = os.path.join(ROOT, "i18n")

# key -> (中文, en, ja, es)
NEW = {
    "CURTAIN_DUCK_SPEAKER": (
        "鸭绅士",
        "Duck Gentleman",
        "アヒル紳士",
        "Caballero Pato"),
    "CURTAIN_DUCK_GREETING_DRUID": (
        "这次又给你添麻烦了。",
        "Sorry to trouble you again.",
        "またお手を煩わせてしまって、すみません。",
        "Perdón por causarte problemas otra vez."),
    "CURTAIN_DUCK_GREETING_ROGUE": (
        "能帮我逮住那只该死的猫吗？走私，逃税，偷窃，简直无恶不作。",
        "Could you catch that blasted cat for me? Smuggling, tax evasion, theft, "
        "you name it, it does it.",
        "あの忌々しい猫を捕まえてくれませんか？密輸、脱税、窃盗、ろくでもないことばかりです。",
        "¿Podrías atrapar a ese maldito gato por mí? Contrabando, evasión de impuestos, "
        "robo... no hay bajeza que no cometa."),
    "CURTAIN_DUCK_GREETING_MECH": (
        "别急着走，我还要很多合作想和你谈。",
        "Don't rush off. I still have plenty of partnerships to discuss with you.",
        "お急ぎにならないで。まだまだ相談したいことがたくさんあるんですよ。",
        "No te vayas tan rápido. Todavía tengo muchas colaboraciones que hablar contigo."),
    "CURTAIN_DUCK_REPLY_DRUID": (
        "很高兴能帮到大家。",
        "Glad I could help everyone.",
        "みんなの役に立てて嬉しいです。",
        "Me alegra poder ayudar a todos."),
    "CURTAIN_DUCK_REPLY_ROGUE": (
        "强吗，那家伙？",
        "Is that one strong?",
        "強いんですか、そいつは？",
        "¿Y es fuerte, ese tal?"),
    "CURTAIN_DUCK_REPLY_MECH": (
        "下次一定。",
        "Next time, then.",
        "また今度、ですね。",
        "La próxima vez, entonces."),
}

# 行号重算：curtain_lines.gd 里出现过这些 key 的行
LINES_SRC = "scripts/curtain_lines.gd"
SCENE_SRC = "scripts/curtain_scene.gd"


def line_of(fname, key):
    path = os.path.join(ROOT, fname)
    with io.open(path, encoding="utf-8", newline="") as f:
        for i, ln in enumerate(f.read().split("\n"), 1):
            if ('"%s"' % key) in ln:
                return i
    return 0


def load(name):
    with io.open(os.path.join(I18N, name), encoding="utf-8", newline="") as f:
        return json.load(f)


def save(name, data):
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    with io.open(os.path.join(I18N, name), "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("WROTE", name, len(text.encode("utf-8")), "bytes")


zh = load("interface_zh_canonical.json")
shell = zh["scopes"]["shell"]

before = len(shell)
for key, (z, _en, _ja, _es) in NEW.items():
    line = line_of(LINES_SRC, key)
    assert line > 0, "源码里找不到 %s" % key
    assert key not in shell, "zh 表里已经存在 %s" % key
    shell[key] = {"source": "%s:%d" % (LINES_SRC, line), "zh": z}
print("shell", before, "->", len(shell))

# 重算已有的 CURTAIN_* 行号（文件被重写过）
fixed = 0
for key, entry in shell.items():
    if not key.startswith("CURTAIN_"):
        continue
    src = entry.get("source", "")
    if not src.startswith("scripts/curtain"):
        continue
    fname = src.split(":", 1)[0]
    line = line_of(fname, key)
    if line > 0 and entry["source"] != "%s:%d" % (fname, line):
        entry["source"] = "%s:%d" % (fname, line)
        fixed += 1
print("source 行号校正", fixed, "条")

zh["expected_counts"]["shell"] = len(shell)
save("interface_zh_canonical.json", zh)

for lang, idx in (("en", 1), ("ja", 2), ("es", 3)):
    data = load("interface_%s.json" % lang)
    rows = data["scopes"].setdefault("shell", {})
    for key, vals in NEW.items():
        if key in rows:
            raise SystemExit("%s 已存在 %s" % (lang, key))
        rows[key] = vals[idx]
    save("interface_%s.json" % lang, data)

# 西语校验器里的写死条数
p = os.path.join(I18N, "validate_spanish.py")
with io.open(p, encoding="utf-8", newline="") as f:
    s = f.read()
old = "check(len(interface_zh_rows) == 828, \"interface 共 828 条（R810 +新月耳饰状态注）\")"
new = ("check(len(interface_zh_rows) == 835,\n"
       "      \"interface 共 835 条（R822 +鸭绅士 7 条事件文案）\")")
assert s.count(old) == 1, "西语校验器里的 828 锚点没找到"
with io.open(p, "w", encoding="utf-8", newline="") as f:
    f.write(s.replace(old, new))
print("validate_spanish 828 -> 835")
