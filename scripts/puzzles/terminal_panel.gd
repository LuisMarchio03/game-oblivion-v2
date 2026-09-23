class_name TerminalPanel
extends PuzzlePanel
## Terminal do laboratório: várias perguntas, cada uma com sua resposta.
## `items` = [{q: "AQUELE QUE TE DOPA", answers: [...]}, ...]

var items: Array = []
var _edits: Array[LineEdit] = []
var _marks: Array[Label] = []


func _init(p_title: String, p_items: Array, p_desc := "", p_hints: Array = []) -> void:
	title = p_title
	items = p_items
	description = p_desc
	hints = p_hints
	panel_size = Vector2(1400, 860)


func _build_puzzle(c: VBoxContainer) -> void:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("03111a")
	sb.border_color = Color("1f6f8f")
	sb.set_border_width_all(3)
	sb.set_content_margin_all(26)
	box.add_theme_stylebox_override("panel", sb)
	c.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	box.add_child(col)
	for i in items.size():
		var q := UiTheme.label("> " + str(items[i]["q"]), 36, Color("9fe2ff"))
		col.add_child(q)
		var row := HBoxContainer.new()
		var e := LineEdit.new()
		e.custom_minimum_size = Vector2(1000, 58)
		e.add_theme_font_size_override("font_size", 36)
		e.placeholder_text = "..."
		e.text_submitted.connect(func(_t): _check(i, true))
		e.focus_exited.connect(func(): _check(i, false))
		row.add_child(e)
		var m := UiTheme.label("", 40, Color("8fe3a8"))
		m.custom_minimum_size = Vector2(60, 0)
		row.add_child(m)
		col.add_child(row)
		_edits.append(e)
		_marks.append(m)
	var ok := UiTheme.button("Enviar", _try_all)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(ok)


func _is_ok(i: int) -> bool:
	return Game.matches(_edits[i].text, items[i]["answers"])


func _check(i: int, advance: bool) -> void:
	if _closed:
		return
	if _is_ok(i):
		if _marks[i].text == "":
			Audio.sfx("bell", -8.0)
		_marks[i].text = "OK"
		_edits[i].editable = false
		if advance:
			for k in range(i + 1, _edits.size()):
				if _edits[k].editable:
					_edits[k].grab_focus()
					break
		if _all_ok():
			_try_all()
	elif advance and _edits[i].text.strip_edges() != "":
		_marks[i].text = ""
		fail("Resposta não reconhecida.")


func _all_ok() -> bool:
	for i in _edits.size():
		if not _is_ok(i):
			return false
	return true


func _try_all() -> void:
	if _all_ok():
		succeed("")
	else:
		fail("Ainda falta algo.")
