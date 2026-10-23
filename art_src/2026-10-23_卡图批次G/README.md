# 卡图批次 G · 跨职业八张（R334）

> 本批**不再锁单职业**：从三个职业的待做卡里随机各抽 3 张（抽签种子 `20261023`，可复现），
> 由用户逐张给画面方向后出图。8022 地狱咏唱者用户指定本次不生成 → 已进 `art_plan.json` 的 `skip`。

| id | 卡名 | 职业 · 种类 | 费/稀有 | 一句话画面 |
|---|---|---|---|---|
| 9056 | 镜像 | 森林精魄 · 效果 | 2 / 史诗 | 森林精魄少女的**全息投影**，脚下圆盘投影器射出光锥 |
| 9051 | 自然之力 | 森林精魄 · 技能 | 1 / 稀有 | 一根断枝插在苔藓土里**发芽**，逆光新叶透绿 |
| 9075 | 魔法塔 | 森林精魄 · 工事 | 2 / 普通 | **木质瞭望塔**，木柱与横梁刻满发琥珀金光的符文 |
| 9087 | 连刺 | 暗影刺客 · 技能 | 1 / 普通 | 反握匕首的手 + **同角度半透明虚影**，三道紫白刺击光 |
| 9101 | 不眠 | 暗影刺客 · 效果 | 1 / 稀有 | 暗影刺客**在篝火边守夜**，橙光只打亮她一侧 |
| 8052 | 城墙 | 机械之心 · 工事 | 2 / 普通 | 一整段**钢铁城墙**，铆接厚板 + 垛口 + 断箭 |
| 8029 | 战斗骨骼 | 机械之心 · 盟友 | 2 / 普通 | **没有外装甲**的机器人，骨架与液压全裸露 |
| 8055 | 钢铁卫士 | 机械之心 · 盟友 | 2 / 稀有 | **履带腿**的守卫，展开蓝白六边形**能量护盾** |

## 用户口径（R334 原话）

- 镜像：**「森林精魄的全息影像。」**
- 自然之力：**「发芽的树枝。」**
- 魔法塔：**「木质，类似瞭望塔，上面刻有符文」**
- 连刺：**「拿匕首＋拿匕首的虚影，同一个角度」**
- 地狱咏唱者：**「先不生成，标记不生成」**
- 不眠：**「暗影刺客角色在篝火边守夜」**
- 城墙：**「钢铁城墙」**
- 战斗骨骼：**「没有外装甲的机器人」**
- 钢铁卫士：**「展开能量护盾，腿部替换为履带的机器人」**

## 主色分配（防撞脸）

青蓝全息（9056）/ 嫩绿新芽（9051）/ 木褐+琥珀符文（9075）/ 紫白刀光（9087）/
橙红篝火+紫黑（9101）/ 冷钢灰（8052）/ 银灰+橙液压（8029）/ 蓝白护盾（8055）。

两张工事（9075 魔法塔 / 8052 城墙）刻意走了完全不同的材质路线：一个木、一个钢，
缩到 99×119 时靠色温就能分开（暖褐 vs 冷灰）。
两张盟友（8029 战斗骨骼 / 8055 钢铁卫士）同理：一个裸银灰骨架、一个黄铜暗钢重甲。

## 角色一致性

| 卡 | 参照图 | 首句 |
|---|---|---|
| 9056 镜像（森林精魄） | `assets/pics/9007.png`（火球术） | `EXACT SAME CHARACTER as the reference image` |
| 9101 不眠（暗影刺客） | `assets/pics/9086.png`（终结） | `EXACT SAME CHARACTER as the reference image` |

两张都走 `input_fidelity = high`，并把正典特征逐条写死（森林精魄：Q 版三到四头身、
黑猫耳、浅金长卷发过膝、绿叶裙 + 白雏菊、赤脚；暗影刺客：紫黑兜帽斗篷、黑紧身衣、
皮束带、无指手套、弯匕首）。

9101 的提示词里还额外写了 `NEW SCENE, completely different from the reference: she is NOT
fighting, no enemy, no robot, no moonlit rooftop` —— 不然 img2img 会把 9086 那张的
「她和机械人背对背」的构图带过来。

