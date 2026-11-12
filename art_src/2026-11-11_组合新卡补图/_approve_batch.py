# -*- coding: utf-8 -*-
"""本批 4 张卡图「转正」：从 assets/pics/_pending/ 正式移入主目录。

15:23 店长指令「转正」＝ approve 入库（区别于 15:11 的「点名即转正」，
那次只是把 v2a 覆盖到 _pending 成品位）。

纪律：
  · 逐张点名 approve，**绝不用 `approve all`** —— _pending 里还有 R563 的 114 张
    待审图，其中 24 张与主目录重名，整批 approve 会误搬 / 跳过，口径会乱。
  · approve 前先补 manifest 出生档案，避免 cmd_approve 只留 status/approved 两个字段。
  · PNG 由 cardart.py 用 shutil.move 搬；配套 .import 跟着搬并改 source_file 路径，
    不在 _pending 留新孤儿（历史遗留的 122 个孤儿 .import 本轮不动）。
  · 不 commit / 不 push / 不打包；art_plan 批次记录仍留整批归档时补。
可重复执行：已搬走的会跳过，最终状态用断言收口。
"""
import hashlib
import json
import os
import subprocess
import sys

from PIL import Image

ROOT = r"E:\work\card_rogue"
D = os.path.dirname(os.path.abspath(__file__))
PICS = os.path.join(ROOT, "assets", "pics")
PEND = os.path.join(PICS, "_pending")
MANIFEST = os.path.join(PEND, "manifest.json")

# 出生档案：字段对齐 manifest 现有条目（name/tier/created/ref/prompt/note）。
DOSSIER = {
    "9246": {
        "name": "宝石兽", "tier": "A", "created": "2026-11-11",
        "ref": "影之诗「马纳历亚宝石兽」+ 游戏王「宝玉兽 红玉兽」实图（refs/，纪律 O）；"
               "图生图形象参考 参考A_影之诗小幻兽.png；风格参考桶 treant=8003",
        "prompt": "毛茸茸的奶油浅绿小幻兽：额上一颗绿宝石、两只大尖耳、蓬松大尾、"
                  "琥珀色眼睛，蹲在苔石上，脚下冒出嫩芽；暗色柔焦森林背景，硬边赛璐璐平涂。"
                  "宝石是嵌在活物身上的饰物，不是身体材质。",
        "note": "v1 几何矿石兽方向错（按卡名脑补材质，纪律 O）。15:11 店长点名 v2a 转正为 "
                "_pending 成品，v2b 四耳小狐留候选；v1 备份 backup_9246/。正式 prompt "
                "9246_宝石兽_v2a.txt，raw/9246_宝石兽_v2a.png。15:23 整批 approve 入库。",
    },
    "9247": {
        "name": "拼装工厂", "tier": "A", "created": "2026-11-11",
        "ref": "风格参考桶 mech=8025；画面纪律 H（R563 侦察塔 / 9167 合体踩坑）",
        "prompt": "固定钢制工厂工事，正面三个不同形状的模块插槽（方块 / 楔块 / 圆柱）"
                  "与实体灰色部件物理扣合，琥珀状态片只为平涂色块、不发光；暗色工业背景。",
        "note": "明确排除发光雷达碟 / 炮管 / 炮塔 / 传送带 / 烟雾，避免与 8037 改造工厂、"
                "9147 流水线装配撞画面。448×403 验收四边留白足。",
    },
    "9190": {
        "name": "猫鼠游戏", "tier": "A", "created": "2026-11-11",
        "ref": "风格参考桶 shadow_beast=8006；规范 A/B（技能卡只画物件、不画生物 / 不画卡牌）",
        "prompt": "暗紫棋盘上两枚无脸几何棋子（尖耳 / 圆耳）+ 沙漏（紫沙落在下半球）"
                  "+ 两片重叠新月刃影表示下回合翻倍，地上散几片空白小片；暗紫调硬边平涂。",
        "note": "不画真猫真鼠、人脸、卡牌、卡框、文字、箭头、光束。语义＝丢弃所有手牌 + "
                "下回合技能伤害加倍。",
    },
    "9191": {
        "name": "黑暗嵌合", "tier": "A", "created": "2026-11-11",
        "ref": "风格参考桶 shadow_beast=8006；规范 A/B；避开 9167「合体吸能」老坑",
        "prompt": "三块黑曜石楔块带榫卯接缝物理扣合成一枚菱形核心，周围六片朝外的"
                  "扁平紫色菱形碎片表示打全体；暗紫调硬边平涂，无漩涡 / 光束 / 烟雾。",
        "note": "语义＝组合一张卡使其获得「保存」并对所有敌人造成伤害；楔块必须是硬扣合，"
                "不是能量吸收。",
    },
}
IDS = list(DOSSIER)


