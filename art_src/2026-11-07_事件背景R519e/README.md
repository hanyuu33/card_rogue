# 2026-11-07 事件整屏背景 · 画风返工（R519e）

## 用户口径

「这些事件图的风格太写实了。注意生成时契合游戏风格，你可以参考占卜那种风格」

## 一句话结论

R519d 那六张不是「生成跑偏」，是**提示词写的就是写实厚涂**（raw 文件名
`Semi_realistic_painted_fantasy` 就是证据）。本轮换掉风格底 + 钉死明度，六张重出，
与 `bg_divination.png` 同一套画法。

## 保留什么 / 换掉什么

**保留**：构图契约（主体全在上三分之二、下三分之一留空压暗）、水印裁切口径、
`process_*.py` 的裁切逻辑、`EventBG` 的顶部对齐实现 —— 这些都没问题。

**换掉**：只有风格底与提示词写法。渲染方式、描边、上色、调色、明度全部改。

## 出图方法

| 项 | 值 |
|---|---|
| 模型 | 后端默认（当前工具无法指定 Seedream v5） |
| size | 1536×1024 |
| image1 | `style_ref/bg_divination.png` |
| input_fidelity | `low` —— 只借画风，不借场景 |
| prompt | 「只借画风」声明 + 风格底（§一·C）+ 明度约束 + 构图契约 + 主题 |

完整提示词见 `prompts.md`。

## 六张结果

| kind | 画面 | 备注 |
|---|---|---|
| `smith` | 鸭鸭工匠铺：炉火 + 铁砧台 + 铁钳夹着一张牌 | 一次过 |
| `struggle` | 暗风暴天空下的裂地荒原，金属板拼成的龙从血雾里立起来 | **返工一次**（原天空粉紫粉彩） |
| `oblivion` | 暮色森林的死水潭，水面什么都不映 | 一次过，全场最暗 |
| `snow_leopard` | 月夜雪坡，一串脚印通向坡顶的雪豹 | **返工一次**（原通篇发白、像另一个游戏） |
| `adventurer` | 崖根石台：旧行囊 + 空笔记本 + 扣环上的燧石 | 一次过 |
| `martial` | 大树下盘坐的老人（背影）+ 横膝木棍 + 被捶裂的石头 | 一次过 |

共出 8 张（6 + 2 返工）。

## 返工的那两张：明度没锁住

`dark` 写进风格底只保证「局部暗」，不保证「整张暗」。第一批两张栽在这：

- `snow_leopard`：写成「雪坡 + 淡紫黄昏」，出来是发白粉彩，混在四张暗调里像贴错图。
  → 改 `NIGHT scene`，明写 `snow is NOT white, muted blue-grey in shadow`、
  `must NOT read as bright / pastel / washed out`，加一轮月亮当唯一亮点。过。
- `struggle`：写明度不够，天空成了粉紫。
  → 改成 `dark storm-grey, NOT pastel, NOT pink, NOT lavender, NOT magenta`，
  龙改成「画面里最亮的东西」。过。

判据：**六张拼一张，一眼跳出来的那张就是明度没锁住。**

## ⚠️ 流程坑：换图后 Godot 不会自动重导入

改完 `assets/ui/*.png` 直接 `godot --path . res://scenes/event.tscn` 截图，
屏幕上还是 `.godot/imported/` 里的旧 `.ctex` —— 本轮第一次截图六张全是 R519d 的旧图，
差点误判成「新图没生效」。截图前必须先：

```
godot --headless --path . --import
```

判据：`.godot/imported/bg_<kind>.png-*.ctex` 的 mtime 晚于 `assets/ui/` 里那张。

## 工具

| 脚本 | 用途 |
|---|---|
| `tools/process_r519e.py` | 居中裁 16:9 + 水印复核 + 缩 1280×720。`--write` 才落盘 |
| `tools/shoot_r519e.py` | 六个事件各截一张（`event.tscn -- <kind> --screenshot`） |

出图在 `_review/`（已被 .gitignore 忽略），`processed/` 是落盘前中转。

## 验收图

