# -*- coding: utf-8 -*-
"""发布前素材体检（R595b）。

思路：**不手写素材清单**，从「谁在用」反推「该有什么」：
  ① 卡图   ← cards.json 每张卡（公用初始卡走 `<id>_<职业>.png` 变体）
  ② 道具   ← relics.json 每个道具的 `relic_icon_<id>` + `relic_rim_<id>`（信物 6061~6063 除外）
  ③ 事件   ← `event_scene._kind()` 返回的 kind 集合 → `event_/side_/bg_` 三类
  ④ 职业   ← PlayerClass 三个角色 → `class_cg_/class_avatar_/class_badge/class_avatar_locked_`
  ⑤ 地图   ← `assets/ui/map_icons/` 的节点类型
  ⑥ BGM    ← `bgm.SLOT_TRACKS` 的槽位 → `assets/audio/bgm/<slot>.ogg`
  ⑦ 代码字面量 ← `get_tex("x")` / `shop_icon("x")` / `"map_icons/x"` … 全部查一遍
     （跳过格式串 `%d` / 常量拼接 / 测试占位名）

输出：控制台摘要 + `_preview/asset_audit.{json,txt}`
跑法：python tools/audit_release_assets.py
"""
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "ui")
PICS = os.path.join(ROOT, "assets", "pics")
# R595b：`_pending/` 是「已出图、等店长审批」的暂存层（同 448×403 规格）。
# 它不属于 assets/pics 正式库，但**绝不能算成「没做过」** —— R595 就是漏了这层，
# 把 89 张已完成的图报成待生成。
PEND = os.path.join(PICS, "_pending")
SCRIPTS = os.path.join(ROOT, "scripts")


def rd(*p):
    return os.path.join(ROOT, *p)


def load_json(name):
    with io.open(rd(name), "r", encoding="utf-8") as f:
        return json.load(f)


def read(path):
    with io.open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def png_ui(name):
    return os.path.exists(os.path.join(UI, name + ".png"))


def png_pic(name):
    return os.path.exists(os.path.join(PICS, name + ".png"))


def png_pend(name):
    return os.path.exists(os.path.join(PEND, name + ".png"))


report = {}

# ── ① 卡图 ───────────────────────────────────────────────────────────────
cards = load_json("cards.json")
items = cards["cards"] if isinstance(cards, dict) else cards
CLASS_SUFFIX = ["_forest", "_mech", "_shadow"]
# `art_plan.json.skip` 里的是**已定案不再出图**的卡（如 9158 弃用的旧召唤物机制）。
# 它们既不算「缺」也不算「待办」，单列一态，否则报告永远收不了口。
try:
    _plan = load_json("art_plan.json")
    SKIP = {int(k): v for k, v in (_plan.get("skip") or {}).items()}
except Exception:                                              # noqa: BLE001
    SKIP = {}
miss_cards = []      # 两张都没有 = 真待生成
pend_cards = []      # 正式库没有、_pending 有 = 等审批
skip_cards = []      # 已定案永久不出图
for c in items:
    cid = c["id"]
    variants = []
    if png_pic(str(cid)):
        continue
    variants = [s for s in CLASS_SUFFIX if png_pic(str(cid) + s)]
    if len(variants) == len(CLASS_SUFFIX):       # 三职业变体齐全 = 不缺
        continue
    row = {"id": cid, "name": c.get("name", ""), "kind": c.get("kind", ""),
           "rarity": c.get("rarity", 0), "group": c.get("group", ""),
           "card_class": c.get("class", ""), "variants": variants}
    if cid in SKIP:
        row["reason"] = SKIP[cid]
        skip_cards.append(row)
    elif png_pend(str(cid)):
        pend_cards.append(row)
    else:
        miss_cards.append(row)
report["cards"] = {"total": len(items),
                   "have": len(items) - len(miss_cards) - len(pend_cards) - len(skip_cards),
                   "pending": pend_cards, "missing": miss_cards, "skipped": skip_cards}