def md5(path):
    with open(path, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


def main():
    # ---- 0. 前置：主目录不得已有同名图（防覆盖旧图） -----------------------
    for cid in IDS:
        assert not os.path.exists(os.path.join(PICS, "%s.png" % cid)), \
            "主目录已有 %s，先人工比对" % cid
        assert os.path.exists(os.path.join(PEND, "%s.png" % cid)), \
            "_pending 缺 %s" % cid
    before = {cid: md5(os.path.join(PEND, "%s.png" % cid)) for cid in IDS}

    # ---- 1. 补 manifest 出生档案（固定 LF + indent=1，与 cardart._save 一致）----
    with open(MANIFEST, encoding="utf-8") as f:
        m = json.load(f)
    m["updated"] = "2026-11-11"
    for cid, rec in DOSSIER.items():
        it = m["items"].setdefault(cid, {})
        for k, v in rec.items():
            it.setdefault(k, v)          # 不覆盖已有档案
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(m, f, ensure_ascii=False, indent=1)

    # ---- 2. 逐张 approve（绝不用 all） -------------------------------------
    for cid in IDS:
        r = subprocess.run(
            [sys.executable, os.path.join(ROOT, "tools", "cardart.py"), "approve", cid],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
        print("[approve %s] %s" % (cid, r.stdout.strip().replace("\n", " | ")))
        assert r.returncode == 0, "cardart approve %s 失败: %s" % (cid, r.stderr[:200])

    # ---- 3. .import 跟着资源搬到主目录，改 source_file 路径 ------------------
    for cid in IDS:
        src = os.path.join(PEND, "%s.png.import" % cid)
        dst = os.path.join(PICS, "%s.png.import" % cid)
        if os.path.exists(src) and not os.path.exists(dst):
            txt = open(src, encoding="utf-8").read()
            old = 'source_file="res://assets/pics/_pending/%s.png"' % cid
            new = 'source_file="res://assets/pics/%s.png"' % cid
            assert old in txt, "%s .import 路径锚点不符" % cid
            with open(dst, "w", encoding="utf-8", newline="\n") as f:
                f.write(txt.replace(old, new))
            os.remove(src)
            print("[import] %s.png.import -> assets/pics/" % cid)

    # ---- 4. 断言收口 ------------------------------------------------------
    with open(MANIFEST, encoding="utf-8") as f:
        m2 = json.load(f)
    for cid in IDS:
        p = os.path.join(PICS, "%s.png" % cid)
        assert os.path.exists(p) and Image.open(p).size == (448, 403), p
        assert md5(p) == before[cid], "%s 搬运后字节变了" % cid
        assert not os.path.exists(os.path.join(PEND, "%s.png" % cid)), \
            "%s 仍在 _pending（重复图）" % cid
        assert os.path.exists(os.path.join(PICS, "%s.png.import" % cid)), \
            "%s 缺 .import" % cid
        it = m2["items"][cid]
        assert it["status"] == "approved" and it["approved"] == "2026-11-11", it
        assert all(k in it for k in ("name", "tier", "created", "ref", "prompt", "note")), it
    print("[approve-batch] 4 张已入库：448x403 / md5 不变 / _pending 无残留 / "
          "manifest 档案齐全")

    # ---- 5. 刷新验收页（_preview 已改为主目录优先） -----------------------
    r = subprocess.run([sys.executable, os.path.join(D, "_preview.py")],
                       cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    print(r.stdout.strip())
    if r.stderr.strip():
        print("stderr:", r.stderr.strip()[:300])
    assert r.returncode == 0, "_preview.py 失败"


if __name__ == "__main__":
    main()
