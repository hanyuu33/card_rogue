# -*- coding: utf-8 -*-
"""修 R766 界面补丁的接缝：C/D/E/G 四处少了前导换行。

病因：`L(*lines)` 只是 `"\\r\\n".join(lines)`，**不补前导**换行；
B 那处恰好第一个元素是 '' 所以侥幸正确，其余四处把新块直接粘在了上一行末尾。
"""
import pathlib

P = pathlib.Path(r"E:\work\card_rogue\scripts\battle_scene.gd")
src = P.read_bytes().decode("utf-8")
before = len(src)

FIXES = [
    # C 确认分发
    ('\t\t\t_clear_selection()\t\t"regret":',
     '\t\t\t_clear_selection()\r\n\t\t"regret":'),
    # D 取消 / 右键守卫
    ('\t\t_say("乌鸦：必须从弃牌堆选择一张盟友回到手牌")\r\n\t\treturn\t# R766 懊悔的消失面板',
     '\t\t_say("乌鸦：必须从弃牌堆选择一张盟友回到手牌")\r\n\t\treturn\r\n\t# R766 懊悔的消失面板'),
    # E 结束回合守卫
    ('\t\t_say("乌鸦：请先选择一张要回到手牌的盟友")\r\n\t\treturn\tif engine.regret_pending:',
     '\t\t_say("乌鸦：请先选择一张要回到手牌的盟友")\r\n\t\treturn\r\n\tif engine.regret_pending:'),
    # G action 分发
    ('\t\t\t_say("乌鸦：%s 从弃牌堆回到手牌" % cr_name)\t\t"regret_pick":',
     '\t\t\t_say("乌鸦：%s 从弃牌堆回到手牌" % cr_name)\r\n\t\t"regret_pick":'),
]

for old, new in FIXES:
    n = src.count(old)
    if n != 1:
        print("FAIL count=%d for %r" % (n, old[:40]))
        raise SystemExit(1)
    src = src.replace(old, new)
    print("fixed:", new.split("\r\n")[-1][:30])

P.write_bytes(src.encode("utf-8"))
raw = P.read_bytes()
print("size %d -> %d, CRLF intact: %s" % (before, len(src), raw.count(b"\r\n") == raw.count(b"\n")))

# 复核：不应再有「代码行尾直接跟 tab+引号」的接缝
bad = [i for i, ln in enumerate(src.split("\r\n"), 1) if "\t\t\"" in ln and "return\t" in ln]
print("residual glue lines:", bad or "none")
