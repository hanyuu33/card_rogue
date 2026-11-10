# -*- coding: utf-8 -*-
"""R563 返工第三批（店长 2026-11-11 凌晨两轮反馈，共 8 张）：

  9154 破绽          → 盾牌破碎的标记
  9185 麻痹          → 黄色的电弧标记
  9168 许愿          → 森林精魄角色在祈祷（借 class_cg_forest 角色设计）
  9242 普罗诺亚之影  → 机械之心角色外观 + 浑身黑气笼罩的黑化形态（借 class_cg_mech）
  9049 齿轮升腾      → 只聚焦两枚嵌合齿轮，去掉蓝色圆形
  9115 使魔之力      → 以使魔鸭子为主体（借 9009 本体）
  9028 龙裔          → 半龙人（双足人形，非四足小龙兽）
  9014 远古虚骨龙    → 真实 Coelurus fragilis 解剖 + 低角度仰视俯冲张口（借当前正式图保画风）
  9149 疲惫          → 森林精魄角色在篝火边打瞌睡（试验版，借 class_cg_forest）

复用 R562 的 codex 图生图管线；suffix=_v2，prompt 为 <id>_<name>_v2.txt。
"""
import importlib.util
import os
import subprocess
import sys

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_缺图收口_R563")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")
PREP = os.path.join(ROOT, "tools", "cardart_prep.py")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

P = os.path.join(ROOT, "assets", "pics")
UI = os.path.join(ROOT, "assets", "ui")

# (id, 卡名, 参考图绝对路径)
JOBS = [
    (9154, "破绽",           os.path.join(P, "9179.png")),
    (9185, "麻痹",           os.path.join(P, "9179.png")),
    (9168, "许愿",           os.path.join(UI, "class_cg_forest.png")),
    (9242, "普罗诺亚之影",   os.path.join(UI, "class_cg_mech.png")),
    (9049, "齿轮升腾",       os.path.join(P, "8025.png")),
    (9115, "使魔之力",       os.path.join(P, "9009.png")),
    (9028, "龙裔",           os.path.join(P, "1013.png")),
    (9014, "远古虚骨龙",     os.path.join(P, "9014.png")),
    (9149, "疲惫",           os.path.join(UI, "class_cg_forest.png")),
]


def cut(path, cid):
    r = subprocess.run([sys.executable, PREP, path, str(cid)],
                       capture_output=True, text=True, encoding="utf-8")
    print("   ", r.stdout.strip() or ("cut %d FAIL %s" % (cid, r.stderr.strip()[:160])), flush=True)


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, ref in JOBS:
        if only and cid not in only:
            continue
        prompt = os.path.join(D, "%d_%s_v2.txt" % (cid, name))
        assert os.path.exists(ref), "参考图缺失: " + ref
        assert os.path.exists(prompt), "prompt 缺失: " + prompt
        print("RUN  %d %s  <- %s" % (cid, name, os.path.basename(ref)), flush=True)
        ok = m.run_one(cid, name, ref, "_v2")
        if ok:
            cut(os.path.join(RAW, "%d_%s_v2.png" % (cid, name)), cid)
            done.append(cid)
        else:
            fail.append(cid)
        print("DONE %d %s %s" % (cid, name, "OK" if ok else "FAIL"), flush=True)
    print("=== 返工第三批 成功%d / 失败%d %s" % (len(done), len(fail), fail), flush=True)


if __name__ == "__main__":
    main()
