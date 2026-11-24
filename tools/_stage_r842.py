# -*- coding: utf-8 -*-
"""R842 提交准备：从工作区版本里剥掉**并行线 R841（锤子 7018 / 润滑油 7019）**的改动，
只留 R842 自己的增量，产出两份「干净副本」供 `git hash-object` + `update-index --cacheinfo`。

为什么不能直接 `git add`：`test_engine.gd` 与 `demo_scope.json` 里同时躺着并行线的 WIP，
整文件提交会让 HEAD 出现「断言要 18 件工具、数据只有 17 件」的自相矛盾。
工作区保持不动（并行线还要用），只把干净 blob 塞进索引。

⚠️ `test_engine.gd` 是「每行之间夹一个空行」的排版（`\\r\\n\\r\\n`），跨行锚点很容易写错 ——
这里一律只替换**单行内的子串**，不碰换行。
"""
import io
import json

# ── ① test_engine.gd ──
SRC = "scripts/test_engine.gd"
DST = "E:/tmp/te_clean.gd"
txt = io.open(SRC, encoding="utf-8", newline="").read()
before_len = len(txt)


def rep(old, new, tag):
    global txt
    n = txt.count(old)
    assert n == 1, "%s 锚点 %d" % (tag, n)
    txt = txt.replace(old, new)
    print("OK %s" % tag)


# R745：random_traps() 17 → 15（连文案一起退回）
rep("random_traps().size() == 17", "random_traps().size() == 15", "R745 断言")
rep("R745 工具池：可随机 17 件（烤肉 7007 被 rest_only、石头 7012 被 no_drop 排除；"
    "R841 +锤子 7018 / +润滑油 7019）",
    "R745 工具池：可随机 14 件（烤肉 7007 仍被 rest_only 排除；"
    "R797 +河豚 7015 / R801 +爆炸蘑菇 7016）", "R745 文案")

# R817：demo 工具 18 → 16
rep('baseline_count("traps") == 18', 'baseline_count("traps") == 16', "R817 断言")
rep("R817 基线：工具 = 18 件（R841 锤子 7018 / 润滑油 7019 进试玩，实际 %d）",
    "R817 基线：工具 = 16 件（实际 %d）", "R817 文案")

for bad in ("7018", "7019", "R841 +锤子", "R841 锤子"):
    assert bad not in txt, "残留并行线：%s" % bad
for mine in ("_test_r842", "R842 附魔：brawn", "dragon_slab", "稀有价值",
             "R842 稀有价值：删哪几张跟着种子走", "seed_of"):
    assert mine in txt, "丢了 R842 标识：%s" % mine

io.open(DST, "w", encoding="utf-8", newline="").write(txt)
b = io.open(DST, "rb").read()
print("te_clean  CRLF=%d lone-LF=%d bytes=%d（原 %d）"
      % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n"), len(b), before_len))

# ── ② demo_scope.json：摘掉 traps 末尾的 7018 / 7019 ──
P2 = "demo_scope.json"
D2 = "E:/tmp/demo_scope_clean.json"
t2 = io.open(P2, encoding="utf-8", newline="").read()
l2 = t2.splitlines(keepends=True)
hit = [i for i, L in enumerate(l2) if L.strip() == "7018,"]
assert len(hit) == 1, "7018 命中 %d 行" % len(hit)
i = hit[0]
assert l2[i + 1].strip() == "7019", repr(l2[i + 1])   # 末元素没有逗号
assert l2[i - 1].strip() == "7016,", repr(l2[i - 1])
l2[i - 1] = l2[i - 1].replace("7016,", "7016")
del l2[i:i + 2]
t2 = "".join(l2)
d = json.loads(t2)
assert "dragon_slab" in d["events"] and 6090 in d["relics"]
assert d["traps"][-1] == 7016, d["traps"][-3:]
assert 7018 not in d["traps"] and 7019 not in d["traps"]
print("demo_scope traps 尾部 =", d["traps"][-3:], " count =", len(d["traps"]))
print("demo_scope events =", len(d["events"]), " relics =", len(d["relics"]))
io.open(D2, "w", encoding="utf-8", newline="").write(t2)
print("WROTE", DST, "and", D2)
