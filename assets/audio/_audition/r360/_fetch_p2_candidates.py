# -*- coding: utf-8 -*-
"""R421：下载「启示者第 2 阶段（battle_revelator_p2）」的替换候选 loop 素材。

背景：现用 Relentless 是 PeriTune 2026-08 新曲，走 2026-03-01 新规约，
「同梱二次配布仅限非营利」—— 本作一旦收费售卖必须换掉。
本脚本只负责把**授权无虞（CC BY 4.0）**的候选取到本地，不接入游戏。

要点：
- 走**直连**（显式剔除 http_proxy/https_proxy）：走本机代理只有 6KB/s，直连 30KB/s。
- 服务器单连接限速，所以**多首并行**；单文件用 `curl -C -` 反复续传。
- 有两首形态不同：Rapid4 官方只给 `loop/..._loop.ogg` 直链（无 zip）；
  其余给 `loop/..._loop.zip`，解出里面的 `*_loop.ogg`。
- 沙箱不许删文件：坏档一律**截断为 0**再续，不 remove。
"""
import os
import re
import subprocess
import sys
import threading
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "loop")
UA = "Mozilla/5.0"
ENV = {k: v for k, v in os.environ.items()
       if k.lower() not in ("http_proxy", "https_proxy", "all_proxy")}

BASE = "https://peritune.com/loop/PerituneMaterial_%s_loop"

ZIP_JOBS = ["Firmament3_Active", "Augury", "Rapid5", "Demise", "Cyber_Noir"]
OGG_JOBS = ["Rapid4"]

TOTAL_RE = re.compile(r"Content-Range: bytes \d+-\d+/(\d+)", re.I)
LEN_RE = re.compile(r"Content-Length: (\d+)", re.I)

_lock = threading.Lock()
_report = []


def say(msg):
    with _lock:
        print(msg, flush=True)


def total_size(url):
    r = subprocess.run(["curl", "-sS", "-o", os.devnull, "-D", "-", "-r", "0-0",
                        "--max-time", "40", "-A", UA, url],
                       capture_output=True, text=True, env=ENV)
    h = r.stdout or ""
    m = TOTAL_RE.search(h)
    if m:
        return int(m.group(1))
    m2 = LEN_RE.search(h)
    return int(m2.group(1)) if m2 else 0


def fetch(url, path, rounds=16):
    """断点续传到 size == Content-Length。返回 True/False。"""
    want = total_size(url)
    if not want:
        say("  !! 拿不到总长度（链接失效？）: %s" % os.path.basename(path))
        return False
    if os.path.exists(path):
        have = os.path.getsize(path)
        if have > want:                      # 坏档（HTML 冒充等）
            open(path, "wb").close()
    for i in range(rounds):
        have = os.path.getsize(path) if os.path.exists(path) else 0
        if have >= want:
            say("  完成 %-46s %9d / %9d" % (os.path.basename(path), have, want))
            return True
        subprocess.run(["curl", "-sSL", "-C", "-", "--max-time", "150", "-A", UA,
                        url, "-o", path], capture_output=True, env=ENV)
    have = os.path.getsize(path) if os.path.exists(path) else 0
    say("  未完成 %-44s %9d / %9d" % (os.path.basename(path), have, want))
    return False


def is_ogg(p):
    if not os.path.exists(p):
        return False
    with open(p, "rb") as f:
        return f.read(4) == b"OggS"


def is_zip(p):
    return os.path.exists(p) and zipfile.is_zipfile(p)


def pick_loop_ogg(names):
    """从 zip 成员里挑「完整循环版」的 ogg。

    ⚠️ Demise 包内同时有 `_loop.ogg`（2.27MB）与 `_loop_intro.ogg`（0.33MB 前奏），
    早先按「名字含 loop 取第一个」会撞上 intro，装进去就只是段前奏。
    所以先精确匹配以 `_loop.ogg` 结尾的成员，再退而求其次排除 intro。
    """
    oggs = [n for n in names if n.lower().endswith(".ogg")]
    exact = [n for n in oggs if n.lower().endswith("_loop.ogg")]
    if exact:
        return exact[0]
    loose = [n for n in oggs if "intro" not in n.lower()]
    return loose[0] if loose else (oggs[0] if oggs else None)


def do_zip(name):
    url = (BASE % name) + ".zip"
    zpath = os.path.join(DST, "PerituneMaterial_%s_loop.zip" % name)
    out = os.path.join(DST, "PerituneMaterial_%s_loop.ogg" % name)
    if is_ogg(out):
        say("  跳过（已有 ogg）: %s" % os.path.basename(out))
        _report.append((name, True, os.path.getsize(out), "already"))
        return
    if not is_zip(zpath):
        fetch(url, zpath)
    if not is_zip(zpath):
        _report.append((name, False, 0, "zip 无效"))
        return
    try:
        with zipfile.ZipFile(zpath) as z:
            pick = pick_loop_ogg(z.namelist())
            if not pick:
                _report.append((name, False, 0, "zip 内无 ogg"))
                return
            data = z.read(pick)
        if data[:4] != b"OggS":
            _report.append((name, False, len(data), "非 OggS"))
            return
        with open(out, "wb") as f:
            f.write(data)
        say("  解出 %-46s %9d  ← %s" % (os.path.basename(out), len(data), pick))
        _report.append((name, True, len(data), pick))
    except Exception as e:
        _report.append((name, False, 0, "解压失败: %s" % e))


def do_ogg(name):
    url = (BASE % name) + ".ogg"
    out = os.path.join(DST, "PerituneMaterial_%s_loop.ogg" % name)
    if is_ogg(out):
        say("  跳过（已有 ogg）: %s" % os.path.basename(out))
        _report.append((name, True, os.path.getsize(out), "already"))
        return
    ok = fetch(url, out)
    good = ok and is_ogg(out)
    _report.append((name, good, os.path.getsize(out) if os.path.exists(out) else 0,
                    "direct ogg" if good else "失败"))


def main():
    os.makedirs(DST, exist_ok=True)
    t0 = time.time()
    say("目标目录: %s" % DST)
    say("并行 %d 路（zip %d + ogg %d），不走上游代理"
        % (len(ZIP_JOBS) + len(OGG_JOBS), len(ZIP_JOBS), len(OGG_JOBS)))
    ts = [threading.Thread(target=do_zip, args=(n,)) for n in ZIP_JOBS]
    ts += [threading.Thread(target=do_ogg, args=(n,)) for n in OGG_JOBS]
    for t in ts:
        t.start()
    for t in ts:
        t.join()

    say("")
    say("=========== 汇总（耗时 %.1fs）===========" % (time.time() - t0))
    okn = 0
    for name, ok, size, note in sorted(_report):
        say("%-20s %-4s %9d  %s" % (name, "OK" if ok else "FAIL", size, note))
        okn += 1 if ok else 0
    say("成功 %d / %d" % (okn, len(ZIP_JOBS) + len(OGG_JOBS)))
    return 0 if okn == len(ZIP_JOBS) + len(OGG_JOBS) else 1


if __name__ == "__main__":
    sys.exit(main())
