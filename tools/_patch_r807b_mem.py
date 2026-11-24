# -*- coding: utf-8 -*-
"""R807b 记忆更新：MEMORY.md（CRLF）+ ROUNDS 追加（LF）+ 新建 2026-11-19.md。"""
import io
import os
import sys

M = "E:/work/.workbuddy/memory"
E = "\r\n"


def rw(name, eol, pairs):
    p = os.path.join(M, name)
    s = io.open(p, "rb").read().decode("utf-8")
    for old, new, cnt in pairs:
        o = old.replace("\n", eol)
        n = new.replace("\n", eol)
        c = s.count(o)
        if c != cnt:
            print("FAIL %s count=%d expect=%d\n  %r" % (name, c, cnt, old[:70]))
            sys.exit(1)
        s = s.replace(o, n)
    io.open(p, "wb").write(s.encode("utf-8"))
    print("OK   %s" % name)


rw("MEMORY.md", E, [
    ("- **卡图验收两道关**：① 规格 —— 只看「可见带」",
     "- **prompt 的【风格】段写反了比不写更糟（R807）**：9276 第一版风格段写「日式动漫**厚涂**插画：强体积感、"
     "硬边高光、布料质感清晰；**不要描边线条、不要赛璐璐**」→ 出图是照片级写实的布偶。"
     "项目标准是「日式动漫赛璐璐 / 2-step 上色 / 细黑线描边」，与「厚涂 + 不要描边 + 纹理清晰」正好相反。"
     "自查：把风格段和 ART 的赛璐璐条款各念一遍，对不上就重写。写实倾向的题材（布偶 / 麻布 / 旧木 / 灰尘）"
     "额外点名 `NO burlap weave, NO individual threads, NO volumetric god rays, NO dust motes, NO film grain`。\n"
     "- **可见带只有 268px，主体大小要按算的（R807）**：448×404 的可见带 = 第 68..335 行。"
     "主体占图高 52%~61% + 脚底落在 73% 才刚好进带；写「占 65% + 脚贴 62%」算出来主体 965px > 带高 748px，"
     "**必然切脚**（v1/v2 就这样）。prompt 里直接给百分比，别用「尽量留边」这种形容词。\n"
     "- **卡图验收两道关**：① 规格 —— 只看「可见带」", 1),
])

ROUNDS_ADD = """
### 卡图定版（R807b）

店长第一版反馈「风格稍微有点写实了」。**根因在原 prompt 的风格段**：写的是
「日式动漫**厚涂**插画：强体积感、硬边高光、布料质感清晰；**不要描边线条、不要赛璐璐卡通化**」——
与项目规范（赛璐璐 / 2-step / 细黑线描边）正好相反，所以必然出照片。
新 prompt 把画风提到第一句，反面逐条点名 `NO burlap weave / NO individual threads / NO volumetric god rays /
NO dust motes / NO film grain / NO realistic wood grain`。

五版对比（`processed/_compare_style5.png`）后**定版 v3**：赛璐璐 + 细描边，主体 52%、脚底 62%、
下方 38% 留空地板，背景补回「墙 / 地板水平分界 + 左上硬边光斑」。
v1/v2 画风也对了但主体过大（65%）导致**脚落在可见带之外**，v4 是同一画风的放大版（61%）留作备选。
换图后九套回归仍全绿（engine 6682）。
"""

p = os.path.join(M, "MEMORY_ROUNDS.md")
s = io.open(p, "rb").read().decode("utf-8")
if "卡图定版（R807b）" in s:
    print("--   ROUNDS 已有 R807b")
else:
    if not s.endswith("\n"):
        s += "\n"
    s += ROUNDS_ADD
    io.open(p, "wb").write(s.encode("utf-8"))
    print("OK   MEMORY_ROUNDS.md 追加 R807b")

DIARY = """# 2026-11-19

## R807b 卡图定版 v3 + 出包（发布版）

- 店长定 v3（赛璐璐 + 细描边 · 主体 52% · 脚底 62% · 下方留空地板），已换入
  `assets/pics/9276.png`（md5 `94d67022`），`--import` 重导，九套回归全绿（engine 6682）。
- 换图后提交 `ef4b076` 已推送；`HANDOFF.md` 被 codex 追加过 33 行交接记录，`git checkout HEAD --` 还原。
- **画风跟坑记**：原 prompt 风格段写成「厚涂 + 不要描边 + 布料质感清晰 + 不要赛璐璐」，
  和项目规范正好反过来 → 出图是照片。prompt 改法见 ART 铁律（R807 条）。
- 发布版 exe：`python _release.py --release --no-verify` →
  `E:\\work\\卡牌肉鸽_独立版`，Quackill_release.exe 80.37MB + pck 202.19MB + content 1.08MB，
  自检 engine 5784✓ / reward 26✓ / bgm 31✓ / smoke 74。顺手清掉目录里两个历史测试版单文件包
  （DuckCardsRogue.exe 251MB / Quackill.exe 277MB，脚本点名要清，免得玩家点错）。
- 发布版 APK：`bash release/build_apk.sh R807 release`。
"""

p = os.path.join(M, "2026-11-19.md")
if os.path.exists(p):
    s = io.open(p, "rb").read().decode("utf-8")
    if "R807b" in s:
        print("--   2026-11-19.md 已有 R807b")
    else:
        io.open(p, "wb").write((s + "\n" + DIARY).encode("utf-8"))
        print("OK   2026-11-19.md 追加")
else:
    io.open(p, "wb").write(DIARY.encode("utf-8"))
    print("OK   2026-11-19.md 新建")

for f in ["MEMORY.md", "MEMORY_ROUNDS.md", "2026-11-19.md"]:
    b = io.open(os.path.join(M, f), "rb").read()
    crlf, lf = b.count(b"\r\n"), b.count(b"\n")
    tag = "PURE-CRLF" if crlf == lf and crlf > 0 else ("PURE-LF" if crlf == 0 else "MIXED!!")
    print("%-20s %s" % (f, tag))
