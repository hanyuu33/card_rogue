# -*- coding: utf-8 -*-
"""R167 批 I：.gitignore 显式声明 art_src 入库；并提交 art_src。"""
import io, os, subprocess

GIT = r"C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\1.2.0\cmd\git.exe"
CWD = r"D:\work\card_rogue"

gi = os.path.join(CWD, ".gitignore")
raw = io.open(gi, "rb").read()
eol = "\r\n" if b"\r\n" in raw else "\n"
t = raw.decode("utf-8")
NOTE = (
    "\n"
    "# 出图过程档案 art_src/ —— **有意入库**（含所有被弃用的候选图）。\n"
    "#   靠 art_src/.gdignore 让 Godot 忽略它（不导入、不进发布包）。\n"
    "#   ⚠️ 别把它写进任何忽略规则。\n"
)
if "art_src" not in t:
    t = t.rstrip("\r\n") + eol + NOTE.replace("\n", eol)
    io.open(gi, "wb").write(t.encode("utf-8"))
    print("OK   .gitignore 已声明 art_src")
else:
    print("SKIP .gitignore 已提到 art_src")

MSG = """R167b: 出图过程档案入库 —— 新增 art_src/（含全部被弃用的候选图）

用户口径（R167 新规则）：**AI 出图过程中产生的所有图片都要同步进 git**，
不只是最终采用的那几张。

- 新增 art_src/，把出图暂存区 D:\\work\\gen_raw 的 81 个文件（103 MB）整体归档：
  · 2026-10-10_地图图标与背景/（16）地图背景 + 宝箱/旗帜/桥/巧克力图标候选
  · 2026-10-12_卡框与森林背景/（2）
  · 2026-10-14_角色CG与头像/（33）R165b–R166c 三职业 CG/头像的**全部候选**（含 4 轮弃用版）
  · processed/（15）抠图裁切后的成品来源件
  · _review/（12）当时的验收拼图与放大图
  · tools/（3）当时的处理脚本
- art_src/README.md：写清规则、目录说明、以及 2026-10-14 每一轮的「采用 / 弃用 + 原因」。
- ⚠️ art_src/.gdignore 必须存在 —— 实测 `--import` 后 art_src 下 0 个 .import，
  Godot 完全不碰这个目录（不导入、不进 pck）。
- .gitignore 里显式声明 art_src 有意入库，别写进忽略规则。
"""

open(os.path.join(CWD, "_cm.txt"), "w", encoding="utf-8").write(MSG)


def run(*a):
    r = subprocess.run([GIT] + list(a), cwd=CWD, capture_output=True, text=True)
    print("$ git", " ".join(a), "-> rc", r.returncode)
    print((r.stdout or "").strip()[:600], (r.stderr or "").strip()[:300])
    return r


run("add", "-A")
run("commit", "-F", "_cm.txt")
os.remove(os.path.join(CWD, "_cm.txt"))
run("push", "origin", "main")
head = run("rev-parse", "HEAD").stdout.strip()
d = os.path.join(CWD, ".git", "refs", "remotes", "origin")
os.makedirs(d, exist_ok=True)
open(os.path.join(d, "main"), "w").write(head + "\n")
run("status", "-sb")
