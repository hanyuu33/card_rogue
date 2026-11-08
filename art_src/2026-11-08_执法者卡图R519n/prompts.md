# R519n · 执法者（9223）卡图 prompts

画风锚点：`assets/pics/9131.png`（量产型俄倪厄，执法者同阵营机械单位）。
用户口径：「执法者：持枪的警员机器人，注意科幻感」。

## 出图（image1 画风参照，input_fidelity=low）

```
Use the input image ONLY AS AN ART-STYLE REFERENCE. Copy its drawing technique: clear
cel-shaded anime/comic outlines, flat colour blocks with hard-edged shadows, dark charcoal
armour, yellow warning-stripe accents, glowing cyan optical eyes, and military mass-produced
mechanical detailing. Do NOT copy its four-legged beast form, pose, or composition. Create a
COMPLETELY DIFFERENT subject.

SQUARE CARD ILLUSTRATION for an enemy ally unit named "Enforcer" (执法者) in a light-fantasy
trading-card game. The card is a gold-rarity heavy mech unit (8 cost, 10 power, 80 health)
with traits 机械 (mech) and 执法 (law enforcement).

SUBJECT: ONE single upright humanoid police-enforcer ROBOT standing in a firm, authoritative
three-quarter pose, holding a long-barrelled sci-fi pulse rifle in both hands across its chest,
aimed slightly downward-ready. It is a clearly mechanical humanoid, NOT a human, NOT an animal,
NOT a beast. Natural sci-fi law-enforcement design: dark gunmetal and charcoal armour plates
with bold yellow warning stripes on the shoulder pauldrons, chest plate and shin guards; a
sealed angular helmet head with a single glowing cyan visor/optical strip instead of a face;
small cyan glow lights on the chest and backpack; a small glowing cyan badge-like emblem on the
chest; hydraulic cables at the joints; grille vents and riveted plates; sturdy armoured boots.
The machine reads as cold, disciplined and imposing, like a combat enforcer robot.

Colours follow the reference: deep charcoal/dark-grey armour, muted metal tones, yellow-and-black
hazard stripe accents, with cyan (light blue) as the single glowing accent colour (visor, chest
light, gun charge).

The robot is the large focal subject, occupying about 65 percent of the image height, fully
visible from helmet top to boots, with the rifle, both arms, and both feet clearly readable.
Leave breathing room above the head and below the feet for card cropping; the gun and boots must
sit well above the bottom edge.

Background: a dark, quiet sci-fi mechanical interior (metal bulkhead walls, faint pipes, dim
lights) in low saturation, so the subject stands out. Background continues to every edge with no
empty band.

2D hand-drawn anime game card art, thick clean dark outlines, flat cel-shaded colours, exactly
two-to-three hard-edged shading steps, no soft gradients inside objects. NO photorealism, NO
realistic airbrush, NO 3D render, NO film grain, NO depth of field. NO people, NO animals, NO
other characters, NO text, NO letters, NO logo, NO watermark, NO card frame, NO border.
```

参数：`size=1024x1024, quality=high, background=opaque`。

## 处理

- 裁切 `(0, 70, 1024, 991)` = 1024×921 → `448×403`。
- 水印固定框（R515b 口径）全图坐标 `(872, 948, 1024, 1024)`，上沿落在窗内 → 对窗内部分
  `(872, 878, 1024, 921)` 做 `patch_wm()`（右侧背景地面，无主体，修补安全）。
- 脚本：`tools/process_9223.py`（`--write` 落盘 `processed/9223.png` 与 `assets/pics/9223.png`）。

## 验收

- 原图：直立持枪警员机器人、科幻感、画风、主体完整、背景铺满 → 通过。
- 处理图：头/双臂/枪/双足完整，水印彻底清除、无涂抹痕 → 通过。
- 图鉴 `--group enemy --card 9223`：卡图正常、无黄三角、名称属性效果文本正确 → 通过。
