# -*- coding: utf-8 -*-
"""R804：更新 MEMORY.md（卡图验收两关 + 轮次号）。保持 CRLF。"""
import io

P = "E:/work/.workbuddy/memory/MEMORY.md"
d = open(P, "rb").read().decode("utf-8")
n0 = d.count("\r\n")


def rep(old, new, cnt=1):
    global d
    assert d.count(old) == cnt, "锚点命中 %d 次（应为 %d）：%r" % (d.count(old), cnt, old[:60])
    d = d.replace(old, new)


# ① 卡图验收：从「只看可见带」扩成两道关
OLD45 = ("- **卡图验收只看「可见带」= 448x404 第 68..335 行**（`CARD_ART_RATIO=0.662`）；"
         "图标按目标显示尺寸判（`RelicBarLayout.CELL = 44.0`）。")
NEW45 = ("- **卡图验收两道关**：① 规格 —— 只看「可见带」= 448x404 第 68..335 行"
         "（`CARD_ART_RATIO=0.662`），图标按目标显示尺寸判（`RelicBarLayout.CELL = 44.0`）；"
         "② **叙事 —— 把卡名和效果念一遍，图讲的是同一件事吗**"
         "（R804：连斩被画成两把刀对称交叉，尺寸与完整度全过、逻辑全错）。"
         "多道残影类构图：交叉 / 对称 / 同点互穿一律读成「多把武器」或「静态装饰」；"
         "「连续」只能靠**同源扇面 + 透明度梯度 + 一条节奏弧线**表达。")
rep(OLD45.replace("\n", "\r\n"), NEW45.replace("\n", "\r\n"))

# ② 出图 prompt：硬约束胜形容词
OLD = ("⚠️ codex 会自己在 `HANDOFF.md` 追加「交接记录」小节（含「Git 执行受限」之类元信息）"
       "→ 提交前 `git checkout HEAD -- HANDOFF.md`。")
NEW = (OLD + "\r\n"
       "  **写 prompt 时用可数的硬约束替代形容词**：R804 靠一句「全图只允许出现一处刀柄 / 护手」"
       "就同时掐死了双持（只有一处刀柄）、对称装饰（扇面是单向的）、静态（弧线给出顺序）三种误读；"
       "反过来「横向铺满、小尺寸仍可辨」这种形容词约束会把弯刀逼成直线光条（读作羽扇），"
       "**铺满与叙事逻辑可能互斥，先保逻辑**。")
rep(OLD.replace("\n", "\r\n"), NEW)

# ③ 轮次
rep("## 当前状态（2026-11-18 · R803 已推送）", "## 当前状态（2026-11-18 · R804 已推送）")
rep("号段：道具 **6078**、工具 **7016**、卡 **9275**、轮次 **R803**（新号 6079 / 7017 / 9276 / **R804**）。",
    "号段：道具 **6078**、工具 **7016**、卡 **9275**、轮次 **R804**（新号 6079 / 7017 / 9276 / **R805**）。")

n1 = d.count("\r\n")
assert n1 == n0 + 1, "CRLF 数变化异常：%d -> %d" % (n0, n1)
assert "\n" not in d.replace("\r\n", ""), "混入了裸 LF"

io.open(P, "wb").write(d.encode("utf-8"))
print("ok  CRLF %d -> %d  size=%d" % (n0, n1, len(d.encode("utf-8"))))
