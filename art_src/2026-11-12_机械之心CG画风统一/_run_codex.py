# -*- coding: utf-8 -*-
"""2026-11-12 机械之心 CG 画风统一 —— codex 图生图两版候选驱动。

借 class_cg_forest / class_cg_rogue 各出一版，只借画风不借内容，机械之心定稿设定不变。
产出落 raw/，作为候选，不覆盖正式 assets/ui/class_cg_mech.png（纪律 J：店长选了才转正）。

复用 R562 管线：代理 7897 / prompt 走 stdin / 从 JSONL 取图 / 重试 2 次 / 可重跑跳过。
用法：
    python _run_codex.py            # 跑两版（已有成品自动跳过）
    python _run_codex.py v_forest   # 只跑指定版
    CODEX_PROXY=http://127.0.0.1:7897 python _run_codex.py
"""
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = r"E:\work\card_rogue"
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
D = os.path.join(ROOT, "art_src", "2026-11-12_机械之心CG画风统一")
PROMPTS = os.path.join(D, "prompts")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
PROXY = os.environ.get("CODEX_PROXY", "http://127.0.0.1:7897")

# key -> (参考图, prompt 文件名)
JOBS = [
    ("v_forest", os.path.join(ROOT, "assets", "ui", "class_cg_forest.png")),
    ("v_rogue", os.path.join(ROOT, "assets", "ui", "class_cg_rogue.png")),
    ("v_keepcomp", os.path.join(ROOT, "assets", "ui", "class_cg_mech.png")),
]

PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def progress(key, ok):
    with open(os.path.join(D, "_progress.txt"), "a", encoding="utf-8", newline="\n") as f:
        f.write("%s\t%s\t%s\n" % (time.strftime("%H:%M:%S"), key, "OK" if ok else "FAIL"))


def proxy_ok():
    import urllib.error
    import urllib.request
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
    req = urllib.request.Request("https://chatgpt.com", headers={"User-Agent": "Mozilla/5.0"})
    try:
        with opener.open(req, timeout=15) as r:
            log("代理预检 HTTP %d" % r.status)
            return r.status < 500
    except urllib.error.HTTPError as e:
        log("代理预检 HTTP %d（链路通，目标站拒绝）" % e.code)
        return e.code < 500
    except Exception as e:  # noqa: BLE001
        log("代理预检失败 %s：%r" % (PROXY, e))
        return False


def pick_output(jsonl_text):
    """从 codex JSONL 里找最后一张生成图的绝对路径。"""
    hits = PAT.findall(jsonl_text.replace("\\\\", "\\"))
    for p in reversed(hits):
        p = p.replace("/", "\\")
        if os.path.exists(p):
            return p
    m = re.search(r'"thread_id"\s*:\s*"([0-9a-f-]+)"', jsonl_text)
    if m:
        d = os.path.join(GEN, m.group(1))
        if os.path.isdir(d):
            pngs = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".png")]
            if pngs:
                return max(pngs, key=os.path.getmtime)
    return None


def run_one(key, ref):
    dst = os.path.join(RAW, "%s_codex.png" % key)
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %s（已有 %d KB）" % (key, os.path.getsize(dst) // 1024))
        return True
    prompt = os.path.join(PROMPTS, "%s.txt" % key)
    if not os.path.exists(prompt):
        log("MISS %s（没有 prompt）" % key)
        return False
    if ref and not os.path.exists(ref):
        log("MISS %s 参考图不存在：%s" % (key, ref))
        return False

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %s  参考=%s  第%d次" % (key, os.path.basename(ref), attempt))
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT]
                    + (["-i", ref] if ref else []),
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=900, cwd=ROOT,
                    creationflags=0x08000000,   # CREATE_NO_WINDOW
                )
            text = proc.stdout.decode("utf-8", "replace")
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace")
            log("TIMEOUT %s（%.0fs）" % (key, time.time() - t0))
        except Exception as e:  # noqa: BLE001
            log("ERROR %s %r" % (key, e))
            text = ""
        with open(os.path.join(D, "_log_%s.jsonl" % key), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

        src = pick_output(text)
        if src:
            shutil.copyfile(src, dst)
            log("OK   %s  <- %s  (%.0fs, %d KB)" % (
                key, os.path.basename(src), time.time() - t0, os.path.getsize(dst) // 1024))
            progress(key, True)
            return True
        log("FAIL %s 第%d次没有图（代理 %s 不通？）" % (key, attempt, PROXY))
        time.sleep(5)
    progress(key, False)
    return False


def main():
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("代理 %s 不可用：先启动 Clash Verge（7897），或用 CODEX_PROXY 指定。本次不出图。" % PROXY)
        print("PROXY_DOWN", flush=True)
        return 1
    log("代理预检 OK：%s" % PROXY)
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for key, ref in JOBS:
        if only and key not in only:
            continue
        (done if run_one(key, ref) else fail).append(key)
    log("=== 机械之心CG画风统一结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", len(done), " FAIL:", fail, flush=True)
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
