extends LevelBase
## Capítulo 1 — A Clareira (tutorial). É o lugar do acidente, mas ninguém lembra.
## A e B acordam encharcados em margens opostas de um riacho. B lê a pedra pintada;
## A puxa as alavancas na ordem certa (verde, vermelha, azul) e a ponte desce.
## Terror: rio abaixo, perto da câmera, um carro afundado pisca os faróis debaixo
## d'água (quem chega perto comenta, sem saber o que é). Errar a ordem apaga as velas das alavancas.
## Quando a ponte desce, o hospital vaza (voz do cap. 1) e o Esquecido aparece entre
## as árvores da margem de B; um clarão e ele some.
## Lembrança m1 ("A festa"): canto escuro a noroeste do lado de A, atrás de um tronco caído.

const ORDER := ["verde", "vermelha", "azul"]
const BRIDGE_Z := -4.0
const CAR_Z := 4.8
const FIGURE := Vector3(11.4, 0, -8.8)
const MEMORY := Vector3(-13.0, 0, -12.6)

var _levers := {}
var _pulled: Array = []
var _bridge: Mover
var _bridge_block: StaticBody3D
var _done := false
var _lever_lights: Array[Light3D] = []
var _lights_armed := false
var _car_seen := {}
var _car_blink: Tween
var _car_lights: Array[OmniLight3D] = []
var _car_glows: Array[Sprite3D] = []


func _init() -> void:
	chapter_index = 0
	preset = "forest"
	ambience = "amb_forest"
	spawn_a = Vector3(-6, 0, 3)
	spawn_b = Vector3(6, 0, 3)
	cam_bounds = Rect2(-11, -13, 22, 17)


