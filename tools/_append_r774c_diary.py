# -*- coding: utf-8 -*-
# R774c：append 今日日记（append-only，LF）。
import io

p = r"E:/work/.workbuddy/memory/2026-11-16.md"
block = """

## R774c · 状态特效文字英文版（非中文语言统一用英文艺术字）

- 店长口径：「以后除了中文版，全用英文版艺术字」。R774 中文 11 主题照旧，非中文一律走 `assets/fx/status_words_en/`。
- status_badge.gd：新增 RULES_EN / WORD_TEX_EN / WORD_ZH / WORD_EN，word_of(glyph) 按 _is_zh() 切中英文词；
  _rules() / _word_tex() 也按语言分支。中英词表一一对应、RULES_EN 覆盖 11 主题。
- battle_scene.gd：5 处纯状态词飘字改 word_of —— 冰封 / 眩晕 / 治疗+X / 力量-X / 力量+X。
  复合描述（隐藏能源 / 超负荷死亡 / 风暴屏障等卡名或机制名）不动，归文案 i18n，不归状态词艺术字。
  别用 paint() 入口全局 localize：RULES 别名「攻击」→SWORD→"Power" 会翻成「Power力」语义错位。
- 英文素材：图生图黑底 → _process_en_words.py（黑底抠透明 → 连通域排除右下水印 → 合并其余 → 统一字高 750）。
  字母间空隙会拆散连通域，不能只取最大连通域，要排除水印后合并所有。
- 中文素材重生成：燃烧 _compose_flame.py（screen 叠加替代 multiply + 火光 + 火星，亮度 33→165）、
  能量 _compose_energy.py（紫色光晕，63→180），全 11 张 _unify_words.py 统一字高 750 + 15px padding。
- test_engine 补 4 条 R774c 断言（英文素材齐全 / RULES_EN 覆盖 / 词表对应 / 文件真实存在）——
  被并行线 R777 提交时顺手带进 aa8b916f（不在本 commit）。
- 出图 _shot_r774c_en_art.gd：用 `-- --lang=en` 走 GameSettings 官方出图口；棋盘横屏转置后只有 3 列，
  英文词宽超出列宽 → 改屏幕坐标陈列墙（4 列 → 3 列避开右面板）。验收：11 词拼写全对、无中文残留、质感对、数字清晰。
- 提交 1cca93db 已推送。提交时 battle_scene.gd 混进并行线未提交的 anthem/organ 删除 → hunk 筛选
  （_stage_r774c.py：split hunk → 删该 hunk → new_start += 20 → 转 CRLF → git apply --cached，
  并用 git diff --cached 复验真落进 index，避开 R774 那次「apply OK 却没落 index」的坑）。
  并行线 anthem/organ 删除仍在工作区未提交、未被破坏。
"""

with io.open(p, "a", encoding="utf-8", newline="") as f:
    f.write(block)
print("appended to", p)
