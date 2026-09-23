extends LevelBase
## Capítulo 1 — A Clareira (tutorial).
## A e B acordam em margens opostas de um riacho. B lê a pedra pintada;
## A puxa as alavancas na ordem certa (verde, vermelha, azul) e a ponte desce.

const ORDER := ["verde", "vermelha", "azul"]
const BRIDGE_Z := -4.0

var _levers := {}
var _pulled: Array = []
var _bridge: Mover
var _bridge_block: StaticBody3D
var _done := false


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
	var avoid := [Rect2(-2.5, -24, 5, 40), Rect2(-10, -9, 8, 14), Rect2(3, -16, 7, 20), Rect2(-11, BRIDGE_Z - 1.5, 22, 3)]
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
	Build.omni(geo, Vector3(-6.6, 2.0, -5.5), Color("7b97d6"), 1.2, 7.0)
	Build.omni(geo, Vector3(7, 2.0, -0.2), Color("7b97d6"), 1.0, 6.0)
	# Saída ao norte do lado B.
	Build.torch(geo, Vector3(6.6, 1.2, -14.0))
	Build.torch(geo, Vector3(9.4, 1.2, -14.0))
	exit_zone(Vector3(8, 1, -15.5), Vector3(4, 2, 2))
	# Quem cair no riacho volta para a própria margem.
	zone(Vector3(0, -0.9, -6), Vector3(3.0, 0.6, 40), func(ch: Character):
		Audio.sfx("splash", -2.0)
		ch.teleport(Vector3(-3.0 if ch.who == "a" else 3.0, 0.1, BRIDGE_Z + 2.0)), false)


func _begin() -> void:
	objective("Acordem. Descubram onde estão.")
	await say([
		"a: ...onde eu estou?",
		"a: O chão está molhado. Tem um riacho aqui do lado.",
		"b: %s? É você do outro lado da água?" % Game.name_a,
		"a: %s! Não consigo atravessar. A ponte está suspensa." % Game.name_b,
		"b: Tem uma pedra pintada aqui perto de mim. E do seu lado?",
		"a: Três alavancas. Vermelha, verde e azul.",
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
		if not Game.get_flag("ch1_first_fail"):
			Game.set_flag("ch1_first_fail")
			await say([ch.who + ": As alavancas voltaram para cima. A ordem importa."])
		return
	if _pulled.size() == ORDER.size():
		_done = true
		await get_tree().create_timer(0.5).timeout
		Game.lock_input()
		await cam.look_at_point(Vector3(0, 0, BRIDGE_Z), 1.0)
		_bridge.open()
		cam.shake(0.4)
		await get_tree().create_timer(2.6).timeout
		_bridge_block.queue_free()
		Audio.sfx("success", -4.0)
		cam.target = party.active
		Game.unlock_input()
		await say([
			"b: A ponte desceu!",
			"a: Vamos sair daqui. Tem uma trilha com tochas do seu lado.",
		])
		objective("Sigam juntos pela trilha iluminada ao norte.")
