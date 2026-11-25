# -*- coding: utf-8 -*-
"""
23 号后出图归档核对工具。

用途（用户口径）：
  · 23 号后生成但**未归档**的新图 —— 能被方便地找到并确认存在；
  · 23 号后**已归档**的新图 —— 能方便地确认确实归档过。

口径（重要）：
  · mtime 会被 git checkout / clone 刷新，**不能**单独当作"生成时间"；
    生成侧（gen_raw / art_output）不在 git 内，mtime 可信；
    归档侧（art_src / assets）在 git 内，归档事实以**内容 MD5** 与清单登记为准。
  · "已归档" 判据 = 生成侧某图的内容 MD5 在 art_src 里存在副本（同名不同名都算）。
  · "已登记" 判据 = 该副本路径出现在《出图归档清单.md》。

用法：
  python art_src/_audit_art_archive.py
输出：
  art_src/出图归档核对.md  （UTF-8 / CRLF，可直接看，也可重跑刷新）
"""
import os, re, sys, hashlib, datetime

WORK = r"D:\work"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(REPO, "art_src")
MANIFEST = os.path.join(ART, "出图归档清单.md")
REPORT = os.path.join(ART, "出图归档核对.md")
GEN_ROOTS = [os.path.join(WORK, "gen_raw"), os.path.join(WORK, "art_output")]
ARCH_ROOTS = [ART, os.path.join(REPO, "assets")]
IMG_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")
CUTOFF = datetime.datetime(2026, 11, 23)