func _build() -> void:
	var grass := Build.mat("grass")
	var floor_mat := Build.mat("forest_floor")
	# Margens e leito do riacho.
	Build.ground(geo, Rect2(-24, -24, 22.5, 36), 0.0, grass, "grass")
	Build.ground(geo, Rect2(1.5, -24, 22.5, 36), 0.0, grass, "grass")
	Build.ground(geo, Rect2(-1.5, -24, 3, 36), -1.1, Build.mat("dirt_dark"), "dirt")
	Build.water(geo, Rect2(-1.5, -24, 3, 36), -0.45)
	# Barrancos.
	Build.box(geo, Vector3(0.3, 1.1, 36), Vector3(-1.5, -0.55, -6), Build.mat("dirt"), false)
	Build.box(geo, Vector3(0.3, 1.1, 36), Vector3(1.5, -0.55, -6), Build.mat("dirt"), false)
	# Bloqueios nas margens (com vão na altura da ponte).
	for side in [-1.0, 1.0]:
		Build.blocker(geo, Vector3(0.4, 3, 20), Vector3(side * 1.3, 1.5, BRIDGE_Z - 11.2))
		Build.blocker(geo, Vector3(0.4, 3, 14.6), Vector3(side * 1.3, 1.5, BRIDGE_Z + 8.5))
	_bridge_block = Build.blocker(geo, Vector3(2.8, 3, 2.6), Vector3(0, 1.5, BRIDGE_Z))
	# Limites do mapa.
	Build.blocker(geo, Vector3(50, 4, 1), Vector3(0, 2, 9))
	Build.blocker(geo, Vector3(1, 4, 40), Vector3(-15, 2, -6))
	Build.blocker(geo, Vector3(1, 4, 40), Vector3(15, 2, -6))
	Build.blocker(geo, Vector3(24, 4, 1), Vector3(-3, 2, -18))

	# Ponte levadiça: começa suspensa entre dois postes.
	var wood := Build.mat("planks_dark", Color(1, 1, 1), 1.0)
	for x in [-2.2, 2.2]:
		for z in [BRIDGE_Z - 1.3, BRIDGE_Z + 1.3]:
			Build.box(geo, Vector3(0.3, 3.6, 0.3), Vector3(x, 1.8, z), Build.mat("bark"), true)
	_bridge = Build.mover(geo, Vector3(4.6, 0.25, 2.2), Vector3(0, 3.4, BRIDGE_Z), Vector3(0, -3.52, 0), wood)
	_bridge.time = 2.4
	# Correntes (decorativas).
	for z in [BRIDGE_Z - 1.1, BRIDGE_Z + 1.1]:
		Build.box(_bridge, Vector3(0.05, 1.2, 0.05), Vector3(-2.1, 0.6, z - BRIDGE_Z), Build.color_mat(Color("555a60"), 0.0, 0.3), false)
		Build.box(_bridge, Vector3(0.05, 1.2, 0.05), Vector3(2.1, 0.6, z - BRIDGE_Z), Build.color_mat(Color("555a60"), 0.0, 0.3), false)

	# Trilha de terra.
	Build.box(geo, Vector3(8, 0.02, 2.2), Vector3(-6, 0.01, BRIDGE_Z), Build.mat("dirt"), false)
	Build.box(geo, Vector3(2.4, 0.02, 12), Vector3(8, 0.01, -9), Build.mat("dirt"), false)
	Build.box(geo, Vector3(6, 0.02, 2.2), Vector3(5, 0.01, BRIDGE_Z), Build.mat("dirt"), false)

	# --- Lado A: alavancas e bilhete.
	var colors := {"vermelha": Color("b3262e"), "verde": Color("2f8f3a"), "azul": Color("2e5fb3")}
	var xs := {"vermelha": -8.0, "verde": -6.6, "azul": -5.2}
	Build.box(geo, Vector3(4.6, 1.2, 0.4), Vector3(-6.6, 0.6, -7.4), Build.mat("stone_wall"), true)
	Build.text3d(geo, "PONTE", Vector3(-6.6, 1.05, -7.18), 0.0, 64, Color("c9c2b0"))
	# Velas de beira de estrada em cima do muro (apagam quando a ordem sai errada).
	for x in [-8.6, -4.6]:
		_lever_lights.append(_light_of(Build.candle(geo, Vector3(x, 1.2, -7.45), 0.8, 4.0)))
	Build.flat_sprite(geo, "flower_white", Vector3(-8.2, 1.21, -7.4), Vector3(-90, 40, 0), 0.02, Color(0.7, 0.7, 0.65))
	for key in ["vermelha", "verde", "azul"]:
		var lv := Build.lever(geo, Vector3(xs[key], 0, -6.7), colors[key])
		_levers[key] = lv
		interact(Vector3(xs[key], 0.5, -6.3), "Puxar alavanca " + key, _pull.bind(key), "any", 0.9, true, 1.5)
	doc(Vector3(-9, 0.05, 1.5), {
		"id": "ch1_bilhete",
		"title": "Bilhete amassado",
		"body": "Se você está lendo isto, não confie na sua memória.\n\nAnote tudo.\n\nO que um de vocês vê, o outro não vê.",
		"style": "paper",
	}, "Pegar bilhete")
	Build.flat_sprite(geo, "icon_note", Vector3(-9, 0.03, 1.5), Vector3(-90, 20, 0), 0.03)

	# --- Lado B: pedra pintada.
	var stone := Build.box(geo, Vector3(1.6, 1.4, 0.8), Vector3(7, 0.7, -1.5), Build.mat("gravestone"), true)
	stone.rotation_degrees.y = -12
	var dots := [[Color("b3262e"), 0.22, -0.45], [Color("2e5fb3"), 0.32, 0.1], [Color("2f8f3a"), 0.12, 0.55]]
	for d in dots:
		var disc := Build.cylinder(stone, d[1], 0.04, Vector3(d[2], 0.2, 0.42), Build.color_mat(d[0], 0.15), false, 16)
		disc.rotation_degrees.x = 90
	doc(Vector3(7, 0.5, -0.6), {
		"id": "ch1_pedra",
		"title": "Pedra pintada",
		"circles": [["#b3262e", 60], ["#2e5fb3", 90], ["#2f8f3a", 28]],
		"body": "[center]Sob os círculos, talhado na pedra:\n\n[i]\"Do menor ao maior.\"[/i][/center]",
		"style": "stone",
	}, "Examinar pedra")

	# --- Vegetação e clima.
	var avoid := [Rect2(-2.5, -24, 5, 40), Rect2(-10, -9, 8, 14), Rect2(3, -16, 7, 20), Rect2(-11, BRIDGE_Z - 1.5, 22, 3), Rect2(-15, -15, 6, 11), Rect2(FIGURE.x - 1.2, FIGURE.z - 1.0, 2.4, 2.0)]
	for i in 38:
		var x := rng.randf_range(-15, 15)
		var z := rng.randf_range(-18, 8)
		var ok := true
		for r in avoid:
			if r.has_point(Vector2(x, z)):
				ok = false
		if not ok:
			continue
		if abs(x) < 9 and z > -2 and z < 6:
			continue
		Build.tree(geo, ["tree_pine", "tree_pine", "tree_dead", "tree_oak"][rng.randi_range(0, 3)], Vector3(x, 0, z), rng.randf_range(0.8, 1.3))
	# Moldura de árvores no fundo.
	for i in 16:
		Build.tree(geo, "tree_pine", Vector3(-16 + i * 2.1 + rng.randf_range(-0.5, 0.5), 0, -18.5 + rng.randf_range(-1, 1)), rng.randf_range(1.0, 1.5), false)
	Build.scatter(geo, ["grass", "grass", "fern", "bush", "flower_white"], Rect2(-14, -16, 28, 23), 170, 0.0, rng, [Rect2(-2, -24, 4, 40)])
	for i in 18:
		Build.billboard(geo, "reeds", Vector3([-1.8, 1.8][i % 2], 0, rng.randf_range(-16, 7)), 0.035)
	var crow := Build.billboard(geo, "crow", Vector3(-10.5, 3.4, -9), 0.04, 2)
	var ca := SpriteAnim.new()
	ca.frames = 2
	ca.fps = 1.3
	crow.add_child(ca)
	Build.motes(geo, Vector3(0, 1.2, -4), Vector3(12, 1.2, 10), 70, Color(0.7, 1.0, 0.8, 0.9), "firefly", 0.05)
	_lever_lights.append(Build.omni(geo, Vector3(-6.6, 2.0, -5.5), Color("7b97d6"), 1.2, 7.0))
	Build.omni(geo, Vector3(7, 2.0, -0.2), Color("7b97d6"), 1.0, 6.0)
	# Saída ao norte do lado B.
	Build.torch(geo, Vector3(6.6, 1.2, -14.0))
	Build.torch(geo, Vector3(9.4, 1.2, -14.0))
	exit_zone(Vector3(8, 1, -15.5), Vector3(4, 2, 2))
	_build_car()
	_build_figure_spot()
	_build_memory()
	# Quem cair no riacho volta para a própria margem.
	zone(Vector3(0, -0.9, -6), Vector3(3.0, 0.6, 40), func(ch: Character):
		Audio.sfx("splash", -2.0)
		ch.teleport(Vector3(-3.0 if ch.who == "a" else 3.0, 0.1, BRIDGE_Z + 2.0)), false)


