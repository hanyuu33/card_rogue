# -*- coding: utf-8 -*-
"""R794 修补 2：zh_canonical 底本 / glossary 事件名 / gd 字面量 / 校验计数 / 换行对齐。"""
import json


def jesc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


# --- 1. zh_canonical.json +9271 ---
p = "i18n/zh_canonical.json"
t = open(p, encoding="utf-8").read()
if '"9271"' not in t:
    anchor = ('  "9247": {\n'
              '   "name": "拼装工厂",\n'
              '   "effect_text": "回合开始时，组合一张卡。",\n'
              '   "changed": false\n'
              '  },')
    assert t.count(anchor) == 1
    entry = ('\n  "9271": {\n'
             '   "name": "巧克力工厂",\n'
             '   "effect_text": "回合开始时，获得 1 费用并抽一张卡。",\n'
             '   "changed": false\n'
             '  },')
    t = t.replace(anchor, anchor + entry)
    open(p, "wb").write(t.encode("utf-8"))
    print("ok zh_canonical +9271")
else:
    print("skip zh_canonical")

# --- 2. glossary.json events +巧克力工厂 ---
p = "i18n/glossary.json"
t = open(p, encoding="utf-8").read()
if '"巧克力工厂"' not in t:
    anchor = '    "林中的剑": {'
    i = t.find(anchor)
    assert i >= 0
    depth = 0
    j = i
    while True:
        c = t[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    tail = t[j + 1:]
    assert tail.startswith(",")
    entry = ('\n    "巧克力工厂": {\n'
             '      "en": "Chocolate Factory",\n'
             '      "ja": "チョコレート工場",\n'
             '      "key": "factory"\n'
             '    },')
    t = t[:j + 1] + entry + tail
    open(p, "wb").write(t.encode("utf-8"))
    print("ok glossary +巧克力工厂")
else:
    print("skip glossary")
json.load(open(p, encoding="utf-8"))

# --- 3. event_scene.gd：第④档结果改为字面卡名（与 event_ui key 对齐） ---
p = "scripts/event_scene.gd"
t = open(p, encoding="utf-8").read()
old = ('			RunState.add_card(FACTORY_CARD_ID)\n'
       '			var factory_card := CardRepo.load_json().get_card(FACTORY_CARD_ID)\n'
       '			_factory_result = "失去 %d 点最大生命（现 %d / %d）——「%s」已加入卡组" % [\n'
       '					factory_paid, RunState.hp, RunState.max_hp,\n'
       '					factory_card.card_name if factory_card != null else "巧克力工厂"]')
new = ('			RunState.add_card(FACTORY_CARD_ID)\n'
       '			_factory_result = "失去 %d 点最大生命（现 %d / %d）——「巧克力工厂」已加入卡组" % [\n'
       '					factory_paid, RunState.hp, RunState.max_hp]')
if t.count(old) == 1:
    t = t.replace(old, new)
    open(p, "wb").write(t.encode("utf-8"))
    print("ok event_scene 字面卡名")
else:
    print("skip event_scene（count=%d）" % t.count(old))

# --- 4. validate_event_ui.py 计数 91→97 / 68→71 ---
p = "i18n/validate_event_ui.py"
t = open(p, encoding="utf-8").read()
old = ('# R793：林中的剑 +4 选项（拔剑 / 上限不足 / 已持有 / 离开）、+1 结果。\n'
       'EXPECTED_COUNTS = {"options": 91, "results": 68, "pickers": 5, "rest_dynamic": 3}')
new = ('# R793：林中的剑 +4 选项（拔剑 / 上限不足 / 已持有 / 离开）、+1 结果。\n'
       '# R794：巧克力工厂 +6 选项（四档试吃 / 上限不足 / 离开）、+3 结果（免费 / 换血 / 得卡）。\n'
       'EXPECTED_COUNTS = {"options": 97, "results": 71, "pickers": 5, "rest_dynamic": 3}')
if t.count(old) == 1:
    t = t.replace(old, new)
    open(p, "wb").write(t.encode("utf-8"))
    print("ok validate_event_ui 计数")
else:
    print("skip validate_event_ui（count=%d）" % t.count(old))

# --- 5. narrative en/ja/es DESC 换行数对齐 zh（4 行） ---
FIX = {
    "en": (
        "A sweet smell drifts from deep in the woods. The copper door stands ajar; inside, a conveyor carries a row of duck-shaped chocolate molds past, and a warm river of chocolate flows by your feet.\nA little blackboard on the counter reads: \"Free tasting—the first piece is on the house. Every piece after that costs something.\"\nAnd in the corner, one smaller line: the guest willing to pay the most may take the whole factory home.",
        "A sweet smell drifts from deep in the woods. The copper door stands ajar; inside, a conveyor carries a row of duck-shaped chocolate molds past,\nand a warm river of chocolate flows by your feet.\nA little blackboard on the counter reads: \"Free tasting—the first piece is on the house. Every piece after that costs something.\"\nAnd in the corner, one smaller line: the guest willing to pay the most may take the whole factory home.",
    ),
    "ja": (
        "森の奥から甘い匂いが漂ってくる。銅の扉は半開きで、中ではベルトコンベアがアヒル型のチョコレートの型を一列に運んでいる。足元には温かいチョコレートの川がゆっくり流れている。\nカウンターには小さな黒板が立っている：「試食はひとつめ無料——この先はひとつごとに何かと引き換えだ。」\n黒板の隅にはさらに小さな文字：いちばん惜しまず払う客は、工場ごと持ち帰ってよい。",
        "森の奥から甘い匂いが漂ってくる。銅の扉は半開きで、中ではベルトコンベアが\nアヒル型のチョコレートの型を一列に運んでいる。足元には温かいチョコレートの川がゆっくり流れている。\nカウンターには小さな黒板が立っている：「試食はひとつめ無料——この先はひとつごとに何かと引き換えだ。」\n黒板の隅にはさらに小さな文字：いちばん惜しまず払う客は、工場ごと持ち帰ってよい。",
    ),
    "es": (
        "Un dulce aroma flota desde el fondo del bosque. La puerta de cobre está entreabierta; dentro, una cinta transportadora lleva una fila de moldes de chocolate con forma de pato, y un río tibio de chocolate fluye junto a tus pies.\nEn el mostrador hay una pequeña pizarra: «Degustación gratis: la primera pieza va por nuestra cuenta. Cada pieza después se paga con algo.»\nY en una esquina, una letra más pequeña: el cliente que más esté dispuesto a pagar puede llevarse la fábrica entera.",
        "Un dulce aroma flota desde el fondo del bosque. La puerta de cobre está entreabierta; dentro, una cinta transportadora lleva una fila de moldes de chocolate con forma de pato,\ny un río tibio de chocolate fluye junto a tus pies.\nEn el mostrador hay una pequeña pizarra: «Degustación gratis: la primera pieza va por nuestra cuenta. Cada pieza después se paga con algo.»\nY en una esquina, una letra más pequeña: el cliente que más esté dispuesto a pagar puede llevarse la fábrica entera.",
    ),
}
for code, (old_v, new_v) in FIX.items():
    p = "i18n/narrative_%s.json" % code
    t = open(p, encoding="utf-8").read()
    o = jesc(old_v)
    n = jesc(new_v)
    if t.count(o) == 1:
        t = t.replace(o, n)
        open(p, "wb").write(t.encode("utf-8"))
        print("ok narrative_%s DESC 4 行" % code)
    elif t.count(n) == 1:
        print("skip narrative_%s（已对齐）" % code)
    else:
        raise AssertionError((p, t.count(o), t.count(n)))
    json.load(open(p, encoding="utf-8"))

print("DONE")
