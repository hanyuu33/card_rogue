# -*- coding: utf-8 -*-
"""热血战斗 BGM 追加下载（R175 追加批）

- 魔王魂（.ogg 直链，需 Referer https://maou.audio/）：
  来自 neorock（メタル/ラウド = 高能吉他金属）/ orchestra（戦闘曲）/ cyber（決戦・ラストダンジョン）
- PeriTune（.mp3 直链）：EpicBattle 系列 / Kengeki / Raid_FolkMetal / Thunderclap /
  Puppeteer / Battle_Fun / Rapid5 / Wuxia3 —— 标题均含「戦闘曲/勇壮」等
- 幂等：已存在且 >1KB 跳过；完成后写 _extra_report.json
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "Chrome/130.0 Safari/537.36")
CURL = ["curl", "-sS", "-m", "300", "--retry", "2", "--retry-delay", "2",
        "-x", "http://127.0.0.1:7897"]

MAOU = ["bgm_neorock13", "bgm_neorock32", "bgm_neorock40", "bgm_neorock75",
        "bgm_neorock81", "bgm_neorock83", "bgm_orchestra11", "bgm_orchestra12",
        "bgm_orchestra24", "bgm_cyber39", "bgm_cyber35"]

PERI = ["PerituneMaterial_EpicBattle", "PerituneMaterial_EpicBattle2",
        "PerituneMaterial_EpicBattle_Deity", "PerituneMaterial_EpicBattle_J",
        "PerituneMaterial_Kengeki", "PerituneMaterial_Raid_FolkMetal",
        "PerituneMaterial_Thunderclap", "PerituneMaterial_Puppeteer",
        "PerituneMaterial_Battle_Fun", "PerituneMaterial_Rapid5",
        "PerituneMaterial_Wuxia3"]


def fetch(url: str, dst: str, referer: str) -> bool:
    if os.path.exists(dst) and os.path.getsize(dst) > 1024:
        return True
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tmp = dst + ".part"
    args = CURL + ["-A", UA, "-o", tmp, "-w", "%{http_code}", "-e", referer, url]
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=900,
                           encoding="utf-8", errors="replace")
        code = r.stdout.strip()
        if r.returncode != 0 or code != "200":
            print("  !! HTTP %s rc=%d %s" % (code, r.returncode, url), flush=True)
            if os.path.exists(tmp):
                os.remove(tmp)
            return False
        with open(tmp, "rb") as f:
            head = f.read(4)
        if os.path.getsize(tmp) < 1024 or head[:4] == b"<!do":
            print("  !! 疑似 HTML:", url, flush=True)
            os.remove(tmp)
            return False
        os.replace(tmp, dst)
        return True
    except Exception as e:  # noqa: BLE001
        print("  !! 失败:", url, "-", repr(e)[:110], flush=True)
        if os.path.exists(tmp):
            os.remove(tmp)
        return False


def main() -> int:
    jobs = []
    for s in MAOU:
        # 魔王魂 文件名带 maou_ 前缀：slug=bgm_neorock13 → maou_bgm_neorock13.ogg
        fn = "maou_%s.ogg" % s
        jobs.append((s, "https://maou.audio/sound/bgm/%s" % fn,
                     os.path.join(RAW, "maou", fn),
                     "https://maou.audio/"))
    for p in PERI:
        jobs.append((p, "https://peritune.com/music/%s.mp3" % p,
                     os.path.join(RAW, "peritune", p + ".mp3"),
                     "https://peritune.com/"))
    ok, fail = 0, []
    for tag, url, dst, ref in jobs:
        if os.path.exists(dst) and os.path.getsize(dst) > 1024:
            ok += 1
            print("跳过", tag, "(已存在)", flush=True)
            continue
        print("下载", tag, flush=True)
        if fetch(url, dst, ref):
            ok += 1
            print("  ok %.1f MB" % (os.path.getsize(dst) / 1048576), flush=True)
        else:
            fail.append(tag)
        time.sleep(0.3)
    print("\n== 追加批汇总 == 成功 %d / 失败 %d" % (ok, len(fail)), flush=True)
    for f in fail:
        print("  失败:", f, flush=True)
    json.dump({"ok": ok, "fail": fail},
              open(os.path.join(HERE, "_extra_report.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
