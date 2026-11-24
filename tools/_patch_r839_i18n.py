## R839：大蒜 7017 —— 三份译文（en / ja / es）
## traps.json 与 trap_data.gd 已由 _patch_r839_data.py 处理完，这里只补译文。
## 用法：python tools/_patch_r839_i18n.py
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"

TRANSLATIONS = {
    "en": {
        "name": "Garlic",
        "desc": "Drag it onto an empty battlefield cell to place it. That cell cannot be used for 3 of your turns — no unit can enter or pass through it; the tool is then used up.",
    },
    "ja": {
        "name": "ニンニク",
        "desc": "戦場の空きマスにドラッグして設置する。そのマスは自分の3ターンの間使用できず、どのユニットも進入も通過もできない。使用後は消費される。",
    },
    "es": {
        "name": "Ajo",
        "desc": "Arrástrala a una casilla vacía del campo de batalla para colocarla. Esa casilla no se puede usar durante 3 de tus turnos: ninguna unidad puede entrar ni pasar por ella; después, la herramienta se consume.",
    },
}


def read(p):
    with io.open(ROOT + p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(ROOT + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


for lang, row in TRANSLATIONS.items():
    path = "i18n/traps_%s.json" % lang
    d = read(path)
    crlf = "\r\n" in d
    norm = d.replace("\r\n", "\n")
    if '"7017"' in norm:
        print("skip %-24s（已有 7017）" % path)
        continue
    i = norm.find('\n  "7016": {')
    assert i >= 0, "%s 里找不到 7016 段" % path
    close = "\n  }"
    k = norm.find(close, i)
    assert k > i, "%s 里 7016 段没有闭合" % path
    end = k + len(close)          # 指向闭合 } 之后，正是插「,」的位置
    assert norm[end] in "\n,", "%s 插入点异常：%r" % (path, norm[end:end + 12])
    insert = (',\n  "7017": {\n'
              '   "name": %s,\n'
              '   "desc": %s\n'
              '  }') % (json.dumps(row["name"], ensure_ascii=False),
                       json.dumps(row["desc"], ensure_ascii=False))
    out = norm[:end] + insert + norm[end:]
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    parsed = json.loads(io.open(ROOT + path, encoding="utf-8").read())
    assert "7017" in parsed["traps"], "%s 写坏了（7017 不在表里）" % path
    print("ok  %-24s (+7017)" % path)

# 收尾：id 覆盖必须与 traps.json 完全一致（三条校验器里最硬的一条）
t = json.loads(read("traps.json"))
ids = {str(r["id"]) for r in t["traps"]}
assert len(t["traps"]) == 17, "工具数 %d（应为 17）" % len(t["traps"])
for lang in ("en", "ja", "es"):
    pack = json.loads(read("i18n/traps_%s.json" % lang))["traps"]
    assert set(pack) == ids, "%s id 覆盖不一致：缺 %s 多 %s" % (
        lang, sorted(ids - set(pack)), sorted(set(pack) - ids))
print("三份译文 id 覆盖 = traps.json（%d 件）" % len(ids))
