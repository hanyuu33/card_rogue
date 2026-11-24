# -*- coding: utf-8 -*-
"""R774d：状态飘字里的数字退回「共用伤害数字」（DmgNumber 五层笔法），撤掉数字素材。

三个文件行尾不同：
  status_badge.gd  LF
  battle_scene.gd  CRLF
  test_engine.gd   CRLF
一律按 bytes 读、bytes 替换，不碰行尾。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_bytes(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return f.read()


def write_bytes(rel, data):
    with open(os.path.join(ROOT, rel), "wb") as f:
        f.write(data)


def apply(rel, pairs):
    """pairs: [(旧 bytes, 新 bytes), ...]，每个必须恰好命中一次。"""
    data = read_bytes(rel)
    for i, (old, new) in enumerate(pairs):
        n = data.count(old)
        if n != 1:
            print("FAIL %s pair#%d count=%d" % (rel, i, n))
            print("  head:", repr(old[:120]))
            sys.exit(1)
        data = data.replace(old, new)
    write_bytes(rel, data)
    print("OK  %s (%d 处)" % (rel, len(pairs)))


L = b"\n"
C = b"\r\n"


def join(lines, eol):
    return eol.join(x.encode("utf-8") if isinstance(x, str) else x for x in lines)


# ══════════════════════════════════════════════════════ status_badge.gd（LF）
sb = "scripts/status_badge.gd"
sb_pairs = []

# ① 文件头：素材只剩状态词
sb_pairs.append((
    join([
        "## R774：状态特效文字的**绘制唯一口**。素材来自 AI 生成（`assets/fx/status_words/`、",
        "## `assets/fx/status_digits/`），字形用内嵌思源黑体渲染锁死、AI 只贡献质感，黑底已抠透明。",
    ], L),
    join([
        "## R774：状态特效文字的**绘制唯一口**。素材来自 AI 生成（`assets/fx/status_words/`），",
        "## 字形用内嵌思源黑体渲染锁死、AI 只贡献质感，黑底已抠透明。",
    ], L),
))

# ② 解析注释
sb_pairs.append((
    join([
        "## 文本解析：`_segments()` 把一条飘字拆成「状态词图 + 数字/符号图 + 兜底文字」片段，",
        "## 横向拼接（「中毒 -3」= 中毒.png + sign_minus.png + digit_3.png）。",
    ], L),
    join([
        "## 文本解析：`_segments()` 把一条飘字拆成「状态词图 + 数字段 + 兜底文字」片段，",
        "## 横向拼接（「中毒 -3」= 中毒.png + `DmgNumber.paint()` 画的 `-3`）。",
        "## ⚠️ R774d（店长口径「倒回去用之前共用的伤害数字」）：数字**不再贴素材** ——",
        "##    素材数字的字重跟 AI 艺术字对不上，摆一起像两个年代的 UI。数字一律走",
        "##    `DmgNumber.paint()` 的五层笔法，字号见 `_digit_px()`。",
    ], L),
))

# ③ 撤掉 DIGIT_TEX 常量，换成字号常量
old_digit = join([
    "## 数字 / 符号素材。",
    "const DIGIT_TEX := {",
    '\t"0": "res://assets/fx/status_digits/digit_0.png",',
    '\t"1": "res://assets/fx/status_digits/digit_1.png",',
    '\t"2": "res://assets/fx/status_digits/digit_2.png",',
    '\t"3": "res://assets/fx/status_digits/digit_3.png",',
    '\t"4": "res://assets/fx/status_digits/digit_4.png",',
    '\t"5": "res://assets/fx/status_digits/digit_5.png",',
    '\t"6": "res://assets/fx/status_digits/digit_6.png",',
    '\t"7": "res://assets/fx/status_digits/digit_7.png",',
    '\t"8": "res://assets/fx/status_digits/digit_8.png",',
    '\t"9": "res://assets/fx/status_digits/digit_9.png",',
    '\t"+": "res://assets/fx/status_digits/sign_plus.png",',
    '\t"-": "res://assets/fx/status_digits/sign_minus.png",',
    "}",
], L)
new_digit = join([
    "## R774d：数字 / 符号改由字体绘制（`DmgNumber.paint()`），`assets/fx/status_digits/`",
    "## 那 12 张素材已随本轮删除 —— 别再把它加回来当绘制路径。",
    "## 数字字号相对状态词高度 H 的倍率：思源黑体数字字面高 ≈ 0.72 倍字号，",
    "## 1.05H 落到视觉高 ≈ 0.76H，比状态词矮一档、不抢戏。",
    "const DIGIT_FONT_SCALE := 1.05",
], L)
sb_pairs.append((old_digit, new_digit))

# ④ _digit_h → _digit_px
old_h = join([
    "## 素材基准高度（px）。状态词 / 数字统一缩放到这个高度，按各自宽高比定宽。",
    "const BASE_H := 40.0",
    "## 数字相对状态词的高度倍率（数字单字符，略矮才不抢状态词的戏）。",
    "const DIGIT_H_SCALE := 0.82",
    "",
    "static func _digit_h(ch: String, H: float) -> float:",
    '\t## 符号 / 数字的高度：减号是细横条（比数字矮），加号是十字（略矮于数字）。',
    '\tif ch == "-":',
    "\t\treturn H * 0.24",
    '\tif ch == "+":',
    "\t\treturn H * 0.72",
    "\treturn H * DIGIT_H_SCALE",
], L)
new_h = join([
    "## 素材基准高度（px）。状态词缩放到这个高度，按宽高比定宽。",
    "const BASE_H := 40.0",
    "",
    "",
    "static func _digit_px(H: float) -> int:",
    "\t## 数字字号（字体绘制）。减号 / 加号不再单独定高 —— 字体自己排，横杠粗细随字号走。",
    "\treturn maxi(9, int(round(H * DIGIT_FONT_SCALE)))",
], L)
sb_pairs.append((old_h, new_h))

# ⑤ _push_chars：连续数字收成一段 num
old_push = join([
    "static func _push_chars(out: Array, s: String) -> void:",
    '\tvar buf := ""',
    "\tfor i in range(s.length()):",
    "\t\tvar c := s.substr(i, 1)",
    '\t\tif c == " " or c == "\\u3000":',
    '\t\t\tif buf != "":',
    '\t\t\t\tout.append({"kind": "text", "text": buf})',
    '\t\t\t\tbuf = ""',
    '\t\t\tout.append({"kind": "gap"})',
    '\t\telif c == "+" or c == "-" or (c >= "0" and c <= "9"):',
    '\t\t\tif buf != "":',
    '\t\t\t\tout.append({"kind": "text", "text": buf})',
    '\t\t\t\tbuf = ""',
    '\t\t\tout.append({"kind": "digit", "text": c})',
    "\t\telse:",
    "\t\t\tbuf += c",
    '\tif buf != "":',
    '\t\tout.append({"kind": "text", "text": buf})',
], L)
new_push = join([
    "static func _push_chars(out: Array, s: String) -> void:",
    "\t## R774d：连续的数字与 + / - **收入同一段 `num`** —— 交给 `DmgNumber.paint()`",
    "\t## 用字体整串排版（字距自然、字重与状态词同代），不再逐字符贴素材图。",
    '\tvar buf := ""',
    '\tvar num := ""',
    "\tfor i in range(s.length()):",
    "\t\tvar c := s.substr(i, 1)",
    '\t\tvar is_num := c == "+" or c == "-" or (c >= "0" and c <= "9")',
    "\t\tif is_num:",
    '\t\t\tif buf != "":',
    '\t\t\t\tout.append({"kind": "text", "text": buf})',
    '\t\t\t\tbuf = ""',
    "\t\t\tnum += c",
    "\t\t\tcontinue",
    '\t\tif num != "":',
    '\t\t\tout.append({"kind": "num", "text": num})',
    '\t\t\tnum = ""',
    '\t\tif c == " " or c == "\\u3000":',
    '\t\t\tout.append({"kind": "gap"})',
    "\t\telse:",
    "\t\t\tbuf += c",
    '\tif num != "":',
    '\t\tout.append({"kind": "num", "text": num})',
    '\tif buf != "":',
    '\t\tout.append({"kind": "text", "text": buf})',
], L)
sb_pairs.append((old_push, new_push))

# ⑥ paint 的 digit 分支 → num 分支（走 DmgNumber.paint）
old_seg = join([
    '\t\t\t"digit":',
    '\t\t\t\tvar tex := _tex(str(DIGIT_TEX[str(seg["text"])]))',
    '\t\t\t\tvar dh := _digit_h(str(seg["text"]), H)',
    "\t\t\t\tvar tw := float(tex.get_width()) * dh / float(tex.get_height())",
    "\t\t\t\tci.draw_texture_rect(tex, Rect2(x, y + (H - dh) * 0.5, tw, dh), false, mod)",
], L)
new_seg = join([
    '\t\t\t"num":',
    "\t\t\t\t# R774d：数字走共用伤害数字的笔法（外描边 / 厚度 / 字面 / 顶高光四层），",
    "\t\t\t\t# 与状态词并排时字重同代；配色仍走 DmgNumber.palette（默认暖白、特殊染色留色相）。",
    "\t\t\t\tDmgNumber.paint(ci, font, Vector2(x + w * 0.5, y + H * 0.5), _digit_px(H),",
    '\t\t\t\t\t\tstr(seg["text"]), alpha, DmgNumber.palette(DmgNumber.TIER_NORMAL, tint),',
    "\t\t\t\t\t\tDmgNumber.TIER_NORMAL)",
], L)
sb_pairs.append((old_seg, new_seg))

# ⑦ _seg_width 的 digit 分支
old_w = join([
    '\t\t"digit":',
    '\t\t\tvar tex := _tex(str(DIGIT_TEX[str(seg["text"])]))',
    '\t\t\tvar dh := _digit_h(str(seg["text"]), H)',
    "\t\t\treturn float(tex.get_width()) * dh / float(tex.get_height())",
], L)
new_w = join([
    '\t\t"num":',
    '\t\t\treturn font.get_string_size(str(seg["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1,',
    "\t\t\t\t\t_digit_px(H)).x",
], L)
sb_pairs.append((old_w, new_w))

apply(sb, sb_pairs)


# ══════════════════════════════════════════════════════ dmg_number.gd（LF）
dn = "scripts/dmg_number.gd"
dn_pairs = []

dn_pairs.append((
    join([
        "## ⚠️ 这里的函数**一律不许有副作用**（不读节点、不读时钟），`t` 由调用方传进来；",
        "##    `test_engine` 的 R770 段落直接喂数值断言曲线，不构造场景。",
    ], L),
    join([
        "## ⚠️ 这里的函数**一律不许有副作用**（不读节点、不读时钟），`t` 由调用方传进来；",
        "##    `test_engine` 的 R770 段落直接喂数值断言曲线，不构造场景。",
        "##    唯一例外是 `paint()` —— 它要在调用方的 `_draw()` 里落笔，只画不改状态。",
    ], L),
))

dn_pairs.append((
    join([
        "static func preview_size(tier: int) -> int:",
    ], L),
    join([
        "## ---------------------------------------------------------------- 绘制",
        "static func paint(ci: CanvasItem, font: Font, center: Vector2, px: int, text: String,",
        "\t\talpha: float, pal: Dictionary, tier: int) -> void:",
        "\t## R770 的五层笔法，**R774d 起是唯一实现**（从 battle_scene 搬进来）：",
        "\t##   ① 柔和辉光 —— 重击以上才开（普通伤害加光会糊，反而看不清数值）",
        "\t##   ② 外描边（暗）—— 把数字从任何底图上「抠」出来，这是 GBF 观感的地基",
        "\t##   ③ 厚度层 —— 往下错开半个笔宽，露出下缘的实体感",
        "\t##   ④ 字面",
        "\t##   ⑤ 顶高光 —— 整字上移一小截 + 半透白，上缘最亮、下缘仍是 core（伪渐变）",
        "\t##",
        "\t## **故意不自带变换**：`center` 就是调用方那套空间的坐标 —— 飘字在屏幕空间",
        "\t## （要叠震动）、拖卡预览在棋盘空间（缩放与滚动都没复位），硬塞进来必然错位。",
        "\t## 状态特效文字（StatusBadge）后面的数字也走这一口，两边不许各写一份。",
        "\tif alpha <= 0.004:",
        "\t\treturn",
        "\tvar p := maxi(8, px)",
        '\tvar core: Color = pal["core"]',
        '\tvar depth: Color = pal["depth"]',
        '\tvar edge: Color = pal["edge"]',
        '\tvar hi: Color = pal["hi"]',
        "\tvar w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, p).x",
        "\tvar origin := center + Vector2(-w * 0.5, float(p) * 0.36)",
        "\tvar ow := outline_width(p)",
        "\tif tier >= TIER_HEAVY and alpha > 0.2:",
        "\t\tvar gr := float(p) * 1.35",
        "\t\tfor i in 3:",
        "\t\t\tvar k := 1.0 - 0.26 * float(i)",
        "\t\t\tci.draw_circle(origin + Vector2(0.0, -float(p) * 0.06), gr * k,",
        "\t\t\t\t\tColor(core.r, core.g, core.b, 0.042 * alpha))",
        "\tci.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, p, ow,",
        "\t\t\tColor(edge.r, edge.g, edge.b, alpha * 0.95))",
        "\tci.draw_string(font, origin + Vector2(0.0, float(ow) * 0.45), text,",
        "\t\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, p, Color(depth.r, depth.g, depth.b, alpha))",
        "\tci.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, p,",
        "\t\t\tColor(core.r, core.g, core.b, alpha))",
        "\tci.draw_string(font, origin - Vector2(0.0, float(ow) * 0.28), text,",
        "\t\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, p, Color(hi.r, hi.g, hi.b, hi.a * alpha))",
        "",
        "",
        "static func preview_size(tier: int) -> int:",
    ], L),
))

apply(dn, dn_pairs)


# ══════════════════════════════════════════════════════ battle_scene.gd（CRLF）
bs = "scripts/battle_scene.gd"
bs_pairs = []

old_body = join([
    "func _paint_dmg_number(font: Font, center: Vector2, px: int, text: String, alpha: float,",
    "\t\tpal: Dictionary, tier: int) -> void:",
    "\t## R770：GBF 风伤害数字的笔法（**不加变换**：调用方负责，`center` 就是它那套空间的坐标）。",
    "\t## 为什么不做成自带变换：飘字在屏幕空间（要叠震动）、拖卡预览在棋盘空间",
    "\t## （缩放 + 滚动都还没复位），两套调用方坐标语义不同，硬塞进来必然错位。",
    "\t##",
    "\t## 从下往上五层：",
    "\t##   ① 柔和辉光 —— 重击以上才开（普通伤害加光会糊，反而看不清数值）",
    "\t##   ② 外描边（暗）—— 把数字从任何底图上「抠」出来，这是 GBF 观感的地基",
    "\t##   ③ 厚度层 —— 往下错开半个笔宽，露出下缘的实体感",
    "\t##   ④ 字面",
    "\t##   ⑤ 顶高光 —— 整字上移一小截 + 半透白，上缘最亮、下缘仍是 core，形成伪渐变",
    "\tif px < 8:",
    "\t\tpx = 8",
    '\tvar core: Color = pal["core"]',
    '\tvar depth: Color = pal["depth"]',
    '\tvar edge: Color = pal["edge"]',
    '\tvar hi: Color = pal["hi"]',
    "\tvar w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x",
    "\tvar origin := center + Vector2(-w * 0.5, float(px) * 0.36)",
    "\tvar ow := DmgNumber.outline_width(px)",
    "\tif tier >= DmgNumber.TIER_HEAVY and alpha > 0.2:",
    "\t\tvar gr := float(px) * 1.35",
    "\t\tfor i in 3:",
    "\t\t\tvar k := 1.0 - 0.26 * float(i)",
    "\t\t\tdraw_circle(origin + Vector2(0.0, -float(px) * 0.06), gr * k,",
    "\t\t\t\t\tColor(core.r, core.g, core.b, 0.042 * alpha))",
    "\tdraw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ow,",
    "\t\t\tColor(edge.r, edge.g, edge.b, alpha * 0.95))",
    "\tdraw_string(font, origin + Vector2(0.0, float(ow) * 0.45), text,",
    "\t\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(depth.r, depth.g, depth.b, alpha))",
    "\tdraw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,",
    "\t\t\tColor(core.r, core.g, core.b, alpha))",
    "\tdraw_string(font, origin - Vector2(0.0, float(ow) * 0.28), text,",
    "\t\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(hi.r, hi.g, hi.b, hi.a * alpha))",
], C)

new_body = join([
    "func _paint_dmg_number(font: Font, center: Vector2, px: int, text: String, alpha: float,",
    "\t\tpal: Dictionary, tier: int) -> void:",
    "\t## R770：GBF 风伤害数字的笔法 —— **R774d 起唯一实现在 `DmgNumber.paint()`**。",
    "\t## 留这一层只是为了不动调用点（飘字 / 拖卡预览两处坐标语义不同），内部纯转发。",
    "\t## ⚠️ 仍然不加变换：`center` 由调用方按自己那套空间算好再传进来。",
    "\tDmgNumber.paint(self, font, center, px, text, alpha, pal, tier)",
], C)

bs_pairs.append((old_body, new_body))
apply(bs, bs_pairs)


# ══════════════════════════════════════════════════════ test_engine.gd（CRLF）
te = "scripts/test_engine.gd"
te_pairs = []

old_t = join([
    "\t# 数字 0-9 + 符号 + - 都要有素材",
    '\tvar r774_dig := ""',
    '\tfor r774_c: String in "0123456789+-":',
    "\t\tif not StatusBadge.DIGIT_TEX.has(r774_c):",
    '\t\t\tr774_dig += r774_c + " "',
    '\tcheck(r774_dig == "", "R774 素材：数字/符号素材齐全（缺 %s）" % r774_dig)',
    "\t# 解析：中毒 -3 → word(中毒) + gap + digit(-) + digit(3)",
    '\tvar r774_seg := StatusBadge._segments("中毒 -3")',
    "\tcheck(r774_seg.size() == 4 and str(r774_seg[0][\"kind\"]) == \"word\"",
    "\t\t\tand int(r774_seg[0][\"glyph\"]) == StatusBadge.GLYPH_POISON,",
    '\t\t\t"R774 解析：中毒 -3 首段是「中毒」状态词")',
    '\tcheck(str(r774_seg[2]["kind"]) == "digit" and str(r774_seg[2]["text"]) == "-"',
    '\t\t\tand str(r774_seg[3]["kind"]) == "digit" and str(r774_seg[3]["text"]) == "3",',
    '\t\t\t"R774 解析：-3 拆成符号与数字两张图")',
], C)

new_t = join([
    "\t# R774d（店长口径「倒回去用之前共用的伤害数字」）：",
    "\t# 状态飘字里的数字不再贴素材，改由 DmgNumber.paint() 的字体五层笔法绘制。",
    "\t# ① 撤干净：源码里不许再出现数字素材常量（残留 = 还有别的绘制路径在用）",
    '\tvar r774d_sb := FileAccess.get_file_as_string("res://scripts/status_badge.gd")',
    '\tcheck_src(r774d_sb.find("DIGIT_TEX") < 0,',
    '\t\t\t"R774d 撤素材：StatusBadge 不再引用 DIGIT_TEX（数字走 DmgNumber 笔法）")',
    "\t# ② 数字委托：状态飘字的数字必须真调 DmgNumber.paint（换回贴图会静默退步）",
    '\tcheck_src(r774d_sb.find("DmgNumber.paint(") >= 0,',
    '\t\t\t"R774d 共用：状态飘字的数字走 DmgNumber.paint（与伤害数字同一实现）")',
    "\t# ③ 解析：中毒 -3 → word(中毒) + gap + num(-3)（整串一段，交给字体排版）",
    '\tvar r774_seg := StatusBadge._segments("中毒 -3")',
    "\tcheck(r774_seg.size() == 3 and str(r774_seg[0][\"kind\"]) == \"word\"",
    "\t\t\tand int(r774_seg[0][\"glyph\"]) == StatusBadge.GLYPH_POISON,",
    '\t\t\t"R774 解析：中毒 -3 首段是「中毒」状态词")',
    '\tcheck(str(r774_seg[2]["kind"]) == "num" and str(r774_seg[2]["text"]) == "-3",',
    '\t\t\t"R774d 解析：-3 收成一段 num（不再逐字符贴素材）")',
], C)

te_pairs.append((old_t, new_t))
apply(te, te_pairs)

print("\nALL PATCHED")
