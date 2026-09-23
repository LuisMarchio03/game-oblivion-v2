extends CanvasLayer
## Camada de interface global: transições, HUD, diálogo, avisos, painéis modais,
## pausa e diário.

signal advance_pressed

const PORTRAITS := {
	"a": "res://assets/sprites/char_a_portrait.png",
	"b": "res://assets/sprites/char_b_portrait.png",
}

var in_level := false
var using_gamepad := false

var _root: Control
var _fx: ColorRect
var _hud: Control
var _portrait: TextureRect
var _hud_name: Label
var _hud_switch: Label
var _hud_objective: Label
var _prompt: Label
var _dialog: PanelContainer
var _dialog_speaker: Label
var _dialog_text: RichTextLabel
var _toasts: VBoxContainer
var _modal_layer: Control
var _fade: ColorRect
var _flash: ColorRect
var _modal_stack: Array[Control] = []
var _dialog_busy := false
var _switch_enabled := true


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/screen_fx.gdshader")
	_fx.material = sm
	_root.add_child(_fx)

	_build_hud()
	_build_prompt()
	_build_dialog()

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-500, 40)
	_toasts.custom_minimum_size = Vector2(1000, 0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)

	_modal_layer = Control.new()
	_modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal_layer)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	set_hud_visible(false)
	Game.objective_changed.connect(_on_objective)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.4):
		if not using_gamepad:
			using_gamepad = true
			_refresh_hud_labels()
	elif event is InputEventKey or event is InputEventMouseButton:
		if using_gamepad:
			using_gamepad = false
			_refresh_hud_labels()


func _unhandled_input(event: InputEvent) -> void:
	if _dialog_busy and (event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		advance_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if not in_level or not _modal_stack.is_empty() or _dialog_busy:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_panel(PauseMenu.new())
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		open_panel(JournalPanel.new())


# --- Rótulos de tecla -------------------------------------------------------------

func key_label(action: String) -> String:
	var kb := {"interact": "E", "switch": "Tab", "journal": "J", "pause": "Esc", "run": "Shift", "cancel": "Esc"}
	var pad := {"interact": "A", "switch": "Y", "journal": "Select", "pause": "Start", "run": "RB", "cancel": "B"}
	return (pad if using_gamepad else kb).get(action, action)


# --- Transições -------------------------------------------------------------------

func fade_out(time := 0.6) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, time)
	await t.finished


func fade_in(time := 0.8) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, time)
	await t.finished


func set_black(on: bool) -> void:
	_fade.color.a = 1.0 if on else 0.0


func flash(color := Color.WHITE, time := 0.6) -> void:
	_flash.color = Color(color.r, color.g, color.b, 1.0)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, time)
	await t.finished


func whiteout(time := 2.0) -> void:
	_flash.color = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 1.0, time)
	await t.finished


func clear_whiteout(time := 2.0) -> void:
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, time)
	await t.finished


## Troca de cena passando pelo preto. A cena nova é responsável pelo fade_in.
func change_scene(path: String) -> void:
	close_all_panels()
	hide_prompt()
	set_hud_visible(false)
	in_level = false
	await fade_out(0.6)
	_flash.color.a = 0.0
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func set_screen_fx(vignette: float, grain := 0.045, tint := Color(0.0, 0.02, 0.06)) -> void:
	var sm: ShaderMaterial = _fx.material
	sm.set_shader_parameter("vignette", vignette)
	sm.set_shader_parameter("grain", grain)
	sm.set_shader_parameter("tint", tint)


# --- Cartões e narração -----------------------------------------------------------

func chapter_card(index: int) -> void:
	var roman := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 := UiTheme.label("CAPÍTULO " + roman[index], 36, UiTheme.INK_DIM, UiTheme.FONT_LOGO)
	var l2 := UiTheme.label(Game.CHAPTERS[index]["title"], 72, UiTheme.INK, UiTheme.FONT_SERIF)
	for l in [l1, l2]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	box.modulate.a = 0.0
	_root.add_child(box)
	_root.move_child(box, _root.get_child_count() - 1)
	set_black(true)
	var t := create_tween()
	t.tween_property(box, "modulate:a", 1.0, 1.2)
	t.tween_interval(1.8)
	t.tween_property(box, "modulate:a", 0.0, 1.0)
	await t.finished
	box.queue_free()


