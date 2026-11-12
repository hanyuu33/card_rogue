# -*- coding: utf-8 -*-
"""R614 补丁（可重放，带 count==1 断言）。

用户口径（2026-11-12）：
  1. 「文本依然有冗余描述。传授的效果只需要：从全职业卡池组合一张卡。」
     → 8084/8085/8086 的 effect_text 缩成一句，删掉「6 张候选卡怎么拖」的说明书，
       以及「字段「次元」：…」这句尾注（R600 起字段解释只在字段框 / 词条浮窗）。
  2. 「这一批组合卡加了次元之后都漏了文本描述次元」
     → 不是要把它写回正文，而是让**「次元」「组合」在显示层查得到**。
  3. 「确保在商店、奖励卡、查看完整卡组界面都能联系到组合这个词条」
     → 商店 / 奖励卡已有字段浮窗（R444）；完整卡组等区域面板会盖住左栏信息面板，
       所以在面板之上补画一层解释浮窗。

落地：
  · cards.json        ：三张传授卡正文 → 「从全职业卡池组合一张卡。」
  · card_data.gd      ：新增 MECH_KEYWORDS（机制词条表，与 affixes 分开）+ word_def()
                        + CardData.mech_keywords()；affix_label/desc/glyph/colors 走 word_def
  · card_face.gd      ：affix_index_items() 把机制词条并进浮窗
  · battle_scene.gd   ：_info_blocks() 加词条框；区域面板之上补画解释浮窗（_hover_zone_rect）
  · test_assemble.gd  ：R592 的「正文末句」文本锁 → 换成显示层判据 + 源码锁
  · test_smoke.gd     ：R444 浮窗测试补一条 8084 = 「次元」+「组合」

用法：python tools/_patch_r614.py --check-only   # 只校验，不落盘
      python tools/_patch_r614.py                # 落盘
"""
import sys

CHECK = "--check-only" in sys.argv

NEW_TEXT = "从全职业卡池组合一张卡。"

# ---------------------------------------------------------------- 1. cards.json
CARDS_OLD = ("组合一张盟友/工事卡：从随机 6 张候选卡中拖 3 张，分别决定属性值、"
             "上半效果、下半效果；生成的卡带「组合」印记。字段「次元」：打出后消失，不进弃牌区。")


def patch_cards(check):
    p = "cards.json"
    s = open(p, "r", encoding="utf-8", newline="").read()
    n = s.count(CARDS_OLD)
    print(f"[cards.json] 命中 {n} 处（期望 3）")
    assert n == 3, n
    if check:
        return
    s = s.replace(CARDS_OLD, NEW_TEXT)
    open(p, "w", encoding="utf-8", newline="").write(s)
    b = open(p, "rb").read()
    crlf = b.count(b"\r\n")
    print(f"[cards.json] 写出 crlf={crlf} bare={b.count(chr(10).encode()) - crlf}")


# ------------------------------------------------------- 2. card_data.gd（CRLF）
CD_AFFIX_TAIL = ('"共享护盾": {"label": "共享护盾", "desc": "我方 HP 要受到伤害时，'
                 '改由这张卡承受（每次都能顶，顶到它死亡）。", "glyph": "share", '
                 '"bg": "33161c", "fg": "ff8fa8"},\r\n}')

CD_NEW_BLOCK = '''"共享护盾": {"label": "共享护盾", "desc": "我方 HP 要受到伤害时，改由这张卡承受（每次都能顶，顶到它死亡）。", "glyph": "share", "bg": "33161c", "fg": "ff8fa8"},
}

## ── 【机制词条】（R614）正文里会提到、但**不是字段**的机制名 ──
##
## 和字段的分工：
##   * `AFFIX_DEFS`  = **持久状态**。进卡面右上圆槽、战场徽标、引擎判据（`affixes` 数组）。
##   * `MECH_KEYWORDS` = **一次性流程的名字**。没有状态可挂，不进 `affixes`。
##
## 「组合」为什么不能塞进 `AFFIX_DEFS`（R559 踩过）：`add_affix("组合")` 之后卡面立刻多出
## 一条 buff 条 + 一枚不存在的「状态」图标（`_draw_affix_badges`），而那根本不是状态。
## 但它同样需要「玩家能查到解释」——所以单独一张表，**与字段共用同一套解释浮窗 / 词条框**
## （`CardFace.affix_index_items()` 与 `BattleScene._info_blocks()` 都读 `word_def()`）。
##
## 用户口径（R614）：「确保在商店、奖励卡、查看完整卡组界面都能联系到组合这个词条。」
const MECH_KEYWORDS: Dictionary = {
\t"组合": {"label": "组合", "desc": "从随机 6 张候选卡中拖 3 张，分别决定属性值、上半效果、下半效果，生成一张带「组合」金印的新卡。", "glyph": "combine", "bg": "2b2410", "fg": "ffd76e"},
}


## 字段 / 机制词条的**统一解释查询**：先 AFFIX_DEFS，再 MECH_KEYWORDS。
## 新增一个「正文里查得到」的机制名时，只改 `MECH_KEYWORDS` 一处。
static func word_def(name: String) -> Dictionary:
\tvar d: Dictionary = AFFIX_DEFS.get(name, {})
\tif not d.is_empty():
\t\treturn d
\treturn MECH_KEYWORDS.get(name, {})'''

