class_name NoteView
extends ModalPanel
## Mostra um documento. Estilos: paper (padrão), hand, stone, sign, screen,
## pigpen, pigpen_key, image. Campos do doc: title, body, style, image, cipher.

const STYLES := {
	"paper": {"font": UiTheme.FONT_TYPED, "ink": Color("2b2119"), "bg": "paper", "tint": Color(0.93, 0.88, 0.78)},
	"hand": {"font": UiTheme.FONT_HAND, "ink": Color("5a1414"), "bg": "paper", "tint": Color(0.86, 0.84, 0.8), "size": 46},
	"blue": {"font": UiTheme.FONT_UI, "ink": Color("dbe8ff"), "bg": "paper", "tint": Color(0.28, 0.42, 0.62), "size": 40},
	"stone": {"font": UiTheme.FONT_SERIF, "ink": Color("e1e4e8"), "bg": Color("3b4048"), "size": 44},
	"sign": {"font": UiTheme.FONT_UI, "ink": Color("f0e2c8"), "bg": Color("3a2717"), "size": 44},
	"screen": {"font": UiTheme.FONT_UI, "ink": Color("9fe2ff"), "bg": Color("041018"), "size": 42},
	"pigpen": {"font": UiTheme.FONT_TYPED, "ink": Color("2b2119"), "bg": "paper", "tint": Color(0.93, 0.88, 0.78)},
	"pigpen_key": {"font": UiTheme.FONT_TYPED, "ink": Color("2b2119"), "bg": "paper", "tint": Color(0.93, 0.88, 0.78)},
	"image": {"font": UiTheme.FONT_UI, "ink": UiTheme.INK, "bg": Color("05080f")},
}

var doc: Dictionary


func _init(d: Dictionary) -> void:
	doc = d
	panel_size = Vector2(1000, 800)
	dim = 0.8


func _build(c: VBoxContainer) -> void:
	var style_name: String = doc.get("style", "paper")
	var st: Dictionary = STYLES.get(style_name, STYLES["paper"])
	var ink: Color = st["ink"]
	var fsize: int = st.get("size", 36)

	var sheet := PanelContainer.new()
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.set_content_margin_all(56)
	if st["bg"] is Color:
		sb.bg_color = st["bg"]
		sb.border_color = Color(0, 0, 0, 0.5)
		sb.set_border_width_all(4)
		sheet.add_theme_stylebox_override("panel", sb)
	else:
		var tex := StyleBoxTexture.new()
		tex.texture = load("res://assets/legacy/old_paper.png")
		tex.modulate_color = st["tint"]
		tex.set_content_margin_all(64)
		sheet.add_theme_stylebox_override("panel", tex)
	c.add_child(sheet)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	sheet.add_child(col)

	var ttl: String = doc.get("title", "")
	if ttl != "":
		var tl := UiTheme.label(ttl, fsize + 6, ink, st["font"])
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(tl)

	if doc.has("image") and ResourceLoader.exists(doc["image"]):
		var img := TextureRect.new()
		img.texture = load(doc["image"])
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(0, doc.get("image_height", 420))
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		col.add_child(img)

	if doc.has("swatch"):
		var sw := ColorRect.new()
		sw.color = Color(doc["swatch"])
		sw.custom_minimum_size = Vector2(0, 160)
		col.add_child(sw)

	if doc.has("circles"):
		# Círculos pintados: [[cor, raio], ...]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(0, 220)
		var circles: Array = doc["circles"]
		holder.draw.connect(func():
			var n := circles.size()
			for i in n:
				var cx := holder.size.x * (i + 1) / (n + 1)
				holder.draw_circle(Vector2(cx, 110), float(circles[i][1]), Color(circles[i][0])))
		col.add_child(holder)

	if style_name == "pigpen" and doc.has("cipher"):
		var pp := PigpenText.new(doc["cipher"], false, 72.0)
		pp.ink = ink
		col.add_child(pp)
	elif style_name == "pigpen_key":
		var pk := PigpenText.new("", true, 58.0)
		pk.ink = ink
		col.add_child(pk)

	var body: String = doc.get("body", "")
	if body != "":
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rt.add_theme_font_override("normal_font", UiTheme.font(st["font"]))
		rt.add_theme_font_override("bold_font", UiTheme.font(st["font"]))
		rt.add_theme_font_override("italics_font", UiTheme.font(st["font"]))
		rt.add_theme_font_override("bold_italics_font", UiTheme.font(st["font"]))
		rt.add_theme_font_size_override("italics_font_size", fsize)
		rt.add_theme_font_size_override("normal_font_size", fsize)
		rt.add_theme_font_size_override("bold_font_size", fsize)
		rt.add_theme_color_override("default_color", ink)
		rt.text = body
		col.add_child(rt)
