# R847 / R847b · 场地卡边框素材（六张）

店长口径：**「敌我不用管，但是漩涡和清泉不该一样。场地需要有边框素材特效（而不是这种简陋的）。素材委托 codex 生成。」**

原来 `_draw_field_markers()` 画的是「45° 斜纹（只画左上三角）+ 冷色描边 + 左下角一行名字」。
六张场地还因为**全部带「持续场地」trait**，颜色一律走冷青 —— 逐条看下来两张场地站在一起几乎分不出谁是谁。

这批素材解决三件事：① 每张场地有自己的图案；② 边框本身承担「这格挂着场地」的语义；
③ 有素材之后**不再画名字角标**（那行字有一半压在卡面数值行上）。

## 出图提示词

`prompts/<id>_<名>.txt`，纯文生图、无参考图（ART.md：画风不对时先摘掉参照图）。
六段 prompt 共用一个骨架，只换「雕饰 + 配色 + 负面锁定」：

| 卡 | id | 雕饰 | 配色 |
|---|---|---|---|
| 清泉 | 8028 | 水波纹浮雕 + **左右两枚**荷叶圆章（v2 去掉了底边垂饰，见下） | 米砂 + 浅青 |
| 维修间 | 8036 | 铆接钢板 + 四角螺栓 + 扳手/螺丝刀徽章 + 顶边齿轮齿 + 侧面管件 | 钢蓝灰 + 黄铜 |
| 改造工厂 | 8037 | 四角外露齿轮 + 底边传送带板 + 顶边三点火星 + 侧面格栅 | 铜/琥珀 + 烟熏铁 |
| 漩涡 | 9186 | 浪旋盘绕四边、四角收成小涡，泡沫白条纹 | 深青 + 海蓝绿 |
| 毒沼 | 8082 | 裂石苔藓 + 底边垂落毒液 + 侧面毒泡 + 嵌白骨碎片 | 病绿 + 泥橄榄 |
| 标记 | 9224 | 四角符文圆环（纯几何、不带字母）+ 上下十字准星 + 边缘发光符线 | 暗紫 + 洋红辉光 |

骨架里固定写死的四条（每张都重写，不靠「参考前一张」）：

```
A single hand-drawn cartoon game UI asset: an ornamental border FRAME for one square cell of a
card battle board, viewed straight on. The canvas is slightly WIDER than tall, about 113 to 100,
NOT square — a wide landscape rectangle.
...（雕饰段）...
The inside of the frame is completely EMPTY pure white, nothing at all drawn inside the ring.
The border band is SLIM and even: the left and right bands are at most one twelfth of the canvas
width, the top and bottom bands are at most one sixteenth of the canvas height. The empty window
inside the ring is very large, at least 90% of the canvas height and at least 74% of the canvas
width. ...（装饰集中到四角与左右边）... It must still read clearly when shrunk to 124 by 110 pixels.
Thick dark brown outline, flat cel shading with two or three tone steps, ...
no text, no letters, no numbers, no symbols, no watermark, no drop shadow, no ground shadow.
NOT a card, NOT a panel with a picture inside, ...（逐张点名最容易画错的东西）...
```

- 「**inside EMPTY pure white**」是这段里最要命的一句：不写死，codex 会往中间画一张小插画。
- 负面清单逐张点名：清泉「不是火/岩浆/冰晶」，漩涡「中间不是整片海洋」，标记「不要五芒星、不要字母」。

## 数量与耗时

| 项 | 值 |
|---|---|
| 出图 | 6 张 × 2 版（v1 厚边废案 + v2 细边定稿），单次会话 63~90s（`_batch.log`） |
| 原始图 | v2 全是横向 1310~1334 × 1179~1200，1.0~1.2 MB，`raw/`；v1 废案留在 `raw_v1_thick/` |
| 成品 | 248 × 220 RGBA（格子 124×110 的 2×），15~37 KB，`processed/` 与 `assets/ui/` **同字节** |

