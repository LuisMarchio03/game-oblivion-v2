class_name NameEntry
extends ModalPanel
## Tela de "login": nome do jogador e do parceiro.

var _a: LineEdit
var _b: LineEdit


func _init() -> void:
	title = "OBLIVION"
	panel_size = Vector2(900, 620)


func _build(c: VBoxContainer) -> void:
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	var info := UiTheme.label("Vocês são dois. Você controla os dois.", 30, UiTheme.INK_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(info)
	_a = _field(c, "DIGITE SEU NOME", "Ana")
	_b = _field(c, "NOME DO SEU PARCEIRO", "Leo")
	_a.text_submitted.connect(func(_t): _b.grab_focus())
	_b.text_submitted.connect(func(_t): _ok())
	var ok := UiTheme.button("Começar", _ok)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(ok)


func _field(c: VBoxContainer, label: String, placeholder: String) -> LineEdit:
	var l := UiTheme.label(label, 30, UiTheme.INK_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = 14
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(560, 66)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(e)
	return e


func _ok() -> void:
	var a := _a.text.strip_edges()
	var b := _b.text.strip_edges()
	if a == "":
		a = _a.placeholder_text
	if b == "":
		b = _b.placeholder_text
	if a.to_lower() == b.to_lower():
		b += " II"
	close([a, b])
