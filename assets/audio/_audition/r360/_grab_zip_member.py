# -*- coding: utf-8 -*-
"""按 zip 中央目录，用 HTTP Range 只取需要的那个成员（不必下完 30MB 整包）。"""
import os, struct, sys, time, urllib.request, zlib

URL = "https://peritune.com/music/PeriTune_Rituale_Machina.zip"
WANT = "_loop.ogg"
UA = {"User-Agent": "Mozilla/5.0"}


def head_size():
    r = urllib.request.urlopen(urllib.request.Request(URL, method="HEAD", headers=UA), timeout=30)
    return int(r.headers["Content-Length"])


def get_range(a, b):
    for i in range(6):
        try:
            req = urllib.request.Request(URL, headers={**UA, "Range": "bytes=%d-%d" % (a, b)})
            d = urllib.request.urlopen(req, timeout=180).read()
            if len(d) == b - a + 1:
                return d
        except Exception as e:
            print("  range retry", i, e, flush=True)
        time.sleep(2)
    raise SystemExit("range failed %d-%d" % (a, b))


total = head_size()
print("zip size", total, flush=True)
tail = get_range(max(0, total - 131072), total - 1)
eocd = tail.rfind(b"PK\x05\x06")
cd_size, cd_off = struct.unpack("<II", tail[eocd + 12:eocd + 20])
print("cd_off", cd_off, "cd_size", cd_size, flush=True)
cd = get_range(cd_off, cd_off + cd_size - 1)

p = 0
found = None
while p < len(cd):
    if cd[p:p + 4] != b"PK\x01\x02":
        break
    method = struct.unpack("<H", cd[p + 10:p + 12])[0]
    csize, usize = struct.unpack("<II", cd[p + 20:p + 28])
    nlen, elen, clen = struct.unpack("<HHH", cd[p + 28:p + 34])
    lho = struct.unpack("<I", cd[p + 42:p + 46])[0]
    nm = cd[p + 46:p + 46 + nlen].decode("utf-8", "replace")
    print("  %-42s method=%d csize=%d usize=%d off=%d" % (nm, method, csize, usize, lho), flush=True)
    if nm.endswith(WANT):
        found = (nm, method, csize, usize, lho)
    p += 46 + nlen + elen + clen

if not found:
    raise SystemExit("member not found")

nm, method, csize, usize, lho = found
lh = get_range(lho, lho + 29)
l_nlen, l_elen = struct.unpack("<HH", lh[26:30])
start = lho + 30 + l_nlen + l_elen
print("fetching", nm, "data", start, "-", start + csize - 1, flush=True)
raw = get_range(start, start + csize - 1)
data = zlib.decompress(raw, -15) if method == 8 else raw
assert len(data) == usize, (len(data), usize)
assert data[:4] == b"OggS", data[:8]
out = "PeriTune_Rituale_Machina_loop.ogg"
open(out, "wb").write(data)
print("OK", out, len(data), "bytes", flush=True)