- `_review/r519e_sheet.png` —— 六张 raw 裁 16:9 拼图（看画风）
- `_review/ingame_sheet.png` —— 六张游戏内截图拼图（看卡片压上去之后）
- `_review/对比_d_vs_e.png` —— R519d 与 R519e 上下对照

---

# R519f 追加：构图契约的两处硬伤

用户口径：「雪豹为什么要刻意做成半张图的效果？没有必要」。

不是模型问题，是**契约写错了**。`snow_leopard` 的地形到中线就收边，下面整片是一个
色值 —— 观感就是被横切的半张图。根因是提示词里那句「下三分之一留空压暗 /
keep it clean and simple」被理解成**刷一块纯色**。

同时检查其余五张，发现 `martial` 有另一处硬伤：老人坐在正中，**游戏里被卡片整块盖住**
—— 事件叫「武术大师」，画面里没有大师。根因是「主体放上三分之二」对**坐地题材**不成立，
人物只能在中段，而中段正好是卡片的位置。

两处都改了契约（已写进 `_style_prompts.md` §一·C 与 `UI设计规范.md` §4.54）：

| 原写法 | 新写法 |
|---|---|
| 下三分之一留空压暗 | 画面**铺满整张**，地面画到画面底边，有草/石/影/轮廓与两级明暗；只是**不摆主体**。明写 `NOT a flat single-colour fill, NOT a black bar`、`NO horizontal line where detail stops` |
| 主体放上三分之二 | 主体放**左三分之一 / 右三分之一**，或上三分之二；中间那条留空给卡片 |

卡片实际遮挡：纵向 y≈47% 往下、横向约 26%–74%。

## 本轮返工两张

| kind | 问题 | 改法 |
|---|---|---|
| `snow_leopard` | 下半张纯色空块，像被横切 | 前景雪堤铺满下半、跑出画面底边，加碎石与枯草；脚印延续到前景 |
| `martial` | 老人被卡片整块盖住 | 老人移到左侧约 18% 处、身体落在 38%–62% 高度线之间；捶裂的石头移右侧同高；中间只留树干与草地 |

`martial` 中间试过一版「把人整体上移」，结果天空变成橙粉落日、明度也跳出去了 ——
**坐地题材上移不现实，只能左右摆**，这一版废掉重出。

## 追加出图

3 张（`snow_leopard` ×1、`martial` ×2，中间那一版废）。
新契约已固化，下一批（`pear` / `hero` / `bluefish` / `apple_doctor`）直接照 §一·C 出。

---

# R519g 追加：武术大师改成左右布局

用户口径：「武术大师：人物会被选项框挡住。这样吧，这个事件也做成湖中仙女那样的左右的格式」。

R519f 是把老人挪到左侧 18% 避开卡片 —— 那是**绕着卡片摆**。坐地的人物天生在地面中段，
怎么挪都在赌。左右布局换赛道：侧图独占左栏，卡片去右栏。

| 项 | 值 |
|---|---|
| 产物 | `assets/ui/side_martial.png` **742×742**（同 `side_lake_lady.png`） |
| 代码 | `event_scene.gd` `SIDE_LAYOUT_KINDS` 加 `"martial"` |
| 删掉 | `assets/ui/bg_martial.png` + `.import` —— 左右布局不吃整屏图 |
| 出图 | 1536×1024 → 取左侧 `1024×1024` 方形 → 缩 742 |
| 脚本 | `tools/process_side_martial.py`（`--write` 才落盘） |
| 水印 | 原图右下 x≈1400 之后 → 裁左方形时**自然出界**，不需要修补 |

## 侧图契约（第一版踩的坑）

第一版写成「右三分之一留白」→ 模型刷了一条**硬边纯色竖带**（x≈72.5%），
而 `_side_fade_material()` 的 alpha 从 74% 才开始收 → 正好露出一条竖缝，废。

正确写法：

```
The subject occupies the LEFT TWO THIRDS of the square, filling the frame top to bottom.
The RIGHT THIRD is deliberately PLAIN: the same drawn ground simply gets quieter and DARKER
in a continuous way - still grass with drawn texture and a drawn silhouette.
NEVER a solid rectangle of one colour, NEVER a hard edge, NEVER a wall.
```

