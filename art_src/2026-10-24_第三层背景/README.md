# 第三层背景图 —— 天空中漂行的巨大空艇（R354 / R354b 修正）

## 成品

| 文件 | 说明 |
|---|---|
| `map_bg_3_定稿1280x720.png` | **定稿**，已放入 `assets/ui/map_bg_3.png` |
| `_对比_压暗后.png` | 验收对照：旧版（战舰破浪）vs 新版（空艇云团），各叠 42% 暗罩 |
| `raw/` | 八版原图（1536×1024，未裁） |
| `REJECT_旧版_像战舰破浪1280x720.png` | **已被否掉**的第一版定稿（R354 初版） |
| `REJECT_v1_*` / `备选_*` | 画风不对的废稿 / 未采用的备选 |

## 用户要求

**第一轮：**

> 生成第三层的背景图：天空中，巨大的机械方舟在云层中行进。注意背景图大小和比例，注意风格为日本动漫

**第二轮（否掉第一版定稿）：**

> 不要做的像真的海和真的船，是空艇和云

第一版定稿被否的原因：`cloud sea` + `ploughing through` + `steel hull with armour plates` + `propeller pods`
这套词把画面推成了「钢制战舰在真云海里破浪」—— 有水面感的云海、有船首浪、有装甲带式的舷侧。

## 处理链

原图 1536×1024（生成模型可选尺寸里最接近 16:9 的）
→ 切底部 11%（去右下角「AI生成」水印）
→ 顶部让 24px、裁成 1536×864（16:9）
→ LANCZOS → **1280×720**
→ `--headless --import`

定稿额外调色：`gamma 1.40` + `Color ×1.16` + `Contrast ×1.06`，把平均亮度 134.7 → **105.4**（压暗后 63.8）。
调整目标不是「原图亮度」，是**压暗后**的亮度（见坑 2）。

## 版本演进

### 第一轮（「机械方舟在云层中行进」，方向是战舰）

| 版本 | 结果 | 判据 |
|---|---|---|
| v1 | ✗ 废 | 写实厚涂 / 3D 渲染，不是日式动漫；方舟占满画面像模型 |
| v2 | 备选 | 动漫味对了，但云和光偏亮，会和白云朵节点图标撞 |
| v3 | 备选 | 平涂最干净、行进感最强，但整片冷蓝云海 → 读成「云海里的潜水艇」 |
| v4 | 定稿母本 | 构图最好（斜穿破浪 + 头顶深蓝天空），但太暗（压暗后 43） |
| v5 | 备选 | 亮度对了，但船被云海淹掉一半，破浪感和巨大感都弱 |

**旧定稿 = v4 构图 + 调色到 v5 亮度** → 已被否（像真海真船）。

### 第二轮（「空艇和云」）

| 版本 | 结果 | 判据 |
|---|---|---|
| v6 | 备选 | 气球吊舱空艇 + 云团，方向对了；但云太白太多（原图亮度 171.6 / 压暗后 102），且下半云团有连成云海的势头 |
| v7 | ✗ 废 | 把云减到五六团之后**太空**：气囊变球形热气球、艇小得像玩具，「巨大」和「行进」全丢了 |
| v8 | **定稿** | 雪茄形长气囊 + 吊舱 + 尾鳍 + 螺旋桨 = 一眼是空艇；八到十团云块彼此分开、缝隙见天；顶光克制（原图 134.7 / 压暗后 63.8） |

**定稿 = v8 原图直出 + gamma 1.40 压到第三层该待的亮度。**

## 五个坑（下次直接用）

1. **「日式动漫」必须写成「不是写实」才生效。** 只写 `Japanese anime style` 出来的是厚涂厚光影。
   要同时写 `hand-drawn 2D cel-animation look` + `NOT 3D, NOT photo-real, NOT oil painting`
   + `clean dark ink line work` + `2 to 3 hard-edged tone steps per surface`。
2. **地图背景不是「看完就算」的插图 —— 它上面压着 42% 暗罩和满屏白色云朵节点。**
   判据不是「原图好不好看」，而是「**压暗后**平均亮度」：第一层 107 / 第二层 69 /
   战斗默认 98。第三层落 **63.8**（最高一层、最冷一调，继续往下递进但不至于变夜景）。
   验收必须真跑 `map.tscn -- --screenshot --bg 3` 看，不能只看原图。
3. **「巨大」的判据是「被云挡住一截」，不是「画得大」。** 写
   `one near cloud clump passes IN FRONT of the airship and hides the front of its envelope`
   —— 大小是靠**遮挡关系**读出来的，占画面比例大反而像模型。
4. **「不要像真的海」不是改词，是改云的形态。** 只要还写 `cloud sea` / `layer` / `carpet` /
   `horizon`，出来就是水面。必须写 `separate rounded clumps at DIFFERENT depths with large
   clear gaps of open sky between them`，再在反面点名
   `NO ocean / NO waves / NO foam / NO whitecaps / NO bow wave / NO wake lines /
   NO water reflections / NO horizontal water horizon line`。
5. **「不要像真的船」= 换主体，不是删细节。** 删掉炮塔装甲带之后剩下的还是船体。
   要明确写 `ONE VERY LONG cigar-shaped lifting envelope, NOT a round balloon, NOT a spherical
   hot-air balloon` + `a narrow gondola deck hanging below` + `NO battleship / NO naval vessel /
   NO gun turrets / NO armour belt`。
   ⚠️ 但反向也会翻车：v7 为了「更空艇」把云减太多，气囊变球形、艇变玩具 ——
   **云的密度和艇的体积是耦合的，动一个必须同时看另一个。**

## 复现用的关键提示词（定稿那一版，节选）

```
Japanese anime film background art, hand-painted 2D cel-animation look.
A COLOSSAL fantasy AIRSHIP glides steadily between drifting cloud clumps, seen from
far away and slightly above, moving from the lower left toward the middle right.

THE AIRSHIP — a FLYING VESSEL, not a sea ship. ONE VERY LONG cigar-shaped lifting
envelope, tapered and elongated with a pointed nose, rib seams running lengthwise.
NOT a round balloon, NOT a spherical hot-air balloon. Below it hangs a narrow gondola
deck with railings and a short mast; tall swept dorsal fins and a tail fin assembly;
several small propellers on short outriggers; thin cables and rigging.

THE CLOUDS: eight to ten separate, rounded, softly billowing cumulus CLUMPS, widely
spaced at DIFFERENT depths, with large clear gaps of open sky between them — they do
NOT merge into a continuous surface and do NOT form a carpet across the bottom.
Thin torn wisps drawn into long soft ribbons stream past the hull and trail behind.

VALUE: MEDIUM-to-DARK cool key. The sky is the brightest thing in the image: no cloud
and no part of the ship reaches pure white. Lit tops soft muted off-white, shaded sides
dusty lilac and cool slate blue.

ABSOLUTELY NOT A SEA: NO ocean, NO sea, NO water surface, NO waves, NO foam, NO
whitecaps, NO spray, NO bow wave, NO wake lines, NO reflections in water.
NOT A WARSHIP: NO battleship, NO naval vessel, NO gun turrets, NO armour belt,
NO smokestacks, NO round balloon gondola basket.

NO photo-real rendering, NO 3D CGI look, NO oil paint texture, NO visible brush strokes.
NO text, NO letters, NO watermark, NO people, NO jet aircraft, NO second airship.
```
