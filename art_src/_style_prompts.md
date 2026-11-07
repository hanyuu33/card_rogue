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

**构图契约**（事件页正文卡片从 y≈47% 盖下来）：

```
All detail lives in the UPPER TWO THIRDS of the frame.
The BOTTOM THIRD is calm empty ground fading to near-black, keep it clean and simple.
```


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

