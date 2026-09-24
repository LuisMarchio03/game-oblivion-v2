class_name PuzzlePanel
extends ModalPanel
## Base dos painéis de enigma: descrição, dicas progressivas e retorno
## true (resolvido) ou null (fechado sem resolver).

var description := ""
var hints: Array = []
var _hint_i := 0
var _solved := false
var _hint_label: Label
var _msg: Label


func _build(c: VBoxContainer) -> void:
	if description != "":
		var d := RichTextLabel.new()
		d.bbcode_enabled = true
		d.fit_content = true
		d.scroll_active = false
		d.add_theme_font_size_override("normal_font_size", 32)
		d.add_theme_color_override("default_color", UiTheme.INK_DIM)
		d.text = "[center]" + description + "[/center]"
		c.add_child(d)
	_build_puzzle(c)
	_msg = UiTheme.label("", 32, UiTheme.BLOOD)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_msg)
	_hint_label = UiTheme.label("", 28, Color("9fc3ee"))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_hint_label)
	if not hints.is_empty():
		add_footer_button("Dica", _show_hint)


func _build_puzzle(_c: VBoxContainer) -> void:
	pass


func _show_hint() -> void:
	if hints.is_empty():
		return
	_hint_i = min(_hint_i + 1, hints.size())
	var lines := []
	for i in _hint_i:
		lines.append(hints[i])
	_hint_label.text = "\n".join(lines)


func fail(text := "Nada acontece.") -> void:
	if _solved:
		return
	Audio.sfx("error", -4.0)
	_msg.add_theme_color_override("font_color", UiTheme.BLOOD)
	_msg.text = text
	shake()
	Game.puzzle_failed.emit()


func succeed(text := "") -> void:
	if _solved:
		return
	_solved = true
	Audio.sfx("success", -2.0)
	_msg.add_theme_color_override("font_color", Color("8fe3a8"))
	_msg.text = text
	set_process_unhandled_input(false)
	await get_tree().create_timer(0.7, true, false, true).timeout
	close(true)