# `_pending` 里有、卡库里已经没有的 id（卡被删或改号后的残留，只报不删）
known = {c["id"] for c in items}
orphan = sorted(int(os.path.basename(p)[:-4]) for p in __import__("glob").glob(
    os.path.join(PEND, "*.png")) if os.path.basename(p)[:-4].isdigit())
report["cards"]["orphan"] = [i for i in orphan if i not in known]

# ── ② 道具 ──────────────────────────────────────────────────────────────
relics = load_json("relics.json")
ritems = relics["relics"] if isinstance(relics, dict) else relics
miss_icon, miss_rim = [], []
for r in ritems:
    rid = r["id"]
    if rid in (6061, 6062, 6063):
        continue
    if not png_ui("relic_icon_%d" % rid):
        miss_icon.append({"id": rid, "name": r.get("name", "")})
    if not png_ui("relic_rim_%d" % rid):
        miss_rim.append({"id": rid, "name": r.get("name", "")})
report["relics"] = {"total": len(ritems), "missing_icon": miss_icon, "missing_rim": miss_rim}

# ── ②b 稀有度缎带（按卡库实际用到的 rarity 反查）───────────────────────
# `UiAssets.rarity_ribbon(r)` → `ribbon_<r>.png`，下标同 CardData.RARITY_COLORS（0..6）。
# 诅咒卡 rarity=6，素材名 ribbon_6 —— 只按 0..5 数会漏掉「诅咒卡没有缎带」。
used_rarity = sorted({int(c.get("rarity", 0)) for c in items})
rib_missing = [r for r in used_rarity if not png_ui("ribbon_%d" % r)]
by_rarity = {}
for c in items:
    by_rarity.setdefault(int(c.get("rarity", 0)), []).append(c["id"])
report["ribbon"] = {"used": used_rarity, "missing": rib_missing,
                    "missing_cards": {str(r): by_rarity[r] for r in rib_missing}}

# ── ③ 事件 kind ─────────────────────────────────────────────────────────
src_ev = read(os.path.join(SCRIPTS, "event_scene.gd"))
body = src_ev.split("func _kind() -> String:")[1].split("\nfunc ")[0]
kinds = sorted(set(re.findall(r'return "([a-z_]+)"', body)))
# R596：左右布局只吃竖版图，居中布局吃「插图 or 整屏背景」，分开判才看得清真缺口。
side_layout = re.findall(r'"([a-z_]+)"',
                         src_ev.split("const SIDE_LAYOUT_KINDS := [")[1].split("]")[0])
ev_missing = {"event": [], "side": [], "bg": [],
              "side_no_pic": [], "center_blank": [], "center_no_bg": []}
for k in kinds:
    has_e, has_s, has_b = png_ui("event_" + k), png_ui("side_" + k), png_ui("bg_" + k)
    if not has_e:
        ev_missing["event"].append(k)
    if not has_s:
        ev_missing["side"].append(k)
    if not has_b:
        ev_missing["bg"].append(k)
    if k in side_layout:
        if not has_s:                       # 左右布局没竖版 = 整页没图，真缺
            ev_missing["side_no_pic"].append(k)
    else:
        if not has_e and not has_b:         # 居中布局两种图都没有 = 只剩程序化底色
            ev_missing["center_blank"].append(k)
        elif not has_b:                     # 有 320×240 插图但没整屏背景
            ev_missing["center_no_bg"].append(k)
report["events"] = {"kinds": kinds, "side_layout": side_layout, "missing": ev_missing}

# ── ④ 职业 ──────────────────────────────────────────────────────────────
src_pc = read(os.path.join(SCRIPTS, "player_class.gd"))
classes = re.findall(r'^const (?:DRUID|ROGUE|MECH) := "([^"]+)"', src_pc, re.M)
cls_keys = {"森林精魄": "forest", "暗影刺客": "rogue", "机械之心": "mech"}
cls_missing = []
for cn in classes:
    key = cls_keys.get(cn, "")
    # 命名口径来自 UiAssets：class_cg_<key> / class_avatar_<key> /
    # class_avatar_<key>_locked（后缀在后）/ class_<key>（= class_badge）
    for fname in ("class_cg_" + key, "class_avatar_" + key,
                  "class_avatar_" + key + "_locked", "class_" + key):
        if not png_ui(fname):
            cls_missing.append({"class": cn, "slot": fname})
