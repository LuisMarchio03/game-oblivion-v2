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

## O Esquecido que patrulha a fase (criado por `spawn_stalker`).
var stalker: Stalker
## Onde os dois voltam quando o Esquecido alcança alguém.
var checkpoint_a := Vector3.ZERO
var checkpoint_b := Vector3.ZERO
var _catching := false
# Segunda figura, só para "quem fica sozinho" (não interfere na patrulha).
var _shade: Stalker
var _watch := {}
# Erros em enigmas apagam luzes; o terceiro chama o Esquecido.
var _dread_fails := 0
var _pending_dark := 0
var _pending_glimpse := false
var _dread_lights: Array = []

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
	checkpoint_a = spawn_a
	checkpoint_b = spawn_b
	Game.puzzle_failed.connect(_on_puzzle_failed)
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
	_watch = {}
	Ui.set_dread(0.0)
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


# --- Terror ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if party == null or _finishing:
		return
	var dread := 0.0
	if stalker and stalker.is_active():
		var d := stalker.distance_to_active()
		var hunting := stalker.state == Stalker.CHASE or stalker.state == Stalker.STALK
		dread = clampf(1.0 - (d - 1.5) / 9.0, 0.0, 1.0) * (1.0 if hunting else 0.55)
	if not _watch.is_empty():
		dread = maxf(dread, _process_watch(delta))
	if _shade and _shade.is_active():
		dread = maxf(dread, clampf(1.0 - (_shade.distance_to_active() - 1.0) / 8.0, 0.0, 1.0))
	if in_level_ok():
		Ui.set_dread(dread)
	if not Ui.has_open_panel() and Game.can_control():
		while _pending_dark > 0:
			_pending_dark -= 1
			_darken_next()
		if _pending_glimpse:
			_pending_glimpse = false
			_glimpse()


func in_level_ok() -> bool:
	return Ui.in_level


## Cria o Esquecido desta fase. Configure `path`, velocidades e chame `patrol()`/`appear()`.
func spawn_stalker() -> Stalker:
	if stalker:
		return stalker
	stalker = Stalker.new()
	stalker.name = "Esquecido"
	add_child(stalker)
	stalker.setup(party)
	stalker.caught.connect(_on_caught)
	return stalker


func set_checkpoint(pos_a: Vector3, pos_b: Vector3) -> void:
	checkpoint_a = pos_a
	checkpoint_b = pos_b


func _on_caught(ch: Character) -> void:
	if _catching or _finishing:
		return
	_catching = true
	Game.lock_input()
	Audio.sfx("whisper_many", -2.0)
	await Ui.jumpscare("res://assets/legacy/face_hand.png", 0.7)
	await Ui.fade_out(0.3)
	for c in [party.a, party.b]:
		if c.visible:
			c.leave_hiding()
			c.teleport(checkpoint_a if c.who == "a" else checkpoint_b)
	await _caught(ch)
	cam.target = party.active
	cam.snap()
	Ui.set_dread(0.0, true)
	await get_tree().create_timer(0.8).timeout
	await Ui.fade_in(0.8)
	Game.unlock_input()
	_catching = false
	await say(["?: ...esqueça."])


## Depois de alguém ser pego (já teletransportado ao checkpoint). Padrão: o Esquecido
## recomeça a patrulha do início. Fases podem sobrescrever.
func _caught(_ch: Character) -> void:
	if stalker == null:
		return
	if stalker.path.is_empty():
		stalker.vanish(0.0)
	else:
		stalker.global_position = stalker.path[0]
		stalker.patrol(stalker.path, 1 if stalker.path.size() > 1 else 0)


## Esconderijo: quem entra some da vista do Esquecido até sair (Interagir de novo).
func hide_spot(pos: Vector3, prompt := "Esconder-se", who := "any", radius := 1.1) -> Interactable:
	return interact(pos, prompt, func(ch: Character): ch.hide_in(pos), who, radius, true, 1.2)


