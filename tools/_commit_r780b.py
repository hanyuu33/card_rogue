# -*- coding: utf-8 -*-
"""R780b 原子提交：**降级 → 拼干净版 → 写 index → add → commit → 校验** 全在一个进程里。

为什么必须一个进程：R780 / R780b 各踩一次 —— 并行线会在我 `git add` 之后、我在外面敲
`git commit` 之前，把**同一个 `battle_scene.gd`** 重新 `git add` 一次（他们的工作区版本，
含删除 `anthem` / `organ` 两条演出分支的 20 行）。于是 `git commit -- <paths>` 提交的是
**他们的版本**，我的提交里多出 20 行删除 = 把别人的既有功能删掉了。

中间不留任何空档之后，还要**逐字节复核**：`git show HEAD:<file>` 必须等于我拼出来的
干净版；不等就说明 index 又被换过。
"""
import io
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
MY = ["cards.json", "i18n/zh_canonical.json", "i18n/cards_en.json", "i18n/cards_ja.json",
      "i18n/cards_es.json", "scripts/card_face.gd", "scripts/card_info_boxes.gd",
      "scripts/game_engine.gd", "scripts/test_engine.gd", "scripts/battle_scene.gd"]


def run(*a, check=True):
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


print(run(sys.executable, ROOT + "tools/_mk_r780b_battle_clean.py").strip())

clean = io.open(ROOT + "tools/_tmp_r780b_battle_clean.gd", encoding="utf-8", newline="").read()
# 干净版必须仍然包含并行线**已在 HEAD 里**的既有功能（anthem / organ 两条演出分支），
# 否则说明干净版的基准取错了 —— 那样提交就等于删别人东西。
for keep in ('"anthem":', '"organ":'):
    if keep not in clean:
        sys.exit("干净版丢了 HEAD 里的既有功能 %s —— 基准取错，中止" % keep)

blob = run("git", "hash-object", "-w", "tools/_tmp_r780b_battle_clean.gd").strip()
if len(blob) != 40:
    sys.exit("blob 异常：%r" % blob)
run("git", "update-index", "--cacheinfo", "100644,%s,scripts/battle_scene.gd" % blob)
run("git", "add", *MY[:-1])

num = run("git", "diff", "--cached", "--numstat", "scripts/battle_scene.gd").strip()
heads = [ln for ln in run("git", "diff", "--cached", "-U0", "scripts/battle_scene.gd")
         .splitlines() if ln.startswith("@@")]
if len(heads) != 4:
    sys.exit("index 里 battle_scene 的 hunk 数不是 4（%d）" % len(heads))
print("staged battle_scene:", num)

run("git", "commit", "--quiet", "-F", "_commit_r780b.txt", "--", *MY)

# ---- 提交后逐字节复核 ----
head_scene = run("git", "show", "HEAD:scripts/battle_scene.gd")
if head_scene != clean:
    sys.exit("提交内容与干净版不一致（head %d / clean %d 字符）"
             % (len(head_scene), len(clean)))
for keep in ('"anthem":', '"organ":'):
    if keep not in head_scene:
        sys.exit("提交里丢了 %s" % keep)
for must in ("_draw_damage_cap_aura", '"damage_capped"', '"glyph": "immune"'):
    if must not in head_scene:
        sys.exit("提交里缺我的改动：%s" % must)

print(run("git", "show", "--numstat", "--oneline", "HEAD").strip())
print("COMMIT_OK")