## 出图记录

- **八张一次过**，没有重画。
- 每张右下角都有「AI生成」水印 → 统一走 `_r334_cardart.py`：
  切底部 11% → cover 1.1117 → LANCZOS 448×403 → `--headless --import`。
- 9056 的「全息」是靠四件事堆出来的，缺一样就会读成「青色皮肤的人」：
  ① 半透明（背景能穿过身体）② 轮廓一圈发光边 ③ 表面扫描线 + 像素块 ④ 脚下投影器 + 光锥。
  提示词里这四条各写了一句，并把 `the hologram is the only bright thing in the frame;
  the forest stays dark` 也写死，避免画面整体提亮后「影像感」消失。

## 提示词

### 9056 镜像（img2img，image1 = 9007）

```
EXACT SAME CHARACTER as the reference image — the same tiny chibi anime forest spirit girl:
only three to four heads tall, huge round head with big amber-gold eyes, long wavy ash-blonde
hair flowing past her knees, fluffy BLACK CAT EARS on top of her head, NO elf ears, short dress
made entirely of overlapping green leaves with tiny white daisies, a white daisy beside one cat
ear, barefoot.

BUT the character is NOT physically present — she exists only as a HOLOGRAPHIC PROJECTION.
Render her entire body as a translucent cyan-blue hologram: semi-transparent so the forest behind
her shows through her body, bright glowing cyan rim light along every silhouette edge, faint
horizontal scanlines and pixel-block shimmer crawling across her, tiny floating projection
particles, occasional subtle glitch slices, soft volumetric light cone rising from the projector
at her feet. Her eyes glow cyan-white. She is calm and still, standing upright, arms slightly
open, as if being displayed.

Setting: a dark forest clearing at night, in the middle of the frame is a round brushed-metal
projector disc set into the mossy ground, ringed with glowing cyan emitter lenses, throwing the
light cone upward that forms her. Around it deep green night forest, faint fireflies, wet moss,
fallen leaves. The hologram is the only bright thing in the frame; the forest stays dark.

Camera: straight-on eye level, medium shot, the hologram centred and filling most of the frame
height.

Style: Japanese anime illustration, thick painterly rendering, cinematic, square composition
filling the entire frame, FULL-BLEED, NO white background, NO border, NO text, NO watermark,
NO books, NO paper props.
```

### 9051 自然之力

```
FULL-BLEED Japanese anime illustration, thick painterly rendering, cinematic, square composition
filling the entire frame, NO white background, NO border, NO text, NO watermark.

Subject: a single rough broken BRANCH, snapped off and standing in mossy forest soil, and it is
SPROUTING — fresh young leaf buds pushing out of the broken cut end and along the bark. Backlit
by warm sunlight filtering through the canopy so the new leaves glow translucent yellow-green.

Detail: the bark is dark wet brown and cracked, the break is raw pale wood with visible fibres,
and from the fresh buds thin curling tendrils of warm green-gold light spiral upward like visible
life force, tiny glowing motes and floating pollen drifting above the sprouts, a few drops of sap
catching the light on the cut. The soil below is dark moss, tiny white mushrooms and a few fallen
leaves.

Composition: low close-up, the branch diagonal from lower left to upper right, the sprouting tip
in sharp focus occupying the upper right, the forest bokeh soft behind — deep green shadow with
warm amber sunbeams and floating dust motes.

Palette: deep forest green shadow, warm bark brown, and one bright fresh yellow-green for the new
growth — nothing else. Quiet, hopeful, alive.
```

### 9075 魔法塔

