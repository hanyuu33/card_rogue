# 卡图批次 F · 机械之心三张（R333）

| id | 卡名 | 费 | 稀有度 | 一句话画面 |
|---|---|---|---|---|
| 8071 | 报废 | 3 | 稀有(1) | 仓库大门被推开，**光只从门外来**，光柱里照着一台报废机器人 |
| 9145 | 聚能炮击 | 1 | 普通(0) | 三脚架激光炮开火的瞬间，**侧面斜仰视** |
| 9146 | 填充 | 0 | 稀有(1) | **同一台炮**，尾部电池舱掀开，塞进一块汽车电瓶 |

## 用户口径（R333 原话）

- 报废：**「开门，在阴暗的仓库里有一些废旧机器人。（注意开门后的光照，门外光源门内没有）」**
- 聚能炮击：**「激光炮发射激光，侧面斜仰视视角」**
- 填充：**「同款激光炮，更换电池（类似汽车电池）」**

## 主色分配（防撞脸）

暖金光柱（8071）/ 青白激光（9145）/ 蓝白电弧（9146）。三张缩到手牌 99×119
也能靠色块分开——8071 是大片冷暗蓝里一条暖光，9145/9146 则是金属暗底上一处高亮。

## 连续性：9145 → 9146 是同一台炮

9146 走 **image-to-image**（`image1` = 9145 的成品、`input_fidelity = high`），
首句写死 `EXACT SAME WEAPON as the reference image`，并把炮的五个特征逐条点名：

> flared crown muzzle with four cooling fins / dark gunmetal body with rivets and weld seams /
> worn brass and mustard-yellow accent plates / large ring-shaped copper induction coil /
> three splayed support legs on the same cracked concrete floor

结果三脚架、粗短炮管、喇叭口炮冠、铜色线圈、黄铜+暗钢配色全部对上了，
镜像方向不同（9145 炮口朝右上、9146 炮口朝左上）但不影响「同一台机器」的辨识。

## 「门外光 / 门内无光」怎么落

这是本批唯一一条**光照约束**，提示词里连写三句正面 + 一句反面，缺一句模型就会自己
给仓库加灯：

```
The ONLY light source is daylight coming from OUTSIDE through that open doorway —
the warehouse interior itself has absolutely NO lamps, NO ceiling lights, NO glowing machinery.
...
warm golden light outside the door vs pitch-dark interior
```

同时把「废机器人不许发光」也写死了（`no glowing eyes`）——否则模型很喜欢给报废机器人
点一对红眼睛，画面立刻从「报废场」变成「待激活的机械军团」，与 8071 的效果
（把其他手卡变成聚能炮击）要表达的「拆件回收」语义相反。

## 出图记录

- 三张**一次过**，没有重画。
- 每张都有右下角「AI生成」水印 → 统一走 `_r333_cardart.py` 处理链：
  切底部 11% → cover 1.1117 → LANCZOS 448×403 → `--headless --import`。
- 提示词全文见下。

## 提示词

### 8071 报废

```
FULL-BLEED Japanese anime illustration, thick painterly rendering, cinematic dramatic
chiaroscuro, square composition filling the entire frame, NO white background, NO border,
NO text, NO watermark.

Subject: the interior of a dark abandoned robot scrapyard warehouse at night. A massive rusted
steel warehouse door on the left has just been shoved open. The ONLY light source is daylight
coming from OUTSIDE through that open doorway — the warehouse interior itself has absolutely
NO lamps, NO ceiling lights, NO glowing machinery. The doorway throws a hard narrow wedge of
warm golden light across the concrete floor and up onto the nearest junked robot, while
everything deeper inside stays in deep cold blue-black shadow. Strong contrast between the warm
light outside the door and the pitch-dark interior.

In the gloom: rows of scrapped humanoid robots slumped against the walls and stacked in heaps —
rusted yellow-and-grey armor plating, cracked chest plates with exposed dead wiring, missing
arms and heads, dangling severed cables, one robot slumped forward on its knees with a dead
dull eye lens, another lying on its side in the pile. Dead, neglected, no motion, no glowing
eyes. Dust motes and thin haze floating inside the light beam, oil stains on the floor, scattered
bolts and broken servo parts.

Palette: cold desaturated blue-black and rust brown for the warehouse interior, one warm
amber-gold shaft of light from the open door. Camera: slightly low eye level, looking into the
warehouse past the open door frame. Melancholic, quiet, industrial.
```