## Quem fica sozinho é caçado. `victim_fn` devolve o Character que está sozinho agora
## (ou null). Depois de ~35% de `limit` segundos seguidos vêm os sussurros; ~60%, o
## Esquecido surge atrás da vítima e anda até ela; no fim, ele alcança. `on_caught(ch)`
## desfaz o que a vítima segurava (placa, roda...).
func lonely_watch(victim_fn: Callable, limit := 35.0, on_caught := Callable()) -> void:
	_watch = {"fn": victim_fn, "limit": limit, "cb": on_caught, "t": 0.0, "victim": null, "stage": 0}


func stop_lonely_watch() -> void:
	_watch = {}
	if _shade and _shade.is_active():
		_shade.vanish(0.8)


func _process_watch(delta: float) -> float:
	if _catching or not Game.can_control():
		return 0.0
	var w := _watch
	var v = w["fn"].call()
	if v != w["victim"]:
		if int(w["stage"]) >= 2 and _shade:
			_shade.vanish(0.8)
		w["victim"] = v
		w["stage"] = 0
		w["t"] = 0.0
	if v == null:
		return 0.0
	var ch: Character = v
	w["t"] = float(w["t"]) + delta
	var limit: float = w["limit"]
	var frac: float = w["t"] / limit
	if int(w["stage"]) == 0 and frac > 0.35:
		w["stage"] = 1
		Audio.sfx("whisper_many", -12.0)
		Ui.toast("Ninguém está perto de %s. Alguma coisa percebeu." % Game.char_name(ch.who), UiTheme.BLOOD)
	elif int(w["stage"]) == 1 and frac > 0.6:
		w["stage"] = 2
		var shade := _get_shade()
		var pos := _behind(ch, 4.5)
		shade.appear(pos, 1.2)
		var remain: float = max(limit - float(w["t"]), 2.0)
		shade.stalk(ch, pos.distance_to(ch.global_position) / remain)
		Audio.sfx("dread_sting", -6.0)
	if party.active == ch:
		return clampf(frac, 0.0, 1.0) * 0.95
	return 0.3 if int(w["stage"]) >= 1 else 0.0


func _get_shade() -> Stalker:
	if _shade == null:
		_shade = Stalker.new()
		_shade.name = "Sombra"
		add_child(_shade)
		_shade.setup(party)
		_shade.hunting = false
		_shade.caught.connect(_on_shade_caught)
	return _shade


func _on_shade_caught(ch: Character) -> void:
	if _catching or _finishing:
		return
	_catching = true
	Game.lock_input()
	Audio.sfx("whisper_many", -2.0)
	await Ui.jumpscare("res://assets/legacy/face_hand.png", 0.7)
	_shade.vanish(0.0)
	if not _watch.is_empty():
		var cb: Callable = _watch["cb"]
		_watch["t"] = 0.0
		_watch["stage"] = 0
		_watch["victim"] = null
		if cb.is_valid():
			await cb.call(ch)
	Ui.set_dread(0.0, true)
	Game.unlock_input()
	_catching = false
	await say([ch.who + ": ...tinha alguém atrás de mim. Com a mão no rosto."])


## Ponto atrás do personagem (longe do parceiro), livre de paredes e com chão.
func _behind(ch: Character, dist: float) -> Vector3:
	var other := party.other(ch)
	var away := ch.global_position - other.global_position
	away.y = 0.0
	var base_ang := atan2(away.x, away.z) if away.length() > 0.1 else PI
	var space := get_world_3d().direct_space_state
	for k in [0.0, 0.6, -0.6, 1.2, -1.2, 2.0, -2.0, PI]:
		for dd in [dist, dist * 0.6]:
			var a: float = base_ang + k
			var p: Vector3 = ch.global_position + Vector3(sin(a), 0, cos(a)) * dd
			var q := PhysicsRayQueryParameters3D.create(ch.global_position + Vector3(0, 1.0, 0), p + Vector3(0, 1.0, 0), 1)
			if not space.intersect_ray(q).is_empty():
				continue
			var down := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.5, 0), p + Vector3(0, -2.0, 0), 1)
			var hit := space.intersect_ray(down)
			if hit.is_empty():
				continue
			return hit["position"]
	return ch.global_position + Vector3(0, 0, -dist * 0.5)


## Luz que se apaga quando alguém erra um enigma. A cada três erros, o Esquecido aparece.
## `group` (opcional) junta as luzes de um enigma; veja `dread_focus`.
func dread_light(l: Light3D, group := "") -> void:
	_dread_lights.append({"light": l, "energy": l.light_energy, "group": group})