CD_OLD_LABEL = '''static func affix_label(name: String) -> String:
\tvar d: Dictionary = AFFIX_DEFS.get(name, {})'''
CD_NEW_LABEL = '''static func affix_label(name: String) -> String:
\tvar d: Dictionary = word_def(name)'''

CD_OLD_DESC = '''static func affix_desc(name: String) -> String:
\tvar d: Dictionary = AFFIX_DEFS.get(name, {})'''
CD_NEW_DESC = '''static func affix_desc(name: String) -> String:
\tvar d: Dictionary = word_def(name)'''

CD_OLD_GLYPH = '''static func affix_glyph(name: String) -> String:
\tvar d: Dictionary = AFFIX_DEFS.get(name, {})'''
CD_NEW_GLYPH = '''static func affix_glyph(name: String) -> String:
\tvar d: Dictionary = word_def(name)'''

CD_OLD_COLORS = '''static func affix_colors(name: String) -> Array:
\tvar d: Dictionary = AFFIX_DEFS.get(name, {})'''
CD_NEW_COLORS = '''static func affix_colors(name: String) -> Array:
\tvar d: Dictionary = word_def(name)'''

CD_OLD_LINE = '''## 卡面上要追加的那一行字段提示（引擎在卡被赋予新字段后会自动补上 ——
## 因为它改的就是 `affixes` 这个数组）。
func affix_line() -> String:'''
CD_NEW_LINE = '''## 这张卡**正文里提到**的机制词条（按 `MECH_KEYWORDS` 顺序，去重）。
## 为什么按正文命中、而不是按数据挂载：这些名字没有持久状态（见 `MECH_KEYWORDS` 的说明），
## 但卡面写着它，玩家就得能查到解释 —— 商店 / 奖励卡 / 完整卡组的浮窗都读这里。
func mech_keywords() -> Array[String]:
\tvar out: Array[String] = []
\tfor k: String in MECH_KEYWORDS:
\t\tif effect_text.contains(k) and not out.has(k):
\t\t\tout.append(k)
\treturn out


## 卡面上要追加的那一行字段提示（引擎在卡被赋予新字段后会自动补上 ——
## 因为它改的就是 `affixes` 这个数组）。
func affix_line() -> String:'''


def patch_card_data(check):
    p = "scripts/card_data.gd"
    s = open(p, "r", encoding="utf-8", newline="").read()

    def c(x):
        # 统一成 CRLF（本文件是 CRLF）：先压成 LF 再整体还原，避免半 LF 半 CRLF
        return x.replace("\r\n", "\n").replace("\n", "\r\n")

    for old, new in [(CD_AFFIX_TAIL, CD_NEW_BLOCK),
                     (CD_OLD_LABEL, CD_NEW_LABEL),
                     (CD_OLD_DESC, CD_NEW_DESC),
                     (CD_OLD_GLYPH, CD_NEW_GLYPH),
                     (CD_OLD_COLORS, CD_NEW_COLORS),
                     (CD_OLD_LINE, CD_NEW_LINE)]:
        old, new = c(old), c(new)
        assert s.count(old) == 1, (old[:40], s.count(old))
        s = s.replace(old, new)
    print("[card_data.gd] 6 处锚点全部命中")
    if check:
        return
    open(p, "w", encoding="utf-8", newline="").write(s)
    b = open(p, "rb").read()
    crlf = b.count(b"\r\n")
    print(f"[card_data.gd] crlf={crlf} bare={b.count(chr(10).encode()) - crlf}")


