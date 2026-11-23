# 选人 CG 出图提示词（R864 定稿口径）

> **这是现役口径。** 出「选人界面职业 CG」时照抄本文件的 `STYLE-BASE`，只换角色块。
> 素材落点 `assets/ui/class_cg_<kind>.png`，1280×720，流程见同目录 `_apply_cg.py`。
> 原始会话：`C:\Users\Administrator\.codex\sessions\2026\11\23\rollout-2026-11-23T15-53-42-01a20765-...jsonl`

---

## 〇、一分钟用法

1. 取下面 **§1 的 STYLE-BASE（v2）** 整段放最前，**一个字都不改**。
2. 接一段角色块：身份 → 服装 → 动作 → 场景 → 配色 → 反面点名。
3. 走**图生图**，`referenced_image_paths` 至少带一张身份参考（旧 CG 或角色设定图）。
4. 出图后按 §5 自查；不合格就改角色块，**不要改 STYLE-BASE**。

---

## 一、风格底（现行 = v2，2026-11-23 11:27 定稿）

### v2 · 现行（**用这个**）

```
Create a completely redesigned playable protagonist CG for the SAME Japanese western medieval fantasy game as the style reference. Delicate anime painterly linework, softly layered watercolor and opaque paint, luminous ivory highlights, subtle paper texture, atmospheric hand-painted environments, expressive natural face, carefully painted fabric and metal, storybook finish. No hard cel-shaded TV anime blocks, no photorealistic 3D, no UI, no text, no card frame, no watermark. Wide landscape 16:9, character right 60 percent, readable quieter scene left, full figure or knees-up with head fully inside image.
```

比 v1 多的三句，都是踩过坑才加的：

| 加粗点 | 原文 | 为什么 |
|---|---|---|
| 禁 TV 动画块面 | `No hard cel-shaded TV anime blocks` | v1 出图滑向硬边赛璐璐，和游戏内柔和卡图不一致 |
| 强调同游戏 | `for the SAME ... as the style reference` | 不提就会自创一套画风 |
| 保头 | `head fully inside image` | 顶部被标题栏切头（见 README 第五节） |

### v1 · 已弃（2026-11-23 10:45，仅存档对照）

```
Japanese western medieval fantasy protagonist CG, delicate confident anime painterly linework, softly layered watercolor and opaque paint, luminous ivory highlights, subtle paper texture, rich controlled colors, expressive readable silhouette, refined storybook finish, natural fabrics and carefully painted antique metal, warm diffused cinematic light with atmospheric depth. High-end playable hero design with purposeful functional costume and memorable silhouette, no text, no UI, no card frame, no border, no watermark. Wide 16:9 landscape composition, single character on right 60 percent, quieter environmental space on left, character shown head to boots, no cropped ears or feet.
```

> ⚠️ **别把这里的风格块和另外两份混用**：
> - `art_src/2026-11-23_frames/style-prompt.md` 是**方形卡图**（448:403）框架 —— 出 CG 不用。
> - `art_src/_style_prompts.md` 的 A「日式动漫赛璐璐」是**硬边**风格底 —— 本轮明确反向要求柔和水彩层叠。

---

## 二、构图硬约束（不是审美，是界面几何）

选人界面 `class_pick_scene._draw()` 用 `CardFace.cover_region_top()` **顶部优先**铺满整窗，左侧压着 416px 详情面板，最上方还有 30px 标题栏。所以：

- **16:9 横向**，落点 1280×720。
- **人物在右侧 60%**，左侧必须是「安静的环境」—— 面板压上去不能挡脸。
- **全身或膝上，头部完整在画面内**：头顶到源图上沿至少留 8%（落图时还要加 40px 延伸带，见 `_apply_cg.py`）。
- 底部 40px 会被头像行压住，可以不重要 —— 但也别让脚/尾巴成构图主体。

---

## 三、角色年龄（用户明确纠正过，写死）

