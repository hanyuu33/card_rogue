shader_type canvas_item;
render_mode blend_mix;

// R604 片头：让徽记的金线「一段段被画出来」。
//
// 为什么这样做：图标是位图，没法像矢量那样按路径逐笔生长。这里用「显现次序场」
// 解决——每个像素算一个 order（自下而上为主 + 细粒噪声扰动），progress 追上 order
// 时才露出该像素。于是线条不是整张淡入，而是从下往上、一笔接一笔地冒出来。
//
// progress: 0 = 完全看不见，1 = 全部显现。
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 笔尖刚划过那一小段的白光强度，0 = 关掉。
uniform float hot_amount : hint_range(0.0, 1.0) = 0.85;
uniform vec4 hot_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);

// 噪声颗粒密度：越大 = 笔画被切得越碎（越像手绘勾线）。
uniform float grain : hint_range(60.0, 480.0) = 260.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);

	float cell = hash21(floor(UV * grain));
	float order = (1.0 - UV.y) * 0.62 + cell * 0.38;

	// 映射略微超过 1，保证收尾时没有残留笔画
	float p = progress * 1.12;
	float soft = 0.035;

	float shown = smoothstep(order - soft, order + soft, p);
	float hot = shown * (1.0 - smoothstep(order + soft, order + soft * 3.0, p));

	c.a *= shown;
	c.rgb = mix(c.rgb, hot_color.rgb, hot * hot_amount);
	COLOR = c;
}
