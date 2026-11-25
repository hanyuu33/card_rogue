# -*- coding: utf-8 -*-
"""
新图追溯索引 —— 一键刷新（Codex / 并行出图会话共用入口）

用法：
    python art_src/_trace_new_art.py

产出：
    art_src/出图归档清单.md   —— 把 23 号后 art_src 里未登记的图全部补登，保持时间升序
    art_src/新图追溯索引.md   —— 一行一张图的统一追溯表（卡号 / 批次 / 归档路径 / 原始路径 / 采用状态）

随后可跑 `python art_src/_audit_art_archive.py` 刷新归档核对报告。

口径：
    · 归档侧（art_src / assets）在 git 内，mtime 会被 checkout 刷新，仅作本机生成时间参考；
      归档事实以内容 MD5 与《出图归档清单.md》登记路径为准。
    · 生成侧（D:\\work\\gen_raw / D:\\work\\art_output）不在 git 内，mtime 可信；
      原始生成路径按内容 MD5 反查，生成侧已清理则显示「—」。
"""
import os
import re
import hashlib
import datetime

WORK = r"D:\work"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(REPO, "art_src")
MANIFEST = os.path.join(ART, "出图归档清单.md")
DELIVERY = os.path.join(ART, "卡图风格修复交付索引.md")
TRACE = os.path.join(ART, "新图追溯索引.md")
GEN_ROOTS = [os.path.join(WORK, "gen_raw"), os.path.join(WORK, "art_output")]
IMG_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")
CUTOFF = datetime.datetime(2026, 11, 23)
BATCH_RE = re.compile(r"^2026-11-(2[3-9]|3[01])")
CARD_RE = re.compile(r"^(\d{4})[_-](.+?)(?:_v\d+)?\.")
PATH_RE = re.compile(r"`([^`]+\.(?:png|jpg|jpeg|webp|gif|bmp))`", re.I)


def read_text(fp):
    with open(fp, "r", encoding="utf-8-sig", newline="") as f:
        return f.read()


def write_like(path, text):
    """保持原文件换行符风格；新文件用 CRLF。"""
    old = ""
    if os.path.exists(path):
        with open(path, "rb") as f:
            old = f.read().decode("utf-8", "replace")
    nl = "\r\n" if "\r\n" in old else "\n"
    text = text.replace("\r\n", "\n").replace("\n", nl)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def md5(fp):
    h = hashlib.md5()
    with open(fp, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def walk_images(root):
    out = []
    if not os.path.isdir(root):
        return out
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d != ".git" and not d.startswith(".")]
        for fn in fns:
            if fn.lower().endswith(IMG_EXT):
                fp = os.path.join(dp, fn)
                try:
                    st = os.stat(fp)
                except OSError:
                    continue
                out.append((fp, st.st_mtime, st.st_size))
    return out


def rel(fp, base):
    return os.path.relpath(fp, base).replace("\\", "/")


def ts(t):
    return datetime.datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M:%S")


def is_new_batch(relative_path):
    """艺术归档侧：批次目录或根目录散图，均须 23 号后。"""
    parts = relative_path.split("/")
    if len(parts) < 2 or parts[0] != "art_src":
        return False
    return bool(BATCH_RE.match(parts[1]))


def classify(fn, batch):
    low = fn.lower()
    b = batch.lower()
    if "map_bg" in low or "地图背景" in batch:
        return "地图背景"
    if "battle_bg" in low or "战斗背景" in batch:
        return "战斗背景"
    if low.startswith("bg_") or "事件背景" in batch:
        return "事件背景"
    if "keyart" in low or "主视觉" in batch or "steam" in b:
        return "主视觉"
    if "frames" in b or "frame" in low or "卡框" in batch:
        return "卡框/边框"
    if "三视图" in fn or "cg" in b or "角色" in batch:
        return "角色设定"
    if CARD_RE.match(fn):
        return "卡图"
    return "其他"


# ---- 1. 生成侧 MD5 -> 原始路径 ----
gen_items = []
gen_by_hash = {}
for root in GEN_ROOTS:
    for fp, mt, sz in walk_images(root):
        gen_items.append((fp, mt, sz))
        gen_by_hash.setdefault(md5(fp), []).append(rel(fp, WORK))

