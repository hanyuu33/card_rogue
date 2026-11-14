# -*- coding: utf-8 -*-
"""R690 三语补丁：水元素 9068 效果文案（改为抓漩涡）。

用法：python tools/_patch_r690_i18n.py [--write]
"""
import json
import sys

WRITE = "--write" in sys.argv

OLD = {
    "ja": "自陣の効果カード1枚につき、このカードのコスト-1。使用時、山札から効果カード1枚を手札に加え、そのコストを2減らす。",
    "en": "This card's Cost is -1 for each Effect card on your side of the field. On Use: add an Effect card from your Draw Pile to your Hand; its Cost is reduced by 2.",
    "es": "El Coste de esta carta es -1 por cada carta de Efecto de tu lado del campo. Al usarla: añade una carta de Efecto de la pila de robo a la mano; su Coste se reduce en 2.",
}

NEW = {
    "ja": "自陣の効果カード1枚につき、このカードのコスト-1。使用時、「渦」1枚を手札に加える。",
    "en": 'This card\'s Cost is -1 for each Effect card on your side of the field. On Use: add a "Vortex" to your Hand.',
    "es": "El Coste de esta carta es -1 por cada carta de Efecto de tu lado del campo. Al usarla: añade un «Vórtice» a la mano.",
}


def esc(s):
    """JSON 文本里的转义形式（含双引号 → \\\"）。R688 踩过没转义的坑。"""
    return json.dumps(s, ensure_ascii=False)[1:-1]


for lang in ("ja", "en", "es"):
    path = "i18n/cards_%s.json" % lang
    raw = open(path, "rb").read().decode("utf-8")
    assert raw.count("\r\n") == 0, path + " 不是纯 LF"
    old = '"effect_text": "%s"' % esc(OLD[lang])
    new = '"effect_text": "%s"' % esc(NEW[lang])
    c = raw.count(old)
    assert c == 1, "[%s] 锚点命中 %d 次" % (lang, c)
    out = raw.replace(old, new)
    d = json.loads(out)                       # 整份 JSON 必须仍然合法
    assert d["cards"]["9068"]["effect_text"] == NEW[lang]
    print("  %s OK：%s" % (lang, NEW[lang][:60]))
    if WRITE:
        open(path, "wb").write(out.encode("utf-8"))

print("写入完成" if WRITE else "干跑通过（未写入）")
