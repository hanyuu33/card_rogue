# -*- coding: utf-8 -*-
"""R562 返工：4 张全身机甲被卡窗裁掉头顶/靴底 → 重新出图，锁死「占幅 78% + 上下留白」。

根因（已印证）：参考图 8073 自身是「紧贴画框的全身机甲」，图生图会把这种占幅一起学走，
于是 1254 正方形里头顶到 y≈2%、脚底到 y≈99%，而 448x403 的裁窗要切掉上下各 63px（5%），
两头都会被削。解法不是换裁窗（比例固定、余量不够），是重出图把主体缩到 78%。
"""
import importlib.util
import os

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("rb", os.path.join(D, "_run_batch.py"))
rb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rb)

FRAME = """
COMPOSITION — CRITICAL: the whole machine must sit INSIDE the frame with clear empty background
above its head and below its boots. Scale the figure to about 78% of the frame height and centre it,
so there is at least 8% of empty background at the TOP edge and at least 8% at the BOTTOM edge.
Both the top of the head and both feet must be FULLY visible and NOT cropped by the frame.
Do NOT fill the frame edge-to-edge like the reference image; pull the camera back.
"""

CARDS = [(8083, "拼装原型"), (9220, "阵地保卫者"), (9221, "结合者"), (9222, "忒修斯奇械")]

for cid, name in CARDS:
    src = os.path.join(D, "%d_%s.txt" % (cid, name))
    text = open(src, encoding="utf-8").read()
    marker = "\nAVOID ALWAYS:"
    assert marker in text, src
    head, tail = text.split(marker, 1)
    out = head + FRAME + marker + tail
    path = os.path.join(D, "%d_%s_v2.txt" % (cid, name))
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)
    print("wrote", os.path.basename(path))

for cid, name in CARDS:
    rb.run_one(cid, name, rb.STYLE_ALLY, suffix="_v2")
