class_name WheelLock
extends PuzzlePanel
## Cadeado de rodas. Setas ←/→ escolhem a roda, ↑/↓ giram; também dá para clicar.

var answer := ""
var charset := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
var count := 4
var _values: Array[int] = []
var _labels: Array[Label] = []
var _frames: Array[PanelContainer] = []
var _sel := 0


func _init(p_title: String, p_answer: String, p_charset := "ABCDEFGHIJKLMNOPQRSTUVWXYZ", p_desc := "", p_hints: Array = []) -> void:
	title = p_title
	answer = Game.normalize(p_answer)
	charset = p_charset
	count = answer.length()
	description = p_desc
	hints = p_hints
	panel_size = Vector2(1100, 640)


func _build_puzzle(c: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i in count:
		_values.append(0)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var up := UiTheme.button("+")
		up.focus_mode = Control.FOCUS_NONE
		up.pressed.connect(_turn.bind(i, -1))
		col.add_child(up)
		var fr := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1b140f")
		sb.border_color = Color("6b5238")
		sb.set_border_width_all(3)
		sb.set_content_margin_all(8)
		fr.add_theme_stylebox_override("panel", sb)
		fr.custom_minimum_size = Vector2(96, 120)
		var l := UiTheme.label(charset[0], 84, Color("f1dfbf"), UiTheme.FONT_UI)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fr.add_child(l)
		fr.mouse_filter = Control.MOUSE_FILTER_STOP
		fr.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				_select(i)
				if e.button_index == MOUSE_BUTTON_WHEEL_UP:
					_turn(i, -1)
				elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_turn(i, 1))
		col.add_child(fr)
		var dn := UiTheme.button("-")
		dn.focus_mode = Control.FOCUS_NONE
		dn.pressed.connect(_turn.bind(i, 1))
		col.add_child(dn)
		row.add_child(col)
		_labels.append(l)
		_frames.append(fr)
	c.add_child(row)
	var ok := UiTheme.button("Abrir", _try)
	ok.focus_mode = Control.FOCUS_NONE
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(ok)
	c.add_child(UiTheme.label("Setas: esquerda/direita escolhem a roda · cima/baixo giram · Enter abre", 24, UiTheme.INK_DIM))
	_select(0)


func _focus_first() -> void:
	pass


func _select(i: int) -> void:
	_sel = clampi(i, 0, count - 1)
	for k in count:
		var sb: StyleBoxFlat = _frames[k].get_theme_stylebox("panel")
		sb.border_color = UiTheme.ACCENT if k == _sel else Color("6b5238")


func _turn(i: int, d: int) -> void:
	_select(i)
	_values[i] = posmod(_values[i] + d, charset.length())
	_labels[i].text = charset[_values[i]]
	Audio.sfx("wheel_click", -6.0, randf_range(0.95, 1.05))


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if _closed:
		return
	if event.is_action_pressed("move_left"):
		_select(_sel - 1)
	elif event.is_action_pressed("move_right"):
		_select(_sel + 1)
	elif event.is_action_pressed("move_up"):
		_turn(_sel, -1)
	elif event.is_action_pressed("move_down"):
		_turn(_sel, 1)
	elif event.is_action_pressed("interact"):
		_try()
	elif event is InputEventKey and event.pressed and not event.echo:
		var ch := char(event.unicode).to_upper() if event.unicode > 0 else ""
		var idx := charset.find(ch) if ch != "" else -1
		if idx >= 0:
			_values[_sel] = idx
			_labels[_sel].text = charset[idx]
			Audio.sfx("wheel_click", -6.0)
			_select(_sel + 1)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _try() -> void:
	var s := ""
	for v in _values:
		s += charset[v]
	if s == answer:
		succeed("Clique. As rodas travam na posição.")
	else:
		fail("O cadeado não cede.")
