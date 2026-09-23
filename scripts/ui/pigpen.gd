class_name PigpenText
extends Control
## Desenha texto na cifra pigpen (maçônica). Com `key_mode = true` desenha a
## chave: as duas grades e os dois X com as letras.

var text := ""
var key_mode := false
var glyph := 64.0
var ink := Color("2a1d17")
var line_w := 5.0


func _init(t := "", as_key := false, size_px := 64.0) -> void:
	text = t
	key_mode = as_key
	glyph = size_px
	custom_minimum_size = Vector2(0, glyph * (5.2 if as_key else 1.3))


func _draw() -> void:
	if key_mode:
		_draw_key()
	else:
		_draw_text()


func _draw_text() -> void:
	var x := 0.0
	var gap := glyph * 0.35
	var letters := Game.normalize(text) if text.find(" ") == -1 else text.to_upper()
	var total := 0.0
	for c in letters:
		total += (gap * 1.5) if c == " " else (glyph + gap)
	x = (size.x - total) * 0.5
	for c in letters:
		if c == " ":
			x += gap * 1.5
			continue
		_draw_glyph(c, Rect2(x, glyph * 0.15, glyph, glyph))
		x += glyph + gap


## Desenha a letra `c` dentro do quadrado `r`.
func _draw_glyph(c: String, r: Rect2) -> void:
	var code := c.unicode_at(0) - "A".unicode_at(0)
	if code < 0 or code > 25:
		return
	var tl := r.position
	var tr := r.position + Vector2(r.size.x, 0)
	var bl := r.position + Vector2(0, r.size.y)
	var br := r.end
	var mid := r.get_center()
	var dot := false
	if code < 18:
		dot = code >= 9
		var idx := code % 9
		var row := idx / 3
		var col := idx % 3
		if col < 2:
			draw_line(tr, br, ink, line_w)
		if col > 0:
			draw_line(tl, bl, ink, line_w)
		if row < 2:
			draw_line(bl, br, ink, line_w)
		if row > 0:
			draw_line(tl, tr, ink, line_w)
	else:
		var k := code - 18  # S T U V | W X Y Z
		dot = k >= 4
		var wedge := k % 4  # 0 topo, 1 direita, 2 baixo, 3 esquerda
		var top_mid := Vector2(mid.x, tl.y)
		var bot_mid := Vector2(mid.x, bl.y)
		var left_mid := Vector2(tl.x, mid.y)
		var right_mid := Vector2(tr.x, mid.y)
		match wedge:
			0:
				draw_line(tl, bot_mid, ink, line_w)
				draw_line(tr, bot_mid, ink, line_w)
			1:
				draw_line(tr, left_mid, ink, line_w)
				draw_line(br, left_mid, ink, line_w)
			2:
				draw_line(bl, top_mid, ink, line_w)
				draw_line(br, top_mid, ink, line_w)
			3:
				draw_line(tl, right_mid, ink, line_w)
				draw_line(bl, right_mid, ink, line_w)
		if dot:
			var off := Vector2.ZERO
			match wedge:
				0: off = Vector2(0, -r.size.y * 0.22)
				1: off = Vector2(r.size.x * 0.22, 0)
				2: off = Vector2(0, r.size.y * 0.22)
				3: off = Vector2(-r.size.x * 0.22, 0)
			draw_circle(mid + off, line_w * 1.1, ink)
		return
	if dot:
		draw_circle(mid, line_w * 1.1, ink)


func _draw_key() -> void:
	var font := UiTheme.font(UiTheme.FONT_TYPED)
	var cell := glyph
	var fig := cell * 3.0
	var gap := cell * 1.0
	var total := fig * 4 + gap * 3
	var ox := (size.x - total) * 0.5
	var oy := cell * 0.6
	# Duas grades 3x3 (A–I sem ponto, J–R com ponto).
	for g in 2:
		var o := Vector2(ox + g * (fig + gap), oy)
		draw_line(o + Vector2(cell, 0), o + Vector2(cell, fig), ink, line_w)
		draw_line(o + Vector2(cell * 2, 0), o + Vector2(cell * 2, fig), ink, line_w)
		draw_line(o + Vector2(0, cell), o + Vector2(fig, cell), ink, line_w)
		draw_line(o + Vector2(0, cell * 2), o + Vector2(fig, cell * 2), ink, line_w)
		for i in 9:
			var ch := char("A".unicode_at(0) + g * 9 + i)
			var p := o + Vector2((i % 3) * cell, (i / 3) * cell)
			draw_string(font, p + Vector2(cell * 0.3, cell * 0.62), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell * 0.42), ink)
			if g == 1:
				draw_circle(p + Vector2(cell * 0.72, cell * 0.72), line_w * 0.9, ink)
	# Dois X (S–V sem ponto, W–Z com ponto).
	for g in 2:
		var o := Vector2(ox + (2 + g) * (fig + gap), oy)
		draw_line(o, o + Vector2(fig, fig), ink, line_w)
		draw_line(o + Vector2(fig, 0), o + Vector2(0, fig), ink, line_w)
		var c := o + Vector2(fig, fig) * 0.5
		var spots := [Vector2(0, -fig * 0.33), Vector2(fig * 0.33, 0), Vector2(0, fig * 0.33), Vector2(-fig * 0.33, 0)]
		for i in 4:
			var ch := char("S".unicode_at(0) + g * 4 + i)
			var p: Vector2 = c + spots[i]
			draw_string(font, p + Vector2(-cell * 0.14, cell * 0.16), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell * 0.42), ink)
			if g == 1:
				draw_circle(c + spots[i] * 0.45, line_w * 0.9, ink)
	# Exemplo de leitura.
	var ex_y := oy + fig + cell * 0.9
	draw_string(font, Vector2(ox, ex_y), "Cada letra é o desenho da casa onde ela mora.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell * 0.4), ink)
