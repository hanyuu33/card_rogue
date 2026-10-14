# R170 素材管线：缎带抠图（洋红底→透明）+ 羊皮纸无缝化（中心裁切→镜像平铺）。
# 纪律：边缘洪水填充（不误伤内部高光）→ 只留最大连通块 → 裁包围盒 → 缩放。
from pathlib import Path
from collections import deque
from PIL import Image

SRC = Path("art_src/r170")
OUT = Path("assets/ui")

RIBBONS = {
    0: "A_single_small_vertical_hangin_2026-10-14T10-05-12.png",  # 普通 灰褐布
    1: "A_single_small_vertical_hangin_2026-10-14T10-05-13.png",  # 稀有 宝蓝绸
    2: "A_single_small_vertical_hangin_2026-10-14T10-06-20.png",  # 史诗 紫绸金绣
    3: "A_single_small_vertical_hangin_2026-10-14T10-05-14.png",  # 初始 森林绿
    4: "A_single_small_vertical_hangin_2026-10-14T10-05-08.png",  # 怪物 暗红战损
    5: "A_single_small_vertical_hangin_2026-10-14T10-05-11.png",  # 事件 亮紫罗兰
}
PARCH = "Seamless_aged_parchment_paper__2026-10-14T10-05-12.png"


def bg_color_of(im):
    ## 生成模型的「洋红底」实测并不纯（(231,5,118) 这类），阈值写死会漏 →
    ## 直接采样四角取中位数当背景色，再用色距分类。
    w, h = im.size
    px = im.load()
    samples = [px[3, 3], px[w - 4, 3], px[3, h - 4], px[w - 4, h - 4]][:3]
    rs = sorted(s[0] for s in samples)
    gs = sorted(s[1] for s in samples)
    bs = sorted(s[2] for s in samples)
    return (rs[1], gs[1], bs[1])


def cut_ribbon(src: Path, dst: Path):
    im = Image.open(src).convert("RGBA")
    W, H = im.size
    # 半分辨率做掩膜（纯 Python BFS 的规模可控）
    small = im.resize((W // 2, H // 2), Image.BILINEAR)
    w, h = small.size
    px = small.load()
    cr, cg, cb = bg_color_of(small)
    print("  bg =", (cr, cg, cb), src.name[:44])
    tol2 = 70.0 * 70.0  # 色距阈值（平方）：容下底色的明暗渐变
    mag = bytearray(w * h)  # 1 = 背景候选
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d2 = (r - cr) * (r - cr) + (g - cg) * (g - cg) + (b - cb) * (b - cb)
            if d2 < tol2:
                mag[y * w + x] = 1
    # ① 边缘洪水填充：只把「与图边相连的洋红」标成背景（内部高光/缝隙不受影响）
    bg = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mag[y * w + x] and not bg[y * w + x]:
                bg[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if mag[y * w + x] and not bg[y * w + x]:
                bg[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < w and 0 <= ny < h:
                i = ny * w + nx
                if mag[i] and not bg[i]:
                    bg[i] = 1
                    q.append((nx, ny))
    # ② 前景（非背景）里找最大连通块 = 缎带本体（水印/杂点是独立小块，丢弃）
    fg = bytearray(w * h)
    for i in range(w * h):
        fg[i] = 0 if bg[i] else 1
    seen = bytearray(w * h)
    best = None  # (size, [indices])
    for i in range(w * h):
        if not fg[i] or seen[i]:
            continue
        comp = []
        q.append((i % w, i // w))
        seen[i] = 1
        while q:
            x, y = q.popleft()
            comp.append(y * w + x)
            for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if fg[j] and not seen[j]:
                        seen[j] = 1
                        q.append((nx, ny))
        if best is None or len(comp) > len(best):
            best = comp
    keep = bytearray(w * h)
    for i in best:
        keep[i] = 1
    # ②b 封闭背景口袋：横杆与绸布围出的洋红小块**不与图边相连**，洪水填充够不着，
    #     会被并进缎带连通块（出图实测：几条缎带顶部残留粉色补丁）→
    #     颜色仍落在背景色距内的像素一律透明（绸布本体与背景色相距甚远，安全）。
    for i in range(w * h):
        if keep[i] and mag[i]:
            keep[i] = 0
    # ③ 掩膜升回全分辨率，合成 alpha
    mask = Image.frombytes("L", (w, h), bytes(255 if v else 0 for v in keep))
    mask = mask.resize((W, H), Image.BILINEAR)
    im.putalpha(mask)
    # ④ 裁包围盒（留 2px 呼吸边）
    bbox = mask.getbbox()
    assert bbox, "掩膜为空：%s" % src
    l, t, r, b = bbox
    l = max(0, l - 2); t = max(0, t - 2); r = min(W, r + 2); b = min(H, b + 2)
    im = im.crop((l, t, r, b))
    # ⑤ 缩放到素材尺寸（最长边 192；卡上只画到 ~48px，余量给未来大图）
    scale = 192.0 / max(im.size)
    im = im.resize((max(1, round(im.width * scale)),
                    max(1, round(im.height * scale))), Image.LANCZOS)
    im.save(dst)
    print("  ribbon -> %s  %dx%d" % (dst, im.width, im.height))


def make_parchment(src: Path, dst: Path):
    from PIL import ImageFilter
    im = Image.open(src).convert("RGB")
    W, H = im.size
    # 水印在右下（x>860）→ 只取左部 0..860；再缩到 512 作为平铺单元
    im = im.crop((0, 0, 860, H)).resize((768, 768), Image.LANCZOS)
    # 镜像 2x2 → 任意方向平铺都无缝（边界互为镜像，导数连续）
    def mirror2x2(base):
        t = Image.new("RGB", (base.width * 2, base.height * 2))
        t.paste(base, (0, 0))
        t.paste(base.transpose(Image.FLIP_LEFT_RIGHT), (base.width, 0))
        t.paste(base.transpose(Image.FLIP_TOP_BOTTOM), (0, base.height))
        t.paste(base.transpose(Image.ROTATE_180), (base.width, base.height))
        return t
    tile = mirror2x2(im)
    # 低频光照场压平：原图有方向性明暗渐变，直接镜像会看出「对称轴」。
    # ⚠️ 模糊场必须在**平铺后的图**上做、且用 3x3 扩展再取中心 ——
    #    PIL 高斯模糊在图边是复制延拓，直接在单块上模糊会让边缘带偏色，
    #    平铺后边界处正好露出那条偏色带（出图实测有十字缝）。
    mega = Image.new("RGB", (tile.width * 3, tile.height * 3))
    for dx in range(3):
        for dy in range(3):
            mega.paste(tile, (dx * tile.width, dy * tile.height))
    low = mega.filter(ImageFilter.GaussianBlur(120)).crop(
        (tile.width, tile.height, tile.width * 2, tile.height * 2))
    src_px, low_px = tile.load(), low.load()
    for y in range(tile.height):
        for x in range(tile.width):
            r, g, b = src_px[x, y]
            lr, lg, lb = low_px[x, y]
            src_px[x, y] = (
                min(255, int(r * 235.0 / max(1, lr))),
                min(255, int(g * 225.0 / max(1, lg))),
                min(255, int(b * 205.0 / max(1, lb))))
    tile.save(dst)
    print("  parchment -> %s  %dx%d" % (dst, tile.width, tile.height))


def main():
    for rarity, name in RIBBONS.items():
        cut_ribbon(SRC / name, OUT / ("ribbon_%d.png" % rarity))
    make_parchment(SRC / PARCH, OUT / "panel_parchment.png")
    print("done")


if __name__ == "__main__":
    main()