# ---- 2. 交付索引采用状态 ----
status_by_path = {}
if os.path.isfile(DELIVERY):
    for line in read_text(DELIVERY).splitlines():
        row = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(row) < 4:
            continue
        note = row[-1]
        for link in re.findall(r"\[[^\]]*\]\((\./[^)]+)\)", line):
            status_by_path[link[2:].lower()] = note

# ---- 3. 归档侧 23 号后所有图 ----
items = []
for fp, mt, sz in walk_images(ART):
    r = rel(fp, REPO)
    if not is_new_batch(r):
        continue
    h = md5(fp)
    fn = os.path.basename(fp)
    batch = r.split("/")[1] if "/" in r else ""
    m = CARD_RE.match(fn)
    card_id, card_name = (m.group(1), m.group(2)) if m else ("—", "—")
    status = status_by_path.get(r.lower(), "—")
    origins = gen_by_hash.get(h, [])
    items.append({
        "time": ts(mt), "sort": mt, "path": r, "fn": fn, "batch": batch,
        "kind": classify(fn, batch), "card": card_id, "name": card_name,
        "status": status, "md5": h, "kb": round(sz / 1024),
        "origin": origins[0] if origins else "—",
    })
items.sort(key=lambda x: (x["sort"], x["path"]))

# ---- 3b. 生成侧仍存在、但 art_src / assets 都无副本的图（未归档） ----
archived_md5 = {it["md5"] for it in items}
for fp, mt, sz in walk_images(os.path.join(REPO, "assets")):
    try:
        archived_md5.add(md5(fp))
    except OSError:
        pass
unarchived = []
seen_gen = set()
for fp, mt, sz in sorted(gen_items, key=lambda x: x[1]):
    if datetime.datetime.fromtimestamp(mt) < CUTOFF:
        continue
    h = md5(fp)
    if h in archived_md5:
        continue
    p = rel(fp, WORK)
    if p in seen_gen:
        continue
    seen_gen.add(p)
    unarchived.append({"time": ts(mt), "path": p, "kb": round(sz / 1024), "md5": h})

# ---- 4. 补登《出图归档清单.md》 ----
manifest_text = read_text(MANIFEST)
lines = manifest_text.replace("\r\n", "\n").split("\n")
table_start = None
for i, line in enumerate(lines):
    if line.startswith("| # | 生成时间"):
        table_start = i
        break
if table_start is None:
    raise RuntimeError("找不到清单表头，请人工检查 " + MANIFEST)

table_end = table_start
while table_end < len(lines) and lines[table_end].startswith("|"):
    table_end += 1

existing = {}
for line in lines[table_start + 2:table_end]:
    m = re.match(r"^\|\s*(\d+)\s*\|\s*([0-9:\- ]+)\s*\|", line)
    if not m:
        continue
    paths = PATH_RE.findall(line)
    if paths:
        existing[paths[0]] = {"time": m.group(2).strip(), "raw": line}

added = []
for it in items:
    if it["path"] in existing:
        continue
    # 第一列留占位，稍后与新表头一起统一重编号（否则时间列会被顶掉）
    raw = "| 0 | {time} | {kind} | {card} | {name} | {batch} | `{path}` | {kb}KB |".format(
        time=it["time"], kind=it["kind"], card=it["card"], name=it["name"],
        batch=it["batch"], path=it["path"], kb=it["kb"])
    existing[it["path"]] = {"time": it["time"], "raw": raw}
    added.append(it["path"])

merged = []
for path, ent in existing.items():
    merged.append((ent["time"], path, ent["raw"]))
merged.sort(key=lambda x: (x[0], x[1]))

new_table = ["| # | 生成时间 | 类别 | 卡号 | 卡名 | 批次/来源 | 文件 | 大小 |",
             "|---:|---|---|---|---|---|---|---:|"]
for i, (t, path, raw) in enumerate(merged, 1):
    cells = [c.strip() for c in raw.strip().strip("|").split("|")]
    cells[0] = str(i)
    new_table.append("| " + " | ".join(cells) + " |")

header = lines[:table_start]
footer = lines[table_end:]
total_kb = sum(int(round(round(os.path.getsize(os.path.join(REPO, p.replace("/", os.sep))) / 1024)))
               for p in existing)
