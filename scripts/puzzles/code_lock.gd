class_name CodeLock
extends PuzzlePanel
## Fechadura de texto/código. Opcional: teclado na tela (`keypad`), amostra de
## cor (`swatch`) e prefixo exibido (ex.: "#").

var answers: Array = []
var max_len := 24
var keypad := ""  # ex.: "0123456789ABCDEF"; vazio = só teclado físico
var swatch := Color(0, 0, 0, 0)
var prefix := ""
var placeholder := "digite a resposta"
var _edit: LineEdit


func _init(p_title: String, p_answers: Array, p_desc := "", p_hints: Array = []) -> void:
	title = p_title
	answers = p_answers
	description = p_desc
	hints = p_hints
	panel_size = Vector2(1000, 640)


func _build_puzzle(c: VBoxContainer) -> void:
	if swatch.a > 0.0:
		var sw := ColorRect.new()
		sw.color = swatch
		sw.custom_minimum_size = Vector2(0, 150)
		c.add_child(sw)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if prefix != "":
		row.add_child(UiTheme.label(prefix, 48))
	_edit = LineEdit.new()
	_edit.max_length = max_len
	_edit.custom_minimum_size = Vector2(620, 70)
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.placeholder_text = placeholder
	_edit.add_theme_font_size_override("font_size", 48)
	_edit.text_submitted.connect(func(_t): _try())
	_edit.text_changed.connect(func(t):
		var pos := _edit.caret_column
		_edit.text = t.to_upper()
		_edit.caret_column = pos)
	row.add_child(_edit)
	c.add_child(row)
	if keypad != "":
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		var holder := CenterContainer.new()
		holder.add_child(grid)
		for ch in keypad:
			var b := UiTheme.button(ch)
			b.custom_minimum_size = Vector2(70, 60)
			b.pressed.connect(func():
				if _edit.text.length() < max_len:
					_edit.text += ch
				Audio.sfx("wheel_click", -8.0))
			grid.add_child(b)
		var del := UiTheme.button("DEL")
		del.custom_minimum_size = Vector2(70, 60)
		del.pressed.connect(func(): _edit.text = _edit.text.left(-1))
		grid.add_child(del)
		c.add_child(holder)
	var ok := UiTheme.button("Confirmar", _try)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(ok)


func _try() -> void:
	if Game.matches(_edit.text, answers):
		succeed("Destravado.")
	else:
		fail()
		_edit.select_all()
		_edit.grab_focus()
