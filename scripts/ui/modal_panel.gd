class_name ModalPanel
extends Control
## Base de todo painel modal: fundo escurecido, caixa central, botões de rodapé,
## fechamento por Esc/B. Subclasses montam o conteúdo em `_build(content)`.

signal closed(result: Variant)

var title := ""
var panel_size := Vector2(1100, 760)
var dim := 0.72
var closable := true

var _box: PanelContainer
var _content: VBoxContainer
var _footer: HBoxContainer
var _closed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(0, 0.01, 0.03, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = PanelContainer.new()
	_box.custom_minimum_size = panel_size
	center.add_child(_box)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	_box.add_child(outer)
	if title != "":
		var t := UiTheme.label(title, 46, UiTheme.INK, UiTheme.FONT_UI)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		outer.add_child(t)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	outer.add_child(_content)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 20)
	outer.add_child(_footer)
	_build(_content)
	if closable:
		add_footer_button("Fechar", func(): close(null))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	await get_tree().process_frame
	_focus_first()


func _build(_c: VBoxContainer) -> void:
	pass


func _focus_first() -> void:
	var f := _find_focusable(self)
	if f:
		f.grab_focus()


func _find_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and c.visible:
			if (c is LineEdit or c is Button or c is TextEdit or c is ItemList or c is Slider) and c.focus_mode != Control.FOCUS_NONE and not (c is Button and c.disabled):
				return c
			var r := _find_focusable(c)
			if r:
				return r
	return null


func add_footer_button(text: String, cb: Callable) -> Button:
	var b := UiTheme.button(text, cb)
	_footer.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if closable and (event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)):
		get_viewport().set_input_as_handled()
		Audio.sfx("ui_back", -6.0)
		close(null)


func close(result: Variant = null) -> void:
	if _closed:
		return
	_closed = true
	closed.emit(result)


## Balança a caixa (resposta errada).
func shake() -> void:
	var p := _box.position
	var t := create_tween()
	for i in 6:
		t.tween_property(_box, "position:x", p.x + (12 if i % 2 == 0 else -12), 0.04)
	t.tween_property(_box, "position:x", p.x, 0.04)