### 9145 聚能炮击

```
FULL-BLEED Japanese anime illustration, thick painterly mecha rendering, cinematic, square
composition filling the entire frame, NO white background, NO border, NO text, NO watermark.

Subject: a heavy industrial LASER CANNON firing a shot. LOW-ANGLE THREE-QUARTER SIDE VIEW —
camera kneeling near the ground beside the weapon, looking up along the barrel, so the cannon
looms huge and heroic against the sky, foreshortened muzzle pointing up and away to the upper
right.

Weapon design (must be clear and specific): a squat brutalist tripod-mounted energy cannon —
thick short cylindrical barrel with a flared crown-shaped muzzle and four cooling fins, dark
gunmetal steel body with rivets and weld seams, worn BRASS and mustard-yellow accent plates,
a large exposed ring-shaped copper induction coil around the mid-barrel glowing hot cyan,
thick armored cables looping from the breech to a heavy battery housing at the rear, three heavy
splayed support legs planted in a cracked concrete floor.

Action: at this very instant the cannon fires — a blinding white-cyan high-energy laser beam
blasting out of the muzzle toward the upper right, the beam core pure white with cyan and violet
fringing, intense lens bloom and volumetric glow, heat haze rippling the air, ozone sparks and
ionized dust streaks around the muzzle, the concrete beneath scorched and glowing faintly orange,
recoil pushing the tripod legs up small clouds of dust.

Palette: deep gunmetal and dark teal shadows, cyan-white laser core, brass and amber accents.
Dynamic, powerful, industrial sci-fi.
```

### 9146 填充（image-to-image，image1 = 9145）

```
EXACT SAME WEAPON as the reference image — the exact same squat heavy laser cannon: same flared
crown muzzle with four cooling fins, same dark gunmetal body with rivets and weld seams, same
worn brass and mustard-yellow accent plates, same large ring-shaped copper induction coil, same
thick armored cables, same three splayed support legs on the same cracked concrete floor. Same
Japanese anime thick painterly mecha rendering, same dark industrial hangar setting. Keep the
weapon's silhouette and colors identical.

New action: instead of firing, the cannon is being RELOADED WITH A BATTERY. Its rear armored
battery housing is swung open on a hinge, revealing a deep rectangular socket lined with copper
contacts, thick busbars and a warning stripe. A huge heavy-duty lead-acid CAR-TYPE BATTERY — big
rectangular block, dull matte dark grey-black casing, two thick cylindrical lead posts on top
(one red-marked positive, one black negative) with chunky clamp terminals and braided copper
cables — is being pushed into that socket by two gloved mechanical hands, tilted at an angle,
half-way inserted. Blue-white electric arcs jump between the battery posts and the socket
contacts, bright crackling sparks, ozone glow lighting the inside of the compartment.

No laser beam, no firing. The muzzle is cold and dark, only a faint residual orange heat shimmer
on the barrel tip. Camera: three-quarter side view, medium close-up on the rear battery
compartment, slightly low angle, the open hatch and the big battery dominating the right side
of the frame.

Palette: gunmetal and dark teal shadows, brass and amber accents, concentrated electric
blue-white arc light at the battery. FULL-BLEED, square composition filling the entire frame,
NO white background, NO border, NO text, NO watermark.
```

## 验收

- 图鉴详情：`gallery.tscn -- --screenshot --card 8071|9145|9146` → 三张卡面都正常上色。
- 战斗手牌：`battle.tscn -- --screenshot --r333card --shotframe 600` → 三张并排，
  缩到 99×119 仍能分开。
- 回归：engine 3598 / reward 26 / bgm 31 / smoke 42（本批不动代码逻辑，基线不变）。
