# -*- coding: utf-8 -*-
"""本地接收器：先把上报链路跑通，再谈部署。

用法
----
    python tools/telemetry_server/receiver.py                 # 监听 8788
    python tools/telemetry_server/receiver.py --port 9000

然后把游戏的 `scripts/telemetry.gd` 里 `UPLOAD_ENDPOINT` 改成：

    const UPLOAD_ENDPOINT := "http://127.0.0.1:8788/ingest"

启动游戏（发布版，或编辑器里 `--release --telemetry`），并在标题页点「同意发送」，
标题页 `_ready` 就会把存量发过来。收到的每批按时间戳命名落盘到 `tools/telemetry_server/data/`，
方便直接用 `analyze_balance.py` 分析。

设计：**故意只做三件事** —— 收、校验、落盘。鉴权 / 限流 / 清洗全留给正式后端，
本地这版存在的意义是「证明客户端的上传逻辑是对的」，不是拿来上线。
"""
import argparse
import datetime
import json
import os

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")


class Handler(BaseHTTPRequestHandler):
    server_version = "QuackillTelemetry/1"

    def _reject(self, code, msg):
        body = msg.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):  # noqa: N802
        if self.path.rstrip("/") not in ("/ingest", ""):
            self._reject(404, "unknown path")
            return
        n = int(self.headers.get("Content-Length", "0") or 0)
        if n <= 0:
            self._reject(400, "empty body")
            return
        raw = self.rfile.read(n).decode("utf-8", errors="replace")
        good, bad = [], 0
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except Exception:  # noqa: BLE001
                bad += 1
                continue
            if isinstance(e, dict) and "ev" in e:
                good.append(e)
            else:
                bad += 1
        if not good:
            self._reject(400, "no valid events (%d bad lines)" % bad)
            return
        os.makedirs(DATA, exist_ok=True)
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        path = os.path.join(DATA, "batch-%s.jsonl" % stamp)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            for e in good:
                f.write(json.dumps(e, ensure_ascii=False) + "\n")
        print("  ← %d 条（坏行 %d）→ %s" % (len(good), bad, os.path.basename(path)))
        body = ("ok %d" % len(good)).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802
        # 健康检查：部署 / 联调时先 curl 一下，别拿游戏试。
        body = b"ok"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):  # 安静点，只留我们自己打的摘要
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8788)
    ap.add_argument("--host", default="127.0.0.1")
    a = ap.parse_args()
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print("接收器 → http://%s:%d/ingest  （落盘 %s）" % (a.host, a.port, DATA))
    print("把 telemetry.gd 的 UPLOAD_ENDPOINT 指到上面这个地址即可。Ctrl+C 退出。")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")


if __name__ == "__main__":
    main()
