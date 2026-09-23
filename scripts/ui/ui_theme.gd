class_name UiTheme
## Tema visual compartilhado por menus, painéis e enigmas.

const FONT_UI := "res://assets/fonts/VT323-Regular.ttf"
const FONT_TYPED := "res://assets/fonts/SpecialElite-Regular.ttf"
const FONT_HAND := "res://assets/fonts/Caveat.ttf"
const FONT_LOGO := "res://assets/fonts/Michroma-Regular.ttf"
const FONT_SERIF := "res://assets/fonts/IMFeENrm28P.ttf"

const INK := Color("dce6f2")
const INK_DIM := Color("8193ab")
const ACCENT := Color("4f8fe0")
const BLOOD := Color("a3202a")
const BG := Color(0.02, 0.04, 0.08, 0.92)
const PANEL := Color("0a1424")
const PANEL_EDGE := Color("2c4a72")

static var _theme: Theme
static var _fonts := {}


static func font(path: String) -> Font:
	if not _fonts.has(path):
		var f: FontFile = load(path)
		_fonts[path] = f
	return _fonts[path]


static func ui_font() -> Font:
	return font(FONT_UI)


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 34

	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK_DIM)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.4, 0.5))
	t.set_font_size("font_size", "Button", 38)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.06, 0.1, 0.18, 0.6)
	btn.border_color = Color(0.17, 0.29, 0.45, 0.8)
	btn.set_border_width_all(2)
	btn.set_content_margin_all(10)
	btn.content_margin_left = 22
	btn.content_margin_right = 22
	var hov := btn.duplicate()
	hov.bg_color = Color(0.1, 0.18, 0.32, 0.85)
	hov.border_color = ACCENT
	var foc := hov.duplicate()
	foc.border_color = Color.WHITE
	var prs := hov.duplicate()
	prs.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("focus", "Button", foc)
	t.set_stylebox("pressed", "Button", prs)
	t.set_stylebox("disabled", "Button", btn)

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = PANEL_EDGE
	panel.set_border_width_all(3)
	panel.set_content_margin_all(24)
	panel.shadow_color = Color(0, 0, 0, 0.6)
	panel.shadow_size = 16
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.02, 0.05, 0.1, 0.95)
	le.border_color = PANEL_EDGE
	le.set_border_width_all(2)
	le.set_content_margin_all(12)
	var le_f := le.duplicate()
	le_f.border_color = ACCENT
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_f)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_font_size("font_size", "LineEdit", 40)
	t.set_stylebox("normal", "TextEdit", le)
	t.set_stylebox("focus", "TextEdit", le_f)
	t.set_color("font_color", "TextEdit", INK)
	t.set_font_size("font_size", "TextEdit", 32)

	t.set_font_size("normal_font_size", "RichTextLabel", 32)
	t.set_color("default_color", "RichTextLabel", INK)

	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.set_content_margin_all(6)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.1, 0.16, 0.26)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)

	var tab_sel := btn.duplicate()
	tab_sel.bg_color = Color(0.1, 0.18, 0.32, 0.95)
	tab_sel.border_color = ACCENT
	t.set_stylebox("tab_selected", "TabBar", tab_sel)
	t.set_stylebox("tab_unselected", "TabBar", btn)
	t.set_stylebox("tab_hovered", "TabBar", hov)
	t.set_stylebox("tab_focus", "TabBar", foc)
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_font_size("font_size", "TabBar", 32)
	t.set_font_size("font_size", "TabContainer", 32)
	t.set_color("font_selected_color", "TabBar", Color.WHITE)
	t.set_color("font_unselected_color", "TabBar", INK_DIM)

	var empty := StyleBoxEmpty.new()
	t.set_stylebox("panel", "ItemList", le)
	t.set_font_size("font_size", "ItemList", 32)
	t.set_color("font_color", "ItemList", INK_DIM)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_stylebox("selected", "ItemList", tab_sel)
	t.set_stylebox("selected_focus", "ItemList", tab_sel)
	t.set_stylebox("focus", "ItemList", empty)
	t.set_stylebox("cursor", "ItemList", empty)
	t.set_stylebox("cursor_unfocused", "ItemList", empty)

	_theme = t
	return t


static func label(text: String, size := 34, color := INK, font_path := FONT_UI) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): Audio.sfx("ui_hover", -14.0))
	b.focus_entered.connect(func(): Audio.sfx("ui_hover", -14.0))
	b.pressed.connect(func(): Audio.sfx("ui_click", -6.0))
	if callback.is_valid():
		b.pressed.connect(callback)
	return b
