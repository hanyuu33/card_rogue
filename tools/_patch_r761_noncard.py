# -*- coding: utf-8 -*-
"""R761 补丁 11b：noncard 四份文件插入「诗」6069（这几份是手写紧凑格式，不做 JSON 重排）。

同时把 i18n/validate_noncard.py 的道具总数锁 62 → 63。
"""
import json
import sys

ZH_DESC = "每回合第一次使用其他职业的盟友时，回复 1 点费用。其他职业的盟友 +2 力量（持续生效，不叠加）。"
EN = ("Poem",
      "The first time each turn you use an Ally from another class: gain 1 Cost. "
      "Allies from other classes have +2 Power (persistent; does not stack).")
JA = ("詩",
      "毎ターン最初に他クラスの味方を使用したとき、コストを1得る。"
      "他クラスの味方の攻撃力+2（継続し、重複しない）。")
ES = ("Poema",
      "La primera vez cada turno que uses un Aliado de otra clase, ganas 1 de Coste. "
      "Los Aliados de otras clases tienen +2 de Poder (efecto persistente; no se acumula).")


def read(p):
    return open(p, encoding="utf-8").read()


def write(p, t):
    open(p, "w", encoding="utf-8", newline="\n").write(t)


def rep(path, old, new, tag):
    t = read(path)
    n = t.count(old)
    if n != 1:
        print("FAIL %s：%s 命中 %d 次" % (path, tag, n))
        sys.exit(1)
    write(path, t.replace(old, new, 1))
    print("  ok", tag)


# ① canonical（单行条目风格）
zh_anchor = ('    "6068": {"name": "工具箱", "desc": "立即获得一个随机工具。进入新的一层，再获得一个随机工具。"}')
t_zh = read("i18n/noncard_zh_canonical.json")
if '"6069"' in t_zh:
    print("  skip noncard_zh_canonical（已含 6069）")
else:
    old = '    "6068": {"name": "工具箱", "desc": "立即获得一个随机工具。每进入新的一层，再获得一个随机工具。"}\n'
    new = old.rstrip("\n") + ',\n    "6069": ' + json.dumps(
        {"name": "诗", "desc": ZH_DESC}, ensure_ascii=False) + "\n"
    rep("i18n/noncard_zh_canonical.json", old, new, "zh 6069")

# ② en / ja / es（多行条目风格，插在 6068 之后、classes 之前）
for path, (name, desc) in (("i18n/noncard_en.json", EN),
                           ("i18n/noncard_ja.json", JA),
                           ("i18n/noncard_es.json", ES)):
    t = read(path)
    if '"6069"' in t:
        print("  skip %s（已含 6069）" % path)
        continue
    old = '    }\n  },\n  "classes": {'
    new = ('    },\n'
           '    "6069": {\n'
           '      "name": ' + json.dumps(name, ensure_ascii=False) + ',\n'
           '      "desc": ' + json.dumps(desc, ensure_ascii=False) + '\n'
           '    }\n'
           '  },\n'
           '  "classes": {')
    rep(path, old, new, path.split("/")[-1] + " 6069")

# ③ 校验脚本的件数锁
rep("i18n/validate_noncard.py",
    'check(len(SOURCE) == 62 and len(expected_ids) == 62, "真源为 62 件不重复道具")',
    'check(len(SOURCE) == 63 and len(expected_ids) == 63, "真源为 63 件不重复道具")',
    "validate_noncard 63")
rep("i18n/validate_noncard.py",
    '"\\nNONCARD I18N OK: 62 relics + 3 classes',
    '"\\nNONCARD I18N OK: 63 relics + 3 classes',
    "validate_noncard 汇总文案")

# ④ 复核
for p in ("i18n/noncard_zh_canonical.json", "i18n/noncard_en.json",
          "i18n/noncard_ja.json", "i18n/noncard_es.json"):
    d = json.loads(read(p))
    assert "6069" in d["relics"] and len(d["relics"]) == 63, p
    print("  ok", p, len(d["relics"]))
print("noncard OK")