| 职业 | 年龄 | 外观判据 |
|---|---|---|
| 森林精魄 | **8~9 岁** | 儿童身高、头身比大、圆脸颊、四肢短、手小；**不得**成人比例 |
| 吟游诗人 | **11~12 岁** | 少女、圆脸、短鼻、儿童体型；**不得**成人曲线或高瘦剪影 |
| 机械之心 | 青年 | 成年女性工匠 |
| 暗影刺客 | 青年 | 与身份参考同龄 |

反面点名句（必须带）：

```
Avoid tall slender teen/adult silhouette, fitted corset, ornate heavy gear.
```

---

## 四、四职业身份定义（定稿）

| id | 种族/身份 | 写死的识别点 | 反面点名 |
|---|---|---|---|
| `forest` | 山猫（lynx）林间守林人 | 白金长发（松散侧辫）、金瞳、**黑尖三角耳 + 长黑耳簇**、山猫短尾 | 无花卉连衣裙、无花冠、无人类装备（11:40 后） |
| `bard` | 豚鼠（guinea pig）吟游诗人 | 蜜金短卷发、琥珀金瞳、**圆形绒毛耳**（低垂头侧）、**没有尾巴** | NO pointed cat/fox ears, NO tail |
| `mech` | 人类机械工匠 | 墨蓝低侧马尾、圆眼镜、青瞳、象牙长工坊袍 + 炭灰高领、琥珀腰带 | no cold sci-fi lab, no neon, no floral motifs |
| `rogue` | 白发兽耳刺客 | 白短乱发 + **淡紫挑染**、红瞳、深紫兜帽（脸可见）、痞笑 | 别做成肃穆杀手；no flowers, no extra characters |

森林精魄有一条**立意约束**（11:40 用户原话：「自然中生长的，人类社会要素不能这么强」）：
服装必须是**层叠树叶 / 苔藓毡 / 植物纤维**自然形成，赤足或苔藓裹足，**没有**衬衫、纽扣、皮带、靴子、刺绣、扣具、工具、法杖、花冠。

---

## 五、出图后自查（不合格改角色块，别改 STYLE-BASE）

- [ ] 头顶完整，没有贴边（贴边 = 回头必被标题栏切）
- [ ] 人物重心在右半边，左侧能看清是景不是杂物
- [ ] 不是硬边赛璐璐、不是 3D 渲染
- [ ] 年龄对得上（森林/吟游最容易被画老）
- [ ] 种族特征对（豚鼠**无尾无尖耳**；山猫有耳簇和短尾）
- [ ] 画面里没有文字、UI、卡框、水印
- [ ] 配色没有抢走职业色（吟游诗人身上绿不能占主）

---

## 六、完整原文（可复现，照抄）

### 6.1 v1 首批：森林 + 吟游（2026-11-23 10:45）

```text
Japanese western medieval fantasy protagonist CG, delicate confident anime painterly linework, softly layered watercolor and opaque paint, luminous ivory highlights, subtle paper texture, rich controlled colors, expressive readable silhouette, refined storybook finish, natural fabrics and carefully painted antique metal, warm diffused cinematic light with atmospheric depth. High-end playable hero design with purposeful functional costume and memorable silhouette, no text, no UI, no card frame, no border, no watermark. Wide 16:9 landscape composition, single character on right 60 percent, quieter environmental space on left, character shown head to boots, no cropped ears or feet.
```

```
Use reference ONLY for core identity; completely redesign clothing, pose, scene, accessories. Young adult female lynx woodland guardian, pale platinum long hair gathered into practical loose side braid, golden eyes, distinctive black-tipped triangular LYNX ears with long black ear tufts, short bobtail appropriate to lynx. Self-assured warm alert expression, ready to lead adventure. Layered forest-green ranger tunic over ivory linen shirt, fitted leather belt and utility pouches, modest practical leaf-shaped asymmetrical cape, sturdy knee boots, leather forearm guards; restrained leaf stitching, one tiny daisy hair pin only, no floral dress or flower crown. Holding a carved wooden nature staff in one hand, other hand gently directing a small swirl of green forest magic. Strong relaxed active stance on mossy ancient forest path, sunlit deep woodland, natural magical guardian mood. Forest green, ivory, warm leather and antique brass accents. Preserve charm of original but redesign as an adventurous main controllable hero.
```

