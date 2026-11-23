# -*- coding: utf-8 -*-
"""R793 patch 6 —— 术语表补条目（道具名 / 事件名）+ 修 validate_noncard 的写死件数。

`validate_noncard.py` 原本把「64 件道具」写死，任何新增道具都会让它当场红。
这里的真意是「ID 不重复 / 与真源一一对应」，所以改成按真源长度比，不再钉死数字。
"""
import io, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


def patch(path, pairs):
    p = ROOT.rstrip("/") + "/" + path
    raw = io.open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            o = old.replace("\n", "\r\n")
            n = new.replace("\n", "\r\n")
        else:
            o, n = old, new
        c = txt.count(o)
        assert c == 1, "%s: count=%d for %r" % (path, c, old[:70])
        txt = txt.replace(o, n)
    io.open(p, "wb").write(txt.encode("utf-8"))
    print("OK %-36s %d -> %d  (%s)" % (path, len(raw), len(txt.encode("utf-8")),
                                       "CRLF" if crlf else "LF"))


# ------------------------------------------------------------ glossary.json
OLD_ANCHOR = ('    "猴爪": {\n'
              '      "en": "Monkey\'s Paw",\n'
              '      "ja": "猿の手",\n'
              '      "id": 6066\n'
              '    }\n')
NEW_TAIL = ('    "板甲": {\n'
            '      "en": "Plate Armor",\n'
            '      "ja": "板金鎧",\n'
            '      "id": 6070\n'
            '    },\n'
            '    "兵": {\n'
            '      "en": "Pawn",\n'
            '      "ja": "ポーン",\n'
            '      "id": 6071\n'
            '    },\n'
            '    "墙砖": {\n'
            '      "en": "Wall Brick",\n'
            '      "ja": "壁のレンガ",\n'
            '      "id": 6072\n'
            '    },\n'
            '    "大师之剑": {\n'
            '      "en": "Master Sword",\n'
            '      "ja": "マスターソード",\n'
            '      "id": 6073,\n'
            '      "note": "《塞尔达传说》专名"\n'
            '    }\n')

EVENT_ANCHOR = ('    "鸭鸭低语": {\n'
                '      "en": "Duck Whispers",\n'
                '      "ja": "アヒルのささやき",\n'
                '      "key": "whisper"\n'
                '    },\n')
EVENT_NEW = EVENT_ANCHOR + ('    "林中的剑": {\n'
                            '      "en": "Sword in the Woods",\n'
                            '      "ja": "森の剣",\n'
                            '      "key": "sword",\n'
                            '      "note": "拔剑的亚瑟王 / 大师之剑意象"\n'
                            '    },\n')

patch("i18n/glossary.json", [(OLD_ANCHOR, OLD_ANCHOR.rstrip("\n") + ",\n" + NEW_TAIL), (EVENT_ANCHOR, EVENT_NEW)])

# ------------------------------------------------------------ validate_noncard.py
patch("i18n/validate_noncard.py", [
    ('check(len(SOURCE) == 64 and len(expected_ids) == 64, "真源为 64 件不重复道具")',
     'check(len(SOURCE) >= 64 and len(SOURCE) == len(expected_ids),\n'
     '      "真源道具 ID 不重复（共 %d 件）" % len(SOURCE))'),
    ('print("\\nNONCARD I18N OK: 64 relics + 3 classes | 12 instant markers | numeric/term locks passed")',
     'print("\\nNONCARD I18N OK: %d relics + 3 classes | 12 instant markers | numeric/term locks passed" % len(SOURCE))'),
])

print("patch 6 done")
