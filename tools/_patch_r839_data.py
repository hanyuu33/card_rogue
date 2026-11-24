## R839：大蒜 7017 —— 数据层（traps.json + trap_data.gd + 三份译文）
## 用法：python tools/_patch_r839_data.py
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"


def read(p):
    with io.open(ROOT + p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(ROOT + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def rep(path, old, new, tag):
    d = read(path)
    crlf = "\r\n" in d
    # 统一成 LF 做替换，再按原样回写（文件本身单一区制，不会引入混行）
    norm = d.replace("\r\n", "\n")
    o = old.replace("\r\n", "\n")
    n = new.replace("\r\n", "\n")
    cnt = norm.count(o)
    assert cnt == 1, "%s 锚点命中 %d 次（要求 1）" % (tag, cnt)
    out = norm.replace(o, n)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    print("ok  %-28s (%s)" % (tag, "CRLF" if crlf else "LF"))


# ---------- ① traps.json ----------
OLD_TAIL = '''      "desc": "拖到战场空格上放置。敌人踩到时爆炸，对周围一格内的所有单位造成 15 点伤害（不分敌我），用掉后从工具栏移除。", "icon": "tool_mushroom" }
  ]'''
NEW_TAIL = '''      "desc": "拖到战场空格上放置。敌人踩到时爆炸，对周围一格内的所有单位造成 15 点伤害（不分敌我），用掉后从工具栏移除。", "icon": "tool_mushroom" },
    { "id": 7017, "name": "大蒜", "price": 20, "block_turns": 3,
      "desc": "拖到战场空格上放置。该格在 3 个我方回合内不可使用：任何单位都无法进入或经过，用掉后从工具栏移除。", "icon": "tool_garlic" }
  ]'''
rep("traps.json", OLD_TAIL, NEW_TAIL, "traps.json (+7017)")

# ---------- ② trap_data.gd ----------
OLD_FIELD = '''## R754：「不受随机获得影响」—— 石头只从事件「奇异雕像」的摧毁选项拿，'''
NEW_FIELD = '''## R839：大蒜 7017 —— 放置后该格 **连续 N 个我方回合不可使用**
## （任何单位不能进入 / 经过，也不能往上放陷阱 / 场地 / 单位）。
## >0 = **封锁型**：`place_trap()` 写进 `FieldState.sealed_cells`，**刻意不进 `trap_fields`** ——
## 那张表的语义是「踩上去触发」，而封锁格根本踩不进去；混进去会让 `trap_legal_cells()`
## 把它当成一件已布置的陷阱（同格不许再放），`_trigger_trap()` 又永远等不到人踩。
## 与 `bounce` / `blast` / `fill_hand` 同一条思路：一个工具只说明自己「怎么生效」。
var block_turns := 0
## R754：「不受随机获得影响」—— 石头只从事件「奇异雕像」的摧毁选项拿，'''
rep("scripts/trap_data.gd", OLD_FIELD, NEW_FIELD, "trap_data.gd (field)")

OLD_FROM = '''	t.direct_damage = int(d.get("direct_damage", 0))'''
NEW_FROM = '''	t.direct_damage = int(d.get("direct_damage", 0))
	t.block_turns = int(d.get("block_turns", 0))'''
rep("scripts/trap_data.gd", OLD_FROM, NEW_FROM, "trap_data.gd (from_dict)")

# ---------- ③ 三份译文（按 id 追加，保持原有缩进 1 空格风格）----------
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

for lang, row in TRANSLATIONS.items():
    path = "i18n/traps_%s.json" % lang
    d = read(path)
    crlf = "\r\n" in d
    norm = d.replace("\r\n", "\n")
    # 找到 7016 那一段的结尾：下一个 " }," 之后的换行 + " }" 收尾。
    key = '\n  "7016": {'
    i = norm.find(key)
    assert i >= 0, "%s 里找不到 7016 段" % path
    # 7016 段落结束位置 = 从 i 起第一个 "\n  }"（该段落的闭合括号，缩进 2 空格）
    j = norm.find('\n  }', i)
    assert j > i, "%s 里 7016 段没有闭合" % path
    insert = (',\n  "7017": {\n'
              '   "name": %s,\n'
              '   "desc": %s\n'
              '  }') % (json.dumps(row["name"], ensure_ascii=False),
                       json.dumps(row["desc"], ensure_ascii=False))
    out = norm[:j] + insert + norm[j:]
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    # 立刻回读校验：JSON 合法 + id 覆盖包含 7017
    parsed = json.loads(io.open(ROOT + path, encoding="utf-8").read())
    assert "7017" in parsed["traps"], "%s 写坏了（7017 不在表里）" % path
    print("ok  %-28s (+7017)" % path)

# ---------- ④ 收尾自检 ----------
t = json.loads(read("traps.json"))
rows = {r["id"]: r for r in t["traps"]}
assert len(t["traps"]) == 17, "工具数 %d（应为 17）" % len(t["traps"])
g = rows[7017]
assert g["name"] == "大蒜" and g["price"] == 20 and g["block_turns"] == 3
print("traps.json：%d 件，7017 大蒜 20 金 / 封 3 回合" % len(t["traps"]))
for lang in ("en", "ja", "es"):
    pack = json.loads(read("i18n/traps_%s.json" % lang))["traps"]
    assert set(pack) == {str(r["id"]) for r in t["traps"]}, "%s id 覆盖不一致" % lang
print("三份译文 id 覆盖 = traps.json")