```
FULL-BLEED Japanese anime illustration, thick painterly rendering, cinematic, square composition
filling the entire frame, NO white background, NO border, NO text, NO watermark.

Subject: a WOODEN WATCHTOWER standing in a dark forest clearing — a stout wooden lookout tower
built like a squat siege structure, four thick rough-hewn timber legs braced with crossed
diagonal beams, a solid plank platform on top ringed by a wooden railing, and a small pointed
shingled roof over it. It occupies one battlefield tile, so it reads DENSE and grounded, close to
the ground, not a fairy-tale spire.

Key detail: glowing RUNES are carved deep into the wooden posts and cross-beams — angular
ancestral rune sigils burned into the bark, each one filled with warm amber-gold light, faint
magic smoke curling off them, thin amber light leaking from the carved grooves. Moss and climbing
vines wrap the lower legs, small white flowers at the base.

Camera: low angle looking up, three-quarter view, the tower filling the frame from bottom to near
the top edge, dark forest canopy and drifting fireflies behind it, shafts of pale light through
the leaves.

Palette: dark wet wood brown and deep forest green shadow, with warm amber-gold as the only
bright colour (the runes).
```

### 9087 连刺

```
FULL-BLEED Japanese anime illustration, thick painterly rendering, cinematic, square composition
filling the entire frame, NO white background, NO border, NO text, NO watermark.

Subject: a CLOSE-UP OF A HAND HOLDING A DAGGER, and beside it the GHOSTLY AFTERIMAGE of the very
same hand and dagger — EXACTLY the same pose, EXACTLY the same angle, same blade orientation,
offset slightly behind and to one side like a double-exposure echo. Two identical silhouettes,
one solid, one translucent.

The solid one: a slender gloved hand in dark leather and purple-black assassin wraps, gripping a
curved dagger in a reverse (ice-pick) grip, the blade carbon-dark with a purple-white killing
edge, forearm wrapped in straps, one small silver buckle. Sharp, fully rendered, high contrast.

The afterimage: the same hand and dagger shape in exactly the same position and angle, rendered
as a transparent spectral duplicate — violet-white glowing outline, hollow translucent interior,
faint purple sparks bleeding off its edge, disintegrating into fine particles at the fingers.

Between and behind them: three thin streak-trails of pale violet-white slashing light cutting
across the frame, small purple sparks and drifting embers.

Background: near-black shadow, out-of-focus dark stone and cold purple mist, nothing else
readable.

Camera: tight close-up, slightly low angle, the hand entering from the lower right, blade
pointing up-left, the afterimage behind it.

Palette: near-black and deep purple with one intense violet-white highlight on the blades.
```

### 9101 不眠（img2img，image1 = 9086）

```
EXACT SAME CHARACTER as the reference image — the same female shadow assassin: short dark hair,
deep violet-black hooded cloak with a high collar, black skin-tight bodysuit wrapped with leather
straps, fingerless gloves, a slender curved dagger. Keep her face, hood, cape and outfit
identical.

NEW SCENE, completely different from the reference: she is NOT fighting, no enemy, no robot, no
moonlit rooftop. She is KEEPING WATCH through the night at a small campfire, alone.

Pose: sitting low on a fallen stone or a bundle of gear, one knee drawn up, the other leg folded
under her, her dagger resting point-down against the ground beside her hand, one hand loosely
near the hilt. Her hood is pushed back off her head, hair slightly messy from a long night. She
is fully awake and alert — chin slightly lifted, eyes looking off to the side into the darkness
beyond the fire, not sleepy, not relaxed. Tired but watchful.

Setting: a ruined stone camp at night, small low campfire of crackling logs right in front of her
throwing warm orange firelight up onto one side of her face and body, everything behind her
sinking into cold blue-black night, distant ruined pillars and dead trees barely readable in the
dark, drifting sparks and thin woodsmoke rising, a bedroll and a travel pack behind her.

Lighting: the fire is the ONLY light source, hard orange rim light on one side, the other side of
her face in deep violet shadow. Strong warm/cold split.

Camera: eye-level medium shot, three-quarter angle, she is on the right, the campfire on the
lower left, the empty darkness she is watching opening up on the left of frame.
```

### 8052 城墙