## Os próximos erros apagam primeiro as luzes do grupo (o enigma que está sendo tentado).
func dread_focus(group: String) -> void:
	var front := []
	var rest := []
	for e in _dread_lights:
		if e["group"] == group:
			front.append(e)
		else:
			rest.append(e)
	_dread_lights = front + rest


func _on_puzzle_failed() -> void:
	_dread_fails += 1
	_pending_dark += 1
	Audio.sfx("light_out", -8.0, randf_range(0.9, 1.1))
	if _dread_fails % 3 == 0:
		_pending_glimpse = true
		Ui.jumpscare("res://assets/legacy/face_hand.png", 0.5)


func _darken_next() -> void:
	for e in _dread_lights:
		var l: Light3D = e["light"]
		if is_instance_valid(l) and l.light_energy > 0.01 and l.visible:
			for c in l.get_children():
				if c is Flicker:
					c.set_process(false)
			var t := create_tween()
			t.tween_property(l, "light_energy", e["energy"] * 1.8, 0.05)
			t.tween_property(l, "light_energy", e["energy"] * 0.2, 0.08)
			t.tween_property(l, "light_energy", e["energy"], 0.06)
			t.tween_property(l, "light_energy", 0.0, 0.25)
			return


func _relight_all() -> void:
	for e in _dread_lights:
		var l: Light3D = e["light"]
		if not is_instance_valid(l):
			continue
		create_tween().tween_property(l, "light_energy", e["energy"], 1.5)
		for c in l.get_children():
			if c is Flicker:
				c.set_process(true)


## O Esquecido surge atrás de quem está jogando, olha e some (terceiro erro).
func _glimpse() -> void:
	var ch := party.active
	var shade := _get_shade()
	if shade.is_active():
		return
	shade.appear(_behind(ch, 3.2), 0.2)
	Audio.sfx("dread_sting", -4.0)
	Audio.sfx("breath", -6.0)
	await get_tree().create_timer(2.4).timeout
	await shade.vanish(1.0)
	_relight_all()


## O hospital vaza para o sonho (legenda fria no alto da tela, não bloqueia).
func bleed(lines: Array, beep := true) -> void:
	Ui.bleed(lines, beep)


func bleed_zone(pos: Vector3, size: Vector3, lines: Array, beep := true) -> Area3D:
	return zone(pos, size, func(_ch): bleed(lines, beep))


## Lembrança escondida da noite do acidente (uma por capítulo). É de A: só A pode tocar.
## `id` curto e único ("m1".."m8"). Não aparece de novo se já foi achada.
func memory(pos: Vector3, id: String, title: String, body: String) -> Interactable:
	if Game.has_memory(id):
		return null
	var glow := Build.billboard(geo, "glow", pos + Vector3(0, 0.7, 0), 0.0022, 1, 0, Color(1.0, 0.82, 0.62, 0.55), false)
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	glow.transparent = true
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.15, 1.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "modulate:a", 0.55, 1.6).set_trans(Tween.TRANS_SINE)
	var it := interact(pos, "Tocar a lembrança", Callable(), "a", 1.1, false)
	it.action = _take_memory.bind(id, title, body, glow, it)
	it.deny_text = "Isso não é meu. É uma lembrança de %s." % Game.name_a
	return it


func _take_memory(ch: Character, id: String, title: String, body: String, glow: Sprite3D, it: Interactable) -> void:
	it.disable()
	it.queue_free()
	glow.queue_free()
	Audio.sfx("flash", -10.0)
	Game.add_memory(id)
	await Ui.flash(Color(1.0, 0.92, 0.8), 0.8)
	await Ui.read_doc(ch.who, {"id": "mem_" + id, "title": title, "body": body, "style": "memory"})
	Ui.toast("Lembrança recuperada (%d/%d)" % [Game.memories.size(), Game.MEMORY_TOTAL], Color("efe2cf"))


## Captura de tela: põe o Esquecido 2,5 m à frente do personagem ativo (tools/shot.sh --call=_debug_stalker).
func _debug_stalker() -> void:
	spawn_stalker().appear(party.active.global_position + Vector3(1.2, 0, -2.5), 0.0)