# ------------------------------------------------------- 3. card_face.gd（LF）
CF_OLD = '''\tvar body_w: float = box_w - AFFIX_INDEX_PAD * 2.0
\tfor a: String in card.affixes:
\t\tvar desc := CardData.affix_desc(a)'''
CF_NEW = '''\tvar body_w: float = box_w - AFFIX_INDEX_PAD * 2.0
\t# R614：字段 + **机制词条**（「组合」这类：不是 affixes、没有状态可挂，但正文里出现、
\t# 玩家同样要能查到解释）。两者共用同一块浮窗，所以先并成一条名字流再画。
\tvar names: Array[String] = []
\tfor a: String in card.affixes:
\t\tnames.append(a)
\tfor kw: String in card.mech_keywords():
\t\tif not names.has(kw):
\t\t\tnames.append(kw)
\tfor a: String in names:
\t\tvar desc := CardData.affix_desc(a)'''


def patch_card_face(check):
    p = "scripts/card_face.gd"
    s = open(p, "r", encoding="utf-8", newline="").read()
    assert s.count(CF_OLD) == 1, s.count(CF_OLD)
    s = s.replace(CF_OLD, CF_NEW)
    print("[card_face.gd] 浮窗并入机制词条")
    if check:
        return
    open(p, "w", encoding="utf-8", newline="").write(s)
    b = open(p, "rb").read()
    crlf = b.count(b"\r\n")
    print(f"[card_face.gd] crlf={crlf} bare={b.count(chr(10).encode()) - crlf}")


# -------------------------------------------------- 4. battle_scene.gd（CRLF）
BS_OLD_HOVER_VAR = "var _hover_card: CardData = null  # 鼠标悬停的卡（左侧信息栏优先显示）"
BS_NEW_HOVER_VAR = ("var _hover_card: CardData = null  # 鼠标悬停的卡（左侧信息栏优先显示）\r\n"
                    "var _hover_zone_rect := Rect2()  # R614：区域面板里悬停那张卡的矩形"
                    "（解释浮窗贴它画，见 `_draw()` 末尾）")

BS_OLD_CLEAR = ("\t_hover_card = null\r\n"
                "\t_hover_pl = null\r\n"
                "\t_hover_hand = -1\r\n")
BS_NEW_CLEAR = ("\t_hover_card = null\r\n"
                "\t_hover_pl = null\r\n"
                "\t_hover_hand = -1\r\n"
                "\t_hover_zone_rect = Rect2()   # R614：跟着一起清，否则浮窗会留在屏幕上\r\n")

BS_OLD_ZONE = ("\t\t\tif zr.has_point(pos):\r\n"
               "\t\t\t\tvar zc: CardData = zp[i]\r\n"
               "\t\t\t\t_hover_card = zc\r\n")
BS_NEW_ZONE = ("\t\t\tif zr.has_point(pos):\r\n"
               "\t\t\t\tvar zc: CardData = zp[i]\r\n"
               "\t\t\t\t_hover_card = zc\r\n"
               "\t\t\t\t_hover_zone_rect = zr   # R614：解释浮窗要贴这张卡画\r\n")

BS_OLD_BLOCKS = ("\t\t\t\"segs\": [{\"text\": CardData.affix_label(a), \"bold\": true},\r\n"
                 "\t\t\t\t\t{\"text\": \"：\" + CardData.affix_desc(a)}],\r\n"
                 "\t\t})\r\n")
BS_NEW_BLOCKS = ("\t\t\t\"segs\": [{\"text\": CardData.affix_label(a), \"bold\": true},\r\n"
                 "\t\t\t\t\t{\"text\": \"：\" + CardData.affix_desc(a)}],\r\n"
                 "\t\t})\r\n"
                 "\t# R614：机制词条（「组合」）—— 和字段同一套框，但名字来自 `MECH_KEYWORDS`\r\n"
                 "\t#   （按正文命中，不是 `affixes`；进 `affixes` 会被画成假 buff，R559 踩过）。\r\n"
                 "\tfor kw: String in card.mech_keywords():\r\n"
                 "\t\tvar kc := CardData.affix_colors(kw)\r\n"
                 "\t\tout.append({\r\n"
                 "\t\t\t\"type\": \"line\", \"kind\": \"affix\",\r\n"
                 "\t\t\t\"glyph\": CardData.affix_glyph(kw),\r\n"
                 "\t\t\t\"col\": (kc[1] as Color).darkened(0.30),\r\n"
                 "\t\t\t\"title\": CardData.affix_label(kw),\r\n"
                 "\t\t\t\"segs\": [{\"text\": CardData.affix_label(kw), \"bold\": true},\r\n"
                 "\t\t\t\t\t{\"text\": \"：\" + CardData.affix_desc(kw)}],\r\n"
                 "\t\t})\r\n")

