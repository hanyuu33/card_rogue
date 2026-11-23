# -*- coding: utf-8 -*-
"""R785b：力场素材从「圆环」换成「贴卡框」（`*_card.png`）。

为什么换：
  · 圆环外径 138 > 格子宽 124 → 相邻两个满额度单位的光环互相咬在一起；
  · 环与卡边之间还留一圈空气，读起来是「卡牌漂在一个呼啦圈里」。
  贴卡框是沿卡牌轮廓的重映射素材（总宽 = 卡宽 + 2×(11.5+6) ≈ 111.5 < 124），
  相邻不咬、贴着卡边，语义也才是「罩住」。

改三处：常量块、素材路径、绘制尺寸。
⚠️ battle_scene.gd 是 CRLF，io.open(newline="") 原样读写。
"""
import io
import sys

P = "scripts/battle_scene.gd"


def main() -> int:
    s = io.open(P, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in s else "\n"

    # ---- 1. 常量块：RING/PAD → BAND/PAD ----
    old = nl.join([
        "## 环外径（屏幕像素）。战场卡对角线 = sqrt(76.6^2 + 92.4^2) ≈ 120.0，",
        "## 取 138 让环带整圈落在卡角**外侧**，而不是切进卡面压住四角。",
        "## 素材画布四周另有 CAP_AURA_PAD_PX 留白（与外扩百分比同源，见 _finish_fx.py）。",
        "const CAP_AURA_RING_PX := 138.0",
        "const CAP_AURA_PAD_PX := 6.0",
    ])
    new = nl.join([
        "## 环带厚度（屏幕像素）：从卡边向外 11.5px。**不能用圆环**（R785 首版实拍）：",
        "## 圆环直径必须 ≥ 卡牌对角线 120，而格子宽只有 124 —— 相邻两个满额度单位的",
        "## 光环会咬在一起，还会在卡边外留一圈空气。贴卡框总宽 ≈ 111.5 < 124，相邻不咬。",
        "## 素材画布 = 卡宽高各加 2×(CAP_AURA_BAND + CAP_AURA_PAD_PX)，见 _finish_fx.py。",
        "const CAP_AURA_BAND := 11.5",
        "const CAP_AURA_PAD_PX := 6.0",
    ])
    assert s.count(old) == 1, "锚点1 命中 %d" % s.count(old)
    s = s.replace(old, new, 1)

    # ---- 2. 素材路径换成 *_card ----
    old = 'var _cap_aura_path := "res://assets/fx/fx_cap_aura_%02d.png" % CAP_AURA_VARIANT'
    new = 'var _cap_aura_path := "res://assets/fx/fx_cap_aura_%02d_card.png" % CAP_AURA_VARIANT'
    assert s.count(old) == 1, "锚点2 命中 %d" % s.count(old)
    s = s.replace(old, new, 1)

    # ---- 3. 绘制尺寸 ----
    old = nl.join([
        "\t\tvar side := (CAP_AURA_RING_PX + CAP_AURA_PAD_PX * 2.0) * (1.0 + 0.025 * cp)",
        "\t\tdraw_texture_rect(_cap_aura_tex,",
        "\t\t\t\tRect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false,",
        "\t\t\t\tColor(1.0, 1.0, 1.0, 0.84 + cp * 0.16))",
    ])
    new = nl.join([
        "\t\t# 尺寸口径：卡宽高各加 2×(BAND+PAD)，与素材画布严格 4x 对应（446x510）。",
        "\t\t# 缩放只给 0.8%：环带是贴着卡边的，缩放一大就会一进一出地啃卡框。",
        "\t\tvar ext := (CAP_AURA_BAND + CAP_AURA_PAD_PX) * 2.0 * (1.0 + 0.008 * cp)",
        "\t\tvar dw := w + ext",
        "\t\tvar dh := h + ext",
        "\t\tdraw_texture_rect(_cap_aura_tex,",
        "\t\t\t\tRect2(center - Vector2(dw, dh) * 0.5, Vector2(dw, dh)), false,",
        "\t\t\t\tColor(1.0, 1.0, 1.0, 0.86 + cp * 0.14))",
    ])
    assert s.count(old) == 1, "锚点3 命中 %d" % s.count(old)
    s = s.replace(old, new, 1)

    # 注释里那句「环外径必须 ≥ 卡牌对角线」也要跟着改，否则下一个人会被误导
    old = "\t## ⚠️ 环外径必须 ≥ 卡牌对角线（120.0）；且**只套一圈** —— 卡牌自带华丽金框，"
    new = "\t## ⚠️ 用的是**贴卡框**素材（不是圆环）；且**只套一圈** —— 卡牌自带华丽金框，"
    assert s.count(old) == 1, "锚点4 命中 %d" % s.count(old)
    s = s.replace(old, new, 1)

    io.open(P, "w", encoding="utf-8", newline="").write(s)

    chk = io.open(P, encoding="utf-8", newline="").read()
    for m in ["const CAP_AURA_BAND := 11.5", "_card.png\" % CAP_AURA_VARIANT",
              "var dw := w + ext", "RING_PX"]:
        if m == "RING_PX":
            assert chk.count(m) == 0, "还有 RING_PX 残留 %d 处" % chk.count(m)
        else:
            assert chk.count(m) == 1, "回读缺少 %r（%d）" % (m, chk.count(m))
    assert chk.count("\n") == chk.count("\r\n"), "行尾被改成 LF 了"
    print("PATCH OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