# --- Terror: o carro no riacho, o vulto e a lembrança ---------------------------------

## Carro afundado rio abaixo, bem perto da câmera: só o fim do teto fura a água.
## Os faróis piscam lá embaixo (luz na superfície, bolhas subindo).
func _build_car() -> void:
	var paint := Build.color_mat(Color("1c2129"), 0.0, 0.35)
	var glass := Build.color_mat(Color("0b1016"), 0.0, 0.15)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.1, -1.08, CAR_Z)
	pivot.rotation_degrees = Vector3(12, 8, 4)  # frente afundada para o sul
	geo.add_child(pivot)
	Build.box(pivot, Vector3(1.7, 0.7, 4.0), Vector3.ZERO, paint, false)
	Build.box(pivot, Vector3(1.5, 0.55, 2.0), Vector3(0, 0.6, -0.4), paint, false)
	var chrome := Build.color_mat(Color("8a939e"), 0.0, 0.2)
	# Vidro traseiro inclinado e friso do teto.
	var rear := Build.box(pivot, Vector3(1.42, 0.62, 0.05), Vector3(0, 0.55, -1.5), glass, false)
	rear.rotation_degrees.x = -35
	for x in [-0.74, 0.74]:
		Build.box(pivot, Vector3(0.04, 0.04, 2.0), Vector3(x, 0.88, -0.4), chrome, false)
	Build.box(pivot, Vector3(0.2, 0.03, 0.12), Vector3(0.5, 0.36, -1.9), chrome, false)
	# Janela do motorista quebrada (buraco escuro no vidro).
	Build.box(pivot, Vector3(0.05, 0.36, 0.8), Vector3(-0.76, 0.62, 0.1), glass, false)
	Build.box(pivot, Vector3(0.06, 0.12, 0.4), Vector3(-0.77, 0.5, -0.2), Build.color_mat(Color("000000")), false)
	# Lanternas traseiras apagadas.
	for x in [-0.6, 0.6]:
		Build.box(pivot, Vector3(0.3, 0.12, 0.04), Vector3(x, 0.15, -2.01), Build.color_mat(Color("4a0e10"), 0.2), false)
	# Faróis: brilho na superfície da água, luz fria e bolhas.
	var lights := _car_lights
	var glows := _car_glows
	for x in [-0.55, 0.55]:
		var surf := Vector3(0.1 + x, -0.43, CAR_Z + 1.9)
		var gl := Build.flat_sprite(geo, "glow", surf, Vector3(-90, 0, 0), 0.03, Color(0.9, 0.95, 0.75, 0.0))
		gl.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		gl.transparent = true
		gl.shaded = false
		glows.append(gl)
		lights.append(Build.omni(geo, surf + Vector3(0, 0.25, 0.3), Color("dfe8c8"), 0.0, 2.8))
	Build.motes(geo, Vector3(0.1, -0.3, CAR_Z + 1.2), Vector3(0.9, 0.15, 1.4), 16, Color(0.8, 0.9, 1.0, 0.7), "dust", 0.05)
	var blink := create_tween().set_loops()
	_car_blink = blink
	for step in [[1.0, 0.5], [0.0, 0.15], [1.0, 0.12], [0.0, 1.1], [1.0, 0.8], [0.15, 0.3], [1.0, 0.2], [0.0, 1.6]]:
		var v: float = step[0]
		var dur: float = step[1]
		blink.tween_callback(func():
			for l in lights:
				l.light_energy = 1.6 * v
			for g in glows:
				g.modulate.a = 0.75 * v)
		blink.tween_interval(dur)
	# Quem chega perto da margem comenta.
	zone(Vector3(-2.8, 1, CAR_Z), Vector3(2.6, 2, 4.4), _near_car, false)
	zone(Vector3(2.8, 1, CAR_Z), Vector3(2.6, 2, 4.4), _near_car, false)