```
Use reference ONLY for core identity; completely redesign clothing, pose, scene, accessories. Young adult female anthropomorphic guinea-pig bard in primarily human girl form: honey-blonde short wavy bob, amber golden eyes, small ROUND furry guinea pig ears low on head sides, soft rounded cheeks, friendly charismatic confident expression; NO pointed cat/fox ears, NO tail at all (guinea pigs have no visible tail). Iconic small handheld lyre, expressive believable hands. Outfit redesigned as travelling party leader: mist-blue short shoulder cape with silver clasp, cream linen blouse, fitted blue travel vest, layered practical knee-length skirt over opaque leggings, sturdy ankle boots, leather crossbody music satchel, small rolled song manuscript at belt. Restrained silver embroidery suggesting wind and sound, one tiny white flower pin only, no floral garlands, no elaborate lace doll dress. Engaging three-quarter stance on ancient stone woodland bridge at morning, one foot forward, playing lyre as a subtle ribbon of pale blue music magic floats forward. Balanced bright natural lighting, airy blue distant hills, warm honey hair and ivory skin contrast cool blue costume. Clearly guinea pig rather than squirrel, forest and sage green not dominant in outfit. Charming memorable playable protagonist suitable to lead allies.
```

### 6.2 年龄修正（2026-11-23 11:01）

外层包装句（这轮的用法，可复用）：

```
Redesign the reference character in a new protagonist CG while preserving their core identity. Japanese western medieval fantasy, delicate anime painterly linework, softly layered watercolor and opaque paint, luminous cream highlights, subtle paper texture, warm natural diffused light, expressive clear silhouette, refined storybook finish. Wide 16:9, no frame, no text, no UI, no watermark.
```

```
Forest spirit must visibly be an 8 to 9 year old child girl: child height, large head relative to body, soft round cheeks, short limbs, small hands, no adult body proportions. Keep platinum hair, golden eyes, black-tipped tufted lynx ears. Redesign as charming child woodland guardian wearing a simple loose ivory long-sleeve blouse, forest-green knee-length pinafore tunic, small leaf-shaped shoulder cape, opaque brown leggings and comfortable child boots. Modest age-appropriate outfit, one small utility satchel, light carved sapling staff sized to her. Cheerful curious determined child expression. Avoid tall slender teen/adult silhouette, fitted corset, ornate heavy gear. Full figure including boots on right of wide sunny forest scene.
```

```
Bard must visibly be an 11 to 12 year old preteen child girl: youthful round face, short nose, rounded cheeks, child body proportions, small hands, no adult curves or tall mature silhouette. Honey-blonde wavy short bob, golden amber eyes, small ROUND furry guinea-pig ears, NO tail, NO pointed ears. Cheerful confident travelling young musician, small golden handheld lyre, comfortable mist-blue short cape with silver clasp, loose cream long-sleeve blouse and blue knee-length pinafore travel dress, opaque leggings and simple flat lace-up child boots, small music satchel and one rolled score. Modest age-appropriate clothing, light functional details, no fitted corset, no elaborate adult adventurer gear. Full figure on right side of wide bright stone-bridge landscape with distant blue hills, subtle silver-blue music magic.
```

### 6.3 v2 风格底 + 机械之心 + 暗影刺客（2026-11-23 11:27，**现行**）

STYLE-BASE 见 §1 v2；两个角色块：

```
Reference 1 provides only black-haired glasses-wearing female researcher identity, NOT rendering style or futuristic setting. Reference 2 is the desired painterly style. Redesign her as a young adult human female master artificer, thoughtful quietly confident smile, dark ink-blue hair in practical low side ponytail, fine round spectacles, teal eyes and small turquoise pendant. Memorable ivory long workshop coat with rolled sleeves over charcoal high-neck work tunic, amber waist sash, practical trousers and boots, leather tool belt, tiny brass caliper. She is actively gently adjusting a palm-sized floating clockwork heart core with articulated brass rings and soft warm amber light, one small friendly ivory-and-brass construct beside workbench. Mechanisms have believable gears, hinges and rivets, matte antique brass and ivory ceramic, restrained hand-crafted magical engineering. Sunlit stone-and-timber atelier, warm window rays, paper plans, shelves of mechanical parts, one articulated mechanical arm, clear depth and calm composition. Palette cream, warm brass, charcoal, limited turquoise accents; no cold sci-fi lab, no giant glowing screens, no neon, no floral motifs, no gear decoration on every surface. Main heroine has clear personality and active agency, not passive lab assistant.
```

