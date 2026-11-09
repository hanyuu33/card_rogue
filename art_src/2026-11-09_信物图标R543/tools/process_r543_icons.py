# R543 信物图标处理：棋盘格假透明底 → 真透明 + 去水印 + 裁剪缩放
# 流程按 card-rogue-asset skill：四角 BFS 抠连通背景 → 羽化 → 只留最大连通块 → bbox → 512x512 画布
import os
from collections import deque
from PIL import Image, ImageFilter

RAW = r"D:\work\card_rogue\_r543_icons"
OUT = r"D:\work\card_rogue\assets\ui"
MAP = {
    "Game_item_icon_in_Hearthstone__2026-11-09T08-25-37.png": "key_icon_screw.png",   # 完美螺钉
    "Game_item_icon_in_Hearthstone__2026-11-09T08-25-59.png": "key_icon_seed.png",    # 生命之种
    "Game_item_icon_in_Hearthstone__2026-11-09T08-26-25.png": "key_icon_dagger.png",  # 屠戮匕首
}
EDGE = 512


def is_bg(c):
    # 棋盘格底 = 白(255) 与浅灰(约204) 相间；低饱和 + 足够亮才算背景。
    r, g, b = c[:3]
    return min(r, g, b) >= 196 and max(r, g, b) - min(r, g, b) <= 20


def flood_bg(im):
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(px[x, y]) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(px[x, y]) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and is_bg(px[nx, ny]):
                seen[ny][nx] = True
                q.append((nx, ny))


def largest_blob(im):
    # 只保留最大 alpha 连通块（去掉右下角 AI 水印等残渣）
    w, h = im.size
    px = im.load()
    label = [[0] * w for _ in range(h)]
    best, best_id, cur = 0, 0, 0
    for sy in range(h):
        for sx in range(w):
            if label[sy][sx] == 0 and px[sx, sy][3] > 0:
                cur += 1
                label[sy][sx] = cur
                cnt = 1
                q = deque([(sx, sy)])
                while q:
                    x, y = q.popleft()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and label[ny][nx] == 0 and px[nx, ny][3] > 0:
                            label[ny][nx] = cur
                            cnt += 1
                            q.append((nx, ny))
                if cnt > best:
                    best, best_id = cnt, cur
    for y in range(h):
        for x in range(w):
            if label[y][x] != best_id:
                px[x, y] = (255, 255, 255, 0)


def soften_edge(im):
    # 紧贴透明区的一圈按白度/灰度给半透明羽化，去硬锯齿
    w, h = im.size
    px = im.load()
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        edge.append((x, y))
                        break
    for x, y in edge:
        r, g, b, a = px[x, y]
        if min(r, g, b) >= 180:
            px[x, y] = (r, g, b, 150)


def process(src, dst):
    im = Image.open(os.path.join(RAW, src)).convert("RGB")
    im = im.convert("RGBA")
    flood_bg(im)
    largest_blob(im)
    soften_edge(im)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    bbox = im.getbbox()
    im = im.crop(bbox)
    im.thumbnail((int(EDGE * 0.94), int(EDGE * 0.94)), Image.LANCZOS)
    canvas = Image.new("RGBA", (EDGE, EDGE), (0, 0, 0, 0))
    canvas.paste(im, ((EDGE - im.width) // 2, (EDGE - im.height) // 2), im)
    canvas.save(os.path.join(OUT, dst))
    # 验收拼图：真实徽章 44px 缩样
    small = canvas.copy()
    small.thumbnail((44, 44), Image.LANCZOS)
    return canvas, small


log = []
previews = []
for src, dst in MAP.items():
    canvas, small = process(src, dst)
    log.append("%s -> %s  %dx%d" % (src, dst, canvas.width, canvas.height))
    previews.append(small)

# 三张 44px 验收拼图（金边模拟地图徽章）
sheet = Image.new("RGBA", (44 * 3 + 40, 84), (40, 34, 46, 255))
for i, p in enumerate(previews):
    sheet.paste(p, (10 + i * 54, 20), p)
sheet.save(r"D:\work\card_rogue\_r543_icons\_preview_44px.png")
open(r"C:\Users\Administrator\AppData\Local\Temp\r543_icon.txt", "w", encoding="utf-8").write("\n".join(log))
