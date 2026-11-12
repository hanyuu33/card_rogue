# -*- coding: utf-8 -*-
"""R595c：把 `assets/pics/_pending/` 的成品按「最新版」归档进正式库。

规则（店长 2026-11-12 指令「之前没有归档的素材也按新版归档」）：
  · 正式库没有该 id        → 直接复制过来（补空缺）
  · 正式库已有、pending 更新 → 覆盖（旧文件先备份到 _bk_pics_r595c/）
  · 正式库已有、正式库更新   → 跳过（正式库才是新版）
  · 两边同批（mtime 差值 < 60s）→ 跳过
  · 卡库里已无该 id 的孤儿   → 不搬，留在 _pending
不删任何文件；`.import` 交给 Godot 重新导入生成。
"""
import hashlib
import io
import json
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PICS = os.path.join(ROOT, "assets", "pics")
PEND = os.path.join(PICS, "_pending")
BAK = os.path.join(ROOT, "_bk_pics_r595c")

cards = json.load(io.open(os.path.join(ROOT, "cards.json"), encoding="utf-8"))
cards = cards["cards"] if isinstance(cards, dict) else cards
known = {c["id"] for c in cards}


def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 16), b""):
            h.update(b)
    return h.hexdigest()


added, replaced, skipped_new, skipped_same, orphans = [], [], [], [], []

for name in sorted(os.listdir(PEND)):
    if not name.endswith(".png"):
        continue
    stem = name[:-4]
    base = stem.split("_")[0]
    if base.isdigit() and int(base) not in known:
        orphans.append(name)
        continue
    src = os.path.join(PEND, name)
    dst = os.path.join(PICS, name)
    if not os.path.exists(dst):
        shutil.copy2(src, dst)
        added.append(name)
        continue
    ts, td = os.path.getmtime(src), os.path.getmtime(dst)
    if md5(src) == md5(dst):
        skipped_same.append(name)
        continue
    if ts > td + 60:
        os.makedirs(BAK, exist_ok=True)
        shutil.copy2(dst, os.path.join(BAK, name))
        shutil.copy2(src, dst)
        replaced.append((name, td, ts))
    else:
        skipped_new.append(name)

print("补空缺  %3d" % len(added))
print("覆盖    %3d  （旧文件备份到 _bk_pics_r595c/）" % len(replaced))
print("跳过·正式库更新 %3d" % len(skipped_new))
print("跳过·内容相同   %3d" % len(skipped_same))
print("孤儿不搬        %3d  %s" % (len(orphans), " ".join(orphans)))
print()
if replaced:
    import time
    print("── 被覆盖的（旧 → 新）──")
    for n, td, ts in replaced:
        print("  %-18s %s → %s" % (n, time.strftime("%m-%d %H:%M", time.localtime(td)),
                                  time.strftime("%m-%d %H:%M", time.localtime(ts))))
if skipped_new:
    print()
    print("── 保留正式库版本的 ──")
    print("  " + "  ".join(skipped_new))

# 清单落盘
out = {
    "added": added,
    "replaced": [n for n, _, _ in replaced],
    "skipped_official_newer": skipped_new,
    "skipped_identical": skipped_same,
    "orphans": orphans,
}
io.open(os.path.join(ROOT, "_preview", "r595c_archive.json"), "w",
        encoding="utf-8", newline="\n").write(
    json.dumps(out, ensure_ascii=False, indent=1))
print()
print("清单 → _preview/r595c_archive.json")
