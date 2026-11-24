# -*- coding: utf-8 -*-
"""R780b 提交：`battle_scene.gd` 只带走**我的 4 个 hunk**。

工作区那份 `battle_scene.gd` 里同时有并行线的 `--handbonus`（`_ready` 参数、手牌加成
绘制等，约 70 行）。用 `git add` 会把他们的半成品一起提交 → 构建断裂（R780 踩过）。

做法（确定性，不依赖 `git apply` 的行号推断）：
1. 用 `_mk_r780b_battle_clean.py` 从 **HEAD + 我的改动** 重新拼一份干净文件；
2. `git hash-object -w` 把它写成 blob；
3. `git update-index --cacheinfo` 直接把 index 里那一格指过去 —— 工作区文件不动，
   并行线的改动原样留在工作区；
4. 复核 index：只应有 4 个 hunk、不含 `handbonus`、含 `_draw_damage_cap_aura`。
"""
import io
import subprocess
import sys

ROOT = "E:/work/card_rogue/"


def run(*a, check=True):
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


# 1) 干净版
print(run(sys.executable, ROOT + "tools/_mk_r780b_battle_clean.py").strip())

# 2) blob
blob = run("git", "hash-object", "-w", "tools/_tmp_r780b_battle_clean.gd").strip()
if len(blob) != 40:
    sys.exit("blob 异常：%r" % blob)

# 3) 写进 index
run("git", "update-index", "--cacheinfo", "100644,%s,scripts/battle_scene.gd" % blob)

# 4) 复核 index
stat = run("git", "diff", "--cached", "--numstat", "scripts/battle_scene.gd").strip()
heads = [ln for ln in run("git", "diff", "--cached", "-U0",
                          "scripts/battle_scene.gd").splitlines() if ln.startswith("@@")]
staged = run("git", "show", ":scripts/battle_scene.gd")
print("staged numstat:", stat)
print("staged hunks  :", len(heads))
for h in heads:
    print("   ", h)

if len(heads) != 4:
    sys.exit("index 里的 hunk 数不是 4（%d）—— 并行线内容混进来了" % len(heads))
# ⚠️ 不能用 `handbonus` 当判据：它**已经在 HEAD 里**（R782 之前就合入），
#    真正的判据是「index 的内容 == 从 HEAD 重新拼出来的干净版」，逐字节比。
clean_text = io.open(ROOT + "tools/_tmp_r780b_battle_clean.gd",
                     encoding="utf-8", newline="").read()
if staged != clean_text:
    sys.exit("index 内容与干净版不一致（staged %d 字符 / clean %d 字符）"
             % (len(staged), len(clean_text)))
for must in ("_draw_damage_cap_aura", '"damage_capped"', '{"glyph": "immune"'):
    if must not in staged:
        sys.exit("index 里缺我的改动：%s" % must)
print("STAGE_SCENE_OK")
