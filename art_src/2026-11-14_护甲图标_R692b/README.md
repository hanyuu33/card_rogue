# R692b 护甲图标（卡面「生命值正上方」那颗）

> 2026-11-14 · 店长口径：护甲数值原来**卡面上完全看不见**（R613b 取缔文字徽标条之后，
> 只剩左侧信息栏与悬停提示），要「图标放在卡的生命值正上面，然后加数字」。
> 图标委托 **codex 图生图**（店长指定），数字由代码画。

## 出图

| 项 | 做法 |
|---|---|
| 工具 | `codex exec --json -i assets/ui/affix_shield.png` → codex 内置 `image_gen` |
| 参考图 | `affix_shield.png`（蓝盾）—— **只借画风**：深色圆盘 + 细亮描边 + 单色符号 + 硬描边 + 左上高光 |
| 内容 | 层叠**两块**装甲板（前盾带两颗铆钉），不是单盾；青绿色，刻意与「护盾」字段的冷蓝分开 |
| 代理 | `HTTP(S)_PROXY=http://127.0.0.1:7897`（与 R562 同一套；环境自带代理连不上 chatgpt.com） |
| 取图 | codex 沙箱拷不出文件，图落 `~/.codex/generated_images/<thread>/`，由 `tools/_run_armor_icon.py` 解析 JSONL 复制到 `raw/` |

原始图：`raw/affix_armor_v1.png`（1254×1254，耗时 97s）。

## 后处理（`tools/_prep_armor_icon.py`）

口径照抄现有素材：`affix_shield.png` / `affix_taunt.png` 的 alpha 包围盒都是 `(2,2,126,126)`
—— 即「非透明内容缩到 **124²**，居中放进 **128²**，四周留 2px」。
不照抄的话，新图标在卡面上会比旁边那几颗徽章大一圈。

产出：`assets/ui/affix_armor.png`（128×128，透明角，包围盒 `(3,3,126,125)`）。

## 代码接入

| 位置 | 改动 |
|---|---|
| `CardFace.draw()` / `battle_scene._draw_card_face()` | 末尾加 `armor := 0` 参数（默认 0 = 手牌 / 图鉴 / 奖励页不受影响） |
| `CardFace._draw_badges()` | 生命徽章之后调用 `_draw_armor_badge()`，圆心 x 与生命**同一条竖线** |
| `CardFace._draw_armor_badge()` | 素材 `UiAssets.affix_badge("armor")`（= `assets/ui/affix_armor.png`，复用现成取图口）；缺图回退矢量盾 |
| `CardFace._draw_value_pip()` | **不截断**的数字角标（护甲专用）：`count` 的「9+」是沉睡 / 倒数的口径，护甲 20 写成 9+ 就是错的信息 |
| `CardInfoBoxes.draw_glyph()` | 新增 `"armor"`：盾形 + 两道横纹（区别于纯盾的「护盾」），素材缺失时的回退 |

## 验收

- 实机：`tools/_shot_r692b_armor.gd`（我方 9141 护甲 20 / 敌方 9207 护甲 10）→ `_shots/r692b_armor.png`，
  两张卡都是「生命正上方一颗青绿盾徽 + 右上角 20 / 10」。
- 回归：`python _verify.py` 八套全绿。