report["classes"] = {"names": classes, "missing": cls_missing}

# ── ⑤ 地图节点图标 ───────────────────────────────────────────────────────
# R596：补上 boss —— `rogue_map.LINE_TYPES` 里有 boss（首领），TYPE_MARKS 给的是「王」，
# 但 map_icons/boss.png 从来没做过，地图上首领节点一直只有汉字。
NODE_TYPES = ["battle", "bigchest", "chest", "elite", "event", "rest", "shop", "start",
              "unknown", "boss"]
node_missing = [t for t in NODE_TYPES if not png_ui("map_icons/" + t)]
report["map_nodes"] = {"types": NODE_TYPES, "missing": node_missing}

# ── ⑥ BGM 槽位 ──────────────────────────────────────────────────────────
src_bgm = read(os.path.join(SCRIPTS, "bgm.gd"))
slots = re.findall(r'^\t"([a-z0-9_]+)": "', src_bgm, re.M)
bgm_missing = [s for s in slots if not os.path.exists(rd("assets", "audio", "bgm", s + ".ogg"))]
report["bgm"] = {"slots": len(slots), "missing": bgm_missing}

# ── ⑦ 代码字面量 → assets/ui ─────────────────────────────────────────────
PATTERNS = [
    re.compile(r'get_tex\(\s*"([^"%]+)"'),
    re.compile(r'small_icon\(\s*"([^"%]+)"'),
    re.compile(r'shop_icon\(\s*"([^"%]+)"'),
    re.compile(r'"((?:map_icons|reward_icons|adventure_shared)/[^"%]+)"'),
]
used = {}
for fn in sorted(os.listdir(SCRIPTS)):
    if not fn.endswith(".gd"):
        continue
    src = read(os.path.join(SCRIPTS, fn))
    for rx in PATTERNS:
        for m in rx.finditer(src):
            nm = m.group(1)
            if nm.endswith(".png"):
                nm = nm[:-4]
            if not nm or nm.endswith(("_", "/")) or nm.startswith("__") or "(" in nm:
                continue
            used.setdefault(nm, set()).add(fn)

SHOP_ALIAS = {
    "shop_icon_remove": "reward_icons/deck_delete",
    "shop_icon_card": "reward_icons/cards", "shop_icon_draw": "reward_icons/cards",
    "shop_icon_costdown": "icon_cost", "shop_icon_damage": "map_icons/battle",
    "shop_icon_dimension": "reward_icons/core", "shop_icon_save": "map_icons/chest",
    "shop_icon_opening": "map_icons/start", "shop_icon_maxhp": "adventure_shared/service_vitality",
    "shop_icon_dagger": "key_icon_dagger",
}
miss_ui = []
for nm, where in sorted(used.items()):
    target = SHOP_ALIAS.get(nm, nm)
    if png_ui(target) or png_ui(nm):
        continue
    miss_ui.append({"name": nm, "used_in": sorted(where)})
report["ui_literals"] = {"total": len(used), "missing": miss_ui}