## Texto grande centralizado sobre o preto, com efeito de digitação.
## Cada item de `lines` é mostrado sozinho; o jogador pode acelerar com Interagir.
func narrate(lines: Array, color := UiTheme.INK, size := 44) -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.custom_minimum_size = Vector2(1300, 0)
	lbl.add_theme_font_override("normal_font", UiTheme.ui_font())
	lbl.add_theme_font_size_override("normal_font_size", size)
	lbl.add_theme_color_override("default_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	_root.add_child(holder)
	_root.move_child(holder, _root.get_child_count() - 1)
	_dialog_busy = true
	for line in lines:
		lbl.text = "[center]" + str(line) + "[/center]"
		lbl.visible_characters = 0
		lbl.modulate.a = 1.0
		await _type(lbl, 0.045)
		await _wait_advance(2.6)
		var t := create_tween()
		t.tween_property(lbl, "modulate:a", 0.0, 0.5)
		await t.finished
	_dialog_busy = false
	holder.queue_free()


# --- Diálogo ----------------------------------------------------------------------

## Mostra falas na caixa inferior. Prefixos "a:" e "b:" definem quem fala;
## sem prefixo é narração.
func say(lines: Array) -> void:
	Game.lock_input()
	hide_prompt()
	_dialog_busy = true
	_dialog.visible = true
	for raw in lines:
		var line := str(raw)
		var speaker := ""
		if line.begins_with("a:") or line.begins_with("b:"):
			speaker = Game.char_name(line.substr(0, 1))
			line = line.substr(2).strip_edges()
		elif line.begins_with("?:"):
			speaker = "???"
			line = line.substr(2).strip_edges()
		_dialog_speaker.text = speaker
		_dialog_speaker.visible = speaker != ""
		_dialog_text.text = line
		_dialog_text.visible_characters = 0
		await _type(_dialog_text, 0.028)
		await _wait_advance(-1.0)
	_dialog.visible = false
	_dialog_busy = false
	Game.unlock_input()


func _type(lbl: RichTextLabel, per_char: float) -> void:
	var total := lbl.get_total_character_count()
	var speed: float = max(0.25, float(Game.settings["text_speed"]))
	var skipped := [false]
	var on_skip := func(): skipped[0] = true
	advance_pressed.connect(on_skip)
	var i := 0
	while i < total and not skipped[0]:
		i += 1
		lbl.visible_characters = i
		if i % 2 == 0:
			Audio.sfx("type_blip", -18.0, randf_range(0.9, 1.1))
		await get_tree().create_timer(per_char / speed, true, false, true).timeout
	lbl.visible_characters = -1
	advance_pressed.disconnect(on_skip)


func _wait_advance(auto_seconds: float) -> void:
	# Espera o jogador apertar Interagir (ou o tempo acabar, se auto_seconds > 0).
	var done := [false]
	var cb := func(): done[0] = true
	advance_pressed.connect(cb)
	var elapsed := 0.0
	while not done[0]:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if auto_seconds > 0.0 and elapsed >= auto_seconds:
			break
	advance_pressed.disconnect(cb)


func is_dialog_busy() -> bool:
	return _dialog_busy


# --- Avisos -----------------------------------------------------------------------

func toast(text: String, color := UiTheme.INK) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.1, 0.85)
	sb.border_color = UiTheme.PANEL_EDGE
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var l := UiTheme.label(text, 30, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.3)
	t.tween_interval(3.2)
	t.tween_property(p, "modulate:a", 0.0, 0.6)
	t.tween_callback(p.queue_free)


func show_prompt(text: String) -> void:
	_prompt.text = "[%s]  %s" % [key_label("interact"), text]
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


# --- HUD --------------------------------------------------------------------------

func set_hud_visible(on: bool) -> void:
	_hud.visible = on


func set_switch_enabled(on: bool) -> void:
	_switch_enabled = on
	_refresh_hud_labels()


var _hud_who := "a"


