class_name ChoicePanel
extends ModalPanel
## Escolha sem volta: uma pergunta e botões. Fecha com o índice escolhido.

var question := ""
var options: Array = []


func _init(p_question: String, p_options: Array) -> void:
	question = p_question
	options = p_options
	closable = false
	dim = 0.85
	panel_size = Vector2(1100, 460)


func _build(c: VBoxContainer) -> void:
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	var q := UiTheme.label(question, 48, UiTheme.INK, UiTheme.FONT_SERIF)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(q)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	c.add_child(row)
	for i in options.size():
		var b := UiTheme.button(str(options[i]), close.bind(i))
		b.custom_minimum_size = Vector2(320, 80)
		row.add_child(b)
