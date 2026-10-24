# 第三层背景图 —— 天空中压下来的巨大科幻舰体（R354 / R354b / R354c）

## 成品

| 文件 | 说明 |
|---|---|
| `map_bg_3_定稿1280x720.png` | **定稿 = V9（白天科幻版，R355 定案）**，已放入 `assets/ui/map_bg_3.png`（压暗后 ≈54.6） |
| `_对比_压暗后.png` | 验收对照：四版候选各叠 42% 暗罩（地图 `_draw_background()` 的真实条件） |
| `raw/` | 十张原图（1536×1024，未裁） |
| `REJECT_旧版_像战舰破浪1280x720.png` | 第一版定稿，被否（像真海真船） |
| `REJECT_第二版_复古气囊艇1280x720.png` | 第二版定稿，被否（太复古、缺压迫感） |
| `REJECT_第三版_海平线错觉1280x720.png` | 第三版定稿（v10），R355 被 V9 取代（用户点名用 V9） |
| `备选_*` | 未采用的备选，留着备查 |

## 用户要求（三轮）

**第一轮：**

> 生成第三层的背景图：天空中，巨大的机械方舟在云层中行进。注意背景图大小和比例，注意风格为日本动漫

**第二轮（否掉第一版）：**

> 不要做的像真的海和真的船，是空艇和云

**第三轮（否掉第二版）：**

> 感觉太复古了，而且缺少压迫感。做一个有科幻感的版本，并且用侧面贴近的视角体现它的巨大，最后注意保持风格

## 处理链

原图 1536×1024（生成模型可选尺寸里最接近 16:9 的）
→ 切底部 11%（去右下角「AI生成」水印）
→ 顶部让 6px、裁成 1536×864（16:9）
→ LANCZOS → **1280×720**
→ `--headless --import`

定稿调色用的是 **S 曲线**而不是 gamma：
`[(0,0),(56,58),(120,168),(200,232),(255,255)]` + `Color ×1.10` + `Contrast ×1.08`
→ 平均亮度 72.2 → 86.2（压暗后 **52.7**）。

⚠️ 这版**不能用 gamma 提亮**：gamma 0.72 能把压暗亮度拉到 60.8，但画面整体发灰，
压迫感（深蓝黑的巨物）当场没了。S 曲线保住黑位、只抬中间调 —— 这是这一轮的关键手法。

## 版本演进

### 第一轮：机械方舟（方向是战舰）

| 版本 | 结果 | 判据 |
|---|---|---|
| v1 | ✗ 废 | 写实厚涂 / 3D 渲染，不是日式动漫；方舟占满画面像模型 |
| v2 | 备选 | 动漫味对了，但云和光偏亮，会和白云朵节点图标撞 |
| v3 | 备选 | 平涂最干净、行进感最强，但整片冷蓝云海 → 读成「云海里的潜水艇」 |
| v4 | 定稿母本 | 构图最好（斜穿破浪 + 头顶深蓝天空），但太暗（压暗后 43） |
| v5 | 备选 | 亮度对了，但船被云海淹掉一半，破浪感和巨大感都弱 |

**旧定稿 = v4 构图 + 调色到 v5 亮度** → 被否（像真海真船，见第二轮）。

### 第二轮：空艇与云

| 版本 | 结果 | 判据 |
|---|---|---|
| v6 | 备选 | 气球吊舱空艇 + 云团，方向对了；但云太白太多（原图 171.6 / 压暗 102），gamma 压到 1.95 才 74，压不动 |
| v7 | ✗ 废 | 把云减到五六团之后**太空**：气囊变球形热气球、艇小得像玩具，「巨大」和「行进」全丢 |
| v8 | 定稿（后被否） | 雪茄形长气囊 + 吊舱 + 尾鳍 + 螺旋桨；八到十团云彼此分开；压暗 63.8。**但太复古，缺压迫感** |

### 第三轮：科幻 + 侧面贴近（当前）

| 版本 | 结果 | 判据 |
|---|---|---|
| v9 | **定稿（R355 用户点名）** | 科幻装甲舰体从上方压下来、两侧冲出画框；压暗 ≈54.6。白天科幻、装甲板与冷青光窗槽最清楚 |
| v10 | 曾被选为定稿（R354c） | 云改成三层交叠、缝隙透出更暗的深空，舰体在云顶投下冷暗影；压暗 52.7。R355 被 V9 取代 |

**定稿 = v10 + S 曲线调色。**

## 七个坑（下次直接用）

1. **「日式动漫」必须写成「不是写实」才生效。** 只写 `Japanese anime style` 出来的是厚涂厚光影。
   要同时写 `hand-drawn 2D cel-animation look` + `NOT 3D, NOT photo-real, NOT oil painting`
   + `clean dark ink line work` + `2 to 3 hard-edged tone steps per surface`。
