extends Control
## Final: monitor cardíaco, leito, mensagem e créditos.

var _ecg: Control
var _pts: PackedVector2Array = []
var _x := 0.0
var _beat_t := 0.0
var _running := true


func _ready() -> void:
	Ui.in_level = false
	Ui.set_hud_visible(false)
	Game.reset_input_lock()
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_ecg = Control.new()
	_ecg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ecg.draw.connect(_draw_ecg)
	add_child(_ecg)
	Ui.set_screen_fx(0.5, 0.03)
	Audio.stop_all(1.0)
	_sequence()


func _process(delta: float) -> void:
	if not _running:
		return
	_x += delta * 520.0
	_beat_t += delta
	var w := size.x
	if _x > w:
		_x = 0.0
		_pts.clear()
	var y := size.y * 0.5
	var phase := fmod(_beat_t, 1.0)
	if phase < 0.04:
		y -= 160.0 * sin(phase / 0.04 * PI)
	elif phase < 0.08:
		y += 60.0 * sin((phase - 0.04) / 0.04 * PI)
	if phase < delta:
		Audio.sfx("monitor_beep", -8.0)
	_pts.append(Vector2(_x, y))
	_ecg.queue_redraw()


func _draw_ecg() -> void:
	if _pts.size() > 1:
		_ecg.draw_polyline(_pts, Color(0.35, 1.0, 0.55, 0.9), 4.0)
	var font := UiTheme.ui_font()
	_ecg.draw_string(font, Vector2(80, 110), "LEITO %d" % Game.number_a, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(0.35, 1.0, 0.55, 0.9))


func _sequence() -> void:
	await Ui.fade_in(2.0)
	await get_tree().create_timer(4.0).timeout
	await Ui.narrate([
		"Você abre os olhos.",
		"A luz é branca demais. Tem cheiro de remédio.",
		"A cadeira ao lado da cama está vazia.",
	], UiTheme.INK, 44)
	await Ui.narrate([
		"%s não voltou com você." % Game.name_b,
	], UiTheme.INK_DIM, 44)
	await Ui.narrate([
		"Os assassinos não moravam naquela casa.",
		"Aquele que te dopa. Aquele que te induz.\nAquele que te separa. Aquele que te seduz.",
		"Eles estão aqui fora.",
	], UiTheme.INK, 44)
	Audio.music("music_ending", 3.0, -4.0)
	await Ui.narrate(["[color=#ffffff]AINDA HÁ ESPERANÇA[/color]"], UiTheme.INK, 64)
	_running = false
	var t := create_tween()
	t.tween_property(_ecg, "modulate:a", 0.0, 2.0)
	await t.finished
	await _credits()
	await Ui.fade_out(2.0)
	Game.go_to_menu()


func _credits() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	col.position = Vector2(0, size.y)
	col.size = Vector2(size.x, 10)
	add_child(col)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(0, 220)
	mark.draw.connect(func(): preload("res://scripts/ui/main_menu.gd").draw_logo_mark(mark, Vector2(mark.size.x / 2.0, 110), 80, Color("eef3fa")))
	col.add_child(mark)
	for line in [
		["OBLIVION", 90, UiTheme.FONT_LOGO],
		["Obrigado por jogar!", 54, UiTheme.FONT_SERIF],
		["", 30, UiTheme.FONT_UI],
		["Ideia, roteiro e enigmas originais", 32, UiTheme.FONT_UI],
		["Luis Marchio — Sistemas de Informação, 2023", 40, UiTheme.FONT_UI],
		["", 30, UiTheme.FONT_UI],
		["%s  ·  %s" % [Game.name_a, Game.name_b], 40, UiTheme.FONT_UI],
		["Tempo de jogo: %d min" % int(Game.play_time / 60.0), 30, UiTheme.FONT_UI],
		["", 60, UiTheme.FONT_UI],
		["Esteja no controle da sua vida.", 56, UiTheme.FONT_SERIF],
	]:
		var l := UiTheme.label(line[0], line[1], UiTheme.INK, line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	await get_tree().process_frame
	var t := create_tween()
	t.tween_property(col, "position:y", size.y * 0.5 - col.size.y * 0.5, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	await get_tree().create_timer(6.0).timeout
