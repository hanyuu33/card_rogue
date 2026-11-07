# 风格关键词速查（card_rogue 出图通用）

> 从 `.workbuddy/memory/ART.md` + `art_src/_ref/README.md` + 暗影刺客 CG 定稿 提炼。
> 用法：**文生图**把「风格底」整段贴在最前；**图生图**把「只借画风」那段贴在最前。
> 全部关键词已按「正面写死 + 反面点名」双向锁，避免滑向写实 / 矢量 / 霓虹彩噪。

---

## 一、风格底（两套通用，直接贴首句）

### A. 通用「日式动漫赛璐璐」风格底

```
JAPANESE ANIME trading-card illustration, modern light-fantasy mobile game card art,
anime cel-shaded style, clean crisp THIN black line art, 2-step cel shading with
real volume and depth, HARD-EDGED shadows, hand-painted look.
NO photorealistic rendering, NO ray-traced reflections, NO photographic metal/skin/fur texture,
NO pores, NO wrinkles, NO cinematic 3D render, NO depth-of-field bokeh,
NO flat vector illustration, NO infographic look, NO painterly airbrushing.
```

### B. 暗底高对比·科技感风格底（机械之心 / 夜景 / 暗影刺客）

```
dark understated palette, single accent colour limited to one element,
low-saturation skin and fabric, clean silhouette against a dark background,
the subject is the brightest, sharpest thing in the frame.
NO neon explosion, NO full-screen glow, NO fluorescent hair, NO muddy brown palette,
NO dark western comic style, NO Marvel/DC cover look, NO heavy cross-hatching.
```

### C. **场景整屏背景（事件 CG）风格底** —— 出背景**只用这个**

> ⚠️ R519e 的血泪：R519d 那批背景提示词写了 `semi_realistic_painted_fantasy`，
> 出来的六张厚涂写实、和 UI 完全不是一个游戏，整批返工。
> **唯一验证过的参照是 `assets/ui/bg_divination.png`（占卜室）**，照着它写，别自由发挥。

```
2D ANIME GAME BACKGROUND for a light-fantasy mobile trading-card game,
hand-drawn cel-shaded cartoon illustration, NOT a render.
THICK CLEAN BLACK OUTLINE around every shape and every object.
Flat colour blocks, exactly TWO shading steps per object, hard-edged shadow shapes,
no soft gradient inside a colour area.
Limited low-saturation palette: cool charcoal blue-grey, muted purple, one warm accent.
Simple readable shapes, clear silhouette, drawn detail only where the eye lands.

NO photorealistic texture, NO photographic stone / metal / wood grain, NO rust, NO moss, NO grime,
NO volumetric fog, NO god rays, NO depth-of-field, NO film grain, NO noise,
NO 3D render, NO sculpted PBR material, NO muddy brown palette, NO dark western comic style,
NO cross-hatching, NO airbrush.
```

配图生图：`image1 = assets/ui/bg_divination.png`，`input_fidelity: low`，
prompt 首句贴 §四·用法一「只借画风」。

**明度另写一条，不要指望 `dark` 这个词碰运气**（R519e 有两张栽在这）：

```
IMPORTANT MOOD: DARK and low-key, same darkness level as a candle-lit stone room.
Keep saturation LOW. The image must NOT read as bright, pastel or washed out.
Sky is dark / deep desaturated, NOT pastel, NOT pink, NOT lavender, NOT magenta.
```

**构图契约**（事件页正文卡片：纵向从 y≈47% 往下，横向占中段约 26%–74%）：

```
A UI text panel will later cover the CENTER of this image.
Place all subjects in the LEFT THIRD or the RIGHT THIRD, or in the UPPER TWO THIRDS.
The CENTER strip stays visually empty - only plain scenery there.

The scene FILLS THE WHOLE FRAME from top to bottom.
The ground runs off the bottom edge and is DRAWN - with grass tufts, pebbles, roots,
bushes, cast shadows, a visible silhouette and two tonal steps.
It may be one shade darker than the rest, but it is NOT a flat single-colour fill,
NOT a black bar, NOT an empty void.
There must be NO horizontal line across the frame where drawn detail stops and colour begins.
```

> ⚠️ R519f 教训：原来这里写的是「下三分之一留空压暗 / keep it clean and simple」，
> 被模型理解成**刷一块纯色**，出来的图下半张全空、像被横切的半张图（雪豹那张最明显）。
> 「留空」指的是**不放主体**，不是**不放画面**。地面要照画，只是别在上面摆东西。
> 同理「主体放上三分之二」对**坐地/躺地**的题材不成立 —— 人物只能在中段，
> 而中段正好是卡片的位置，于是武术大师的老人在游戏里完全看不见。
> 这类题材**必须往左右两侧摆**（摆不开就换侧图，见下）。

**侧图（左右布局）的构图** —— 方形 1:1，铺满屏幕左侧全高，右缘被 shader 收掉：

```
A square picture that will sit in the LEFT HALF of a game screen;
a UI panel fades in over its RIGHT edge.
Place the subject in the LEFT TWO THIRDS of the square, filling the frame top to bottom.
The RIGHT THIRD is deliberately PLAIN: the same drawn ground simply gets quieter and DARKER
in a continuous way - still grass with drawn texture and a drawn silhouette.
NEVER a solid rectangle of one colour, NEVER a hard edge, NEVER a wall.
```

