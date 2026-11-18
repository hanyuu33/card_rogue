# -*- coding: utf-8 -*-
## R801：爆炸蘑菇 7016 —— 数据层（traps.json + trap_data.gd）
import io, os, json

ROOT = "E:/work/card_rogue"
os.chdir(ROOT)


def read(p):
    with open(p, "rb") as f:
        return f.read().decode("utf-8")


def write(p, s):
    with open(p, "wb") as f:
        f.write(s.encode("utf-8"))


def eol(s):
    return "\r\n" if s.count("\r\n") > s.count("\n") - s.count("\r\n") else "\n"


# ---------- ① traps.json ----------
P = "traps.json"
d = read(P)
crlf = eol(d)
print("traps.json 行尾:", "CRLF" if crlf == "\r\n" else "LF")

old = ('    { "id": 7015, "name": "河豚", "price": 25, "damage": 3, "bounce": 1,' + crlf
       + '      "desc": "拖到战场空格上放置。敌人踩到时被弹回一格并受到 3 点伤害，用掉后从工具栏移除。", "icon": "tool_puffer" }' + crlf
       + '  ]')
new = ('    { "id": 7015, "name": "河豚", "price": 25, "damage": 3, "bounce": 1,' + crlf
       + '      "desc": "拖到战场空格上放置。敌人踩到时被弹回一格并受到 3 点伤害，用掉后从工具栏移除。", "icon": "tool_puffer" },' + crlf
       + '    { "id": 7016, "name": "爆炸蘑菇", "price": 30, "damage": 15, "blast": 1,' + crlf
       + '      "desc": "拖到战场空格上放置。敌人踩到时爆炸，对周围一格内的所有单位造成 15 点伤害（不分敌我），用掉后从工具栏移除。", "icon": "tool_mushroom" }' + crlf
       + '  ]')
assert d.count(old) == 1, "traps.json 锚点 %d" % d.count(old)
d = d.replace(old, new)
write(P, d)
json.loads(read(P))   # 立刻验 JSON 合法
print("traps.json ok，工具数 =",
      len(json.loads(read(P))["traps"]))

# ---------- ② trap_data.gd ----------
P = "scripts/trap_data.gd"
d = read(P)
crlf2 = eol(d)
print("trap_data.gd 行尾:", "CRLF" if crlf2 == "\r\n" else "LF")
N = crlf2

old = ('## R797：河豚 7015 —— 踩到的单位**回弹这么多格**（1 = 回到来时的格子）。' + N
       + '## 回弹方向不走 `_knockback`（那是「朝对方后排直推」）：河豚是「原地弹回」，' + N
       + '## 只有「没有来路」（效果直达 / 上一格已被占）时，才改朝**河豚所属方**的方向弹一格。' + N
       + 'var bounce := 0' + N)
new = old + (
    '## R801：爆炸蘑菇 7016 —— 爆炸半径（**曼哈顿距离**，1 = 正交四邻）。' + N
    + '## >0 = **范围伤害型**：`_trigger_trap()` **不走**单体那一笔 `_hit_unit(p, damage)`，' + N
    + '## 改由 `_blast_trap()` 对「距离 ≤ blast」的**所有单位**（不分敌我、含中心格自身）' + N
    + '## 各结算一次 `damage`。两条判据必须成对理解 —— 漏掉「跳过单体」就是踩上去吃两遍。' + N
    + '## 与 `bounce` / `fill_hand` 同一条思路：一个工具只说明自己「怎么生效」，判据全在数据里。' + N
    + 'var blast := 0' + N)
assert d.count(old) == 1, "trap_data 字段锚点 %d" % d.count(old)
d = d.replace(old, new)

old2 = '\tt.bounce = int(d.get("bounce", 0))' + N
new2 = old2 + '\tt.blast = int(d.get("blast", 0))' + N
assert d.count(old2) == 1, "trap_data from_dict 锚点 %d" % d.count(old2)
d = d.replace(old2, new2)
write(P, d)
print("trap_data.gd ok")

# ---------- 复核 ----------
for p in ("traps.json", "scripts/trap_data.gd"):
    b = open(p, "rb").read()
    print("%-24s CRLF %-5d LFonly %d" % (p, b.count(b"\r\n"),
                                         b.count(b"\n") - b.count(b"\r\n")))

t = json.loads(read("traps.json"))["traps"][-1]
print("新工具:", json.dumps(t, ensure_ascii=False))
