#!/usr/bin/env python3
"""音乐链接解析器 v3：修 http:// 直链 + 归一化标题匹配 + 魔王魂 slug probing。

v2 发现：PeriTune 下载链是 http://（非 https），且标题用下划线（Sketch_Forest）。
v3：归一化匹配（去空格/下划线、忽略大小写）；music/loop 链 http&https 双抓；
魔王魂失败项用候选 slug 直接 probing + 搜索重试。
"""
import json
import re
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

PROXY = "http://127.0.0.1:63276"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
V2 = Path("E:/tmp/music_manifest_v2.json")
OUT = Path("E:/tmp/music_manifest_v3.json")

PT_NAMES = ["Poema", "Morning Snowfields", "Positive_Happy", "Sakuya2", "Enjoyable 3",
            "Sketch Forest", "Wonder 5", "Teatime", "Piano Refreshing", "Fight", "Wonder 2",
            "Battlefield 5", "Strategy 4", "Raid 2", "Breakthrough", "Dramatic", "Rapid 4",
            "Havoc", "Valiant", "Black_Crystal", "Crimson_Moon", "Augury", "Royal_Baroque",
            "Wish4", "Music-box_Pleasant", "Harvest", "Soaring", "Holy Place", "Grief 2",
            "Music-box_Sad", "Demise"]
MAOU_FIX = {
    "Burning Heart": ["bgm_burning_heart", "bgm_burningheart", "game_battle20"],
    "シャイニングスター": ["bgm_shiningstar", "bgm_shining_star"],
    "ハルジオン": ["bgm_harujion", "bgm_halzion"],
    "月と狼": ["bgm_tsukitokam", "bgm_tsukitookami"],
}


def log(*a):
    print(*a, flush=True)


def norm(s: str) -> str:
    return re.sub(r"[\s_\-]+", "", s or "").lower()


def get(url: str, tries=8, need: bytes = b"") -> bytes:
    for i in range(tries):
        r = subprocess.run(
            ["curl", "-sL", "-x", PROXY, "--max-time", "120", "-A", UA, url],
            capture_output=True)
        if len(r.stdout) > 1000 and (not need or need in r.stdout):
            return r.stdout
        time.sleep(4)
    return b""


def resolve_pt(name: str) -> dict:
    q = urllib.parse.quote(name)
    html = get(f"https://peritune.com/?s={q}").decode("utf-8", "replace")
    results = re.findall(
        r'href="(https://peritune\.com/blog/20\d\d/\d\d/[^"]+/)"[^>]*>([^<]{5,140})<', html)
    pick = None
    for url, title in results:
        if norm(name) in norm(title):
            pick = (title, url)
            break
    if not pick:
        return {"name": name, "ok": False, "why": "no match"}
    title, page = pick
    ph = get(page, need=b"MP3").decode("utf-8", "replace")
    if not ph:
        return {"name": name, "ok": False, "why": "page truncated", "page": page}
    mp3 = re.search(r'href="(https?://peritune\.com/music/[^"]+)"', ph)
    loop = re.search(r'href="(https?://peritune\.com/loop/[^"]+)"', ph)
    drive = re.findall(r'https?://drive\.google\.com/file/d/[A-Za-z0-9_-]+', ph)
    return {"name": name, "ok": True, "page": page, "title": title,
            "mp3": mp3.group(1) if mp3 else None,
            "loop": loop.group(1) if loop else None,
            "drive": drive[0] if drive else None}


def resolve_maou(name: str, slugs) -> dict:
    # 1) 直接 probing 候选 slug
    for slug in slugs:
        page = f"https://maou.audio/{slug}/"
        ph = get(page, need="魔王魂".encode()).decode("utf-8", "replace")
        if ph and "404" not in ph[:200]:
            ogg = re.search(r'(https://maou\.audio/sound/[^"\']+\.ogg)', ph)
            t = re.search(r"<title>([^<]+)</title>", ph)
            if ogg:
                return {"name": name, "ok": True, "page": page, "ogg": ogg.group(1),
                        "title": t.group(1).split("|")[0].strip() if t else name}
    # 2) 搜索重试
    for q in (name,):
        qq = urllib.parse.quote(q)
        for _ in range(4):
            html = get(f"https://maou.audio/?s={qq}").decode("utf-8", "replace")
            m = re.search(r'href="(https://maou\.audio/(?:bgm|game)_[a-z0-9_]+/)"', html)
            if m:
                page = m.group(1)
                ph = get(page, need="魔王魂".encode()).decode("utf-8", "replace")
                ogg = re.search(r'(https://maou\.audio/sound/[^"\']+\.ogg)', ph)
                t = re.search(r"<title>([^<]+)</title>", ph)
                if ogg:
                    return {"name": name, "ok": True, "page": page, "ogg": ogg.group(1),
                            "title": t.group(1).split("|")[0].strip() if t else name}
            time.sleep(3)
    return {"name": name, "ok": False}


def main():
    v2 = json.loads(V2.read_text(encoding="utf-8"))
    out = {}
    # OpenTracks 结果直接用 v2（已正确）
    for slot, cands in v2.items():
        for c in cands:
            if c["lib"] == "OpenTracks":
                out.setdefault(slot, []).append(c)
    # PeriTune 全部重解析
    slot_of = {}
    for slot, cands in v2.items():
        for c in cands:
            if c["lib"] == "PeriTune":
                slot_of[c["name"]] = slot
    for name in PT_NAMES:
        slot = slot_of.get(name, "?")
        log(f"[PeriTune] {slot} / {name}")
        out.setdefault(slot, []).append({"lib": "PeriTune", **resolve_pt(name)})
        time.sleep(1)
    # 魔王魂：v2 成功的保留，失败的重试
    for slot, cands in v2.items():
        for c in cands:
            if c["lib"] == "魔王魂" and c.get("ok"):
                out.setdefault(slot, []).append(c)
    for name, slugs in MAOU_FIX.items():
        slot = "battle_boss" if name == "Burning Heart" else ("victory" if name in ("シャイニングスター", "ハルジオン") else "defeat")
        log(f"[魔王魂] {slot} / {name}")
        out.setdefault(slot, []).append({"lib": "魔王魂", **resolve_maou(name, slugs)})
        time.sleep(1)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    ok = sum(1 for s in out.values() for c in s if c.get("ok"))
    dl = sum(1 for s in out.values() for c in s if c.get("mp3") or c.get("loop") or c.get("ogg") or c.get("drive"))
    log(f"DONE ok={ok} 有直链={dl} -> {OUT}")


main()
