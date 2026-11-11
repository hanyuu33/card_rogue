# -*- coding: utf-8 -*-
"""R575 回归包装：备份 userdata -> 跑 _verify.py 六套 -> 逐文件 cmp 还原。

一次调用跑完，循环关在脚本里；避免测试存档污染正式档。
"""
import filecmp
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-11_事件触发时定事件_R575"
UD = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "卡牌肉鸽"
BK = ROOT / "_bk_r575_userdata"


def snapshot(base: Path):
    return {str(p.relative_to(base)): p.stat().st_mtime_ns
            for p in base.rglob("*") if p.is_file()}


def main() -> int:
    if not UD.is_dir():
        print("NO USERDATA", UD, flush=True)
        return 2
    if BK.exists():
        shutil.rmtree(BK)
    shutil.copytree(UD, BK)
    before = snapshot(UD)
    print("BACKUP OK ->", BK, "files:", len(before), flush=True)

    proc = subprocess.run([sys.executable, "_verify.py"], cwd=str(ROOT),
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          timeout=1800)
    text = proc.stdout.decode("utf-8", "replace")
    (D / "_verify_r575.log").write_text(text, encoding="utf-8", newline="\n")
    print("=== _verify.py rc=%d ===" % proc.returncode, flush=True)
    print(text[-7000:], flush=True)

    restored, removed = [], []
    for rel in snapshot(UD):
        src, dst = BK / rel, UD / rel
        if not src.exists():
            dst.unlink()
            removed.append(rel)
        elif not filecmp.cmp(src, dst, shallow=False) or \
                dst.stat().st_mtime_ns != before.get(rel):
            shutil.copy2(src, dst)
            restored.append(rel)
    for rel in before:
        dst = UD / rel
        if not dst.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(BK / rel, dst)
            restored.append(rel)
    print("RESTORE changed=%d removed=%d" % (len(restored), len(removed)), flush=True)
    for rel in sorted(set(restored + removed))[:30]:
        print("   ", rel, flush=True)
    # 最终判据只看「文件集合 + 内容」：settings.cfg 会被 Godot 退出时重写，
    # mtime 必变，拿它当最终判据会误报 MISMATCH（内容其实已经还原）。
    ok = set(snapshot(UD)) == set(before) and all(
        filecmp.cmp(BK / rel, UD / rel, shallow=False) for rel in before)
    print("RESTORE_VERIFY", "OK" if ok else "MISMATCH", flush=True)
    if proc.returncode:
        return proc.returncode
    return 0 if ok else 3


if __name__ == "__main__":
    raise SystemExit(main())
