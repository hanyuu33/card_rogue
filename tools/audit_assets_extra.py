# -*- coding: utf-8 -*-
"""R596 素材体检补全：把 `audit_release_assets.py` 没覆盖到的口径补齐。

已有脚本盯的是「按数据表反推应有清单」（卡图/道具/事件/职业/地图/BGM/字面量）。
这里反过来做一遍**硬判据**：扫全部脚本里 `res://assets/...` 的真实引用，
逐个查文件在不在 —— 任何类目漏了都会被这一遍抓出来。
另外顺带列出孤儿图（存在但代码从不提）与导出过滤的可疑点，只报不改。
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
OUT = os.path.join(ROOT, "_preview", "asset_audit_extra.txt")


def read(p):
    with io.open(p, encoding="utf-8", errors="replace") as f:
        return f.read()


def all_gd():
    for root, _, files in os.walk(ROOT):
        if ".godot" in root or "node_modules" in root:
            continue
        for fn in files:
            if fn.endswith(".gd"):
                yield os.path.join(root, fn)


# ── ① 全库 res://assets 字面量 ────────────────────────────────────────────
rx_asset = re.compile(r'res://(assets/[^"\')\s]+)')
refs = {}
for p in all_gd():
    for m in rx_asset.finditer(read(p)):
        refs.setdefault(m.group(1), set()).add(os.path.relpath(p, ROOT).replace("\\", "/"))

# 场景/配置里的 res:// 也扫
for extra in ("project.godot", "export_presets.cfg"):
    fp = os.path.join(ROOT, extra)
    if os.path.exists(fp):
        for m in rx_asset.finditer(read(fp)):
            refs.setdefault(m.group(1), set()).add(extra)

# 格式化串（%s / %d）、文档占位（<关卡key>）、注释里的反引号尾，都不是真实路径
def _is_template(rel):
    return ("%" in rel) or ("<" in rel) or rel.endswith("`") or "（" in rel


missing_lit = []
tpl = []
for rel, where in sorted(refs.items()):
    if _is_template(rel):
        tpl.append(rel)
        continue
    if not os.path.exists(os.path.join(ROOT, rel)):
        missing_lit.append((rel, sorted(where)))

# ── ② 字体 ──────────────────────────────────────────────────────────────
font_dir = os.path.join(ROOT, "assets", "fonts")
fonts = sorted(f for f in os.listdir(font_dir) if not f.endswith(".import"))
font_refs = sorted({r for r in refs if r.startswith("assets/fonts/")})
font_missing = [f for f in font_refs if not os.path.exists(os.path.join(ROOT, f))]

# ── ③ 应用图标 / 启动图 ───────────────────────────────────────────────────
icon_refs = []
for extra in ("project.godot", "export_presets.cfg"):
    fp = os.path.join(ROOT, extra)
    if not os.path.exists(fp):
        continue
    for line in read(fp).splitlines():
        if "icon" in line.lower() and "res://" in line:
            for m in rx_asset.finditer(line):
                icon_refs.append((extra, m.group(1)))
icon_missing = [(f, r) for f, r in icon_refs if not os.path.exists(os.path.join(ROOT, r))]

# ── ④ UI 孤儿候选（排除动态拼接族）────────────────────────────────────────
ui_dir = os.path.join(ROOT, "assets", "ui")
ui_files = sorted(f[:-4] for f in os.listdir(ui_dir) if f.endswith(".png"))
# 这些族由代码拼接出文件名（`path_for("affix_" + glyph)`、`art_frame_%s`、`ribbon_%d` …），
# 逐个查 json 会全部误报成孤儿。族名在 ui_assets / card_face 里都有拼接证据。
DYNAMIC = ("relic_icon_", "relic_rim_", "class_", "event_", "side_", "bg_",
           "affix_", "art_frame_", "battle_bg_", "div_vision_", "icon_",
           "key_icon_", "map_", "ribbon_", "shop_icon_", "reward_")
ui_used = set()
for rel in refs:
    if rel.startswith("assets/ui/"):
        ui_used.add(rel[len("assets/ui/"):].rsplit(".", 1)[0])
# UiAssets 的 "name" 口径（get_tex / small_icon / shop_icon / path_for）
for p in all_gd():
    src = read(p)
    for rx in (re.compile(r'get_tex\(\s*"([^"]+)"'), re.compile(r'small_icon\(\s*"([^"]+)"'),
               re.compile(r'shop_icon\(\s*"([^"]+)"'), re.compile(r'path_for\(\s*"([^"]+)"')):
        for m in rx.finditer(src):
            ui_used.add(m.group(1).rsplit(".", 1)[0])

orphans = []
for name in ui_files:
    if any(name.startswith(d) for d in DYNAMIC):
        continue
    if name in ui_used:
        continue
    if name.endswith((".bak_20261106_1", ".bak_20261106_2", ".bak_20261106_3",
                      ".bak_20261106_4", ".bak_20261106_5", ".bak_20261106_6")):
        continue
    if "_bak" in name or name.endswith("_v2_") or name.endswith("_old"):
        orphans.append((name, "疑似版本残留"))
        continue
    orphans.append((name, "代码未引用"))

# ── ⑤ fx 引用情况 ────────────────────────────────────────────────────────
fx_dir = os.path.join(ROOT, "assets", "fx")
fx_files = sorted(f[:-4] for f in os.listdir(fx_dir) if f.endswith(".png"))
fx_used = {u for u in ui_used} | {r[len("assets/fx/"):].rsplit(".", 1)[0]
                                  for r in refs if r.startswith("assets/fx/")}
fx_orphan = [f for f in fx_files if f not in fx_used]

# ── ⑥ 会被打进包的临时目录 ────────────────────────────────────────────────
pending = os.path.join(ROOT, "assets", "pics", "_pending")
pend_png = [f for f in os.listdir(pending) if f.endswith(".png")] if os.path.isdir(pending) else []

# ── 输出 ────────────────────────────────────────────────────────────────
L = []
L.append("素材体检补全（硬判据：脚本里所有 res://assets 引用逐个查存在性）")
L.append("=" * 70)
L.append("")
L.append("① res://assets 字面量引用    %d 条（其中格式化模板 %d 条，已跳过），缺文件 %d"
         % (len(refs), len(tpl), len(missing_lit)))
for rel, where in missing_lit:
    L.append("   MISSING %s   ← %s" % (rel, ", ".join(where[:3])))
L.append("")
L.append("② 字体   %d 个文件：%s" % (len(fonts), " / ".join(fonts)))
L.append("   代码引用 %d 条，缺 %d" % (len(font_refs), len(font_missing)))
for f in font_missing:
    L.append("   MISSING %s" % f)
L.append("")
L.append("③ 应用图标 / 启动图引用 %d 条，缺 %d" % (len(icon_refs), len(icon_missing)))
for f, r in icon_missing:
    L.append("   MISSING %s  ← %s" % (r, f))
L.append("")
L.append("④ UI 孤儿图（存在但代码从不提，排除 relic_/class_/event_/side_/bg_ 动态族）")
L.append("   assets/ui 共 %d 张 PNG，孤儿 %d 张" % (len(ui_files), len(orphans)))
for n, why in orphans:
    L.append("   %-34s %s" % (n, why))
L.append("")
L.append("⑤ 特效图 assets/fx 共 %d 张，未被引用 %d 张：%s"
         % (len(fx_files), len(fx_orphan), " ".join(fx_orphan) if fx_orphan else "无"))
L.append("")
L.append("⑥ assets/pics/_pending/ 里有 %d 张 png（含新补的 9192/9193 与孤儿 8083）" % len(pend_png))
L.append("   export_presets 的 exclude_filter 只排除 `_*.png`（文件名下划线开头），")
L.append("   不会命中 `_pending/` 目录内的 9192.png —— 这几张可能会一起打进包（体积冗余，不影响运行）。")
L.append("")

io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(L))
print("\n".join(L))
