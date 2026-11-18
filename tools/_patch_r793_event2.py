# -*- coding: utf-8 -*-
"""R793 patch 2/4 —— event_scene.gd 的界面分支与结算（拔剑 / 离开）。"""
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


READY_BRANCH = '''\telif _is_sword():
\t\tevent_name.text = "林 中 的 剑"
\t\tdesc.text = SWORD_TAKEN_DESC if _sword_taken else SWORD_DESC
\t\tif _sword_taken:
\t\t\t_collapse_to_leave()
\t\t\tresult_label.text = _sword_result
\t\t\tresult_label.add_theme_color_override("font_color", Color("c8a86a"))
\t\telse:
\t\t\t# R793：三态按钮，**顺序不能反** ——
\t\t\t#   * 「已持有」优先：`gain_relic()` 对重复持有直接 return，血却照扣，
\t\t\t#     不拦就是白掉 13 点上限换一件拿不到的东西；
\t\t\t#   * 其次才是「最大生命不足」：`lose_max_hp()` 至少保留 1 点，
\t\t\t#     13 点以下拔剑等于把自己削到 1 点上限。
\t\t\trest_btn.visible = true
\t\t\tif RunState.has_relic(SWORD_MASTER_ID):
\t\t\t\trest_btn.text = "已持有「大师之剑」（不必再拔）"
\t\t\t\trest_btn.disabled = true
\t\t\telif RunState.max_hp <= SWORD_LIFE_COST:
\t\t\t\trest_btn.text = "最大生命不足（拔剑需失去 %d 点）" % SWORD_LIFE_COST
\t\t\t\trest_btn.disabled = true
\t\t\telse:
\t\t\t\trest_btn.text = "拔剑（失去 %d 最大生命，获得「大师之剑」）" % SWORD_LIFE_COST
\t\t\t\trest_btn.disabled = false
\t\t\tbbq_btn.visible = false
\t\t\talt_btn.visible = false
\t\t\tleave_btn.visible = true
\t\t\tleave_btn.text = "转身离开（不碰那把剑）"
\t\t\tleave_btn.disabled = false
\t\t\tresult_label.text = ""
'''

MAIN_BRANCH = '''\tif _is_sword():
\t\tif _sword_taken:
\t\t\t_on_leave()
\t\t\treturn
\t\t# 与界面置灰**同一条判据**（别只在按钮上拦）：已持有 / 最大生命不足都不许再扣。
\t\tif RunState.has_relic(SWORD_MASTER_ID) or RunState.max_hp <= SWORD_LIFE_COST:
\t\t\treturn
\t\t# 拔剑：先掉上限、再给道具 —— `lose_max_hp()` 至少保留 1 点，所以这一步不会致死。
\t\tvar sword_paid := RunState.lose_max_hp(SWORD_LIFE_COST)
\t\tRunState.gain_relic(SWORD_MASTER_ID)
\t\t_sword_taken = true
\t\t_claim_reward(rest_btn)   # R147
\t\t_collapse_to_leave()
\t\tdesc.text = SWORD_TAKEN_DESC
\t\t_sword_result = "失去 %d 点最大生命（现 %d / %d）——「大师之剑」已收进行囊" % [
\t\t\t\tsword_paid, RunState.hp, RunState.max_hp]
\t\tresult_label.text = _sword_result
\t\tresult_label.add_theme_color_override("font_color", Color("c8a86a"))
\t\t_redraw()
\t\treturn
'''

patch("scripts/event_scene.gd", [
    ('\telif _is_cave():\n\t\tevent_name.text = ', READY_BRANCH + '\telif _is_cave():\n\t\tevent_name.text = '),
    ('\t\t\t\tSTRUGGLE_LIFE, RunState.hp, RunState.max_hp, cname]\n'
     '\t\tresult_label.add_theme_color_override("font_color", Color("a44ad0"))\n'
     '\t\t_redraw()\n'
     '\t\treturn\n',
     '\t\t\t\tSTRUGGLE_LIFE, RunState.hp, RunState.max_hp, cname]\n'
     '\t\tresult_label.add_theme_color_override("font_color", Color("a44ad0"))\n'
     '\t\t_redraw()\n'
     '\t\treturn\n'
     + MAIN_BRANCH),
])

print("patch 2/4 done")
