# -*- coding: utf-8 -*-
"""R773 补：zh_canonical.json 用**文本插入**（键序是历史追加序，不能重排）。

cards_en / cards_ja 已验证可 json 重写（indent=1 roundtrip 字节一致），
zh_canonical 的键序既非字符串序也非 int 序 → 一律走文本插入，只加末尾一条。
"""
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = "i18n/zh_canonical.json"
raw = io.open(os.path.join(ROOT, P), "rb").read().decode("utf-8")

EFFECT = "费用本局 +1。将一张随机比这张卡费用高 1 的其他职业盟友加入手卡，其费用本局变为 0。"

anchor = (
    '  "9264": {\n'
    '   "name": "招募",\n'
    '   "effect_text": "从三个其他职业的盟友中选一张，加入手卡。",\n'
    '   "changed": false\n'
    '  }\n'
    ' }\n'
    '}'
)
assert raw.count(anchor) == 1, "锚点不唯一：%d" % raw.count(anchor)

new_tail = (
    '  "9264": {\n'
    '   "name": "招募",\n'
    '   "effect_text": "从三个其他职业的盟友中选一张，加入手卡。",\n'
    '   "changed": false\n'
    '  },\n'
    '  "9266": {\n'
    '   "name": "呼唤",\n'
    '   "effect_text": "%s",\n'
    '   "changed": false\n'
    '  }\n'
    ' }\n'
    '}' % EFFECT
)
raw = raw.replace(anchor, new_tail)
# updated 日期：只改这一处
old_upd = ' "updated": "2026-11-15",'
assert raw.count(old_upd) == 1
raw = raw.replace(old_upd, ' "updated": "2026-11-16",')
io.open(os.path.join(ROOT, P), "wb").write(raw.encode("utf-8"))

d = json.loads(io.open(os.path.join(ROOT, P), "rb").read().decode("utf-8"))
assert d["cards"]["9266"]["name"] == "呼唤"
assert d["cards"]["9266"]["effect_text"] == EFFECT
assert d["updated"] == "2026-11-16"
print("[ok] zh_canonical: %d 条，9266 追加在末尾（键序未重排）" % len(d["cards"]))
