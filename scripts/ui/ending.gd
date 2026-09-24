extends Control
## Finais. `Game.ending` decide:
##   forget   — A escolheu esquecer: o monitor desacelera até a linha reta.
##   remember — A lembrou, sem todas as lembranças: acorda; o leito de B está vazio.
##   hope     — A lembrou com as 8 lembranças: acorda; B respira, o monitor de B responde.
## Depois, créditos.

const TITLES := {
	"forget": "FINAL: ESQUECIMENTO",
	"remember": "FINAL: LEMBRANÇA",
	"hope": "FINAL: AINDA HÁ ESPERANÇA",
}

var _ecg: Control
var _pts: PackedVector2Array = []
var _x := 0.0
var _beat_t := 0.0
var _running := true
var _period := 1.0  # segundos por batida
var _flat := false
var _label := ""
var _label_color := Color(0.35, 1.0, 0.55, 0.9)


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
	if not _flat:
		var phase := fmod(_beat_t, _period) / _period
		var k := 1.0 / _period
		if phase < 0.04 * k:
			y -= 160.0 * sin(phase / (0.04 * k) * PI)
		elif phase < 0.08 * k:
			y += 60.0 * sin((phase - 0.04 * k) / (0.04 * k) * PI)
		if phase < delta / _period:
			Audio.sfx("monitor_beep", -8.0)
	_pts.append(Vector2(_x, y))
	_ecg.queue_redraw()


func _draw_ecg() -> void:
	if _pts.size() > 1:
		_ecg.draw_polyline(_pts, Color(0.35, 1.0, 0.55, 0.9), 4.0)
	var font := UiTheme.ui_font()
	_ecg.draw_string(font, Vector2(80, 110), "LEITO %d" % Game.number_a, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(0.35, 1.0, 0.55, 0.9))
	if _label != "":
		_ecg.draw_string(font, Vector2(80, 180), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, _label_color)


func _sequence() -> void:
	if Game.ending == "":
		Game.ending = "hope" if Game.all_memories() else "remember"
	match Game.ending:
		"forget":
			await _forget()
		"hope":
			await _wake(true)
		_:
			await _wake(false)
	_running = false
	var t := create_tween()
	t.tween_property(_ecg, "modulate:a", 0.0, 2.0)
	await t.finished
	await Ui.narrate(["[color=#8193ab]%s[/color]" % TITLES.get(Game.ending, "")], UiTheme.INK, 52)
	await _credits()
	await Ui.fade_out(2.0)
	Game.go_to_menu()


## Esquecer: o sonho fica bonito e o coração desacelera até parar.
func _forget() -> void:
	_ecg.modulate.a = 0.0
	await Ui.fade_in(2.0)
	Audio.ambience("amb_white", 2.0, -6.0)
	await Ui.narrate([
		"Você escolhe não lembrar.",
		"A casa é branca e bonita. O sol não se põe.",
		"%s está ao seu lado. Ninguém pergunta nada." % Game.name_b,
		"Você não sente mais frio.",
	], UiTheme.INK, 44)
	Audio.stop_ambience(3.0)
	create_tween().tween_property(_ecg, "modulate:a", 1.0, 2.0)
	for p in [1.3, 1.8, 2.6, 3.6]:
		_period = p
		await get_tree().create_timer(p * 2.0).timeout
	_flat = true
	Audio.sfx("flatline", -6.0)
	_label = "04:15"
	_label_color = Color(0.9, 0.2, 0.25, 0.95)
	await get_tree().create_timer(5.0).timeout
	await Ui.narrate(["[color=#8193ab]Existem outros finais.[/color]"], UiTheme.INK, 40)


## Lembrar: A acorda no leito. Com as 8 lembranças, B também responde.
func _wake(hope: bool) -> void:
	await Ui.fade_in(2.0)
	await get_tree().create_timer(3.0).timeout
	await Ui.narrate([
		"Você abre os olhos.",
		"Luz fria. Cheiro de remédio. Um bipe que é seu.",
		"A cortina do leito ao lado está aberta.",
	], UiTheme.INK, 44)
	if hope:
		await Ui.narrate([
			"Leito %d. %s respira por um tubo." % [Game.number_b, Game.name_b],
			"O monitor de lá apita. Fraco. Mas apita.",
			"Você estica o braço até doer.\nOs dedos de %s se fecham nos seus." % Game.name_b,
		], UiTheme.INK, 44)
		Audio.music("music_ending", 3.0, -4.0)
		await Ui.narrate([
			"Você embaça o vidro da janela com a respiração\ne escreve com o dedo:",
			"[color=#ffffff]NUNCA ESQUEÇA[/color]",
		], UiTheme.INK, 48)
		await Ui.narrate(["[color=#ffffff]AINDA HÁ ESPERANÇA[/color]"], UiTheme.INK, 64)
	else:
		await Ui.narrate([
			"Leito %d. O colchão sem lençol." % Game.number_b,
			"Uma enfermeira dobra um cobertor e não olha para você.",
			"No criado-mudo, alguém deixou um relógio de bolso.\nParado em 3:15.",
		], UiTheme.INK, 44)
		Audio.music("music_ending", 3.0, -8.0)
		await Ui.narrate([
			"Você lembra. Da festa, da chave, da ponte, da água.",
			"Vai lembrar amanhã também.",
		], UiTheme.INK, 44)
		_running = false
		Audio.stop_music(1.0)
		Audio.sfx("heartbeat", -2.0)
		await Ui.narrate([
			"Você limpa o vapor da janela.",
			"Do lado de dentro do vidro,\na marca de uma mão. [color=#a3202a]Vermelha.[/color]",
		], UiTheme.INK_DIM, 44)


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
		["Lembranças: %d/%d" % [Game.memories.size(), Game.MEMORY_TOTAL], 30, UiTheme.FONT_UI],
		[TITLES.get(Game.ending, ""), 30, UiTheme.FONT_UI],
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