```
Reference 1 fixes identity and setting, reference 2 supplies the soft painterly rendering style. White short tousled bob hair with PALE LAVENDER streaks, ruby eyes, raised eyebrow and audacious asymmetric toothy smirk, mischievous brazen female rogue, same youthful appearance as identity reference. Dark plum HOOD WORN UP with face visible. Redesign functional dark charcoal and plum layered leather rogue costume, ivory inner collar, silver fasteners, asymmetrical short cloak, wrist guards, modest fully covered travel clothes, practical belts, thigh utility pouch and knee boots. One short dagger held low in a relaxed reverse grip, other hand casually resting on hip; weight confidently shifted forward, playful provocative confidence. Standing on ruined gothic castle rampart, large pale violet full moon on left, distant pointed castle towers and drifting cloud, same essential scene as reference. Lavender moon rim light balanced with soft warm lantern bounce on face and hands; detailed painted stone and fabric; readable values even at night, not pitch black. Restrained ornament, no flowers, no extra characters, no excessive weapons. Preserve personality rather than turning her into solemn assassin.
```

### 6.4 森林精魄「回归自然」（2026-11-23 11:40，采用版的前身）

```
Redesign the reference forest spirit CG. Preserve identity: visibly 8 to 9 year old child girl, platinum long hair, golden eyes, black-tipped tufted lynx ears, youthful round cheeks, small child proportions. She is a spirit born and raised entirely in nature, not a human travelling adventurer. Age-appropriate modest opaque knee-length garment naturally formed from layered soft leaves, moss felt and interwoven plant fibers, irregular organic edges, short leaf shoulder mantle, bare feet or simple soft moss foot wraps. No blouse, buttons, leather bag, belt, boots, embroidery, buckles, tools, staff, human equipment or flower crown. Let natural charm come from leaf textures and wild hair rather than decorations. She is crouching comfortably at a sunlit woodland stream, joyful curious face, one hand extended gently touching noses with a small deer fawn, a woodland rabbit nearby; believable gentle interaction and distinct readable silhouettes. Full child figure and animals on right two thirds, left opens into ancient lush forest depth. Japanese western fantasy storybook CG, delicate anime painterly linework, softly layered watercolor and opaque paint, luminous ivory highlights, subtle paper texture, warm diffused forest sun, coherent anatomy, beautiful natural details, restrained palette, same game art direction. Wide 16:9, no text, no border, no UI, no watermark.
```

---

## 七、迭代史（为什么长这样）

| 时间 | 出图 | 用户反馈 → 改动 |
|---|---|---|
| 10:45 | 森林 v1（成熟女守林人）+ 吟游 v1 | 10:55「年纪被显著提升了」→ 加年龄块 |
| 11:01 | 森林 v2 + 吟游 v2 | 年龄下来了，但森林仍像人类社会冒险者 |
| 11:27 | 机械 v2 + 刺客 v2（换 v2 风格底） | 机械「风格偏差明显」→ 禁 sci-fi 实验室 / 霓虹 / 花卉 |
| 11:40 | 森林 v3 | 「自然中生长的」→ 去掉全部人类装备，改为树叶苔藓，加幼鹿互动 |
| 18:46~19:41 | 复跑取最终版 | 同职业取时间最晚一张，见 `README.md` |

---

## 八、落图（不要手工 resize）

```bash
python art_src/2026-11-23_选人CG重绘R864/_apply_cg.py
```

脚本做两件事：等比缩到 1280×720；取顶部 48 行翻转压成 40px 模糊延伸带贴顶、原图下移 40px、底部等量裁掉（保头）。改 `PICKS` 里的 `head_room` 可单张微调。
