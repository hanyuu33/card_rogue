# -*- coding: utf-8 -*-
"""
按卡号挑选每卡最新版素材，复制到 art_src/_latest/<id>.png（不动游戏现役卡图）。

口径（R878 起，用户指定）：
  同名卡素材合并时，**以文件生成时间（源文件 mtime）更新的为准**。
  不再看版本号、不再看《卡图风格修复交付索引》的采用列、不再设特例。

  1) 候选 = 《新图追溯索引.md》全量追溯表中该卡号的所有「卡图」素材
            ∪ 当前 README 里已选中的那一张（兜底，防止索引未登记时倒退）；
  2) 取候选里 mtime 最大的一张；
  3) mtime 相同则保留当前选取（同一张图被复制到不同归档目录的情形）；
     仍并列时按路径字典序取稳定值，保证幂等。

用法：python art_src/_build_latest.py
产出：art_src/_latest/<id>.png + art_src/_latest/README.md（可重复跑，幂等）
"""
import os
import re
import shutil
import hashlib
import datetime
from collections import defaultdict

ART = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(ART)
OUT = os.path.join(ART, "_latest")
TRACE = os.path.join(ART, "新图追溯索引.md")
README = os.path.join(OUT, "README.md")


def norm(rel):
    return rel.replace("\\", "/").lstrip("./")


def abs_from(rel):
    """索引路径可能相对仓库根（art_src/...）或相对 art_src（批次目录/...）。"""
    rp = norm(rel).replace("/", os.sep)
    if norm(rel).startswith("art_src/"):
        return os.path.join(REPO, rp)
    return os.path.join(ART, rp)


def fmt(t):
    return datetime.datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M:%S")


# ---- 1. 当前选取（README，兜底 + 同 mtime 时保留） ----
cur = {}
if os.path.isfile(README):
    for line in open(README, encoding="utf-8-sig"):
        if not line.startswith("| ") or line.startswith("| 卡号") or line.startswith("|---"):
            continue
        c = [x.strip() for x in line.strip().strip("|").split("|")]
        if len(c) < 8 or not c[0].isdigit():
            continue
        cur[c[0]] = {"rel": norm(c[5].strip("`")), "name": c[1], "batch": c[2]}

# ---- 2. 候选：追溯索引里的卡图素材 ----
cands = defaultdict(dict)   # cid -> rel -> meta
for line in open(TRACE, encoding="utf-8-sig"):
    if not line.startswith("| 2026-"):
        continue
    c = [x.strip() for x in line.strip().strip("|").split("|")]
    if len(c) < 9 or c[1] != "卡图" or not c[2].isdigit():
        continue
    m = re.search(r"`([^`]+)`", c[5])
    if not m:
        continue
    rel = norm(m.group(1))
    fp = abs_from(rel)
    if not os.path.isfile(fp):
        continue
    cands[c[2]][rel] = {"name": c[3], "batch": c[4], "fp": fp}

# ---- 3. 现选兜底（索引没登记的文件也要参与比较） ----
for cid, info in cur.items():
    rel = info["rel"]
    fp = abs_from(rel)
    if os.path.isfile(fp) and rel not in cands[cid]:
        cands[cid][rel] = {"name": info["name"], "batch": info["batch"], "fp": fp}

# ---- 4. 按 mtime 选版 ----
picked = {}
why = {}
for cid, g in cands.items():
    cur_rel = cur.get(cid, {}).get("rel")
    ranked = sorted(
        g.items(),
        key=lambda kv: (os.stat(kv[1]["fp"]).st_mtime, kv[0] == cur_rel, kv[0]))
    rel, meta = ranked[-1]
    picked[cid] = rel
    why[cid] = "mtime 最新" if rel != cur_rel else "mtime 最新（保留现选）"

os.makedirs(OUT, exist_ok=True)

manifest = []
for cid in sorted(picked):
    rel = picked[cid]
    src = abs_from(rel)
    if not os.path.isfile(src):
        print("MISSING", cid, rel)
        continue
    dst = os.path.join(OUT, cid + ".png")
    shutil.copy2(src, dst)   # 保留源文件 mtime，便于后续复核「生成时间」
    st = os.stat(src)
    meta = cands[cid][rel]
    manifest.append({
        "cid": cid,
        "name": meta["name"] or cur.get(cid, {}).get("name", "—"),
        "batch": meta["batch"] or cur.get(cid, {}).get("batch", rel.split("/")[0]),
        "rel": rel,
        "time": fmt(st.st_mtime),
        "src": why[cid],
        "md5": hashlib.md5(open(src, "rb").read()).hexdigest(),
        "kb": round(st.st_size / 1024),
    })

L = []
A = L.append
A("# 每卡最新版素材（装框前原图）")
A("")
A("> 由 `art_src/_build_latest.py` 自动生成，**重跑即刷新，请勿手改**。")
A("> 口径版本：R878（源文件 mtime 优先），内容确定，重跑幂等。")
A("")
A("## 口径（R878）")
A("")
A("同名卡素材合并时**以文件生成时间（源文件 mtime）更新的为准**：")
A("")
A("1. 候选 = 《新图追溯索引.md》中该卡号全部「卡图」素材 ∪ 当前已选中的那一张（兜底）；")
A("2. 取 mtime 最大的一张；不看文件名版本号、不看《卡图风格修复交付索引》采用列、不设特例；")
A("3. mtime 相同则保留现选（同一张图复制到不同归档目录的情况），再并列按路径字典序取稳定值；")
A("4. 复制用 `shutil.copy2` 保留源 mtime，便于复核与下次幂等重跑。")
A("")
A("本目录**不是**装框后的游戏卡图；现役卡图仍在 `assets/pics/<id>.png`（448×404），未被触碰。")
A("后续批量装框时以本目录为源，按 1.51:1 居中横带 → 448×297 → 上下补边 → 448×404 处理。")
A("")
A("## 汇总")
A("")
A("| 指标 | 数值 |")
A("|---|---:|")
A("| 卡号数 | %d |" % len(manifest))
A("| 合计大小 | %.1f MB |" % (sum(x["kb"] for x in manifest) / 1024.0))
A("| 选版口径 | 源文件 mtime 最大 |")
A("")
A("## 清单")
A("")
A("| 卡号 | 卡名 | 来源批次 | 文件生成时间 | 选取依据 | 源文件 | MD5 | 大小 |")
A("|---|---|---|---|---|---|---|---:|")
for x in manifest:
    A("| %s | %s | %s | %s | %s | `%s` | `%s` | %dKB |" % (
        x["cid"], x["name"], x["batch"], x["time"], x["src"],
        x["rel"], x["md5"][:12], x["kb"]))
A("")
with open(README, "w", encoding="utf-8", newline="") as f:
    f.write("\r\n".join(L))

changed = [x for x in manifest if x["src"] == "mtime 最新"]
print("LATEST: %d cards, %.1f MB, changed=%d" %
      (len(manifest), sum(x["kb"] for x in manifest) / 1024.0, len(changed)))
for x in changed:
    print("  %s %s <- %s (%s)" % (x["cid"], x["name"], x["rel"], x["time"]))
for x in manifest:
    if x["cid"] in ("8002", "8048", "9001", "9038", "9103", "9200"):
        print("  %s %s <- %s [%s]" % (x["cid"], x["name"], x["rel"], x["src"]))