BS_OLD_DRAW = ("\t\t\t\t_zone_panel_cards(), _zone_panel_counts())\r\n"
               "\tif _relics_visible:\r\n")
BS_NEW_DRAW = ("\t\t\t\t_zone_panel_cards(), _zone_panel_counts())\r\n"
               "\t# R614：区域面板（完整卡组 / 牌堆 / 消耗区 / 效果区）会盖住左栏信息面板 ——\r\n"
               "\t#   卡组一多 `pw` 几乎满屏（实测 30 张时 px≈73，左栏被整个吃掉），\r\n"
               "\t#   悬停那张卡的「字段 / 机制词条」解释必须画在面板**之上**，\r\n"
               "\t#   否则玩家在「查看完整卡组」里永远查不到「次元」「组合」是什么。\r\n"
               "\t#   底下一层（左栏 `_draw_info_panel()`）留着：卡组小时两处都看得到，不冲突。\r\n"
               "\tif _hover_card != null and _hover_zone_rect.size.x > 0.0:\r\n"
               "\t\tCardFace.draw_affix_index(self, _hover_card, _hover_zone_rect, _font, _font_bold,\r\n"
               "\t\t\t\t172.0, Rect2(0.0, 0.0, WINDOW_W, WINDOW_H))\r\n"
               "\tif _relics_visible:\r\n")


def patch_battle(check):
    p = "scripts/battle_scene.gd"
    s = open(p, "r", encoding="utf-8", newline="").read()
    for old, new in [(BS_OLD_HOVER_VAR, BS_NEW_HOVER_VAR),
                     (BS_OLD_CLEAR, BS_NEW_CLEAR),
                     (BS_OLD_ZONE, BS_NEW_ZONE),
                     (BS_OLD_BLOCKS, BS_NEW_BLOCKS),
                     (BS_OLD_DRAW, BS_NEW_DRAW)]:
        assert s.count(old) == 1, (old[:50], s.count(old))
        s = s.replace(old, new)
    print("[battle_scene.gd] 5 处锚点全部命中")
    if check:
        return
    open(p, "w", encoding="utf-8", newline="").write(s)
    b = open(p, "rb").read()
    crlf = b.count(b"\r\n")
    print(f"[battle_scene.gd] crlf={crlf} bare={b.count(chr(10).encode()) - crlf}")


# -------------------------------------------------- 5. test_assemble.gd（LF）
TA_OLD = '''\tvar rows := {
\t\t8084: "打出后消失", 8085: "打出后消失", 8086: "打出后消失",
\t\t9191: "打出后消失", 9193: "打出后消失",
\t\t9246: "离场即消失", 9247: "离场即消失",
\t}
\tfor cid: int in rows:
\t\tvar c: CardData = repo.get_card(cid)
\t\tcheck(c.has_affix("次元"),
\t\t\t\t"R592：%d %s 必须带「次元」" % [cid, c.card_name])
\t\tvar tail: String = "字段「次元」：%s，不进弃牌区。" % str(rows[cid])
\t\tcheck(c.effect_text.ends_with(tail),
\t\t\t\t"R592：%d %s 卡面末句应为「%s」（实际「%s」）"
\t\t\t\t% [cid, c.card_name, tail, c.effect_text])
'''
TA_NEW = '''\tvar ids: Array[int] = [8084, 8085, 8086, 9191, 9193, 9246, 9247]
\tfor cid: int in ids:
\t\tvar c: CardData = repo.get_card(cid)
\t\tcheck(c.has_affix("次元"),
\t\t\t\t"R592：%d %s 必须带「次元」" % [cid, c.card_name])
\t\t# R614（用户口径「文本依然有冗余描述」）：正文**不再**写「字段「次元」：…」这一句。
\t\t#   原来这里锁的是「卡面末句必须是那句」，现在改成锁**显示层查得到** ——
\t\t#   悬停浮窗必须能给出「次元」和「组合」的解释，否则缩了正文就等于丢了信息。
\t\tcheck(CardData.affix_desc("次元") != "" and CardData.affix_desc("组合") != "",
\t\t\t\t"R614：「次元」「组合」都要有解释文案（浮窗 / 词条框共用 `word_def()`）")
\t\tcheck(c.mech_keywords().has("组合"),
\t\t\t\t"R614：%d %s 正文提到「组合」，`mech_keywords()` 必须认出来"
\t\t\t\t% [cid, c.card_name])

\t# R614：解释浮窗必须真的把机制词条画出来（源码锁 —— 防止只加数据不接显示）
\tvar cf := FileAccess.get_file_as_string("res://scripts/card_face.gd")
\tcheck(cf.find("for kw: String in card.mech_keywords()") >= 0,
\t\t\t"R614：字段浮窗并入机制词条（商店 / 奖励卡能查到「组合」）")
\tvar bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
\tcheck(bs.find("CardFace.draw_affix_index(self, _hover_card, _hover_zone_rect") >= 0,
\t\t\t"R614：完整卡组等区域面板悬停时补画解释浮窗")
\t# 三张传授卡正文只剩一句（用户口径「只需要：从全职业卡池组合一张卡。」）
\tfor tid: int in [8084, 8085, 8086]:
\t\tvar tc: CardData = repo.get_card(tid)
\t\tcheck(tc.effect_text == "从全职业卡池组合一张卡。",
\t\t\t\t"R614：%d %s 正文应为一句（实际「%s」）"
\t\t\t\t% [tid, tc.card_name, tc.effect_text])
'''


