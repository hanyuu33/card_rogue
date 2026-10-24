# 第三层背景图 —— 天空中行进的巨大机械方舟（R354）

## 成品

| 文件 | 说明 |
|---|---|
| `map_bg_3_定稿1280x720.png` | **定稿**，已放入 `assets/ui/map_bg_3.png` |
| `_对比_压暗后.png` | 验收对照：五个候选各叠 42% 暗罩（地图 `_draw_background()` 的真实条件） |
| `raw/` | 五版原图（1536×1024，未裁） |
| `备选_*` | 未采用的另外三版，留着备查 |
| `REJECT_v1_*` | 画风不对的废稿 |

## 用户要求

> 生成第三层的背景图：天空中，巨大的机械方舟在云层中行进。注意背景图大小和比例，注意风格为日本动漫

- 尺寸/比例：与前两层一致，**1280 × 720（16:9）**，`UiAssets.map_bg(3)` 按层号自动取。
- 风格：**日本动漫**（手绘 2D 背景美术 / 赛璐璐），不是写实渲染。

## 处理链

原图 1536×1024（生成模型可选尺寸里最接近 16:9 的）
→ 切底部 11%（去右下角「AI生成」水印）
→ 顶部让 24px、裁成 1536×864（16:9）
→ LANCZOS → **1280×720**
→ `--headless --import`

定稿额外做了一步调色（**不是**调亮度混过去，见下面 v4 那条）：
`gamma 0.68` + `Color ×1.30` + `Contrast ×1.10`，把原图平均亮度 70 → 102。

## 五版演进（每版的判据）

| 版本 | 结果 | 判据 |
|---|---|---|
| v1 | ✗ 废 | 出了**写实厚涂 / 3D 渲染**，不是日式动漫；方舟占满画面像模型摆件 |
| v2 | 备选 | 动漫味对了（线稿 + 手绘云），但云和光都偏亮，铺到地图上会和白云朵节点图标撞 |
| v3 | 备选 | 平涂最干净、行进感最强，但整片冷蓝云海 → 读成「云海破浪的潜水艇」，且图标糊在底上 |
| v4 | 定稿母本 | 构图最好：斜穿破浪 + 头顶深蓝天空 + 云海灰蓝。**太暗**（压暗后亮度 43，第 2 层是 69） |
| v5 | 备选 | 亮度对了（白天高空），但船被云海淹掉一半，破浪感和「巨大」感都弱 |

**定稿 = v4 的构图 + 调色到 v5 的亮度。**

## 踩到的三个坑（下次直接用）

1. **「日式动漫」必须写成「不是写实」才生效。** 只写 `Japanese anime style` 出来的是厚涂厚光影。
   要同时写 `hand-drawn 2D cel-animation look` + `NOT 3D, NOT photo-real, NOT oil painting`
   + `clean dark ink line work` + `2 to 3 hard-edged tone steps per surface`。
2. **地图背景不是「看完就算」的插图 —— 它上面压着 42% 暗罩和满屏白色云朵节点。**
   判据不是「原图好不好看」，而是「**压暗后**平均亮度」：第一层 107 / 第二层 69 /
   战斗默认 98。第三层落 **62**（最高一层、最冷一调，继续往下递进但不至于变夜景）。
   验收必须真跑 `map.tscn -- --screenshot --bg 3` 看，不能只看原图。
3. **「巨大」的判据是「被云吃掉一截」，不是「画得大」。** 写
   `the cloud layer swallows the bottom of the hull` + `a thin cloud band drifts IN FRONT
   of the far end` —— 大小是靠**遮挡关系**读出来的，占画面比例大反而像模型。

## 复现用的关键提示词（定稿那一版，节选）

```
Japanese anime film background art, hand-painted 2D cel-animation look.
A colossal mechanical ark travelling through a vast layer of cloud, seen from far
away and slightly above, crossing the frame diagonally from the lower left.
THE ARK: long dark slate-blue steel hull with big flat armour plates, a dense cluster
of gothic spires, towers and smokestacks on its back, three large side propeller pods,
tall propulsion fins at the stern. NOT a black silhouette — the steel keeps its
blue-grey colour and flat cel-shaded planes.
SCALE: the cloud layer swallows the bottom of the hull, and a separate thin cloud band
drifts in front of the far end of the ship.
VALUE: overall MEDIUM tone, as bright as a clear afternoon. Sky clear medium blue at
the top; cloud sea slate blue / dusty lilac / cool grey, pale but NOT pure-white crests.
NO photo-real rendering, NO 3D CGI look, NO oil paint texture, NO visible brush strokes,
NO ray-traced reflections.
NO text, NO letters, NO watermark, NO people, NO jet aircraft, NO second airship.
```