func _near_car(ch: Character) -> void:
	if _car_seen.has(ch.who) or ch != party.active:
		return
	_car_seen[ch.who] = true
	Audio.sfx("drip", -6.0)
	if ch.who == "a":
		await say([
			"a: Tem luz lá no fundo da água.",
			"a: Duas. Apagam e acendem.",
		])
	else:
		await say([
			"b: Tem alguma coisa brilhando lá embaixo.",
			"b: Deve ser reflexo.",
			"b: ...de quê?",
		])


## Entre as árvores da margem de B, onde o Esquecido vai aparecer.
func _build_figure_spot() -> void:
	for p in [Vector3(FIGURE.x - 1.1, 0, FIGURE.z - 0.5), Vector3(FIGURE.x + 1.2, 0, FIGURE.z + 0.2), Vector3(FIGURE.x + 0.3, 0, FIGURE.z - 1.6)]:
		Build.tree(geo, "tree_dead", p, 1.1, true, Color(0.75, 0.8, 0.9))


## Lembrança m1: canto escuro a noroeste, atrás de um tronco caído.
func _build_memory() -> void:
	var trunk := Build.box(geo, Vector3(2.4, 0.55, 0.55), MEMORY + Vector3(1.0, 0.27, 1.3), Build.mat("bark", Color(0.55, 0.5, 0.45)), true, 14.0)
	trunk.rotation_degrees.x = 6
	Build.billboard(geo, "fern", MEMORY + Vector3(-0.9, 0, 1.0), 0.035)
	Build.billboard(geo, "bush", MEMORY + Vector3(1.9, 0, 1.6), 0.04)
	# Um copo de festa amassado no mato.
	var cup := Build.cylinder(geo, 0.05, 0.12, MEMORY + Vector3(0.3, 0.05, 0.1), Build.color_mat(Color("a8222a"), 0.05), false, 8)
	cup.rotation_degrees.z = 90
	memory(MEMORY, "m1", "A festa",
		"A música estava alta demais. Alguém pôs um copo na minha mão.\n\n%s riu de alguma coisa que eu disse.\n\nQueria lembrar o que era." % Game.name_b)


func _light_of(n: Node) -> Light3D:
	for c in n.get_children():
		if c is Light3D:
			return c
	return null


