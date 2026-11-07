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
