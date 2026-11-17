# -*- coding: utf-8 -*-
"""R785：免伤力场改用 codex 出图的环形素材（三版可切）。

改三处：
  1. 变量区加 CAP_AURA_VARIANT / CAP_AURA_RING_PX / CAP_AURA_PAD_PX / _cap_aura_tex
  2. _ready 里 load 素材（ResourceLoader.exists 兜底，素材缺了不报红）
  3. _draw_damage_cap_aura 改成「素材优先、程序化兜底」

⚠️ battle_scene.gd 是 CRLF：一律 io.open(newline="") 原样读写，新段落自己转 \r\n。
⚠️ 素材必须画在 `_draw_card_face()` **之前**（调用点不动，仍在 10690 那一行），
   画在后面会把右上角状态徽标切断。
"""
import io
import sys

P = "scripts/battle_scene.gd"


def main() -> int:
    s = io.open(P, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    nl = "\r\n" if crlf else "\n"

    def block(text: str) -> str:
        return text.replace("\n", nl)

    # ---- 1. 变量声明 ----
    # ⚠️ 锚点必须带行尾注释：只匹配前半段会把注释挤成一条孤立的 `  # 收束光环…` 行
    anchor1 = "var _fx_lone_ring_tex: Texture2D = null  # 收束光环（圆形，空心）"
    assert s.count(anchor1) == 1, "锚点1 命中 %d" % s.count(anchor1)
    decl = block(
        "var _fx_lone_ring_tex: Texture2D = null  # 收束光环（圆形，空心）\n"
        "## R785：免伤力场的环形素材（codex 纯文生图 → 黑底亮度转 alpha，\n"
        "## 管线见 art_src/2026-11-17_免伤力场素材_R785/，三版候选可切换）。\n"
        "##   1 = 金色六角晶格结界 / 2 = 琥珀符文结界 / 3 = 白金色棱镜力场\n"
        "const CAP_AURA_VARIANT := 1\n"
        "## 环外径（屏幕像素）。战场卡对角线 = sqrt(76.6^2 + 92.4^2) ≈ 120.0，\n"
        "## 取 138 让环带整圈落在卡角**外侧**，而不是切进卡面压住四角。\n"
        "## 素材画布四周另有 CAP_AURA_PAD_PX 留白（与外扩百分比同源，见 _finish_fx.py）。\n"
        "const CAP_AURA_RING_PX := 138.0\n"
        "const CAP_AURA_PAD_PX := 6.0\n"
        "var _cap_aura_tex: Texture2D = null\n")
    s = s.replace(anchor1, decl, 1)

    # ---- 2. 加载 ----
    anchor2 = '_fx_lone_ring_tex = load("res://assets/fx/fx_lone_ring.png")'
    assert s.count(anchor2) == 1, "锚点2 命中 %d" % s.count(anchor2)
    # ⚠️ 每行都要自带 tab：锚点只匹配「不含缩进的那截文本」，原来的 tab 留在原地，
    #    新加的后续行不自己带 tab 就会掉进 class body，报 Unexpected "if"（这个坑踩过两次）
    load_block = block(
        '_fx_lone_ring_tex = load("res://assets/fx/fx_lone_ring.png")\n'
        '\t# R785：免伤力场素材（三版里挑 CAP_AURA_VARIANT 那一张）\n'
        '\tvar _cap_aura_path := "res://assets/fx/fx_cap_aura_%02d.png" % CAP_AURA_VARIANT\n'
        '\tif ResourceLoader.exists(_cap_aura_path):\n'
        '\t\t_cap_aura_tex = load(_cap_aura_path)\n')
    s = s.replace(anchor2, load_block, 1)

    # ---- 3. 绘制函数 ----
    i0 = s.index("func _draw_damage_cap_aura(")
    i1 = s.index("\nfunc _draw_stun_aura(", i0)
    old = s[i0:i1]
    # 兜底段起点：原来那段程序化画法从 `var dc_t` 开始
    k = old.index("\tvar dc_t := float(_now()) / 1000.0")
    fallback = old[k:]

    head = block(
        "func _draw_damage_cap_aura(center: Vector2, w: float, h: float) -> void:\n"
        "\t## 免伤力场（`GameEngine.damage_cap_left(p) == 0` 的唯一表现口，R780b）。\n"
        "\t## 赫尔墨斯 9140 / 量产型赫尔墨斯 9188 本回合的 20 点伤害额度已经吃满，\n"
        "\t## 接下来所有伤害都被上限吃掉、一点血也扣不动。\n"
        "\t## ⚠️ R785（店长口径）：R780b 那版程序化六边形金线「不好看」，改成**贴素材** ——\n"
        "\t##    codex 纯文生图出的环形结界（黑底 → 亮度转 alpha，见\n"
        "\t##    art_src/2026-11-17_免伤力场素材_R785/）。程序化那版降级为**兜底**：\n"
        "\t##    素材没导入 / 被裁掉时仍然要有「打不动」的表现，不能静默消失。\n"
        "\t## ⚠️ 环外径必须 ≥ 卡牌对角线（120.0）；且**只套一圈** —— 卡牌自带华丽金框，\n"
        "\t##    再叠一道高对比金线就读成「描边加粗」而不是「多了个力场」。\n"
        "\t## ⚠️ 呼吸只动 alpha 和 ±2.5% 缩放：环带是贴着卡角的，缩放大一点就会一进一出\n"
        "\t##    地啃卡框，看起来像卡在抖。\n"
        "\tif _cap_aura_tex != null:\n"
        "\t\tvar ct := float(_now()) / 1000.0\n"
        "\t\tvar cp := (sin(ct * 2.6) + 1.0) * 0.5\n"
        "\t\tvar side := (CAP_AURA_RING_PX + CAP_AURA_PAD_PX * 2.0) * (1.0 + 0.025 * cp)\n"
        "\t\tdraw_texture_rect(_cap_aura_tex,\n"
        "\t\t\t\tRect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false,\n"
        "\t\t\t\tColor(1.0, 1.0, 1.0, 0.84 + cp * 0.16))\n"
        "\t\treturn\n"
        "\t# ---- 以下是 R780b 的程序化兜底：仅在素材缺失时才会走到 ----\n")
    s = s[:i0] + head + fallback + s[i1:]

    io.open(P, "w", encoding="utf-8", newline="").write(s)

    # ---- 回读自检 ----
    chk = io.open(P, encoding="utf-8", newline="").read()
    must = ["const CAP_AURA_VARIANT := 1",
            "const CAP_AURA_RING_PX := 138.0",
            "var _cap_aura_tex: Texture2D = null",
            "_cap_aura_tex = load(_cap_aura_path)",
            "if _cap_aura_tex != null:",
            "draw_texture_rect(_cap_aura_tex,"]
    for m in must:
        assert chk.count(m) == 1, "回读缺少 %r（%d）" % (m, chk.count(m))
    assert chk.count("func _draw_damage_cap_aura(") == 1
    assert "\r\n" in chk and chk.count("\n") == chk.count("\r\n"), "行尾被改成 LF 了"
    print("PATCH OK  行尾=%s  文件 %d 行" % ("CRLF" if crlf else "LF", chk.count("\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