func set_active_character(who: String) -> void:
	_hud_who = who
	if ResourceLoader.exists(PORTRAITS[who]):
		_portrait.texture = load(PORTRAITS[who])
	_refresh_hud_labels()
	var t := create_tween()
	_portrait.scale = Vector2(0.85, 0.85)
	t.tween_property(_portrait, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _refresh_hud_labels() -> void:
	if _hud_name == null:
		return
	_hud_name.text = Game.char_name(_hud_who)
	var other := "b" if _hud_who == "a" else "a"
	if _switch_enabled:
		_hud_switch.text = "[%s] trocar para %s     [%s] diário" % [key_label("switch"), Game.char_name(other), key_label("journal")]
	else:
		_hud_switch.text = "[%s] diário" % key_label("journal")


func _on_objective(text: String) -> void:
	_hud_objective.text = text
	if text != "":
		var t := create_tween()
		_hud_objective.modulate = Color(1.6, 1.6, 1.6)
		t.tween_property(_hud_objective, "modulate", Color.WHITE, 1.2)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)

	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.7)
	sb.border_color = UiTheme.PANEL_EDGE
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = Vector2(28, 24)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.pivot_offset = Vector2(48, 48)
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_hud_name = UiTheme.label("", 44)
	col.add_child(_hud_name)
	_hud_switch = UiTheme.label("", 26, UiTheme.INK_DIM)
	col.add_child(_hud_switch)

	_hud_objective = UiTheme.label("", 30, Color("b8c7da"))
	_hud_objective.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_objective.position = Vector2(-940, 34)
	_hud_objective.size = Vector2(900, 60)
	_hud_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_hud_objective)


func _build_prompt() -> void:
	_prompt = UiTheme.label("", 36, Color.WHITE)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-600, -150)
	_prompt.size = Vector2(1200, 50)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("shadow_offset_x", 3)
	_prompt.add_theme_constant_override("shadow_offset_y", 3)
	_prompt.visible = false
	_root.add_child(_prompt)


func _build_dialog() -> void:
	_dialog = PanelContainer.new()
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.position = Vector2(-760, -300)
	_dialog.custom_minimum_size = Vector2(1520, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.03, 0.06, 0.92)
	sb.border_color = UiTheme.PANEL_EDGE
	sb.set_border_width_all(3)
	sb.set_content_margin_all(26)
	_dialog.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	_dialog.add_child(col)
	_dialog_speaker = UiTheme.label("", 34, UiTheme.ACCENT)
	col.add_child(_dialog_speaker)
	_dialog_text = RichTextLabel.new()
	_dialog_text.bbcode_enabled = true
	_dialog_text.fit_content = true
	_dialog_text.scroll_active = false
	_dialog_text.custom_minimum_size = Vector2(1460, 120)
	_dialog_text.add_theme_font_size_override("normal_font_size", 40)
	_dialog_text.add_theme_font_override("normal_font", UiTheme.ui_font())
	col.add_child(_dialog_text)
	_dialog.visible = false
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dialog)


# --- Painéis modais ----------------------------------------------------------------

## Abre um painel modal (Control com sinal `closed(result)`), pausa o jogo e
## devolve o resultado quando ele fecha.
func open_panel(panel: Control) -> Variant:
	hide_prompt()
	get_tree().paused = true
	_modal_stack.append(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(panel)
	var result = await panel.closed
	_modal_stack.erase(panel)
	if is_instance_valid(panel):
		panel.queue_free()
	if _modal_stack.is_empty():
		get_tree().paused = false
	return result


func has_open_panel() -> bool:
	return not _modal_stack.is_empty()


func close_all_panels() -> void:
	for p in _modal_stack.duplicate():
		if is_instance_valid(p) and p.has_method("close"):
			p.close(null)


## Mostra um documento e o guarda no diário de `who`.
func read_doc(who: String, doc: Dictionary) -> void:
	var is_new := Game.add_doc(who, doc)
	Audio.sfx("paper", -4.0)
	await open_panel(NoteView.new(doc))
	if is_new:
		toast("Guardado no diário de %s" % Game.char_name(who))


func jumpscare(texture_path := "res://assets/legacy/face_hand.png", time := 0.55) -> void:
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture = load(texture_path)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tr)
	_root.move_child(tr, _root.get_child_count() - 2)
	Audio.sfx("jumpscare", 0.0)
	var t := create_tween()
	tr.scale = Vector2(1.0, 1.0)
	tr.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	t.tween_property(tr, "scale", Vector2(1.12, 1.12), time)
	t.parallel().tween_property(tr, "modulate:a", 0.0, time * 0.5).set_delay(time * 0.5)
	await t.finished
	tr.queue_free()
