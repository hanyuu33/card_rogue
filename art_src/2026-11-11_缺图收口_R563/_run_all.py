# -*- coding: utf-8 -*-
"""R563 批量驱动：复用 R562 的 codex 图生图管线（代理 / stdin / 取图 / 重试），
只换批次目录和 JOBS。循环关在脚本里，一次调用跑完 27 张。
"""
import importlib.util
import os
import sys

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_缺图收口_R563")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW                      # run_one / log 都读模块全局，改这里即可

P = os.path.join(ROOT, "assets", "pics")
REFS = {
    "treant":          os.path.join(P, "8003.png"),
    "shadow_beast":    os.path.join(P, "8006.png"),
    "prop":            os.path.join(P, "9179.png"),
    "skill_fx":        os.path.join(P, "9004.png"),
    "mech":            os.path.join(P, "8025.png"),
    "shadow_humanoid": os.path.join(P, "9204.png"),
    "tower":           os.path.join(P, "9019.png"),
    "duck":            os.path.join(P, "9001.png"),
    "dragon":          os.path.join(P, "1013.png"),
    "undead":          os.path.join(P, "1053.png"),
    "ship":            os.path.join(P, "9200.png"),
}

# (id, prompt 里的卡名, 参考桶)
JOBS = [
    (8084, "传授", "treant"),
    (8085, "影缚", "shadow_beast"),
    (9149, "疲惫", "prop"),
    (9154, "破绽", "skill_fx"),
    (9157, "罐子", "prop"),
# R563: 9158 罐子(工事) 已弃用（旧召唤物机制），不再出图。见 README。

    (9168, "许愿", "prop"),
    (9241, "激光巨炮", "mech"),
    (9242, "普罗诺亚之影", "shadow_humanoid"),
    (9243, "炮击构状体", "mech"),
    (9244, "护盾构状体", "mech"),
    (9245, "迅捷构状体", "mech"),
    (8020, "鲜血堡垒", "tower"),
    (9185, "麻痹", "prop"),
    (9015, "鸭子号角", "duck"),
    (9028, "龙裔", "dragon"),
    (9029, "骷髅", "undead"),
    (9048, "发条鸭", "duck"),
    (9049, "齿轮升腾", "mech"),
    (9115, "使魔之力", "duck"),
    (9117, "恶魔使魔", "duck"),
    (9139, "充能巨炮", "mech"),
    (9147, "流水线装配", "mech"),
    (9201, "舰炮", "ship"),
    (9202, "电磁屏障", "skill_fx"),
    (9203, "紧急呼叫", "mech"),
    (9209, "空袭", "skill_fx"),
]

# 9158 的成品 id 是 9158，prompt 文件名带 _工事 后缀以和 9157 区分
OUT_ID = {9158: 9158}


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, bucket in JOBS:
        if only and cid not in only:
            continue
        ok = m.run_one(cid, name, REFS[bucket], "_v1")
        (done if ok else fail).append(cid)
    m.log("=== R563 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
