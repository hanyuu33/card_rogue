# -*- coding: utf-8 -*-
"""R764 -> R765 改号：目录、脚本、文档里的轮次号全部对齐。

背景：开工时扫号只看了 `git status` 的路径，没看文件**内容** ——
并行线已在工作区里把 R764 写进 `sfx.gd` / `settings_scene.gd` / `test_engine.gd`
（「音效硬闸」那个功能），于是本线让号到 R765。
"""
import os
import pathlib

ROOT = pathlib.Path(r"E:\work\card_rogue")
ART = ROOT / "art_src"
OLD_NAME = "2026-11-16_巧克力图标_R764"
NEW_NAME = "2026-11-16_巧克力图标_R765"

src = ART / OLD_NAME
dst = ART / NEW_NAME
if src.exists() and not dst.exists():
    src.rename(dst)
    print("renamed dir ->", dst.name)
elif dst.exists():
    print("dir already:", dst.name)
else:
    raise SystemExit("目录不存在：%s" % src)

hits = 0
for p in sorted(dst.rglob("*")):
    if not p.is_file():
        continue
    if p.suffix.lower() not in (".py", ".md", ".txt", ".html"):
        continue
    raw = p.read_text(encoding="utf-8")
    new = raw.replace("R764", "R765").replace("r764", "r765")
    if new != raw:
        p.write_text(new, encoding="utf-8", newline="\n")
        hits += 1
        print("patched", p.relative_to(ROOT))

old_html = dst / "_review" / "r764_choco.html"
if old_html.exists():
    old_html.unlink()
    print("removed stale", old_html.name)

print("files patched:", hits)

# 复核：目录内不应再残留 R764
left = []
for p in sorted(dst.rglob("*")):
    if p.is_file() and p.suffix.lower() in (".py", ".md", ".txt", ".html"):
        if "R764" in p.read_text(encoding="utf-8") or "r764" in p.read_text(encoding="utf-8"):
            left.append(str(p.relative_to(ROOT)))
print("residual R764:", left or "none")