func _begin() -> void:
	objective("Acordem. Descubram onde estão.")
	await say([
		"a: ...água. Tem água no meu ouvido.",
		"a: A roupa está encharcada. Por que a minha roupa está encharcada?",
		"b: %s? É você do outro lado do riacho?" % Game.name_a,
		"a: %s! Você está bem?" % Game.name_b,
		"b: Estou com frio. Não lembro de ter entrado na água.",
		"a: Eu também não. Não lembro de nada.",
		"b: A ponte está erguida. Tem uma pedra pintada aqui perto de mim.",
		"a: Do meu lado tem três alavancas. Vermelha, verde e azul.",
	])
	Ui.toast("[%s] troca entre %s e %s" % [Ui.key_label("switch"), Game.name_a, Game.name_b])
	Ui.toast("[%s] abre o diário e o bloco de notas" % Ui.key_label("journal"))
	objective("Abaixem a ponte.")
	hints([
		"A pedra do lado de %s tem três círculos de tamanhos diferentes." % Game.name_b,
		"\"Do menor ao maior\": a ordem das alavancas segue o tamanho dos círculos.",
		"Puxe a verde, depois a vermelha, depois a azul.",
	])


func _pull(ch: Character, key: String) -> void:
	if _done:
		return
	var lv: Lever = _levers[key]
	if lv.down:
		return
	lv.set_down(true)
	_pulled.append(key)
	var i := _pulled.size() - 1
	if _pulled[i] != ORDER[i]:
		await get_tree().create_timer(0.6).timeout
		Audio.sfx("error", -4.0)
		for k in _levers:
			_levers[k].set_down(false)
		_pulled.clear()
		# Errar custa: as velas do muro se apagam (registradas só no primeiro erro).
		if not _lights_armed:
			_lights_armed = true
			for l in _lever_lights:
				if l:
					dread_light(l)
		Game.puzzle_failed.emit()
		if not Game.get_flag("ch1_first_fail"):
			Game.set_flag("ch1_first_fail")
			await say([
				ch.who + ": As alavancas voltaram para cima. A ordem importa.",
				ch.who + ": E uma das velas apagou sozinha.",
			])
		return
	if _pulled.size() == ORDER.size():
		_done = true
		await get_tree().create_timer(0.5).timeout
		await _lower_bridge()


func _lower_bridge() -> void:
	Game.lock_input()
	await cam.look_at_point(Vector3(0, 0, BRIDGE_Z), 1.0)
	_bridge.open()
	cam.shake(0.4)
	await get_tree().create_timer(2.6).timeout
	_bridge_block.queue_free()
	Audio.sfx("success", -4.0)
	# O hospital vaza enquanto a ponte assenta.
	bleed([
		"Pupilas reagindo.",
		"Mais um cobertor aqui, por favor.",
	])
	# Entre as árvores do outro lado, alguém está parado olhando.
	var s := spawn_stalker()
	s.appear(FIGURE, 0.0)
	await get_tree().create_timer(0.6).timeout
	await cam.look_at_point(FIGURE + Vector3(0, 1.2, 0), 1.6)
	Audio.sfx("dread_sting", -6.0)
	Audio.sfx("breath", -10.0)
	await get_tree().create_timer(1.6).timeout
	Audio.sfx("flash", -4.0)
	Ui.flash(Color(0.95, 0.97, 1.0), 0.5)
	s.vanish(0.0)
	await get_tree().create_timer(0.9).timeout
	cam.target = party.active
	Game.unlock_input()
	await say([
		"b: A ponte desceu.",
		"b: Tinha alguém ali. Entre as árvores.",
		"a: Eu vi.",
		"b: Vem logo, %s." % Game.name_a,
	])
	objective("Atravessem a ponte e sigam juntos pela trilha iluminada ao norte.")
	hints([
		"A ponte desceu entre as duas margens.",
		"%s atravessa a ponte até o lado de %s." % [Game.name_a, Game.name_b],
		"Levem os dois até as tochas no fim da trilha, ao norte do lado de %s." % Game.name_b,
	])


# --- Depuração (tools/shot.sh --call=...) ------------------------------------------------

## O vulto entre as árvores, como a câmera mostra quando a ponte desce.
func _debug_figure() -> void:
	_bridge.set_open(true, true)
	spawn_stalker().appear(FIGURE, 0.0)
	cam.target = null
	cam.set("_focus_point", FIGURE + Vector3(0, 1.2, 0))


## O carro no riacho, visto da margem de A.
func _debug_car() -> void:
	_car_seen["a"] = true
	_car_seen["b"] = true
	_car_blink.kill()
	for l in _car_lights:
		l.light_energy = 1.6
	for g in _car_glows:
		g.modulate.a = 0.75
	party.a.teleport(Vector3(-3.0, 0.1, 3.0))
	cam.target = null
	cam.offset = Vector3(0, 6.5, 5.5)
	cam.set("_focus_point", Vector3(0, -0.4, CAR_Z + 0.5))