# ── 输出 ────────────────────────────────────────────────────────────────
os.makedirs(rd("_preview"), exist_ok=True)
with io.open(rd("_preview", "asset_audit.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

L = []
L.append("发布前素材体检　%d 张卡 / %d 个道具 / %d 类事件 / %d 个 BGM 槽位"
         % (len(items), len(ritems), len(kinds), len(slots)))
L.append("=" * 62)
L.append("卡图　　已归档 %3d ／ 待审批 %3d ／ 真缺 %3d ／ 已弃用 %d（共 %d）"
         % (len(items) - len(miss_cards) - len(pend_cards) - len(skip_cards),
            len(pend_cards), len(miss_cards), len(skip_cards), len(items)))
L.append("道具图标缺 %3d ／ 边缘光缺 %3d / %d" % (len(miss_icon), len(miss_rim), len(ritems)))
L.append("事件（kind 共 %d，左右布局 %d 个）" % (len(kinds), len(side_layout)))
L.append("  ├ 左右布局缺竖版   %d   %s" % (len(ev_missing["side_no_pic"]),
                                          " ".join(ev_missing["side_no_pic"])))
L.append("  ├ 居中·只剩程序化底 %d   %s" % (len(ev_missing["center_blank"]),
                                           " ".join(ev_missing["center_blank"])))
L.append("  └ 居中·有插图无整屏bg %d   %s" % (len(ev_missing["center_no_bg"]),
                                             " ".join(ev_missing["center_no_bg"])))
L.append("稀有度缎带缺 %2d ／ %d 档在用   %s"
         % (len(rib_missing), len(used_rarity),
            " ".join("ribbon_%d(卡%s)" % (r, by_rarity[r]) for r in rib_missing)))
L.append("职业素材缺 %2d（%s）" % (len(cls_missing), " / ".join(classes)))
L.append("地图节点图标缺 %2d / %d" % (len(node_missing), len(NODE_TYPES)))
L.append("BGM 缺 %2d / %d" % (len(bgm_missing), len(slots)))
L.append("代码引用 UI 素材 %d 个，缺 %d" % (len(used), len(miss_ui)))
L.append("")

if miss_cards:
    by = {}
    for m in miss_cards:
        by.setdefault((m["group"], m["kind"]), []).append(m)
    L.append("── 真缺卡图 %d 张（按 阵营/种类）──" % len(miss_cards))
    for (g, k), v in sorted(by.items(), key=lambda x: -len(x[1])):
        L.append("  %-6s %-4s %d 张" % (g, k, len(v)))
    L.append("")
    for m in miss_cards:
        L.append("  %5d  %-3s %-4s r%-2s %-12s %s"
                 % (m["id"], m["group"][:3], m["kind"], m["rarity"], m["card_class"], m["name"]))
    L.append("")
if pend_cards:
    L.append("── 待审批 %d 张（图在 assets/pics/_pending/，未 approve 未提交）──"
             % len(pend_cards))
    L.append("  " + "  ".join("%d %s" % (m["id"], m["name"]) for m in pend_cards))
    L.append("")
if skip_cards:
    L.append("── 已弃用·不出图 %d 张（art_plan.json.skip）──" % len(skip_cards))
    for m in skip_cards:
        L.append("  %5d  %s —— %s" % (m["id"], m["name"], m.get("reason", "")))
    L.append("")
if report["cards"]["orphan"]:
    L.append("── _pending 孤儿 id（不在卡库）── " + " ".join(map(str, report["cards"]["orphan"])))
    L.append("")
if miss_icon:
    L.append("── 缺道具图标 ──")
    for m in miss_icon:
        L.append("  %5d  %s" % (m["id"], m["name"]))
if miss_rim:
    L.append("── 缺道具边缘光 ──")
    for m in miss_rim:
        L.append("  %5d  %s" % (m["id"], m["name"]))
for key, label in (("event", "事件插图 event_"), ("side", "事件竖版 side_"), ("bg", "事件背景 bg_")):
    if ev_missing[key]:
        L.append("── 缺 %s ──" % label)
        L.append("  " + "  ".join(ev_missing[key]))
if cls_missing:
    L.append("── 缺职业素材 ──")
    for m in cls_missing:
        L.append("  %-6s %s" % (m["class"], m["slot"]))
if node_missing:
    L.append("── 缺地图节点图标 ──")
    L.append("  " + "  ".join(node_missing))
if bgm_missing:
    L.append("── 缺 BGM ──")
    L.append("  " + "  ".join(bgm_missing))
if miss_ui:
    L.append("── 缺 UI 素材（代码引用但文件不在）──")
    for m in miss_ui:
        L.append("  %-30s ← %s" % (m["name"], ", ".join(m["used_in"])))

txt = "\n".join(L)
with io.open(rd("_preview", "asset_audit.txt"), "w", encoding="utf-8", newline="\n") as f:
    f.write(txt + "\n")
print(txt)
print()
print("明细：_preview/asset_audit.json")
