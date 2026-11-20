# -*- coding: utf-8 -*-
"""R842c：龙石板文案纠错 —— 「荒原 / 盘龙」→「溪边苔上 / 收着翼膜的龙」。

只做字符串级 exact-replace，不动文件其余字节（含行尾）。
"""
import io

PATCHES = {
    "i18n/narrative_zh_canonical.json": [
        ("荒原上斜插着一块土黄色的石板，比人还高半头。\\n正面浮雕着一条盘龙，鳞爪被风磨得只剩起伏的轮廓，\\n唯独龙眼那一小窝金漆没被吹走",
         "溪边的青苔上斜着一块土黄色的石板，比人还高半头。\\n正面浮雕着一条收着翼膜的龙，鳞爪被苔痕和雨水磨得只剩起伏的轮廓，\\n唯独龙眼那一小窝金漆没被冲掉"),
        ("你身上那些多余的东西被它一一数过——数到第四件，就撕下来丢进裂缝里。",
         "你身上那些多余的东西被它一一数过——前 3 件留下，再往后的一件件撕下来丢进裂缝里。"),
    ],
    "i18n/narrative_en.json": [
        ("A slab of ochre stone leans in the wasteland, half a head taller than you.\\nA coiled dragon is carved across its face; wind has worn scales and claws into shallow ridges,",
         "A slab of ochre stone leans in the moss by the stream, half a head taller than you.\\nA dragon with folded wings is carved across its face; moss and rain have worn scales and claws into shallow ridges,"),
        ("It counted every surplus thing you carried \u2014 and at the fourth, tore it out and dropped it in.",
         "It counted every surplus thing you carried \u2014 the first three stayed, the rest were torn out and dropped into the crack."),
    ],
    "i18n/narrative_ja.json": [
        ("荒れ地に土色の石板が斜めに立っている。背丈より半頭ほど高い。\\n表面には盤龍が浮き彫りにされ、鱗も爪も風に削られて起伏だけが残り、",
         "小川のほとりの苔の上に、土色の石板が斜めに立っている。背丈より半頭ほど高い。\\n表面には翼を畳んだ龍が浮き彫りにされ、鱗も爪も苔と雨に削られて起伏だけが残り、"),
        ("お前が抱えている余分なものを1つずつ数え、4つ目で引きちぎって割れ目に落とした。",
         "お前が抱えている余分なものを1つずつ数え——最初の3枚は残し、それ以降は引きちぎって割れ目に落とした。"),
    ],
    "i18n/narrative_es.json": [
        ("Una losa de piedra ocre se inclina en el yermo, media cabeza más alta que tú.\\nEn su cara está tallado un dragón enroscado; el viento gastó escamas y garras hasta dejar solo relieves,",
         "Una losa de piedra ocre se inclina sobre el musgo junto al arroyo, media cabeza más alta que tú.\\nEn su cara está tallado un dragón de alas plegadas; el musgo y la lluvia gastaron escamas y garras hasta dejar solo relieves,"),
        ("Contó una a una las cosas sobrantes que llevabas, y a la cuarta la arrancó y la echó en la grieta.",
         "Contó una a una las cosas sobrantes que llevabas: las tres primeras se quedaron, y las demás las arrancó y las echó a la grieta."),
    ],
}

for path, pairs in PATCHES.items():
    s = io.open(path, encoding="utf-8", newline="").read()
    for old, new in pairs:
        n = s.count(old)
        assert n == 1, "%s: 锚点命中 %d 次 -> %r" % (path, n, old[:40])
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="").write(s)
    # 立刻回读验 JSON
    import json
    json.load(io.open(path, encoding="utf-8"))
    print("OK", path, len(pairs), "replacements, json valid")

# 残留检查：不该再有「荒原 / 盘龙 / wasteland / 盤龍 / enroscado」
bad = ["荒原上", "一条盘龙", "in the wasteland", "盤龍", "dragón enroscado", "en el yermo"]
for path in PATCHES:
    s = io.open(path, encoding="utf-8", newline="").read()
    for b in bad:
        if b in s:
            print("!! 残留 %r in %s" % (b, path))
print("residual check done")