header_out = []
for line in header:
    if line.startswith("- 图片总数："):
        header_out.append("- 图片总数：**%d** 张，合计约 **%.1f MB**" % (len(merged), total_kb / 1024.0))
    else:
        header_out.append(line)
if not any("新图追溯索引" in x for x in header_out):
    insert_at = next((i for i, x in enumerate(header_out) if x.startswith("- 排序：")), len(header_out))
    header_out.insert(insert_at + 1,
                      "- 统一追溯：`art_src/新图追溯索引.md`（跑 `python art_src/_trace_new_art.py` 一键刷新）")

write_like(MANIFEST, "\n".join(header_out + new_table + footer) + "\n")

# ---- 5. 生成《新图追溯索引.md》 ----
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
L = []
A = L.append
A("# 新图追溯索引（Codex / 并行出图会话）")
A("")
A("> 一行一张图，按生成时间升序；由 `art_src/_trace_new_art.py` 自动生成，**重跑即刷新，请勿手改**。")
A("> 刷新：`python art_src/_trace_new_art.py`，随后 `python art_src/_audit_art_archive.py` 刷新核对报告。")
A("> 生成时间：%s" % now)
A("")
A("## 怎么查")
A("")
A("- 按卡号查：搜索 `| 8048 |`（示例为生产订单）；按名称查：搜索卡名。")
A("- 按批次查：看「批次」列，如 `2026-11-25_卡图修复_batch19`。")
A("- 按采用状态查：搜索「已接入游戏」/「待装框」/「候选」。")
A("- 「归档路径」在仓库里，「原始生成路径」在 `D:\\work\\gen_raw` 或 `D:\\work\\art_output`；后者已清理则显示 —。")
A("")
A("## 汇总")
A("")
A("| 指标 | 数值 |")
A("|---|---:|")
A("| 23 号后新图（art_src） | %d |" % len(items))
A("| 已登记《出图归档清单.md》 | %d |" % (len(items) - len(added)))
A("| 本次补登 | %d |" % len(added))
A("| 生成侧仍有原件（可按 MD5 反查） | %d |" % len([it for it in items if it["origin"] != "—"]))
A("| 清单登记总数 | %d |" % len(merged))
A("| 生成侧未归档（需拷贝进 art_src） | %d |" % len(unarchived))
A("")
A("## 未归档的生成侧图片")
A("")
if unarchived:
    A("> 这些图仍在 `D:\\work\\gen_raw` / `D:\\work\\art_output`，art_src 与 assets 里都没有同内容副本。")
    A("")
    A("| 生成时间 | 原始路径（D:\\work\\...） | 大小 | MD5 |")
    A("|---|---|---:|---|")
    for it in unarchived:
        A("| %s | `%s` | %dKB | `%s` |" % (it["time"], it["path"], it["kb"], it["md5"]))
else:
    A("无。所有生成侧新图都能在 art_src / assets 找到同内容副本。")
A("")
A("## 全量追溯表")
A("")
A("| 生成时间 | 类别 | 卡号 | 卡名 | 批次 | 归档路径 | 原始生成路径 | 采用状态 | MD5 |")
A("|---|---|---|---|---|---|---|---|---|")
for it in items:
    A("| %s | %s | %s | %s | %s | `%s` | %s | %s | `%s` |" % (
        it["time"], it["kind"], it["card"], it["name"], it["batch"],
        it["path"], ("`" + it["origin"] + "`") if it["origin"] != "—" else "—",
        it["status"], it["md5"][:12]))
A("")
A("## 口径说明")
A("")
A("- 归档侧文件在 git 内，mtime 会被 checkout / clone 刷新；跨机器后以 MD5 与清单登记为准。")
A("- 生成侧不在 git 内，mtime 即生成时间；原始路径按内容 MD5 反查。")
A("- 「采用状态」来自《卡图风格修复交付索引.md》；显示 — 表示该图尚未写进采用索引。")
A("- 核对未归档 / 清单缺失：`art_src/出图归档核对.md`（由 `_audit_art_archive.py` 刷新）。")
A("")
write_like(TRACE, "\n".join(L))

print("TRACE:", TRACE)
print("新图=%d 本次补登=%d 清单总数=%d 有生成侧原件=%d"
      % (len(items), len(added), len(merged),
         len([it for it in items if it["origin"] != "—"])))
for p in added:
    print("  ADDED:", p)
