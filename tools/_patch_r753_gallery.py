# -*- coding: utf-8 -*-
"""R753：图鉴锁只属于发布版，测试版默认全解锁。"""
import io, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GS = os.path.join(ROOT, "scripts", "gallery_scene.gd")
TE = os.path.join(ROOT, "scripts", "test_engine.gd")


def read(p):
    with io.open(p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def rep(s, old, new, tag):
    n = s.count(old)
    if n != 1:
        print("FAIL[%s] count=%d" % (tag, n))
        print("anchor repr:", repr(old[:120]))
        sys.exit(1)
    print("OK[%s]" % tag)
    return s.replace(old, new)


# ---------------------------------------------------------------- gallery_scene.gd
gs = read(GS)
assert "\r\n" not in gs, "gallery_scene.gd 应为 LF"

gs = rep(gs,
    "# 店长口径：**发布版**图鉴只列「见过」的卡 —— 没见过的连条目都没有、搜也搜不到；\n"
    "# 全卡开（测试版）时全部位置都排出来，没见过的画成一张**通用未解锁图**。\n"
    "# 「见过」的记账在 `CardFace.draw() / draw_pick()`（唯一口），见 `ProfileData`。\n",
    "# 店长口径（R642，R753 修订）：\n"
    "#   * **发布版**：只列「见过」的卡 —— 没见过的连条目都没有、搜也搜不到；\n"
    "#   * **测试版**：图鉴**默认全解锁**（R753）。以前这里会把没见过的位置排出来再遮成\n"
    "#     「通用未解锁图」，开发自测时反而挡路 —— 现在一把全开，不遮了。\n"
    "# 「见过」的记账在 `CardFace.draw() / draw_pick()`（唯一口），见 `ProfileData`：\n"
    "# 照记不误（发布版要用），只是测试版读的时候不看。\n",
    "header")

gs = rep(gs,
    "func _locked(c: CardData) -> bool:\n"
    "\t## 只有全卡开才可能为真：位置排出来了，但玩家还没见过 → 遮蔽成通用图。\n"
    "\t## 发布版里未见的卡在 `_visible()` 就被挡掉，走不到这里。\n"
    "\treturn not ProfileData.is_card_seen(c.id)\n",
    "static func gallery_locked(c: CardData, release_mode: bool) -> bool:\n"
    "\t## R753：**锁只属于发布版**。测试版一律不锁 —— 图鉴就是开发时的全卡清单。\n"
    "\t## 与 `gallery_visible()` 同规格抽成静态，测试可以直接调，不必实例化场景。\n"
    "\tif not release_mode:\n"
    "\t\treturn false\n"
    "\treturn not ProfileData.is_card_seen(c.id)\n"
    "\n"
    "\n"
    "func _locked(c: CardData) -> bool:\n"
    "\t## 这张卡要不要遮成通用未解锁图。发布版里未见的卡在 `_visible()` 就先被挡掉了，\n"
    "\t## 所以正常路径走不到这一支 —— 留着是给「发布版哪天改成露空位」兜底。\n"
    "\treturn gallery_locked(c, GameBuild.is_release())\n",
    "locked-fn")

gs = rep(gs,
    "\t\t# 全卡开才有的一层：未解锁的只在默认视图占位，一旦筛选 / 搜索就退出。\n",
    "\t\t# 占位层（R642）：未解锁的只在默认视图出现，一旦筛选 / 搜索就退出。\n"
    "\t\t# R753 起测试版恒不锁，这一支实际只对发布版（且理论不可达）有效。\n",
    "filter-comment")

gs = rep(gs,
    "\telse:\n"
    "\t\tsummary = GameI18n.ui(\"map\", \"GALLERY_SUMMARY_TEST\", \"%s · 共 %d 种卡牌\") % [_group_title(), _shown.size()]\n"
    "\t\tvar gc2 := _group_counts()\n"
    "\t\tvar unknown_n := int(gc2[0]) - int(gc2[1])\n"
    "\t\tif unknown_n > 0 and not _has_active_filter():\n"
    "\t\t\tsummary += GameI18n.ui(\"map\", \"GALLERY_SUMMARY_LOCKED\", \"（其中 %d 张未解锁）\") % unknown_n\n",
    "\telse:\n"
    "\t\t# R753：测试版图鉴全解锁 → 不再报「其中 N 张未解锁」。\n"
    "\t\t# 那句话此刻会跟满格可见的卡面自相矛盾（锁都取消了，还报几个锁着）。\n"
    "\t\tsummary = GameI18n.ui(\"map\", \"GALLERY_SUMMARY_TEST\", \"%s · 共 %d 种卡牌\") % [_group_title(), _shown.size()]\n",
    "summary")

gs = rep(gs,
    "\t\t# R642：全卡开时未解锁的位置画**通用未解锁图**，不泄露卡名 / 数值 / 卡图。\n",
    "\t\t# R642：未解锁的位置画**通用未解锁图**，不泄露卡名 / 数值 / 卡图。\n"
    "\t\t# R753：测试版 `_locked()` 恒 false → 走不到这一支。\n",
    "grid-comment")

write(GS, gs)

# ---------------------------------------------------------------- test_engine.gd
te = read(TE)
crlf = "\r\n" in te
lines = te.split("\n")
print("test_engine crlf =", crlf)

# ① 改 R642 ② 的断言文案（结论不变，理由变了）
idx = None
for i, ln in enumerate(lines):
    if "R642 判据：全卡开仍然全部可见，交给绘制层遮蔽成通用未解锁图" in ln:
        idx = i
        break
assert idx is not None, "找不到 R642 ② 断言行"
lines[idx] = lines[idx].replace(
    "全卡开仍然全部可见，交给绘制层遮蔽成通用未解锁图",
    "全卡开仍然全部可见（R753 起测试版直接全解锁，不再遮蔽）")
print("OK[te-assert-text] line", idx + 1)

# ② 断言块后面插入 R753 三段
anchor = None
for i, ln in enumerate(lines):
    if "check(r642_gs.gallery_visible(r642_new_card, false)" in ln:
        anchor = i
        break
assert anchor is not None, "找不到 gallery_visible(new, false) 断言"

eol = "\r" if crlf else ""
block = [
    "",
    "\t# ---- R753（店长口径「图鉴锁只用于发布版，测试版默认全解锁」）----",
    "",
    "\t# ① 同一张没见过的卡：测试版不锁、发布版锁",
    "\tcheck(not r642_gs.gallery_locked(r642_new_card, false),",
    "\t\t\t\"R753 判据：测试版图鉴默认全解锁（没见过的卡也不遮成问号）\")",
    "\tcheck(r642_gs.gallery_locked(r642_new_card, true)",
    "\t\t\tand not r642_gs.gallery_locked(r642_seen_card, true),",
    "\t\t\t\"R753 判据：发布版仍然「没见过就锁」\")",
    "",
    "\t# ② 源码锁：锁的判定必须挂在 GameBuild 版本闸门上，不许再无条件按「见过」判",
    "\tvar r753_gs_src := FileAccess.get_file_as_string(\"res://scripts/gallery_scene.gd\")",
    "\tcheck_src(r753_gs_src.contains(\"static func gallery_locked(\")",
    "\t\t\tand r753_gs_src.contains(\"return gallery_locked(c, GameBuild.is_release())\")",
    "\t\t\t\"R753 源码锁：`_locked()` 走 `gallery_locked(c, GameBuild.is_release())`\")",
    "\t# ③ 测试版不再报「其中 N 张未解锁」",
    "\tcheck_src(not r753_gs_src.contains(\"GALLERY_SUMMARY_LOCKED\"),",
    "\t\t\t\"R753 源码锁：测试版顶栏不再报未解锁张数\")",
]
new_lines = lines[:anchor + 1] + [b + eol for b in block] + lines[anchor + 1:]
write(TE, "\n".join(new_lines))
print("OK[te-block] inserted after line", anchor + 1)

# --- 复核
gs2 = read(GS)
te2 = read(TE)
print("gs has gallery_locked:", "static func gallery_locked(" in gs2)
print("gs old locked body gone:", "return not ProfileData.is_card_seen(c.id)\n" not in gs2)
print("gs SUMMARY_LOCKED gone:", "GALLERY_SUMMARY_LOCKED" not in gs2)
print("te crlf preserved:", ("\r\n" in te2) == crlf)
print("te lock block:", "R753 判据：测试版图鉴默认全解锁" in te2)
print("te gallery_locked call:", "r642_gs.gallery_locked(r642_new_card, false)" in te2)
