# -*- coding: utf-8 -*-
## R801：爆炸蘑菇 7016 —— 引擎侧（_trigger_trap 分支 + _blast_trap）
import os

ROOT = "E:/work/card_rogue"
os.chdir(ROOT)

P = "scripts/game_engine.gd"
raw = open(P, "rb").read()
d = raw.decode("utf-8")
N = "\r\n"
assert d.count(N) > 0, "game_engine 应是 CRLF"

# ---------- ① _trigger_trap：blast>0 跳过单体那一笔 ----------
old = '\t_hit_unit(p, t.damage, "陷阱")' + N
new = ('\t# R801 爆炸蘑菇（7016）：`blast > 0` = **范围伤害型** —— 上面这笔单体伤害必须跳过，' + N
       + '\t# 否则踩上去的单位先吃一次、又落进下面的范围里再吃一次（15 → 30）。' + N
       + '\tif t.blast > 0:' + N
       + '\t\t_blast_trap(cell, t)' + N
       + '\telse:' + N
       + '\t\t_hit_unit(p, t.damage, "陷阱")' + N)
assert d.count(old) == 1, "_hit_unit 锚点 %d" % d.count(old)
d = d.replace(old, new)

# ---------- ② 新增 _blast_trap()，插在 _bounce_cell_ok 之前 ----------
anchor = N + N + 'func _bounce_cell_ok('
assert d.count(anchor) == 1, "_bounce_cell_ok 锚点 %d" % d.count(anchor)

BLOCK = '''
func _blast_trap(cell: Vector2i, t: TrapData) -> void:
\t## R801 爆炸蘑菇 7016 的**范围伤害唯一口**：以触发格为中心、曼哈顿距离 ≤ `t.blast`
\t## 的**所有单位**（不分敌我）各吃一次 `t.damage`。
\t##   * 「距离 1 = 正交四邻」直接走 `manhattan()`（与 `_slam_cells` / 射程同一个尺），
\t##     并且**含中心格自身** —— 踩上去的那位本来就在爆炸范围里，所以
\t##     `_trigger_trap()` 必须跳过单体那一笔，否则他吃两遍。
\t##   * 只收**场上单位**，不碰 HP 行：这是陷阱不是法术（与 `_blast()` 火球的区别 ——
\t##     那个会把半径内最近的 HP 空格也打一格，蘑菇不该越过单位直接掉血）。
\t##   * 格子**先排序**再结算：`state.board` 是 Dictionary，遍历顺序不保证，
\t##     不排序会让回放的伤害顺序漂（与炮火就位 9273 同一条纪律）。
\t##   * 不分敌我 → 己方单位也吃，减伤链照常走 `_hit_unit()`（龟壳 6078 / 能量屏障 /
\t##     护盾生成器都生效）。打死人不在这里收尾：`_trap_path_check()` 循环外统一
\t##     `_destroy_dead()`，和其余陷阱同一条路。
\tvar r:= maxi(0, t.blast)
\tif r <= 0:
\t\treturn
\tvar cells: Array[Vector2i] = []
\tfor c: Vector2i in state.board.keys():
\t\tif manhattan(c, cell) > r:
\t\t\tcontinue
\t\tif state.unit_at(c) == null:
\t\t\tcontinue
\t\tcells.append(c)
\tcells.sort()
\tvar hits:= 0
\tfor c: Vector2i in cells:
\t\tvar u: Placement = state.unit_at(c)
\t\tif u == null or u.health <= 0:
\t\t\tcontinue
\t\t_hit_unit(u, t.damage, "陷阱")
\t\thits += 1
\t_log("爆炸蘑菇：%s 爆炸，%d 个单位在范围内（不分敌我）" % [cell, hits])
'''
BLOCK = BLOCK.replace("\n", N)

d = d.replace(anchor, N + N + BLOCK.strip("\r\n") + N + N + "func _bounce_cell_ok(")

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
print("_blast_trap 定义:", d.count("func _blast_trap("))
print("调用点:", d.count("_blast_trap(cell, t)"))
print("残留 /r/n:", d.count("/r/n"))
