class_name PianoPanel
extends PuzzlePanel
## Piano de uma oitava (C a B). Teclado: A S D F G H J = C D E F G A B.
## Resolve quando as últimas notas tocadas formam `sequence`.

const WHITE := ["C", "D", "E", "F", "G", "A", "B"]
const KEYMAP := {KEY_A: "C", KEY_S: "D", KEY_D: "E", KEY_F: "F", KEY_G: "G", KEY_H: "A", KEY_J: "B"}

var sequence: Array = []
var _played: Array = []
var _keys := {}
var _trail: Label


func _init(p_title: String, p_sequence: Array, p_desc := "", p_hints: Array = []) -> void:
	title = p_title
	sequence = p_sequence
	description = p_desc
	hints = p_hints
	panel_size = Vector2(1200, 760)


func _build_puzzle(c: VBoxContainer) -> void:
	var holder := CenterContainer.new()
	var kb := Control.new()
	kb.custom_minimum_size = Vector2(7 * 120, 360)
	holder.add_child(kb)
	c.add_child(holder)
	for i in 7:
		var n: String = WHITE[i]
		var k := Button.new()
		k.focus_mode = Control.FOCUS_NONE
		k.position = Vector2(i * 120, 0)
		k.size = Vector2(116, 360)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("dcd6c8")
		sb.border_color = Color("1a1410")
		sb.set_border_width_all(3)
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		var sbp := sb.duplicate()
		sbp.bg_color = Color("a8b9d6")
		k.add_theme_stylebox_override("normal", sb)
		k.add_theme_stylebox_override("hover", sb)
		k.add_theme_stylebox_override("pressed", sbp)
		k.text = "\n\n\n\n\n" + n
		k.add_theme_color_override("font_color", Color("5a1414"))
		k.add_theme_color_override("font_hover_color", Color("5a1414"))
		k.add_theme_font_size_override("font_size", 44)
		k.button_down.connect(_play.bind(n))
		kb.add_child(k)
		_keys[n] = k
	# Teclas pretas decorativas (não fazem parte do enigma).
	for i in [0, 1, 3, 4, 5]:
		var bk := ColorRect.new()
		bk.color = Color("0d0b0a")
		bk.position = Vector2(i * 120 + 84, 0)
		bk.size = Vector2(72, 210)
		bk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kb.add_child(bk)
	_trail = UiTheme.label("", 44, Color("c9d6ea"))
	_trail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_trail)
	c.add_child(UiTheme.label("Teclado: A S D F G H J  =  C D E F G A B", 24, UiTheme.INK_DIM))


func _play(n: String) -> void:
	Audio.sfx("piano_" + n.to_lower(), -2.0)
	_played.append(n)
	if _played.size() > 8:
		_played.pop_front()
	_trail.text = "  ".join(_played)
	var k: Button = _keys[n]
	var t := create_tween()
	k.modulate = Color(0.7, 0.8, 1.0)
	t.tween_property(k, "modulate", Color.WHITE, 0.3)
	if _played.size() >= sequence.size() and _played.slice(_played.size() - sequence.size()) == sequence:
		await get_tree().create_timer(0.5, true, false, true).timeout
		Audio.sfx("music_box", -6.0)
		succeed("Um estalo dentro do piano.")


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo and KEYMAP.has(event.physical_keycode):
		_play(KEYMAP[event.physical_keycode])
		get_viewport().set_input_as_handled()
