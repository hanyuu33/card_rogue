# 2026-11-19 · R824 图标：鸭子闹钟（道具 6085）

| 文件 | 说明 |
|---|---|
| `raw/A_cute_hand_drawn_cartoon_game_2026-11-19T11-38-58.png` | 1024×1024 原图 |
| `prompts/6085_鸭子闹钟.txt` | 完整提示词（可单独重出） |
| `processed/_preview_128.png` | 抠图后 3× 放大对照 |
| `assets/ui/relic_icon_6085.png` | 128×128 RGBA 成品（与 preview 同源） |

## 这张是怎么出来的

**不是 codex。** 本轮 codex 那条路断了：Clash 在跑、7897 端口在听，但 chatgpt / google /
api.openai 三个站点全部 `000`（SSL EOF，远端节点坏了），`_run_codex.py` 的代理预检直接中止。
于是改用内置出图跑同一份提示词，原图落 `raw/` 后走 `tools/_make_r824_icons.py` 抠图。

## 两个会复发的坑

1. **`cut()` 的输出参数只能是相对路径** —— 函数内部自己拼 `ROOT`，传绝对路径会变成
   `E:/work/card_rogue/E:/work/card_rogue/...` 然后 `OSError: [Errno 22]`。
2. **`import _make_r755_icons` 会跑它的模块级代码**（重写 `trap_icon_7012.png` /
   `ui_tool_swap.png`、在仓库根写 `_preview_r755_icons.png`）。这三个产物本轮字节未变
   （`git status` 干净），但那个预览图必须手动删 —— 它不进包，只会污染 `git status`。

## 验收

- `git status` 确认 `trap_icon_7012.png` / `ui_tool_swap.png` 字节没变。
- 128×128 预览：背景透明、双铃 / 眼睛 / 扁嘴 / 蹼脚齐全、四边没被裁、无白雾边。
- 回归里 `R577b` 那条「每件道具都有 relic_icon_<id>.png」由 `_test_r824` 也点了一次名。
