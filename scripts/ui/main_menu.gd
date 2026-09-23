extends Node3D
## Menu principal sobre um diorama de floresta à noite, com fluxo de novo jogo:
## nomes → regras → introdução → capítulo 1.

var _ui: Control
var _menu: VBoxContainer
var _cam: Camera3D
var _t := 0.0


func _ready() -> void:
	Ui.in_level = false
	Ui.set_hud_visible(false)
	Game.reset_input_lock()
	_build_scene()
	_build_ui()
	Audio.music("music_menu", 2.0, -4.0)
	Audio.ambience("amb_forest", 2.0, -8.0)
	Ui.set_screen_fx(0.65)
	await Ui.fade_in(1.5)


func _process(delta: float) -> void:
	_t += delta
	if _cam:
		_cam.position = Vector3(sin(_t * 0.05) * 2.0, 3.2 + sin(_t * 0.11) * 0.2, 12.0)
		_cam.look_at(Vector3(0, 2.2, 0), Vector3.UP)


func _build_scene() -> void:
	var p: Dictionary = LevelBase.PRESETS["forest"]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = p["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p["ambient"]
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.fog_enabled = true
	env.fog_light_color = p["fog"]
	env.fog_density = 0.05
	env.volumetric_fog_enabled = int(Game.settings["quality"]) >= 1
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = p["vol_albedo"]
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 160, 0)
	moon.light_color = p["moon"]
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 2.0
	add_child(moon)
	var geo := Node3D.new()
	add_child(geo)
	Build.ground(geo, Rect2(-40, -40, 80, 60), 0.0, Build.mat("forest_floor"), "grass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2023
	for i in 70:
		var x := rng.randf_range(-26, 26)
		var z := rng.randf_range(-30, 4)
		if abs(x) < 3.0 and z > -8:
			continue
		Build.tree(geo, ["tree_pine", "tree_dead", "tree_pine"][rng.randi_range(0, 2)], Vector3(x, 0, z), rng.randf_range(0.9, 1.4), false)
	Build.scatter(geo, ["grass", "fern", "bush"], Rect2(-20, -20, 40, 26), 140, 0.0, rng)
	Build.motes(geo, Vector3(0, 1.5, -2), Vector3(10, 1.5, 8), 50, Color(0.7, 0.9, 1.0, 0.8), "firefly", 0.06)
	Build.omni(geo, Vector3(0, 1.0, -6), Color("6f8fd0"), 2.0, 9.0)
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	_cam.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UiTheme.get_theme()
	layer.add_child(_ui)

	var logo := Control.new()
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.position = Vector2(-560, 110)
	logo.size = Vector2(1120, 220)
	logo.draw.connect(func(): _draw_logo(logo))
	_ui.add_child(logo)

	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.position = Vector2(-220, 40)
	_menu.custom_minimum_size = Vector2(440, 0)
	_menu.add_theme_constant_override("separation", 14)
	_ui.add_child(_menu)
	if Game.has_save():
		_menu.add_child(UiTheme.button("Continuar", _continue))
	_menu.add_child(UiTheme.button("Novo jogo", _new_game))
	_menu.add_child(UiTheme.button("Opções", func(): Ui.open_panel(OptionsPanel.new())))
	_menu.add_child(UiTheme.button("Créditos", func(): Ui.open_panel(_credits_panel())))
	_menu.add_child(UiTheme.button("Sair", func(): get_tree().quit()))
	(_menu.get_child(0) as Button).call_deferred("grab_focus")

	var foot := UiTheme.label("Use fones para melhor imersão · Jogue em tela cheia", 26, UiTheme.INK_DIM)
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.position = Vector2(-500, -70)
	foot.size = Vector2(1000, 40)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(foot)


static func draw_logo_mark(ci: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	ci.draw_arc(center, r, 0, TAU, 72, color, r * 0.36, true)
	var s := r * 0.42
	ci.draw_rect(Rect2(center - Vector2(s, s) / 2.0, Vector2(s, s)), color)


func _draw_logo(c: Control) -> void:
	var font := UiTheme.font(UiTheme.FONT_LOGO)
	var text := "BLIVION"
	var fs := 120
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := 62.0
	var total := r * 2.0 + 24 + tw
	var x0 := (c.size.x - total) / 2.0
	draw_logo_mark(c, Vector2(x0 + r, c.size.y / 2.0), r - 11, Color("eef3fa"))
	c.draw_string(font, Vector2(x0 + r * 2.0 + 24, c.size.y / 2.0 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("eef3fa"))


func _continue() -> void:
	if Game.load_game():
		Audio.stop_all(1.0)
		Game.start_chapter(Game.chapter)


func _new_game() -> void:
	var names = await Ui.open_panel(NameEntry.new())
	if names == null:
		return
	Game.new_game(names[0], names[1])
	await Ui.open_panel(RulesPanel.new())
	_menu.visible = false
	Audio.stop_all(2.0)
	await Ui.fade_out(1.5)
	await _intro()
	Game.start_chapter(0)


func _intro() -> void:
	Ui.set_black(true)
	await get_tree().create_timer(1.0).timeout
	Audio.sfx("heartbeat", -4.0)
	await Ui.narrate(["Sua cabeça dói..."])
	await Ui.narrate([
		"Você não se lembra do seu nome.",
	])
	await Ui.narrate([
		"%s... %s..." % [Game.name_a, Game.name_b],
		"[shake rate=12 level=6]%s[/shake]" % _scramble(Game.name_a + " " + Game.name_b),
	], UiTheme.INK_DIM)
	Audio.sfx("heartbeat", -2.0)
	await Ui.narrate([
		"mas sente uma estranha afinidade\ncom o número [color=#c0303a]%d[/color]." % Game.number_a,
	])


func _scramble(s: String) -> String:
	var chars := "#%&@$*?!/\\"
	var out := ""
	for c in s:
		out += chars[randi() % chars.length()] if c != " " and randf() < 0.7 else c
	return out


func _credits_panel() -> ModalPanel:
	var p := CreditsPanel.new()
	return p
