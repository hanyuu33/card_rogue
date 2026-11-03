from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
p=root/'scripts/ui_theme.gd'
s=p.read_text(encoding='utf-8')
s=s.replace('UiAssets.btn_primary() if primary else UiAssets.btn_plain()', 'UiAssets.get_tex("reward_btn_green") if primary else UiAssets.btn_plain()')
pos=s.index('static func draw_panel_bg('); end=s.index('\n\nconst SCROLL_EDGE',pos)
s=s[:pos]+'''static func draw_panel_bg(canvas: CanvasItem, rect: Rect2) -> void:
	var tex: Texture2D = UiAssets.get_tex("reward_card")
	if tex != null:
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.set_texture_margin_all(18.0)
		canvas.draw_style_box(box, rect)
	else:
		canvas.draw_rect(rect, PANEL_PAPER_BG)


const PAGE_PAPER := Color("f3eee2")
const PAGE_INK := Color("514735")
const PAGE_MUTED := Color("887b65")
const PAGE_GOLD := Color("cbb47e")
const PAGE_GREEN := Color("4c9a52")

static func draw_page(canvas: CanvasItem, rect: Rect2) -> void:
	var paper: Texture2D = UiAssets.panel_parchment()
	if paper != null:
		canvas.draw_texture_rect(paper, rect, true)
	else:
		canvas.draw_rect(rect, PAGE_PAPER)
	var panel := rect.grow(-16.0)
	draw_panel_bg(canvas, panel)
	var banner: Texture2D = UiAssets.get_tex("reward_banner_top")
	if banner != null:
		canvas.draw_texture_rect_region(banner, Rect2(rect.position, Vector2(rect.size.x, 18)), Rect2(0, 0, banner.get_width(), 80))
	canvas.draw_line(Vector2(64, 124), Vector2(rect.end.x - 64, 124), PAGE_GOLD, 1.0, true)
''' +s[end:]
p.write_text(s,encoding='utf-8')
# Full paper pages: preserve geometry and inputs, map only their UI palette.
for name in ['settings','story','record_list','ban','deck_edit','relic_pick']:
 p=root/f'scripts/{name}_scene.gd'; s=p.read_text(encoding='utf-8')
 s=re.sub(r'\tvar top := Color\("[0-9a-f]+"\)\n\tvar bottom := Color\("[0-9a-f]+"\)\n\tfor i in 36:.*?top.lerp\(bottom, t\), true\)', '\tUiTheme.draw_page(self, Rect2(Vector2.ZERO, size))', s, count=1, flags=re.S)
 s=re.sub(r'draw_rect\(Rect2\(Vector2.ZERO, size\), UiTheme.SCREEN_BG\)', 'UiTheme.draw_page(self, Rect2(Vector2.ZERO, size))',s)
 for token in ['SAND','INK_300']:
  s=s.replace('UiTheme.'+token,'UiTheme.PAGE_INK')
 s=s.replace('UiTheme.INK_ON_DARK','UiTheme.PAGE_MUTED').replace('UiTheme.PANEL_DARK','UiTheme.PAGE_PAPER')
 dark=['22242c','222630','343947','414860','2b3040','22242c','3d4762','4a5164','1b1d24','2a2e3a','272b36','242834','303443']
 light=['e6e2d8','ece7db','e8e4da','d8dce7','f0c860','ffffff','c8cdd8','e6e9ef','e8ecf4']
 for c in dark:s=s.replace(f'Color("{c}")','UiTheme.PAGE_PAPER')
 for c in light:s=s.replace(f'Color("{c}")','UiTheme.PAGE_INK')
 # Textured filled UI rectangles, leaving borders and state marks intact.
 s=re.sub(r'draw_rect\(([^\n]+), UiTheme.PAGE_PAPER, true\)',r'UiTheme.draw_panel_bg(self, \1)',s)
 p.write_text(s,encoding='utf-8')
