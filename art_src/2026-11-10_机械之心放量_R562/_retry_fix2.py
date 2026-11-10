# -*- coding: utf-8 -*-
"""R562 返工第二批：店长反馈的两张。

  9167 合体   → 从「能量溶解」改成特摄战队式物理合体（插槽/卡榫/液压锁扣），并写死 76% 占幅。
  8032 侦察塔 → 去掉雷达碟的青色扫描光锥，碟子改回纯机械接收件，发光只留塔身缝线/镜头/警示灯。

复用 _run_batch.py 的管线（代理、stdin 喂 prompt、generated_images 取图），只换 suffix=_v2。
"""
import importlib.util
import os

D = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("r562_batch", os.path.join(D, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

JOBS = [
    (8032, "侦察塔", m.STYLE_MECH),
    (9167, "合体", m.STYLE_MECH),
]

ok, fail = [], []
for cid, name, ref in JOBS:
    (ok if m.run_one(cid, name, ref, "_v2") else fail).append(cid)
print("OK:", ok, " FAIL:", fail)
