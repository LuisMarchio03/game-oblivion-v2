class_name LevelBase
extends Node3D
## Base de todo capítulo. Subclasses sobrescrevem:
##   _build()   monta a geometria (use `geo` como pai) e define spawn_a/spawn_b
##   _begin()   corotina de abertura (falas, objetivo) depois do fade-in
## e usam os ajudantes (interact, doc, zone, finish...).

var chapter_index := 0
var preset := "forest"
var spawn_a := Vector3(-2, 0, 0)
var spawn_b := Vector3(2, 0, 0)
var start_who := "a"
var music := ""
var ambience := "amb_forest"
var cam_bounds := Rect2()
var show_card := true

var geo: Node3D
var party: Party
var cam: CameraRig
var env: Environment
var world_env: WorldEnvironment
var moon: DirectionalLight3D
var rng := RandomNumberGenerator.new()
var _finishing := false

const PRESETS := {
	"forest": {"bg": Color("050a12"), "ambient": Color("3a5578"), "ambient_e": 0.55, "fog": Color("1c2c44"), "fog_d": 0.028, "moon": Color("9fb8e8"), "moon_e": 0.55, "vol": 0.022, "vol_albedo": Color("5a78a8"), "exposure": 1.0, "sat": 0.85},
	"cemetery": {"bg": Color("04080f"), "ambient": Color("34486a"), "ambient_e": 0.5, "fog": Color("223246"), "fog_d": 0.035, "moon": Color("aabfe6"), "moon_e": 0.6, "vol": 0.03, "vol_albedo": Color("6d86ad"), "exposure": 1.0, "sat": 0.8},
	"chapel": {"bg": Color("030509"), "ambient": Color("2a3148"), "ambient_e": 0.4, "fog": Color("1a1a24"), "fog_d": 0.02, "moon": Color("7f95c8"), "moon_e": 0.3, "vol": 0.02, "vol_albedo": Color("8a7a66"), "exposure": 1.1, "sat": 0.9},
	"house_ext": {"bg": Color("04070d"), "ambient": Color("30466a"), "ambient_e": 0.5, "fog": Color("1a2638"), "fog_d": 0.03, "moon": Color("9fb8e8"), "moon_e": 0.6, "vol": 0.025, "vol_albedo": Color("5a78a8"), "exposure": 1.0, "sat": 0.8},
	"house": {"bg": Color("020306"), "ambient": Color("2c3a55"), "ambient_e": 0.42, "fog": Color("10151f"), "fog_d": 0.015, "moon": Color("7f95c8"), "moon_e": 0.25, "vol": 0.012, "vol_albedo": Color("7a6a58"), "exposure": 1.1, "sat": 0.85},
	"attic": {"bg": Color("020306"), "ambient": Color("27354f"), "ambient_e": 0.4, "fog": Color("141a26"), "fog_d": 0.02, "moon": Color("8aa3d6"), "moon_e": 0.35, "vol": 0.03, "vol_albedo": Color("6d86ad"), "exposure": 1.1, "sat": 0.8},
	"dungeon": {"bg": Color("010203"), "ambient": Color("1e2630"), "ambient_e": 0.3, "fog": Color("0b0f12"), "fog_d": 0.03, "moon": Color("000000"), "moon_e": 0.0, "vol": 0.025, "vol_albedo": Color("5a4a3a"), "exposure": 1.2, "sat": 0.85},
	"white": {"bg": Color("eef2f6"), "ambient": Color("ffffff"), "ambient_e": 0.45, "fog": Color("f4f7fa"), "fog_d": 0.005, "moon": Color("fff6ea"), "moon_e": 0.6, "vol": 0.02, "vol_albedo": Color("ffffff"), "exposure": 1.0, "sat": 0.6},
}


func _ready() -> void:
	Ui.in_level = false
	Game.reset_input_lock()
	rng.seed = hash(name) + chapter_index * 101
	geo = Node3D.new()
	geo.name = "Geo"
	add_child(geo)
	_setup_env()
	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	_build()
	cam.bounds = cam_bounds
	party = Party.new()
	party.name = "Party"
	add_child(party)
	party.setup(cam, spawn_a, spawn_b)
	party.activate(start_who, true)
	cam.snap()
	Ui.set_switch_enabled(party.switch_enabled)
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()
	_run.call_deferred()