> ⚠️ R519g：写「右三分之一留白」→ 模型刷了一条硬边纯色竖带（x≈72.5%），
> 而 fade 的 alpha 从 74% 才收，正好露出一条竖缝。
> **「留白 / 留空 / keep it clean」这几个词在背景提示词里一律不许用。**
> 参考产物：`assets/ui/side_lake_lady.png`（742×742）、`assets/ui/side_martial.png`。


---

## 二、画风硬约束（按题材挂）

| 题材 | 正面写 | 反面点名 |
|---|---|---|
| 人物卡 | `anime cel-shaded, thin black line art, 2-3 tone steps, hard-edged shadows` | `NO photorealistic, NO airbrush, NO realistic skin shading` |
| 装备/机甲卡 | `hard-surface, clean line art, flat shading, ONE strong light source` | `NO painterly, NO soft gradients, NO 3D render` |
| 手部特写 | `three rounded segments, one flat skin tone, one hard shadow edge` | `NO knuckle creases, NO tendon lines, NO pores, NO wrinkles, NO veins` |
| 骨头/道具 | `CARTOON BONES, simple smooth cream-ivory, rounded blunt ends, prop bones not anatomy` | `NO anatomical bone detail, NO bone pores, NO realistic teeth` |
| 发光/特效 | `the ONLY bright thing in the frame, light comes from a named object` | `NO light floating in open air, NO source-less glow` |

---

## 三、比例与构图

```
about 6 to 6.5 head-lengths, the head is SMALL relative to the body.
NO chibi, NO super-deformed, NO oversized head, NO toddler proportions, NO four-head-tall figure.
```

- 全身站姿：`full-body standing pose, clean silhouette, feet not cut off by the frame`。
- 越界构图用「画框里只存在什么」陈述（`only the head, neck, hood and shoulder tops EXIST in this image`），
  不要靠 `NO hands` 这类否定句。

---

## 四、图生图专用（保留风格时，剥离人物/背景等无关要素）

### 用法一：只借画风（最常用，你要的「保留风格、不管内容」）

```
input_fidelity: low
Use the reference image ONLY AS AN ART-STYLE REFERENCE:
copy its drawing technique — the line art, the cel-shading, the colour mood, the edge treatment.
Do NOT copy its scene, its characters, its composition, its pose, its camera angle.
Paint a COMPLETELY DIFFERENT scene.
```

### 用法二：只借角色设计（换场景/换姿势时）

```
input_fidelity: high
Use the reference image ONLY FOR THE CHARACTER DESIGN (face, hair, costume, colours).
Do NOT copy the pose, the background, the weapon, the camera angle.
```

### 用法三：只改局部（换部件/换色/删单一物件）

```
input_fidelity: high
CHANGE ONLY <部件>.  Keep EVERYTHING else identical:
pose, face, hands, costume, background, camera angle.
Do NOT change, Do NOT move, Do NOT add or remove anything else.
```

### 用法四：内容延续（换武器/换状态，保持同一角色）

```
input_fidelity: high
EXACT SAME CHARACTER as the reference image (face, hair, outfit, colours).
<逐条列出要改的新状态>
```

---

## 五、踩坑判据（出图后自查）

1. **缩到 448×403 再看一遍**：主体剪影一眼可读、无照片颗粒、无 3D 体积感、无糊成块的暗区。
2. **发色要色相不要荧光**：低饱和彩色发安全，满格荧光发缩图是彩噪。
3. **点缀色只一个、占 5%~10%**，且只在「技术物/发光物」上，人物自身不发光。
4. **姿态类改动别用 img2img**（会顺手改肢体），改颜色/换部件才用 img2img。
5. **加东西 → img2img；删结构 → 摘参照图纯文生图重画**。
6. **暗黑题材不是画暗的理由**：主体暗、环境亮，卡面在 448 下才立得住。
7. **整屏背景别自由发挥**：只认 `bg_divination.png` 的画法（§一·C）。写实厚涂一律返工 —— R519d 六张整批废。
8. **背景的明度要单独锁**：`dark` 一个词不够。六张拼一张图看，跳出来的那张就是没锁住。
9. **换图后必须重导入**：`godot --path .` 直接跑项目**不会**重导入贴图，
   屏幕上还是 `.godot/imported/` 的旧 `.ctex`。截图前先 `godot --headless --path . --import`。
   判据：`.ctex` 的 mtime 晚于 `assets/ui/` 里那张。

10. **「留空 / 留白 / keep it clean」禁用**：模型一律理解成刷一块纯色，出来就是半张图
    或一条硬边色带（R519f 雪豹、R519g 侧图都栽过）。要写「同样的地面继续画，只是更暗更安静」。
11. **别用百分比赌主体位置**（R519h 休息处连废 4 版）：写「左三分之一」「中心 11%」
    「bottom-left corner」都没用，主体照样落在 20%~25%。
    **主体必须避开某块 UI 时，换布局（左右版式），别改提示词硬试。**
12. **卡图重出：画风与形象分开喂**（R519i 金属龙一次过）。
    画风用一张**已验收的卡图**当 `image1`（如 `assets/pics/9207.png`）；
    形象来自事件背景的，**别把背景图喂进去**（主体在背景里只是远景剪影，会带偏构图），
    把外形特征写成文字（板甲 / 铆钉 / 配色 / 姿态）。
13. **验收图的 mtime 必须晚于素材**：R519g 交过一张「撤渐变之前」的旧截图。
    出图 → 落盘 → 重导入 → 再截图，顺序别倒。
