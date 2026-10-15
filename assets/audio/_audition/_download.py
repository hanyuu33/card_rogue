# -*- coding: utf-8 -*-
"""BGM 候选曲批量下载器（R175 前奏）

- 读 music_manifest.json，把 PeriTune(mp3+loop zip) / 魔王魂(ogg) 下载到
  assets/audio/_audition/raw/<库名>/ 暂存（选曲后才进 bgm/，故暂不提交 git）
- OpenTracks 真链在 Cloudflare Worker（本网络不可达），尝试后记录失败清单
- 幂等：已存在且大小>0 的文件跳过；失败项汇总打印
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "music_manifest.json")
RAW = os.path.join(HERE, "raw")

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "Chrome/130.0 Safari/537.36")

LIB_DIR = {"PeriTune": "peritune", "魔王魂": "maou", "OpenTracks": "opentracks"}

# curl 经实测在本环境最稳；走用户系统代理 127.0.0.1:7897（WorkBuddy 沙箱代理
# 对 peritune 仅 ~10KB/s，系统代理 ~100KB/s）
CURL = ["curl", "-sS", "-m", "300", "--retry", "2", "--retry-delay", "2",
        "-x", "http://127.0.0.1:7897"]


def fetch(url: str, dst: str, referer: str = "") -> bool:
    if os.path.exists(dst) and os.path.getsize(dst) > 1024:
        return True
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tmp = dst + ".part"
    args = CURL + ["-A", UA, "-o", tmp, "-w", "%{http_code}"]
    if referer:
        args += ["-e", referer]
    args.append(url)
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=1200,
                           encoding="utf-8", errors="replace")
        code = r.stdout.strip()
        if r.returncode != 0 or code != "200":
            print("  !! HTTP %s rc=%d %s" % (code, r.returncode, url), flush=True)
            if os.path.exists(tmp):
                os.remove(tmp)
            return False
        with open(tmp, "rb") as f:
            head = f.read(8)
        if os.path.getsize(tmp) < 1024 or head[:4] == b"<!do":
            print("  !! 疑似 HTML 而非音频:", url, flush=True)
            os.remove(tmp)
            return False
        os.replace(tmp, dst)
        return True
    except Exception as e:  # noqa: BLE001
        print("  !! 下载失败:", url, "-", repr(e)[:120], flush=True)
        if os.path.exists(tmp):
            os.remove(tmp)
        return False


def main() -> int:
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    ok, fail = 0, []
    for slot, tracks in manifest.items():
        for t in tracks:
            lib = t["lib"]
            name = t["name"]
            outdir = os.path.join(RAW, LIB_DIR.get(lib, lib))
            jobs = []  # (url, dst, referer)
            if lib == "PeriTune":
                if t.get("mp3"):
                    jobs.append((t["mp3"], os.path.join(
                        outdir, os.path.basename(t["mp3"])), t.get("page", "")))
                if t.get("loop"):
                    jobs.append((t["loop"], os.path.join(
                        outdir, os.path.basename(t["loop"])), t.get("page", "")))
            elif lib == "魔王魂":
                jobs.append((t["ogg"], os.path.join(
                    outdir, os.path.basename(t["ogg"])), t.get("page", "")))
            elif lib == "OpenTracks":
                # 详情页里的 dova-worker 真链带时效 token，需现场解析；
                # 本网络 worker 不可达，解析后尝试一次，失败即记录
                import html as _html
                import re
                try:
                    r = subprocess.run(CURL + ["-A", UA, t["detail"]],
                                       capture_output=True, timeout=120)
                    page = r.stdout.decode("utf-8", "ignore")
                    m = re.search(r'src="(https://dova-worker[^"]+\.mp3[^"]*)"', page)
                    if m:
                        real = _html.unescape(m.group(1))
                        jobs.append((real, os.path.join(
                            outdir, "%s.mp3" % t["detail"].rstrip("/").rsplit("/", 1)[-1]),
                            t["detail"]))
                    else:
                        print("  !! 详情页未找到音频真链:", t["detail"], flush=True)
                except Exception as e:  # noqa: BLE001
                    print("  !! 详情页拉取失败:", t["detail"], "-", repr(e)[:100], flush=True)
            for url, dst, ref in jobs:
                tag = "%s/%s" % (slot, os.path.basename(dst))
                if os.path.exists(dst) and os.path.getsize(dst) > 1024:
                    ok += 1
                    continue
                print("下载", tag, flush=True)
                if fetch(url, dst, ref):
                    ok += 1
                    print("  ok %.1f MB" % (os.path.getsize(dst) / 1048576), flush=True)
                else:
                    fail.append(tag)
                time.sleep(0.4)  # 礼貌限速
    print("\n== 汇总 ==  成功 %d / 失败 %d" % (ok, len(fail)))
    for f in fail:
        print("  失败:", f)
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
