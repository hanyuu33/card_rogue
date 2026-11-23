# -*- coding: utf-8 -*-
"""R793c —— 事件标题（「林 中 的 剑」这种空格撑字距写法）在英 / 日 / 西语下永远是中文。

根因：`_localize_text()` 拿 `event_name.text` 直接查 i18n，而 i18n 的 key 是
narrative 里的「林中的剑」（无空格）→ 全串精确匹配必然落空。**所有 26 个事件**都中招
（出图对比 struggle 的 en 版确认过）。修在唯一出口：先去掉排版空格再查。
"""
import io, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


def patch(path, pairs):
    p = ROOT.rstrip("/") + "/" + path
    raw = io.open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            o = old.replace("\n", "\r\n")
            n = new.replace("\n", "\r\n")
        else:
            o, n = old, new
        c = txt.count(o)
        assert c == 1, "%s: count=%d for %r" % (path, c, old[:70])
        txt = txt.replace(o, n)
    io.open(p, "wb").write(txt.encode("utf-8"))
    print("OK %-34s %d -> %d  (%s)" % (path, len(raw), len(txt.encode("utf-8")),
                                       "CRLF" if crlf else "LF"))


patch("scripts/event_scene.gd", [
    ('\tevent_name.text = GameI18n.source(event_name.text)\n',
     '\t# R793c：事件标题是「林 中 的 剑」这种**用空格撑字距**的排版写法，而 i18n 的 key 是\n'
     '\t# narrative 里的「林中的剑」（无空格）—— 全串精确匹配必然落空，于是英 / 日 / 西语版的\n'
     '\t# **每一个事件标题**都还是中文（R793 出 en 图时才发现，struggle 同样中招）。\n'
     '\t# 唯一出口在这里：去掉排版空格再查表；查不到就保持原样（别把字距也吃掉）。\n'
     '\tvar ev_title := event_name.text.replace(" ", "")\n'
     '\tvar ev_title_tr := GameI18n.source(ev_title)\n'
     '\tif ev_title_tr != ev_title:\n'
     '\t\tevent_name.text = ev_title_tr\n'),
])

patch("scripts/test_engine.gd", [
    ('\tcheck_src(r793_es.contains("RunState.lose_max_hp(SWORD_LIFE_COST)")\n',
     '\tcheck_src(r793_es.contains(\'event_name.text.replace(" ", "")\'),\n'
     '\t\t\t"R793 事件：标题去排版空格后再查 i18n（否则外语版每个事件标题都是中文）")\n'
     '\tcheck_src(r793_es.contains("RunState.lose_max_hp(SWORD_LIFE_COST)")\n'),
])

print("patch c done")