def patch_assemble(check):
    p = "scripts/test_assemble.gd"
    s = open(p, "r", encoding="utf-8", newline="").read()
    assert s.count(TA_OLD) == 1, s.count(TA_OLD)
    s = s.replace(TA_OLD, TA_NEW)
    print("[test_assemble.gd] R592 文本锁 → 显示层判据")
    if check:
        return
    open(p, "w", encoding="utf-8", newline="").write(s)
    b = open(p, "rb").read()
    crlf = b.count(b"\r\n")
    print(f"[test_assemble.gd] crlf={crlf} bare={b.count(chr(10).encode()) - crlf}")


# ---------------------------------------------------- 6. test_smoke.gd（CRLF）
TS_OLD = ('\tprint("  [smoke] R444 字段浮窗：单字段靠右 / 两字段一左一右不压卡 / bounds 夹回屏内")\r\n')
TS_NEW = ('\t# R614：机制词条（「组合」）也走同一套浮窗 —— 传授 8084 = 「次元」+「组合」两条。\r\n'
          '\tvar teach: CardData = repo.get_card(8084)\r\n'
          '\tif teach == null:\r\n'
          '\t\t_smoke_fail("R614：找不到 8084 传授")\r\n'
          '\t\treturn\r\n'
          '\tvar kw_names: Array = []\r\n'
          '\tfor rk: Dictionary in CardFace.affix_index_rects(teach, card_rect, font):\r\n'
          '\t\tkw_names.append(str((rk["item"] as Dictionary).get("affix", "")))\r\n'
          '\tif not (kw_names.has("次元") and kw_names.has("组合")):\r\n'
          '\t\t_smoke_fail("R614：传授浮窗应同时列出「次元」与「组合」，实得 %s" % str(kw_names))\r\n'
          '\t\treturn\r\n'
          '\tprint("  [smoke] R444 字段索引浮窗：单字段靠右 / 两字段一右一左不重叠 / bounds 夹回屏内")\r\n'
          '\tprint("  [smoke] R614 机制词条并入浮窗：传授 = 次元 + 组合")\r\n')


def patch_smoke(check):
    p = "scripts/test_smoke.gd"
    s = open(p, "r", encoding="utf-8", newline="").read()
    assert s.count(TS_OLD) == 1, s.count(TS_OLD)
    s = s.replace(TS_OLD, TS_NEW)
    print("[test_smoke.gd] R444 浮窗补「组合」判据")
    if check:
        return
    open(p, "w", encoding="utf-8", newline="").write(s)
    b = open(p, "rb").read()
    crlf = b.count(b"\r\n")
    print(f"[test_smoke.gd] crlf={crlf} bare={b.count(chr(10).encode()) - crlf}")


if __name__ == "__main__":
    print("=== R614 patch", "（dry-run）" if CHECK else "（落盘）", "===")
    patch_cards(CHECK)
    patch_card_data(CHECK)
    patch_card_face(CHECK)
    patch_battle(CHECK)
    patch_assemble(CHECK)
    patch_smoke(CHECK)
    print("=== done ===")