## 抠图（`_cut_frames.py`）

与图标抠图最大的不同：**边框中间是空的，而且必须真的透**。
单位卡画在边框**下面**，中心若留白底，站上去的单位会被一块白膜糊住。所以跑两道泛洪：

1. **四边泛洪**（亮且不饱和 → 背景）；
2. **中心泛洪**（正中心种子，同样判据 → 内圈留白）。

两个坑都写在脚本注释里：

- **`getbbox()` 不能直接用**：RGBA 上它把 RGB 也算进去，而血边扩散会让透明区的 RGB 非 0
  → bbox 会框住整张图，缩完边框只剩一小圈、四周全透（第一次跑就是这么炸的）。
  必须 `out.getchannel("A").getbbox()`。
- **自检不能要求「边中点那一像素是实心的」**：这批边框四角外凸，bbox 由最凸处决定，
  边中点会缩进来几像素。判据改成「从各边中点向内扫 15% 必须撞到边框」。

自检四条（脚本里是断言，不是肉眼）：四角 alpha = 0 / 中心 alpha = 0 / 四边向内能撞到边框 / 非空图。

## 落地

- `processed/field_frame_<id>.png` → `assets/ui/field_frame_<id>.png`（同字节），`.import` 由 `--import` 生成。
- 取图口 `scripts/field_art.gd`（`class_name FieldArt`）：`frame_of(id)` / `has_frame(id)` / `draw_frame()`。
- 调用点 `battle_scene._draw_field_markers()`：有素材贴素材（**铺满整格、不内缩** —— R847b 从 2px 改 0），缺图回退斜纹画法。
- 有素材时**不画名字角标**；缺素材时照旧写出来（那种情况下文字是唯一辨识手段）。
- 回归 `_test_r847()`：六张「有图 / 248×220 / 取得到 Image / **中心全透** / **开口装得下卡面**」，外加「未知 id 必须回退」。

## 实际效果

- 实机 1280×720 六张同屏：`E:/tmp/r847_fieldshot/r847_frames_all.png`（素材批次内不留存档图）。
- 124×110 实尺寸对比页：`processed/_preview_sheet.png` —— 六张在真实格子里仍然一眼可分。

## R847b：卡片顶出边框（店长反馈）

实机截图里「有的卡片超出了框」。量出来的原因是**素材开口装不下卡**，不是框的位置或尺寸算错：

| 量 | 值 |
|---|---|
| 格子 | 124 × 110 |
| 场上单位卡 | 76.6 × 92.4（竖长，`BOARD_CARD_H = 76 × 124/102`） |
| 卡在格内上下余量 | 各 **8.8px** |
| v1 素材开口高 | **60%** → 缩到格子只有 66px，卡上下各顶出 13px |
| v2 素材开口高 | 85%~93% → 缩到格子 94.5~102px，全部装得下 |

改了三处，一处都没往「缩卡」上走（那会让场地格里的卡和邻格大小不一）：

1. **prompt 加两条硬约束**：画布 **横向 113:100（不是正方形）**、边框**上下边特别薄**、
   开口 **≥90% 高**。正方形画布几乎必然把上下边画厚（第一版清泉就是）。
2. **`FRAME_INSET` 2 → 0**：内缩每 1px 就把开口高度白送 2px，而全格只剩 8.8px 余量。
3. **抠图脚本加硬断言**：开口高 < 84% 直接 `RuntimeError`，不许落地 —— 第六张清泉
   就是因为「底边挂了一滴水」把外轮廓拉长、开口压到 79%，被这条拦下来重出的（去掉垂饰后 89.5%）。

`_test_r847()` 也钉了两条：每张按中线量开口，换算到格子尺度必须 ≥ 92.4px（高）/ ≥ 76.6px（宽）。

**教训**：`getbbox()` 之后、缩放到目标尺寸**之前**，素材的「开口占比」才是唯一的判据；
先出图后补救（绘制侧放大 / 缩卡）都会在别处付出代价。
