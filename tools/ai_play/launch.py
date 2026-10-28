# -*- coding: utf-8 -*-
"""启动 / 关闭「带 AI 接口」的游戏进程。

    python launch.py            # 起窗口（能看见游戏）+ AI 接口 8770
    python launch.py --headless # 无窗口（纯跑，省资源）
    python launch.py --port 8799
    python launch.py --stop     # 关掉

游戏进程与 AI 接口是一体的：接口是游戏里的一个 autoload，
没带 `--ai-bridge` 启动的普通游戏**不会**开端口（玩家玩不受影响）。
"""
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(os.environ.get(
    "CARD_ROGUE_GODOT",
    str(Path.home() / ".workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe"),
))
DEFAULT_PORT = 8770
PID_FILE = ROOT / ".ai_bridge.pid"


def port_open(port, host="127.0.0.1"):
    with socket.socket() as s:
        s.settimeout(0.3)
        return s.connect_ex((host, port)) == 0


def stop():
    if not PID_FILE.exists():
        print("没有记录的进程")
        return 0
    pid = int(PID_FILE.read_text().strip() or 0)
    PID_FILE.unlink(missing_ok=True)
    if pid <= 0:
        return 0
    try:
        subprocess.run(["taskkill", "/PID", str(pid), "/F"],
                       capture_output=True, check=False)
        print("已关闭 PID %d" % pid)
    except Exception as e:  # noqa: BLE001
        print("关闭失败：%s" % e)
    return 0


def launch(port=DEFAULT_PORT, headless=False, wait=30.0):
    if port_open(port):
        print("AI 接口已在 %d 上运行" % port)
        return 0
    if not GODOT.exists():
        print("找不到 Godot：%s\n用环境变量 CARD_ROGUE_GODOT 指定路径" % GODOT)
        return 1
    args = [str(GODOT), "--path", str(ROOT)]
    if headless:
        args.append("--headless")
    args += ["--", "--ai-bridge=%d" % port]
    log = ROOT / ".ai_bridge.log"
    fh = open(log, "w", encoding="utf-8")
    proc = subprocess.Popen(args, stdout=fh, stderr=subprocess.STDOUT,
                            cwd=str(ROOT))
    PID_FILE.write_text(str(proc.pid))
    end = time.time() + wait
    while time.time() < end:
        if port_open(port):
            print("已启动：PID %d  接口 http://127.0.0.1:%d  （日志 %s）"
                  % (proc.pid, port, log))
            return 0
        if proc.poll() is not None:
            print("游戏进程退出了，看日志：%s" % log)
            try:
                print(log.read_text(encoding="utf-8")[-2000:])
            except Exception:  # noqa: BLE001
                pass
            return 1
        time.sleep(0.4)
    print("等了 %.0f 秒接口还没起来，看日志：%s" % (wait, log))
    return 1


def main(argv):
    port = DEFAULT_PORT
    headless = False
    for a in argv[1:]:
        if a == "--stop":
            return stop()
        if a == "--headless":
            headless = True
        elif a.startswith("--port="):
            port = int(a.split("=", 1)[1])
        elif a == "--port" and argv.index(a) + 1 < len(argv):
            port = int(argv[argv.index(a) + 1])
    return launch(port, headless)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
