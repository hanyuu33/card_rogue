# 卡图画风提示词框架

固定画风块（每次保持原文，建议同时附上已认可卡图作为视觉参考；仅靠文字无法保证每次完全一致）：

Japanese western medieval fantasy card illustration, delicate anime painterly linework, softly layered watercolor and opaque paint, luminous ivory and cream highlights, subtle paper texture, carefully painted antique metal, natural fabric and feather details, warm diffused lighting, gentle atmospheric depth, expressive readable silhouette, refined storybook finish, coherent anatomy, restrained ornament.

可替换内容块：
Subject: {卡牌主体、外形、服装或材质}.
Action: {一个明确动作}.
Setting: {场景与时间}.
Story cue: {与卡牌效果相关的一个视觉线索}.
Faction palette: {下方职业配色}.
Composition: one clear focal subject, uncluttered background, important features inside central 80%, generous headroom; artwork window target aspect ratio 448:403.
Restrictions: no text, no numbers, no logo, no watermark, no UI, no border; no photorealism, no 3D render, no neon cyberpunk, no excessive baroque ornament.

卡框独立复用，文字由游戏排版，可减少不同卡之间框形和文字的漂移。带框展示时再叠加对应透明PNG。

- 森林精魄：deep forest green enamel, antique gold trim, restrained leaf and branch motifs
- 暗影刺客：deep violet enamel, dark silver trim, restrained dagger and crescent motifs
- 机械之心：amber bronze enamel, brass trim, restrained small gear and geometric motifs
- 吟游诗人：mist blue enamel, luminous silver trim, restrained lyre and flowing musical wind motifs; absolutely no green
- 敌人：deep crimson enamel, aged gunmetal gold trim, restrained thorn and pointed crest motifs
- 其他：ivory pearl enamel, pale antique gold trim, restrained neutral geometric and small star motifs

卡框生成固定提示词：
Generate a single reusable empty square fantasy card illustration frame PNG asset. Same design family as elegant Japanese western medieval fantasy cards: hand-painted polished metal bevels, enamel inlays, rounded rectangular outer silhouette, delicate botanical-style corner filigree adapted to faction. Thin border occupying only outer 6 percent, large fully transparent central artwork opening; blank cream parchment title cartouche centered along upper edge occupying 45 percent width and 10 percent height. No text, no letters, no artwork, no characters, no background, no shadow outside frame. Front view perfectly straight, symmetrical, fully visible with small transparent margin. Refined craftsmanship, readable at small size, restrained ornament, no royal baroque excess. Palette and motifs: {职业配色与纹样}

本轮为设计候选，不自动覆盖游戏现有素材。使用内置 image_gen。

