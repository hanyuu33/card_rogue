# R519p · 敌人卡图 prompts

画风纪律：卡图统一「日式动漫赛璐璐、禁止写实」（`art_src/_style_prompts.md` A 套）。
两张敌方效果卡都走赛璐璐。

## 9210 寒霜结界（image1 = 8081 雪豹，只借画风，input_fidelity=low）

```
Use the reference image ONLY AS AN ART-STYLE REFERENCE: copy its drawing technique — the anime
cel-shading, the thin black line art, the hard-edged shadows, and the cool blue-grey mood.
Do NOT copy its snow leopard, its snowy ridge, its moon, its trees, its pose, or its composition.
Paint a COMPLETELY DIFFERENT scene.

JAPANESE ANIME trading-card illustration, modern light-fantasy mobile game card art, anime
cel-shaded style, clean crisp THIN black line art, 2-step cel shading with real volume and depth,
HARD-EDGED shadows, hand-painted look. NO photorealistic rendering, NO ray-traced reflections,
NO photographic ice/glass texture, NO cinematic 3D render, NO depth-of-field bokeh,
NO flat vector illustration, NO painterly airbrushing.

dark understated palette, single accent colour limited to one element, low-saturation, clean
silhouette against a dark background, the subject is the brightest, sharpest thing in the frame.
NO neon explosion, NO full-screen glow, NO muddy brown palette.

SQUARE CARD ILLUSTRATION for an enemy effect card named "Frost Ward" (寒霜结界) ...
SUBJECT: ONE single large magical frost ward / ice barrier formation floating in the centre of a
dark cold battlefield. It is a ring-shaped sigil of ice and frost: a circular runic magic circle
drawn in glowing pale-cyan light, enclosed by jagged translucent ice crystals and tall frost
spikes rising from the ground around it, with fine white frost veins creeping outward across dark
frozen stone ground, a few drifting snow particles and a faint spiral of cold mist wrapping the
formation. The glowing pale-cyan rune circle is the ONLY bright glowing element ...

NO people, NO creatures, NO animals, NO characters, NO text, NO letters,
NO runes that look like real writing, NO logo, NO watermark, NO card frame, NO border.
```

## 9212 枭熊之怒（image1 = 9214 枭熊，只借角色设计，input_fidelity=low）

```
Use the reference image ONLY FOR THE CHARACTER DESIGN: copy the owlbear creature's design — an owl
head with two upright ear tufts, big round yellow eyes, a hooked raptor beak, a thick dark-brown
feathered bear body, a mane of feathers at the shoulders, and huge grey talons. Do NOT copy its
realistic painterly rendering, its pose, its background, or its camera angle.

JAPANESE ANIME trading-card illustration, ... (A 套同 9210)
dark understated palette, ... (B 套同 9210)

SUBJECT: the SAME owlbear creature now ENRAGED, in a ferocious lunging attack pose. Its owl head
thrust forward with the hooked beak wide open in a furious shriek, the two ear tufts flared and
spiked, big round yellow eyes glowing with anger, feathers bristling and ruffled across the
shoulders and neck, and one huge front paw raised with spread grey talons slashing toward the
viewer. Strong fierce silhouette, dynamic and aggressive, small flecks of torn feathers flying in
the air. Warm dark-brown feathers, amber-yellow glowing eyes, cool blue-grey dark forest background.

NO people, NO other animals, NO characters, NO text, NO letters, NO logo, NO watermark,
NO card frame, NO border.
```

## 处理

- 9210：裁 `(0,55,1024,976)`；水印 `patch_from_left`（左侧暗色地面水平镜像），框 `(760,890,1024,1024)`。
- 9212：裁 `(0,15,1024,936)`；水印 y≈944 起被裁掉，无需修补。
- 脚本 `tools/process_r519p.py`（`--write` 落盘 processed + assets/pics/<id>.png）。

## 验收

- 图鉴 `--group enemy --card 9210 / 9212`：卡图正常、无黄三角、无水印、属性与效果文本正确。

## R519q · 9212 咆哮版 v2（image1 = 初版扑击图，只借角色+画风，input_fidelity=low）

关键差异（相对初版扑击）：
- 姿态：`head thrown back, beak wide open toward the top of the frame`（仰头张嘴咆哮）。
- 声音特效视觉化：`from the wide-open beak radiates several THICK, BOLD pale-cyan-white
  concentric shockwave arcs and sound-wave rings expanding upward and outward, plus a few sharp
  jagged speed-lines ... Make the sound-wave arcs THICK and high-contrast so they stay clearly
  visible even at small card size`。
- 主体完整：`THE WHOLE CREATURE MUST FIT FULLY INSIDE THE FRAME ... all four paws fully visible
  with clear margin below the feet and above the ear tufts`。
- 裁 `(0,0,1024,921)` 保声波；声波外圈贴顶属放射特效自然效果，水印 y≥955 裁掉无需修补。
- 第一版咆哮（`9212_owlbear_roar.png`）声波太细、后脚掌贴底 → 弃用。
