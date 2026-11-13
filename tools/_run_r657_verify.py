# -*- coding: utf-8 -*-
"""R657 回归驱动：备份存档 → 跑 assemble + smoke → 逐文件比对还原。

⚠️ 只跑这两套：本轮只动 `ui_theme.gd` 的按钮字号口 + `ui_menu.gd` 的传参 +
`test_smoke.gd` 的一条断言。**并行会话正在改 battle_scene / card_face /
card_info_boxes / test_engine（R656）**，跑全六套既会跟它抢 `_e.txt` 等中间文件，
也会把它的半成品算进我的基线 —— 所以 engine/reward/bgm/mana 这轮按「未触及」处理。
"""
import hashlib
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UD = r"C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\卡牌肉鸽"
BK = r"E:\tmp\r657_userdata_bk"
GODOT = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64.exe"

SUITES = [
    ("assemble", ["--headless", "--path", ROOT, "--script", "res://scripts/test_assemble.gd"], "_a657.txt"),
    ("smoke", ["--headless", "--path", ROOT, "--script", "res://scripts/test_smoke.gd"], "_s657.txt"),
]


def snap(root):
    out = {}
    for base, dirs, files in os.walk(root):
        rel_base = os.path.relpath(base, root).replace("\\", "/")
        for d in dirs:
            key = (rel_base + "/" + d) if rel_base != "." else d
            out[("D", key)] = ""
        for f in files:
            p = os.path.join(base, f)
            key = (rel_base + "/" + f) if rel_base != "." else f
            with open(p, "rb") as fh:
                out[("F", key)] = hashlib.sha256(fh.read()).hexdigest()
    return out


def main():
    if not os.path.isdir(UD):
        print("[FAIL] 找不到存档目录：%s" % UD)
        return 2
    if os.path.exists(BK):
        shutil.rmtree(BK)
    shutil.copytree(UD, BK)
    before = snap(UD)
    print("[BACKUP] %d 项 → %s" % (len(before), BK), flush=True)

    bad_total = 0
    for name, args, out_name in SUITES:
        out_path = os.path.join(ROOT, out_name)
        with open(out_path, "wb") as f:
            rc = subprocess.call([GODOT] + args, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT)
        d = open(out_path, "rb").read().decode("utf-8", "replace")
        import re
        cn = re.search(r"(\d+)\s*通过\s*/\s*(\d+)\s*失败", d)
        if cn:
            good, bad = int(cn.group(1)), int(cn.group(2))
        else:
            good, bad = d.count("\u2713"), d.count("\u2717")
        bad_total += bad
        print("[%s] %d\u2713 %d\u2717  exit=%s" % (name, good, bad, rc), flush=True)
        if "\u2717" in d:
            for ln in d.splitlines():
                if "\u2717" in ln:
                    print("    " + ln.strip()[:200], flush=True)
        for tag in ("Parse Error", "SCRIPT ERROR"):
            if tag in d:
                print("    [!] %s 出现" % tag, flush=True)
                for ln in d.splitlines():
                    if tag in ln:
                        print("      " + ln.strip()[:200], flush=True)

    current_files = {os.path.relpath(os.path.join(base, f), UD): os.path.join(base, f)
                     for base, _dirs, files in os.walk(UD) for f in files}
    backup_files = {os.path.relpath(os.path.join(base, f), BK): os.path.join(base, f)
                    for base, _dirs, files in os.walk(BK) for f in files}
    extra_root = BK + "_extra"
    extras = sorted(set(current_files) - set(backup_files))
    for rel in extras:
        dst = os.path.join(extra_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(current_files[rel], dst)
    for rel in extras:
        shutil.move(current_files[rel], os.path.join(extra_root, rel))
    for rel, src in backup_files.items():
        dst = os.path.join(UD, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    after = snap(UD)
    ok = (after == before)
    print("[RESTORE_VERIFY] %s（%d 项）" % ("OK" if ok else "MISMATCH", len(after)), flush=True)
    if not ok:
        only_a = sorted(set(after) - set(before))
        only_b = sorted(set(before) - set(after))
        diff = sorted(k for k in set(after) & set(before) if after[k] != before[k])
        print("  新增=%s 缺失=%s 内容不同=%s" % (only_a[:8], only_b[:8], diff[:8]))
    print("[REGRESSION] %s  bad=%d" % ("GREEN" if (bad_total == 0 and ok) else "RED", bad_total), flush=True)
    return 0 if (bad_total == 0 and ok) else 1


if __name__ == "__main__":
    sys.exit(main())