**「留白 / 留空 / keep it clean」这几个词在出图提示词里一律不许用** ——
和 R519f 的「下三分之一留空」是同一个坑，模型只会理解成刷色块。

## 接缝不需要额外压暗

试过在图里叠一道从 52% 起的线性压暗 → 把坐在 60%~74% 的老人一起压暗了，撤掉。
草地轮廓自己会淡出，`_side_fade_material()` 再收 alpha 就够。

## 验收

- `_review/martial_side.png` —— 1280×720
- `_review/martial_1920.png` —— 1920×720（事件页不接 stage，侧图贴屏幕左缘）

---

# R519h 追加：休息处改左右布局（篝火）

用户口径：「休息处的图需要更换，换成正在燃烧的篝火」。

**整屏试了 4 版全废**（详见 `UI设计规范.md` §4.56 的失败对照表）：
模型对「画面里要有一堆篝火」的服从度远高于「篝火必须待在 x<22%」，
每次都落在画面宽度 20%~25%，而卡片左缘在 26% → 必被切。
**这类需求别再试整屏，直接左右布局。**

| 项 | 值 |
|---|---|
| 产物 | `assets/ui/side_rest.png` **742×742** |
| 代码 | `SIDE_LAYOUT_KINDS` 加 `"rest"`；删 `UiAssets.event_bg()` 的 rest 特判 |
| 删掉 | `assets/ui/adventure_shared/rest_clearing.png`（黄昏空地，篝火被卡片埋住） |
| 出图 | 原生 **1024×1024** 方图 → 修补水印 → 缩 742 |
| 脚本 | `tools/process_side_rest.py` |
| 水印 | ⚠️ 方图**裁不掉**，在画面内（872..1024 / 948..1024）→ `patch_wm()` 修补 |

废弃清理：`tools/process_rest.py`、`raw/rest.png`、`processed/rest_clearing.png`
（整屏方案的废稿与脚本，不要复用）。

## 验收

- `_review/rest_after.png` —— 1280×720，篝火完整在左栏，四个选项 + 烟斗提示都放得下
- `_review/rest_1920.png` —— 1920×720
- `_review/martial_side.png` —— **重截**的 1280 武术大师（R519g 那张是撤渐变之前的旧图）
- `_review/_rest_wm_check.png` —— 水印修补区放大

---

# R519j 追加：苹果与医生（只补这一张）

用户口径：「木制的餐桌上放着一个苹果。左右构图。其他暂不生成」。

| 项 | 值 |
|---|---|
| 产物 | `assets/ui/side_apple_doctor.png` **742×742** |
| 代码 | `SIDE_LAYOUT_KINDS` 只新增 `"apple_doctor"`；其余三个待补事件不动 |
| 画面 | 一只完整的红苹果直接放在木制餐桌上；无医生、人物、餐具或多余道具 |
| 出图 | 原生 1024×1024 方图；占卜背景仅作画风参考，`input_fidelity: low` |
| 返工 | 第一版右侧出现硬边竖向暗带；第二版只修接缝，保留苹果与木桌构图 |
| 水印 | 方图右下角，`patch_wm()` 修补后缩 742 |
| 脚本 | `tools/process_side_apple_doctor.py` |

验收：`_review/apple_doctor_1280.png` 与 `_review/apple_doctor_1920.png`。
两种宽度均为左图右文，苹果完整，标题、正文、两个选项无遮挡，右缘过渡自然。
审计后事件背景 16 个，待补只剩 `pear` / `hero` / `bluefish`。

---

# R519k 追加：苹果链接文字重影修复

左右布局的正文是左对齐 + 自动折行，旧链接定位却仍按居中逻辑行计算 → 金色「苹果」
压到「最大生命」。`event_scene.gd` 改为按 `TextParagraph` 的实际可见行与
`horizontal_alignment` 定位。验收图：`_review/apple_doctor_link_fix_{1280,1920}.png`；
居中布局回归图：`_review/smith_link_regression_1280.png`。