2. **地图背景不是「看完就算」的插图 —— 它上面压着 42% 暗罩和满屏白色云朵节点。**
   判据不是「原图好不好看」，而是「**压暗后**平均亮度」：第一层 107 / 第二层 69 /
   战斗默认 98。第三层落 **52.7**（最暗一层，压迫感优先）。
   验收必须真跑 `map.tscn -- --screenshot --bg 3` 看。
3. **「巨大」有两个独立手法，可以叠加：**
   · **遮挡**：`one near cloud clump passes IN FRONT and hides part of it`；
   · **画框裁切 + 仰视**：`the camera is very close to the lower flank, looking slightly UP,
     the vessel RUNS OFF BOTH the left and right edges` —— 只看见一段、看不见首尾，
     比「画得大」有效得多。第三轮就是靠这个解决「缺少压迫感」。
4. **「压迫感」是低明度 + 阴影 + 仰视三件事，不是「画得黑」。** 定稿让舰体
   `casts a broad cold near-black shadow across the cloud tops underneath`，云顶被压暗，
   明亮的只剩远处一小片天空 —— 这才有「巨物从头顶压下来」的体感。
5. **「不要像海」= 改云的形态。** 只要还写 `cloud sea` / `layer` / `carpet` / `horizon`，
   出来就是水面。要写 `separate rounded clumps at DIFFERENT depths`，并且让缝隙
   `open onto MUCH DARKER DEEP BLUE below`（读成**空洞纵深**，不是平面），
   反面点名 `NO ocean / waves / foam / whitecaps / wake lines / water reflections /
   NO horizontal water horizon line / NO flat blue plane between the clouds`。
   ⚠️ v9 就是漏了这一条：云是分开的，但中间那片蓝有横向渐变 + 云沿水平排开 = 海岸线错觉。
6. **「不要复古」要逐项点名。** 写 `futuristic` 不够，气囊、帆、桅杆、螺旋桨、铆钉、黄铜
   会自动回来。正面写 `interlocking angular armour panels` + `deep-set window slots glowing
   cold cyan` + `HOVER RINGS with emitter segments` + `luminous energy strip`，
   反面逐个封：`NO gasbag / NO balloon ribs / NO wooden deck / NO masts / NO sails /
   NO rigging / NO smokestacks / NO propeller blades / NO brass / NO copper / NO rivets /
   NO zeppelin`。
7. **云密度与主体体积是耦合的**：单独把云减到很少，主体看着像玩具；单独把主体放大，
   云会被挤成一条边。踩过两次。

## 复现用的关键提示词（定稿那一版，节选）

```
Japanese anime film background art, hand-painted 2D cel-animation look.

CAMERA AND SCALE: very close to the hull, level with its lower flank, looking slightly
UP along its side. The vessel fills the entire upper half and RUNS OFF BOTH the left and
right edges — only one long section is visible, bow and stern lie far outside the frame.

THE VESSEL — FUTURISTIC, not retro, not a sea ship: one continuous monolithic body of
interlocking angular armour panels in dark slate blue-grey, thin pale seams, shallow
bevels. Long horizontal rows of deep-set rectangular window slots glowing cold pale cyan.
Huge flat HOVER RINGS hang beneath the hull, their shape repeated in a receding row along
the flank to give a sense of enormous length. A thin luminous energy strip runs the whole
length. Slim antenna spires and a fin cluster at the top edge. Mostly in shadow as a
low-key blue-grey mass with hard flat planes — never a black cutout.

THE CLOUDS: NOT a flat open sky and NOT a surface — a STACK of cloud layers seen from
above. Three or four overlapping planes of separate rounded cumulus clumps at different
distances, one partly hiding the one behind, with clear hollow gaps opening onto MUCH
DARKER DEEP BLUE below. Those gaps must read as HOLLOW DEPTH, not a flat plane.
No horizontal banding, no continuous line that could read as a waterline.

LIGHTING: the vessel casts a broad cold near-black shadow across the cloud tops
underneath, with crisp cel-shaded edges. Cloud tops muted off-white and pale lilac —
never pure white.

NOT RETRO, NOT STEAMPUNK: NO gasbag, NO balloon ribs, NO wooden deck, NO masts,
NO sails, NO rigging, NO smokestacks, NO propeller blades, NO brass, NO rivets.

NOT A SEA: NO ocean, NO waves, NO foam, NO whitecaps, NO wake lines,
NO water reflections, NO horizontal water horizon line, NO flat blue plane between clouds.

NO photo-real, NO 3D CGI, NO oil paint, NO lens flare, NO neon cyberpunk signage,
NO holographic UI. NO text, NO letters, NO watermark, NO people, NO second airship.
```