func _run() -> void:
	Game.lock_input()
	if ambience != "":
		Audio.ambience(ambience, 3.0)
	if music != "":
		Audio.music(music, 3.0, -6.0)
	else:
		Audio.stop_music(2.0)
	if show_card:
		await Ui.chapter_card(chapter_index)
	Ui.set_hud_visible(true)
	await Ui.fade_in(1.2)
	Ui.in_level = true
	Game.unlock_input()
	await _begin()


func _build() -> void:
	pass


func _begin() -> void:
	pass


# --- Ambiente -------------------------------------------------------------------------

func _setup_env() -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["forest"])
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = p["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p["ambient"]
	env.ambient_light_energy = p["ambient_e"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = p["exposure"]
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = p["fog"]
	env.fog_density = p["fog_d"]
	env.fog_sky_affect = 0.0
	env.volumetric_fog_density = p["vol"]
	env.volumetric_fog_albedo = p["vol_albedo"]
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.3
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = p["sat"]
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, -28, 0)
	moon.light_color = p["moon"]
	moon.light_energy = p["moon_e"]
	moon.shadow_enabled = p["moon_e"] > 0.0
	moon.directional_shadow_max_distance = 45.0
	moon.light_volumetric_fog_energy = 0.8
	moon.visible = p["moon_e"] > 0.0
	add_child(moon)
	if preset == "white":
		Ui.set_screen_fx(0.25, 0.02, Color(0.9, 0.93, 0.97))
	else:
		Ui.set_screen_fx(0.6, 0.045, Color(0.0, 0.02, 0.06))


func _apply_quality() -> void:
	var high: bool = int(Game.settings["quality"]) >= 1
	env.volumetric_fog_enabled = high
	env.ssao_enabled = high
	env.adjustment_brightness = float(Game.settings["brightness"])
	get_viewport().scaling_3d_scale = 1.0 if high else 0.75


# --- Ajudantes -------------------------------------------------------------------------

## Ponto de interação genérico.
func interact(pos: Vector3, prompt: String, action: Callable, who := "any", radius := 1.4, marker := true, marker_h := 1.4) -> Interactable:
	var it := Interactable.new()
	it.position = pos
	it.prompt = prompt
	it.action = action
	it.who = who
	it.radius = radius
	geo.add_child(it)
	if marker:
		it.setup_marker(marker_h)
	return it


## Documento legível: guarda no diário de quem leu.
func doc(pos: Vector3, data: Dictionary, prompt := "Ler", who := "any", radius := 1.4) -> Interactable:
	return interact(pos, prompt, func(ch: Character): await Ui.read_doc(ch.who, data), who, radius)


## Zona que chama `cb(ch)` quando um personagem entra.
func zone(pos: Vector3, size: Vector3, cb: Callable, once := true) -> Area3D:
	var ar := Area3D.new()
	ar.position = pos
	ar.collision_layer = 0
	ar.collision_mask = 2
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	ar.add_child(cs)
	geo.add_child(ar)
	var fired := [false]
	ar.body_entered.connect(func(b):
		if b is Character and not (once and fired[0]):
			fired[0] = true
			cb.call(b))
	return ar


func plate(pos: Vector3, size := Vector2(1.2, 1.2)) -> PressurePlate:
	var p := PressurePlate.new()
	p.position = pos
	geo.add_child(p)
	p.setup(size)
	return p


func say(lines: Array) -> void:
	await Ui.say(lines)


func objective(text: String) -> void:
	Game.set_objective(text)


func hints(list: Array) -> void:
	Game.set_chapter_hints(list)


func active_who() -> String:
	return party.active.who


## Mostra um enigma e devolve true se foi resolvido.
func puzzle(panel: Control) -> bool:
	var r = await Ui.open_panel(panel)
	return r == true


## Fim do capítulo.
func finish() -> void:
	if _finishing:
		return
	_finishing = true
	Game.lock_input()
	Ui.in_level = false
	Game.next_chapter()


## Saída que exige os dois personagens juntos.
func exit_zone(pos: Vector3, size: Vector3, need_both := true, wait_text := "") -> Area3D:
	var ar := zone(pos, size, func(_ch): pass, false)
	var msg := wait_text if wait_text != "" else "Não vou sem %s."
	ar.body_entered.connect(func(b):
		if not (b is Character) or _finishing:
			return
		if not need_both:
			finish()
			return
		var inside := 0
		for body in ar.get_overlapping_bodies():
			if body is Character and body.visible:
				inside += 1
		if inside >= 2 or not party.switch_enabled:
			finish()
		elif b == party.active:
			var other_name := Game.char_name("b" if b.who == "a" else "a")
			Ui.toast(msg % other_name if msg.contains("%s") else msg))
	return ar
