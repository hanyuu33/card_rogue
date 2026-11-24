# -*- coding: utf-8 -*-
"""R780b 续跑：只补 9188 的四语卡面文本（上一支脚本在 i18n 循环前崩了）。"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"
T = {
    "zh_canonical": "每回合最多受到 20 点伤害。",
    "cards_en": "Takes at most 20 damage each turn.",
    "cards_ja": "1ターンに受けるダメージは最大20。",
    "cards_es": "No puede recibir más de 20 de daño por turno.",
}

fails = []
for lang, txt in T.items():
    p = ROOT + "i18n/%s.json" % lang
    s = io.open(p, encoding="utf-8", newline="").read()
    idx = s.find('"9188"')
    assert idx > 0, "%s 找不到 9188" % lang
    nxt = s.find('"9189"', idx)
    end = nxt if nxt > idx else idx + 400
    seg = s[idx:end]
    if seg.count('"effect_text": ""') != 1:
        fails.append("%s 段内空串计数 %d" % (lang, seg.count('"effect_text": ""')))
        continue
    s = s[:idx] + seg.replace('"effect_text": ""', '"effect_text": "%s"' % txt, 1) + s[end:]
    io.open(p, "w", encoding="utf-8", newline="").write(s)

for lang, txt in T.items():
    pool = json.load(io.open(ROOT + "i18n/%s.json" % lang, encoding="utf-8"))
    pool = pool.get("cards", pool)
    got = pool["9188"]["effect_text"]
    if got != txt:
        fails.append("回读 %s = %r" % (lang, got))
    if pool["9140"]["effect_text"] != "每过3回合，行动次数+1。每回合最多受到 20 点伤害。":
        fails.append("回读 %s 9140 被动了：%r" % (lang, pool["9140"]["effect_text"]))

if fails:
    print("\n".join(fails))
    sys.exit("i18n 未全部命中")
print("I18N_OK")