```
FULL-BLEED Japanese anime illustration, thick painterly mecha rendering, cinematic, square
composition filling the entire frame, NO white background, NO border, NO text, NO watermark.

Subject: a massive STEEL WALL — a segment of heavy iron fortress wall standing alone on the
battlefield like a barricade, filling almost the whole frame. No characters, no people, no
robots.

Construction: huge overlapping riveted steel plates bolted onto a thick iron frame, a crenellated
battlement along the top edge, deep weld seams, reinforcing ribs, heavy diagonal braces at the
back, a row of thick iron spikes along the base. Battle-worn: shallow gouges and dents scored
across the plating, a few broken crossbow bolts and arrow shafts embedded in the steel, scorch
marks, rust bleeding from the rivets, mud and trampled grass piled at the foot.

Camera: low angle looking up, slight three-quarter view, the wall towering and filling the frame
from bottom edge to near the top, cold overcast sky and distant ruined battlefield barely
readable behind it.

Palette: cold steel grey-blue and iron black, faint dull rust orange in the seams — the whole
image cold and dense, nothing bright.
```

### 8029 战斗骨骼

```
FULL-BLEED Japanese anime illustration, thick painterly mecha rendering, cinematic, square
composition filling the entire frame, NO white background, NO border, NO text, NO watermark.

Subject: a HUMANOID ROBOT WITH NO OUTER ARMOR — a bare mechanical endoskeleton standing upright,
completely unskinned. No plating, no shell, no casing anywhere on its body: every structure of
its frame is openly visible.

Detail of the exposed build: dull silver-grey metal skeletal frame, individual ribs and spinal
vertebrae, exposed piston rods and hydraulic cylinders at every joint, bundles of black and red
wiring harnesses taped along the limbs, small servo motors and gear clusters at shoulders,
elbows, knees and ankles, a transparent coolant line running down the forearm with faint amber
fluid inside, a simple rectangular sensor cluster for a head with two glowing amber optical
lenses, a bare ribcage with a faintly pulsing amber power core hanging inside it.

Condition: factory-fresh but unfinished, like a prototype taken off the assembly rack — clean
bare metal, light machining oil glinting on the joints, no rust, no battle damage. It stands
still and neutral, arms at its sides, looking straight at the viewer.

Setting: a dim robotics workshop background, soft pools of cold light, hanging cables and tool
arms far out of focus, concrete floor with scattered bolts.

Camera: eye-level full-body shot, front three-quarter, the endoskeleton centred and filling the
frame height.

Palette: bare silver-grey metal, matte black wiring, and amber-orange as the only accent
(core, lenses, coolant).
```

### 8055 钢铁卫士

```
FULL-BLEED Japanese anime illustration, thick painterly mecha rendering, cinematic, square
composition filling the entire frame, NO white background, NO border, NO text, NO watermark.

Subject: a HEAVY GUARDIAN ROBOT — humanoid upper body mounted on a TRACKED CHASSIS instead of
legs. Where the legs would be, it has a squat armored tracked undercarriage: two wide continuous
steel TREADS running on road wheels, mud and gravel stuck in the tread links, exhaust vents at
the rear. The whole machine reads low, wide and planted.

Upper body: broad armored torso of dark gunmetal steel with worn mustard-yellow and brass accent
plates, thick riveted pauldrons, one heavy three-fingered arm, and the other arm raised forward
holding out a projected ENERGY SHIELD.

The shield: a large circular translucent barrier of blue-white hard light projected from a brass
emitter ring on the forearm, hexagonal cell pattern visible inside it, bright white core fading
to deep cyan at the rim, sparks and thin electrical filaments crawling over its surface, the
light spilling onto the robot's armor and the ground.

Pose: braced, shield raised toward the viewer, tank chassis angled, clearly protecting something
behind it. Battle-ready, immovable.

Setting: cracked concrete battlefield, cold blue haze, drifting dust and small stones, distant
ruined structures out of focus.

Camera: low angle, front three-quarter view, the robot and its glowing shield dominating the
frame.

Palette: dark gunmetal and mustard-brass, with the blue-white energy shield as the brightest
element.
```

## 验收

- 图鉴详情：`gallery.tscn -- --screenshot --card 9056 / 9101 / 8055` 三张抽验，卡面正常上色。
- 索引体检：`python _art_index.py --check` → **体检：通过**（无占位残留 / 无孤儿图 / 计划未失效）。
- 索引口径：44 已完成 / 196 待做 / **21 暂不做**（+8022）。
- 回归：engine 3598 / reward 26 / bgm 31 / smoke 42（本批不动代码逻辑，基线不变）。
