extends Control
## Reusable round portrait, with circular clipping and a restrained brass rim.
const UiTheme = preload("res://scripts/ui_theme.gd")
var _portrait: TextureRect
var texture: Texture2D:
	set(value):
		texture = value
		if _portrait != null:
			_portrait.texture = value

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = TextureRect.new()
	_portrait.position = Vector2(5, 5)
	_portrait.size = size - Vector2(10, 10)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture = texture
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); float d = length(UV - vec2(0.5)); c.a *= 1.0 - smoothstep(0.48, 0.50, d); COLOR = c; }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_portrait.material = mat
	add_child(_portrait)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_circle(center, radius, UiTheme.ADVENTURE_FOREST)
	draw_circle(center, radius - 2, UiTheme.ADVENTURE_BRASS)
	draw_circle(center, radius - 4, UiTheme.ADVENTURE_INPUT)
	draw_arc(center, radius - 1, PI * 1.10, PI * 1.80, 32, UiTheme.ADVENTURE_BRASS_LIT, 1.0, true)
