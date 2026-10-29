# -*- coding: utf-8 -*-
"""参考图抓取（仅供内部风格参考，不入库、不进 git）

走 cn.bing.com 图片搜索的 async 接口：
  1. 从结果 HTML 里按出现顺序抽出 murl（原图地址）与 turl（Bing 缩略图）
  2. 优先下载原图；失败或过小再退回缩略图
  3. 落到 art_src/_ref/<slug>/NN.jpg，并写 _sources.json 记录来源
用法： N=8 python _ref_fetch.py '[["slug","关键词"], ...]'
"""
import os, re, sys, json, html, urllib.request, urllib.parse

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
HDRS = {
    "User-Agent": UA,
    "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
    "Accept-Language": "ja,en;q=0.8,zh-CN;q=0.6",
}
OUT = "art_src/_ref"


def fetch(url, timeout=20, referer=None):
    h = dict(HDRS)
    if referer:
        h["Referer"] = referer
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def search(q, n=10):
    """返回 [(murl, turl, title), ...]"""
    u = ("https://cn.bing.com/images/async?q=" + urllib.parse.quote(q) +
         "&first=1&count=%d&mmasync=1" % n)
    raw = html.unescape(fetch(u, referer="https://cn.bing.com/").decode("utf-8", "replace"))
    mus = re.findall(r'"murl":"(https?://[^"]+)"', raw)
    tus = re.findall(r'"turl":"(https?://[^"]+)"', raw)
    tts = re.findall(r'"t":"([^"]{2,120})"', raw)
    items, seen = [], set()
    for i in range(max(len(mus), len(tus))):
        m = mus[i] if i < len(mus) else ""
        t = tus[i] if i < len(tus) else ""
        if not (m or t):
            continue
        key = m or t
        if key in seen:
            continue
        seen.add(key)
        items.append((m, t, tts[i] if i < len(tts) else ""))
    return items[:n]


def main(slug, query, n=10):
    d = os.path.join(OUT, slug)
    os.makedirs(d, exist_ok=True)
    got = search(query, n)
    print("[%s] %s -> %d hits" % (slug, query, len(got)))
    meta = []
    for k, (murl, turl, title) in enumerate(got, 1):
        p = os.path.join(d, "%02d.jpg" % k)
        data, src = None, ""
        if murl:
            try:
                cand = fetch(murl)
                if len(cand) > 12000:
                    data, src = cand, "原图"
            except Exception:
                pass
        if data is None and turl:
            try:
                data, src = fetch(turl, referer="https://cn.bing.com/"), "缩略图"
            except Exception as e:
                print("   fail", str(e)[:50])
                continue
        if not data or len(data) < 4000:
            print("   skip small")
            continue
        open(p, "wb").write(data)
        try:
            from PIL import Image as _I
            w, h = _I.open(p).size
        except Exception:
            w = h = 0
        meta.append({"file": p, "title": title[:80], "src": src,
                     "url": (murl or turl)[:300], "w": w, "h": h})
        print("   ok %s %dx%d %dKB [%s]" % (p, w, h, len(data) // 1024, src))
    open(os.path.join(d, "_sources.json"), "w", encoding="utf-8").write(
        json.dumps({"query": query, "items": meta}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    for slug, q in json.loads(sys.argv[1]):
        try:
            main(slug, q, int(os.environ.get("N", "10")))
        except Exception as e:
            print("[%s] ERROR %s" % (slug, e))