def md5(fp):
    h = hashlib.md5()
    with open(fp, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def walk(root):
    out = []
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


def fmt_kb(n):
    return "%dKB" % round(n / 1024)


# ---- 归档侧：内容 MD5 -> 文件列表（含 assets 与 art_src）----
arch_rows = []
for root in ARCH_ROOTS:
    if os.path.isdir(root):
        arch_rows += walk(root)
arch_hash = {}
for fp, mt, sz in arch_rows:
    try:
        arch_hash.setdefault(md5(fp), []).append(fp)
    except OSError:
        pass
art_hash = {}
for h, fps in arch_hash.items():
    art_hash[h] = [p for p in fps if p.lower().startswith(ART.lower())]

# ---- 清单登记 ----
manifest = []
with open(MANIFEST, "r", encoding="utf-8") as f:
    for line in f:
        m = re.match(r"^\|\s*(\d+)\s*\|\s*([0-9:\- ]+)\s*\|", line)
        if not m:
            continue
        for r in re.findall(r"`([^`]+\.(?:png|jpg|jpeg|webp|gif|bmp))`", line, re.I):
            manifest.append((int(m.group(1)), m.group(2).strip(), r))
manifest_paths = {r.lower().replace("\\", "/") for _, _, r in manifest}
manifest_abs = {os.path.join(REPO, r.replace("/", os.sep)).lower() for _, _, r in manifest}

# ---- 生成侧：23 号后 ----
gen = []
for root in GEN_ROOTS:
    if os.path.isdir(root):
        gen += walk(root)
gen = [x for x in gen if datetime.datetime.fromtimestamp(x[1]) >= CUTOFF]
gen.sort(key=lambda x: x[1])

unarchived, archived_registered, archived_unlisted = [], [], []
for fp, mt, sz in gen:
    h = md5(fp)
    matches = art_hash.get(h, [])
    src = rel(fp, WORK)
    if not matches:
        unarchived.append((ts(mt), src, sz, h))
        continue
    dests = [rel(p, REPO) for p in matches]
    if any(d.lower() in manifest_paths for d in dests):
        archived_registered.append((ts(mt), src, dests, sz))
    else:
        archived_unlisted.append((ts(mt), src, dests, sz))

# ---- 清单条目存在性 ----
missing = [(i, t, r) for i, t, r in manifest
           if not os.path.isfile(os.path.join(REPO, r.replace("/", os.sep)))]

# ---- art_src 内 23 号后目录、但未登记进清单的图（已归档但没写进清单）----
unlisted_in_art = []
for fp, mt, sz in arch_rows:
    if not fp.lower().startswith(ART.lower()):
        continue
    r = rel(fp, REPO)
    if r.lower() in manifest_paths:
        continue
    d = os.path.basename(os.path.dirname(fp))
    if re.match(r"^2026-11-(2[3-9]|3[01])", d):
        unlisted_in_art.append((r, sz, d))
unlisted_in_art.sort(key=lambda x: (x[2], x[0]))

# ---- 输出报告 ----
L = []
A = L.append
A("# 23 号后出图 · 归档核对")
A("")
A("> 本文件由 `art_src/_audit_art_archive.py` 自动生成，**重跑即刷新**，请勿手改。")
A("> 生成时间：%s" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
A("")
A("## 能确认的两种状态")
A("")
A("| 状态 | 数量 | 含义 |")
A("|---|---:|---|")
A("| 已归档 · 已登记 | %d | 生成图内容 MD5 在 art_src 有副本，且副本路径已写进《出图归档清单.md》 |" % len(archived_registered))
A("| 已归档 · 未登记 | %d | 有归档副本，但清单还没写进去（会显示在下方明细） |" % len(archived_unlisted))
A("| **未归档** | **%d** | 生成图在 `D:\\work\\gen_raw` / `art_output`，art_src 里**没有**同内容副本；下方按时间列出，逐个可查存在性 |" % len(unarchived))
A("| 清单条目 | %d | 《出图归档清单.md》登记条数，磁盘缺失 **%d** 条 |" % (len(manifest), len(missing)))
A("")
A("判据说明：归档侧文件在 git 内，mtime 会被 checkout / clone 刷新，**不作为生成时间证据**；")
A("归档事实按**内容 MD5**判定（文件改名、重存都认），登记事实按清单路径判定。")
A("")
A("## 一、未归档的新图（可逐个找到并确认存在）")
A("")
if unarchived:
    A("| 生成时间 | 原始路径（D:\\work\\...） | 大小 | MD5 | 存在 |")
    A("|---|---|---:|---|---|")
    for t, src, sz, h in unarchived:
        A("| %s | `%s` | %s | `%s` | %s |" % (t, src, fmt_kb(sz), h,
          "✓" if os.path.isfile(os.path.join(WORK, src.replace("/", os.sep))) else "✗ 已不在"))
else:
    A("无。")
A("")
A("## 二、已归档的新图（可确认确实归档过）")
A("")
A("### 2.1 已归档 · 已登记")
A("")
if archived_registered:
    A("| 生成时间 | 原始路径 | 归档副本（art_src / assets） | 大小 |")
    A("|---|---|---|---:|")
    for t, src, dests, sz in archived_registered:
        A("| %s | `%s` | %s | %s |" % (t, src,
          " ".join("`%s`" % d for d in dests), fmt_kb(sz)))
else:
    A("无。")
A("")
A("### 2.2 已归档 · 未登记")
A("")
if archived_unlisted:
    A("| 生成时间 | 原始路径 | 归档副本 | 大小 |")
    A("|---|---|---|---:|")
    for t, src, dests, sz in archived_unlisted:
        A("| %s | `%s` | %s | %s |" % (t, src,
          " ".join("`%s`" % d for d in dests), fmt_kb(sz)))
else:
    A("无。")
A("")
A("### 2.3 art_src 内 23 号后批次、清单未登记的图（共 %d）" % len(unlisted_in_art))
A("")
A("> 这些图**已在 art_src 里**（即已归档），只是《出图归档清单.md》还没补登。")
A("> 按批次分组；25 号批次仍在出图，重跑可刷新。")
A("")
if unlisted_in_art:
    by_batch = {}
    for r, sz, d in unlisted_in_art:
        by_batch.setdefault(d, []).append((r, sz))
    for batch in sorted(by_batch):
        A("#### %s（%d）" % (batch, len(by_batch[batch])))
        A("")
        A("| 归档路径 | 大小 | 存在 |")
        A("|---|---:|---|")
        for r, sz in sorted(by_batch[batch]):
            A("| `%s` | %s | %s |" % (r, fmt_kb(sz),
              "✓" if os.path.isfile(os.path.join(REPO, r.replace("/", os.sep))) else "✗"))
        A("")
else:
    A("无。")
A("")
A("## 三、清单完整性")
A("")
A("- 清单登记：%d 条；磁盘缺失：%d 条。" % (len(manifest), len(missing)))
if missing:
    A("")
    A("| # | 时间 | 路径 |")
    A("|---:|---|---|")
    for i, t, r in missing:
        A("| %d | %s | `%s` |" % (i, t, r))
    A("")
A("## 四、怎么核对")
A("")
A("```bash")
A("python art_src/_audit_art_archive.py   # 重新扫描并刷新本文件")
A("```")
A("")
A("- 找未归档图：看「一」的路径，直接在 `D:\\work\\gen_raw` / `art_output` 打开，存在列是 ✓ 就确认还在。")
A("- 确认归档过：看「二」的归档副本路径，或「2.3」的 art_src 批次明细，都能在仓库里直接打开。")
A("- mtime 只用于生成侧排序；归档侧以内容 MD5 + 清单路径为准。")
A("")

data = "\r\n".join(L) + "\r\n"
with open(REPORT, "w", encoding="utf-8", newline="") as f:
    f.write(data)

print("REPORT:", REPORT)
print("已归档·已登记=%d 已归档·未登记=%d 未归档=%d 清单=%d 缺失=%d art_src未登记=%d"
      % (len(archived_registered), len(archived_unlisted), len(unarchived),
         len(manifest), len(missing), len(unlisted_in_art)))
