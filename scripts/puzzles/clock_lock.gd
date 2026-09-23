class_name ClockLock
extends PuzzlePanel
## Console do relógio: acerta hora (1–12) e minutos (de 5 em 5).

var target_h := 4
var target_m := 15
var _h := 12
var _m := 0
var _face: Control
var _readout: Label


func _init(p_title: String, h: int, m: int, p_desc := "", p_hints: Array = []) -> void:
	title = p_title
	target_h = h
	target_m = m
	description = p_desc
	hints = p_hints
	panel_size = Vector2(1000, 820)


func _build_puzzle(c: VBoxContainer) -> void:
	_face = Control.new()
	_face.custom_minimum_size = Vector2(0, 380)
	_face.draw.connect(_draw_face)
	c.add_child(_face)
	_readout = UiTheme.label("", 48)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_readout)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiTheme.button("Hora −", func(): _set_time(_h - 1, _m)))
	row.add_child(UiTheme.button("Hora +", func(): _set_time(_h + 1, _m)))
	row.add_child(UiTheme.button("Min −", func(): _set_time(_h, _m - 5)))
	row.add_child(UiTheme.button("Min +", func(): _set_time(_h, _m + 5)))
	c.add_child(row)
	var ok := UiTheme.button("Acertar o relógio", _try)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(ok)
	_set_time(12, 0)


func _set_time(h: int, m: int) -> void:
	if m < 0:
		m += 60
		h -= 1
	elif m >= 60:
		m -= 60
		h += 1
	_h = posmod(h - 1, 12) + 1
	_m = m
	_readout.text = "%d:%02d" % [_h, _m]
	Audio.sfx("clock_tick", -6.0)
	_face.queue_redraw()


func _draw_face() -> void:
	var ctr := _face.size / 2.0
	var r: float = min(_face.size.x, _face.size.y) * 0.46
	_face.draw_circle(ctr, r + 10, Color("2b2118"))
	_face.draw_circle(ctr, r, Color("d9ccb0"))
	var font := UiTheme.font(UiTheme.FONT_SERIF)
	var roman := ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
	for i in 12:
		var a := TAU * i / 12.0 - PI / 2.0
		var p := ctr + Vector2(cos(a), sin(a)) * r * 0.8
		_face.draw_string(font, p + Vector2(-18, 10), roman[i], HORIZONTAL_ALIGNMENT_CENTER, 36, 26, Color("2b2118"))
		_face.draw_line(ctr + Vector2(cos(a), sin(a)) * r * 0.93, ctr + Vector2(cos(a), sin(a)) * r, Color("2b2118"), 4)
	var ha := TAU * ((_h % 12) + _m / 60.0) / 12.0 - PI / 2.0
	var ma := TAU * _m / 60.0 - PI / 2.0
	_face.draw_line(ctr, ctr + Vector2(cos(ha), sin(ha)) * r * 0.5, Color("140e0a"), 10)
	_face.draw_line(ctr, ctr + Vector2(cos(ma), sin(ma)) * r * 0.78, Color("140e0a"), 6)
	_face.draw_circle(ctr, 10, Color("140e0a"))


func _try() -> void:
	if _h == target_h and _m == target_m:
		Audio.sfx("clock_chime", -2.0)
		succeed("O relógio bate. Algo range sob o altar.")
	else:
		fail("Os ponteiros voltam a tremer. Não é esta a hora.")
