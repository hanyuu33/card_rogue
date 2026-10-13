#!/usr/bin/env python3
"""Godot 4.3 导出模板「zip 手术」下载器 v2。

沙箱代理对大文件限速（~5-9KB/s）且 burst 后会拒绝连接（000/rc=7）。
策略：tpz 是 zip → 只下尾部中央目录 + 需要的成员字节段。
需要：templates/version.txt + templates/windows_release_x86_64.exe（+ console 变体，75KB）。
全程断点续传 + 长 retry。产物放到 %APPDATA%/Godot/export_templates/。
"""
import os
import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path

URL = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
PROXY = "http://127.0.0.1:63276"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
TOTAL = 1073228327
TAIL_BYTES = 400_000
WORK = Path("E:/tmp/tpl_work")
OUT_DIR = Path(os.path.expandvars(r"%APPDATA%\Godot\export_templates"))
# 成员名 → 安装名（去掉 templates/ 前缀）
NEED = {
    "templates/version.txt": "version.txt",
    "templates/windows_release_x86_64.exe": "windows_release_x86_64.exe",
    "templates/windows_release_x86_64_console.exe": "windows_release_x86_64_console.exe",
}


def log(*a):
    print(*a, flush=True)


def curl_range(start: int, end: int, out: Path, budget=90, tries=100_000) -> int:
    """断点续传下载 [start, end] 到 out，返回文件大小。"""
    want = end - start + 1
    CHUNK = 1_000_000  # 代理对超大 Range 会挂死，必须固定小块请求
    stall = 0
    for attempt in range(tries):
        cur = out.stat().st_size if out.exists() else 0
        if cur >= want:
            return cur
        req_end = min(start + cur + CHUNK - 1, end)
        r = subprocess.run(
            ["curl", "-sL", "-x", PROXY, "--max-time", str(budget), "-A", UA,
             "-r", f"{start + cur}-{req_end}", "-o", str(out) + ".part", URL],
            capture_output=True)
        part = Path(str(out) + ".part")
        got = part.stat().st_size if part.exists() else 0
        if got > want - cur:
            # 服务器忽略 Range 返回了全量 → 只取需要的一段（防污染）
            with open(part, "rb") as p:
                p.seek(cur)
                data = p.read(want - cur)
            with open(out, "ab") as f:
                f.write(data)
            part.unlink()
            log(f"  {out.name}: 截断全量响应，取 {len(data)}B")
        elif got > 0:
            with open(out, "ab") as f, open(part, "rb") as p:
                f.write(p.read())
            part.unlink()
            log(f"  {out.name}: {out.stat().st_size}/{want}")
            stall = 0
        else:
            stall += 1
            if stall % 10 == 1:
                log(f"  {out.name}: 无进展 x{stall} (rc={r.returncode}) #{attempt}")
            time.sleep(5)
    return out.stat().st_size if out.exists() else 0


def parse_cd(tail: bytes, tail_start: int):
    i = tail.rfind(b"PK\x05\x06")
    if i < 0:
        raise RuntimeError("EOCD not found")
    (_, disk, cd_disk, n_disk, n_total, cd_size, cd_off, _) = struct.unpack("<IHHHHIIH", tail[i:i + 22])
    if cd_off < tail_start:
        raise RuntimeError("中央目录不在尾部窗口内，需扩大 TAIL_BYTES")
    cd = tail[cd_off - tail_start: cd_off - tail_start + cd_size]
    members = {}
    p = 0
    while p + 46 <= len(cd) and cd[p:p + 4] == b"PK\x01\x02":
        (ver, _v, _f, method, _t, _d, _crc, csize, usize, nlen, elen, clen, _dk, _ia, _ea, loff) = struct.unpack("<HHHHHHIIIHHHHHII", cd[p + 4:p + 46])
        name = cd[p + 46:p + 46 + nlen].decode("utf-8", "replace")
        members[name] = (method, csize, usize, loff)
        p += 46 + nlen + elen + clen
    return members


def extract_member(raw: bytes, method: int, csize: int, name: str) -> bytes:
    if raw[:4] != b"PK\x03\x04":
        raise RuntimeError(f"{name}: 坏的 local header {raw[:8]!r}")
    nlen, elen = struct.unpack("<HH", raw[26:30])
    data = raw[30 + nlen + elen: 30 + nlen + elen + csize]
    if len(data) < csize:
        raise RuntimeError(f"{name}: 数据不足 {len(data)}/{csize}")
    if method == 0:
        return data
    if method == 8:
        return zlib.decompress(data, -15)
    raise RuntimeError(f"{name}: 不支持的压缩方法 {method}")


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    tail_file = WORK / "tail.bin"
    if tail_file.stat().st_size < TAIL_BYTES if tail_file.exists() else True:
        curl_range(TOTAL - TAIL_BYTES, TOTAL - 1, tail_file, budget=120)
    tail = tail_file.read_bytes()
    members = parse_cd(tail, TOTAL - TAIL_BYTES)
    log(f"中央目录 OK：{len(members)} 成员")
    for n in NEED:
        if n not in members:
            log(f"FATAL 缺成员 {n}")
            return 1

    for src, dst in NEED.items():
        method, csize, usize, loff = members[src]
        dest = OUT_DIR / dst
        if dest.exists() and dest.stat().st_size == usize:
            log(f"SKIP {dst} 已存在且大小吻合")
            continue
        raw_file = WORK / (dst + ".raw")
        curl_range(loff, loff + csize + 8192, raw_file, budget=120)
        raw = raw_file.read_bytes()
        data = extract_member(raw, method, csize, src)
        if len(data) != usize:
            log(f"WARN {dst}: 解出 {len(data)} != 声明 {usize}")
        dest.write_bytes(data)
        log(f"OK {dst}: {len(data):,}B -> {dest}")

    ver = (OUT_DIR / "version.txt").read_text(errors="replace").strip()
    log(f"version.txt = {ver!r}")
    log("ALL DONE")
    return 0


sys.exit(main())
