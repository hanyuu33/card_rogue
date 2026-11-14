# -*- coding: utf-8 -*-
"""R667 陷阱栏实机截图驱动：逐目标拉起 Godot（非 headless）渲染并截图。

沿用 R663/R657 的存档保护口径：跑前备份 userdata，跑完按「文件集合 + sha256」
逐文件还原，打印 RESTORE_VERIFY。分两批是为了增量交付（先给战斗三张）。

用法：
    python tools/_run_r667_shots.py --only battle   # 战斗 3 张 + R669 触发特效 4 张
    python tools/_run_r667_shots.py --only rest     # 地图 / 商店 / 商店栏位满
    python tools/_run_r667_shots.py --only fx       # 只跑 R669 四张触发特效
    python tools/_run_r667_shots.py                # 十一张全跑
"""
import hashlib
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "_shots")
UD = r"C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\卡牌肉鸽"
GODOT = os.path.join(os.path.expanduser("~"), ".workbuddy", "binaries",
                     "godot", "Godot_v4.3-stable_win64_console.exe")
if not os.path.isfile(GODOT):
    GODOT = os.path.join(os.path.expanduser("~"), ".workbuddy", "binaries",
                         "godot", "Godot_v4.3-stable_win64.exe")

BATTLE = ["battle", "battle_drag", "battle_placed"]
# R669：四张 codex 触发特效各截一张实机帧（真事件口 → 真素材图绘制）。
FX = ["battle_fx7001", "battle_fx7002", "battle_fx7003", "battle_fx7004"]
# R670：P0 断链（漩涡 / 空袭）+ P1 技能通用施法图三族 + P2 爆裂，各一张实机帧。
FX670 = ["battle_vortex", "battle_airraid", "battle_blast",
         "battle_skill_shadow", "battle_skill_fire", "battle_skill_ice"]
# R675：机制类伤害（没有技能卡的 source）—— 闪电 / 噩兆 / 护甲爆发 / 废弃机器人 一帧，
# 一条来源一张帧（挤一帧会互相压着，反而看不清对应关系）。
FX675 = ["battle_mech_bolt", "battle_mech_omen", "battle_mech_gale",
         "battle_mech_bot", "battle_mech_armor", "battle_mech_chimera"]
# R679：特效收尾五项 —— 中毒 tick / 灵魂收割 / 折射炮 / 隐藏能源 / 暗影之刃。
FX679 = ["battle_r679_poison", "battle_r679_soul", "battle_r679_refract",
         "battle_r679_hidden", "battle_r679_blade"]
REST = ["map", "shop", "shop_full", "shop_hover"]
ALL = BATTLE + REST + FX + FX670 + FX675 + FX679


def snap(root):
    out = {}
    for base, dirs, files in os.walk(root):
        rel = os.path.relpath(base, root).replace("\\", "/")
        for d in dirs:
            out[("D", (rel + "/" + d) if rel != "." else d)] = ""
        for f in files:
            p = os.path.join(base, f)
            key = (rel + "/" + f) if rel != "." else f
            with open(p, "rb") as fh:
                out[("F", key)] = hashlib.sha256(fh.read()).hexdigest()
    return out


def restore(before, bk):
    cur = {os.path.relpath(os.path.join(b, f), UD): os.path.join(b, f)
           for b, _d, fs in os.walk(UD) for f in fs}
    bak = {os.path.relpath(os.path.join(b, f), bk): os.path.join(b, f)
           for b, _d, fs in os.walk(bk) for f in fs}
    extra_root = bk + "_extra"
    extras = sorted(set(cur) - set(bak))
    for rel in extras:
        dst = os.path.join(extra_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(cur[rel], dst)
    for rel in extras:
        shutil.move(cur[rel], os.path.join(extra_root, rel))
    for rel, src in bak.items():
        dst = os.path.join(UD, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    after = snap(UD)
    print("[RESTORE_VERIFY] %s（%d 项，新增搬走 %d 个）" % (
        "OK" if after == before else "MISMATCH", len(after), len(extras)), flush=True)
    return after == before


def run_one(target, idx, total):
    out_png = os.path.join(SHOTS, "r667_%s.png" % target)
    if os.path.isfile(out_png):
        os.remove(out_png)
    cmd = [GODOT, "--path", ROOT, "--resolution", "1280x720",
           "--script", "res://tools/_shot_r667_traps.gd", "--",
           "--screenshot", "--shop", "--shotframe", "9999", "--target", target]
    print("[shot %d/%d] %s ..." % (idx, total, target), flush=True)
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                           errors="replace", timeout=180)
    except subprocess.TimeoutExpired:
        print("   TIMEOUT %s" % target, flush=True)
        return False
    txt = (p.stdout or "") + "\n" + (p.stderr or "")
    errs = [l for l in txt.splitlines()
            if any(k in l for k in ["Parse Error", "SCRIPT ERROR", "ERROR:"])]
    ok = os.path.isfile(out_png) and os.path.getsize(out_png) > 50000
    print("   rc=%d png=%s size=%d err_lines=%d" % (
        p.returncode, "OK" if ok else "MISS",
        os.path.getsize(out_png) if os.path.isfile(out_png) else 0, len(errs)), flush=True)
    for l in errs[:8]:
        print("   ERR", l[:180], flush=True)
    for l in txt.splitlines():
        if "[r667]" in l:
            print("   ", l[:170], flush=True)
    return ok and p.returncode == 0


def main(argv):
    only = None
    if "--only" in argv:
        i = argv.index("--only")
        if i + 1 < len(argv):
            only = argv[i + 1]
    if only == "battle":
        targets = BATTLE + FX
    elif only == "fx":
        targets = FX
    elif only == "r670":
        targets = FX670
    elif only == "r679":
        targets = FX679
    elif only == "r675":
        targets = FX675
    elif only == "rest":
        targets = REST
    else:
        targets = ALL
    os.makedirs(SHOTS, exist_ok=True)
    if not os.path.isfile(GODOT):
        print("[FAIL] 找不到 Godot：%s" % GODOT)
        return 2
    bk = r"E:\tmp\r667_shots_bk_%s" % time.strftime("%H%M%S")
    if os.path.isdir(UD):
        os.makedirs(os.path.dirname(bk), exist_ok=True)
        shutil.copytree(UD, bk)
        before = snap(UD)
        print("[BACKUP] %d 项 → %s" % (len(before), bk), flush=True)
    else:
        before, bk = None, None
        print("[WARN] 找不到存档目录，跳过备份（脚本内部已切测试档）", flush=True)

    ok_all = True
    for i, t in enumerate(targets, 1):
        if not run_one(t, i, len(targets)):
            ok_all = False
    if before is not None:
        if not restore(before, bk):
            ok_all = False
    print("[SHOTS] %s  共 %d 张 → %s" % (
        "GREEN" if ok_all else "RED", len(targets), SHOTS), flush=True)
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
