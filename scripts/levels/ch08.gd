extends LevelBase
## Capítulo 8 — Ascendência.
## Parte 1 (masmorra): A e B descem por corredores paralelos, entre celas. As duas
## placas diante das grades precisam de peso ao mesmo tempo. No salão, a esfinge
## acorrentada pergunta: "quanto mais se tem, menos se vê?" → ESCURIDÃO.
## As correntes se partem, tudo fica branco e B some.
## Parte 2 (fase branca, no mesmo capítulo): só A. Três lembranças de B flutuam no
## branco; com as três, abre-se uma porta de luz.

const ANSWERS := ["ESCURIDAO", "ESCURIDÃO", "ESCURO", "TREVAS", "BREU"]
const RIDDLE := "\"O que é, o que é: quanto mais se tem, menos se vê?\""
const MONSTER := Vector3(0, 0.3, -20.0)
const GATE_Z := -9.0
## Origem da fase branca (longe da masmorra).
const W := Vector3(80, 0, 0)

const MEMORIES := [
	{"pos": Vector3(-5.5, 0, -1.5), "line": "Lembra quando a gente prometeu não se perder?"},
	{"pos": Vector3(5.5, 0, -5.0), "line": "Não é culpa sua."},
	{"pos": Vector3(-1.5, 0, -10.5), "line": "Acorda. Por favor, acorda."},
]


## Cadeado da esfinge: errar faz a criatura rosnar e ameaçar (sem game over).
class SphinxLock extends CodeLock:
	const THREATS := [
		"\"Errado. Sinto o cheiro do seu medo.\"",
		"\"Mais uma vez, e eu fico com o seu nome.\"",
		"\"As minhas correntes pesam menos que as suas.\"",
		"\"Pensem. Ou fiquem aqui comigo. Para sempre.\"",
	]
	var fails := 0
	var on_fail: Callable

	func _init(p_title: String, p_answers: Array, p_desc := "", p_hints: Array = []) -> void:
		super(p_title, p_answers, p_desc, p_hints)

	func fail(_text := "Nada acontece.") -> void:
		if _solved:
			return
		Audio.sfx("monster_growl", -2.0, randf_range(0.85, 1.05))
		Audio.sfx("chain_rattle", -8.0)
		super.fail(THREATS[fails % THREATS.size()])
		fails += 1
		if on_fail.is_valid():
			on_fail.call()


var _dungeon: Node3D
var _white: Node3D
var _gates: Array[Mover] = []
var _plate_a: PressurePlate
var _plate_b: PressurePlate
var _gates_open := false
var _solved := false
var _chains: Array[MeshInstance3D] = []
var _monster: Sprite3D
var _monster_light: OmniLight3D
var _riddle_heard := false
var _fails := 0
var _white_phase := false
var _memories_found := 0
var _memory_nodes: Array[Node3D] = []
var _memory_its: Array[Interactable] = []
var _light_door: Node3D
var _drip_t := 2.0
var _far_view := false
const VIEW_NEAR := Vector3(0, 7.2, 8.6)
const VIEW_FAR := Vector3(0, 8.6, 11.8)


func _init() -> void:
	chapter_index = 7
	preset = "dungeon"
	ambience = "amb_dungeon"
	spawn_a = Vector3(-4, 0, 8)
	spawn_b = Vector3(4, 0, 8)
	cam_bounds = Rect2(-7, -21, 14, 29)


func _build() -> void:
	_dungeon = Node3D.new()
	_dungeon.name = "Dungeon"
	geo.add_child(_dungeon)
	_white = Node3D.new()
	_white.name = "White"
	_white.visible = false
	geo.add_child(_white)
	_build_dungeon()
	_build_white()


# --- Masmorra -----------------------------------------------------------------------

func _build_dungeon() -> void:
	var D := _dungeon
	var stone := Build.mat("dungeon_stone", Color(1, 1, 1), 2.0)
	var wall_m := Build.mat("stone_wall", Color(0.8, 0.8, 0.85), 2.5)
	var iron := Build.color_mat(Color("2a2c30"), 0.0, 0.45)
	Build.ground(D, Rect2(-12, -26, 24, 38), 0.0, stone, "stone")

	# Bloco central entre os dois corredores.
	Build.box(D, Vector3(4, 3.6, 19.5), Vector3(0, 1.8, 0.75), wall_m)

	# Celas dos dois lados (paredes do fundo, grades e divisórias de grade).
	for side in [-1.0, 1.0]:
		var bx: float = side * 11.0
		Build.box(D, Vector3(0.4, 3.6, 19.5), Vector3(bx, 1.8, 0.75), wall_m)
		_bars(D, Vector3(side * 6.0, 0, -9.0), Vector3(side * 6.0, 0, 10.4), 3.2, iron)
		for z in [-4.4, 0.8, 5.8]:
			_bars(D, Vector3(side * 6.0, 0, z), Vector3(side * 10.8, 0, z), 3.2, iron)
		# Parede norte das celas (fecha a frente do salão).
		Build.box(D, Vector3(5.0, 3.6, 0.4), Vector3(side * 8.5, 1.8, GATE_Z), wall_m)
		# Palha e objetos de cela.
		for z in [-6.5, -1.5, 3.4, 8.2]:
			Build.box(D, Vector3(1.8, 0.12, 1.2), Vector3(side * 9.2, 0.06, z), Build.mat("dirt", Color(1.1, 0.95, 0.6), 1.0), false)
			Build.box(D, Vector3(0.12, 0.8, 0.12), Vector3(side * 10.7, 2.4, z + 0.5), iron, false)
			Build.box(D, Vector3(0.12, 0.8, 0.12), Vector3(side * 10.7, 2.4, z - 0.5), iron, false)
			_chain(D, Vector3(side * 10.75, 2.0, z + 0.5), Vector3(side * 10.3, 0.1, z + 0.9), false)
		Build.omni(D, Vector3(side * 8.5, 2.6, -1.0), Color("6d86ad"), 0.5, 9.0)
		Build.candle(D, Vector3(side * 7.0, 0.0, 8.8), 0.6, 3.0)
		Build.billboard(D, "cobweb", Vector3(side * 10.4, 2.6, -8.4), 0.04)
		Build.billboard(D, "cobweb", Vector3(side * 10.4, 2.6, 9.6), 0.035)
	Build.billboard(D, "corpse", Vector3(-9.0, 0.02, -2.0), 0.035)
	Build.cylinder(D, 0.25, 0.4, Vector3(9.8, 0.2, 3.0), Build.mat("planks_dark"), false)
	Build.cylinder(D, 0.22, 0.5, Vector3(-10.0, 0.25, 6.8), Build.mat("rust_metal"), false)

	# Limites.
	Build.blocker(D, Vector3(24, 4, 1), Vector3(0, 2, 11.2))
	Build.box(D, Vector3(24, 0.6, 0.3), Vector3(0, 0.3, 10.9), wall_m, false)
	Build.blocker(D, Vector3(1, 4, 40), Vector3(-11.8, 2, -6))
	Build.blocker(D, Vector3(1, 4, 40), Vector3(11.8, 2, -6))

	# Tochas nos corredores.
	for z in [6.5, 0.5, -5.5]:
		Build.torch(D, Vector3(-2.15, 1.8, z), 1.4, 6.5)
		Build.torch(D, Vector3(2.15, 1.8, z), 1.4, 6.5)

	# Placas e grades.
	_plate_a = plate(Vector3(-4, 0, -6.6))
	_plate_b = plate(Vector3(4, 0, -6.6))
	_plate_a.changed.connect(_on_plate)
	_plate_b.changed.connect(_on_plate)
	for x in [-4.0, 4.0]:
		var gate := Build.mover(D, Vector3(4.0, 3.2, 0.2), Vector3(x, 1.6, GATE_Z), Vector3(0, -3.3, 0), Build.color_mat(Color(0, 0, 0, 0)))
		gate.sound = "gate_open"
		gate.time = 2.2
		for i in 13:
			Build.box(gate, Vector3(0.07, 3.2, 0.07), Vector3(-1.8 + i * 0.3, 0, 0), iron, false)
		for y in [-1.2, 0.2, 1.5]:
			Build.box(gate, Vector3(4.0, 0.09, 0.1), Vector3(0, y, 0), iron, false)
		_gates.append(gate)
		Build.box(D, Vector3(4.4, 0.5, 0.5), Vector3(x, 3.45, GATE_Z), wall_m, false)
	Build.text3d(D, "JUNTOS, OU NUNCA", Vector3(-4, 3.45, GATE_Z + 0.27), 0.0, 36, Color("b8ad96"))
	Build.text3d(D, "JUNTOS, OU NUNCA", Vector3(4, 3.45, GATE_Z + 0.27), 0.0, 36, Color("b8ad96"))

	# Pistas separadas: rabisco no lado de A, diário de prisioneiro no lado de B.
	doc(Vector3(-5.6, 0.6, 3.0), {
		"id": "ch8_rabisco",
		"title": "Rabisco na grade",
		"body": "[center]Arranhado no ferro, com as unhas:\n\n[i]\"Ele pergunta uma vez.\nQuem responde errado fica para fazer companhia.\"[/i][/center]",
		"style": "stone",
	}, "Examinar arranhões", "any", 1.3)
	Build.flat_sprite(D, "icon_hand", Vector3(-5.85, 1.2, 3.0), Vector3(0, 90, 0), 0.03, Color(0.8, 0.7, 0.6))
	doc(Vector3(5.2, 0.05, -2.0), {
		"id": "ch8_prisioneiro",
		"title": "Página de um prisioneiro",
		"body": "Contei as tochas, uma por uma, até a última se apagar.\n\nDepois disso, ela só crescia.\n\nE quanto mais dela havia, menos eu enxergava.",
		"style": "paper",
	}, "Pegar página")
	Build.flat_sprite(D, "icon_note", Vector3(5.2, 0.03, -2.0), Vector3(-90, -15, 0), 0.03)

	# --- Salão da esfinge.
	Build.box(D, Vector3(22, 3.8, 0.4), Vector3(0, 1.9, -25.2), wall_m)
	Build.box(D, Vector3(0.4, 3.8, 16), Vector3(-11, 1.9, -17), wall_m)
	Build.box(D, Vector3(0.4, 3.8, 16), Vector3(11, 1.9, -17), wall_m)
	for x in [-7.5, 7.5]:
		Build.cylinder(D, 0.5, 3.8, Vector3(x, 1.9, -13.5), wall_m, true, 10)
		Build.cylinder(D, 0.5, 3.8, Vector3(x, 1.9, -21.5), wall_m, true, 10)
	# Estrado e esfinge.
	Build.box(D, Vector3(7, 0.3, 5), Vector3(0, 0.15, -20.5), Build.mat("stone_path", Color(0.7, 0.7, 0.72)), true, 0.0, "stone")
	Build.blocker(D, Vector3(3.6, 4, 2.4), Vector3(0, 2, -20.2))
	_monster = Build.billboard(D, "monster", MONSTER, 0.03, 2)
	var anim := SpriteAnim.new()
	anim.frames = 2
	anim.fps = 1.4
	_monster.add_child(anim)
	_monster_light = Build.omni(D, Vector3(0, 2.6, -16.8), Color("b8433a"), 1.2, 7.5, false, true)
	# Correntes: das paredes e argolas do chão até a criatura.
	var ms := MONSTER
	_chain(D, Vector3(-6.0, 3.4, -24.9), ms + Vector3(-1.35, 0.5, 0.2))
	_chain(D, Vector3(6.0, 3.4, -24.9), ms + Vector3(1.35, 0.5, 0.2))
	_chain(D, Vector3(-3.2, 0.32, -17.8), ms + Vector3(-0.8, 0.35, 0.25))
	_chain(D, Vector3(3.2, 0.32, -17.8), ms + Vector3(0.8, 0.35, 0.25))
	_chain(D, Vector3(0, 3.7, -25.0), ms + Vector3(0, 3.1, 0.1))
	for p in [Vector3(-6.0, 3.4, -24.95), Vector3(6.0, 3.4, -24.95), Vector3(-3.2, 0.32, -17.8), Vector3(3.2, 0.32, -17.8)]:
		Build.sphere(D, 0.14, p, iron)
	# Tochas, ossos e poças.
	for x in [-9.0, -3.5, 3.5, 9.0]:
		Build.torch(D, Vector3(x, 2.0, -24.8), 1.5, 7.0)
	Build.torch(D, Vector3(-10.7, 2.0, -15.0), 1.2, 6.0)
	Build.torch(D, Vector3(10.7, 2.0, -15.0), 1.2, 6.0)
	Build.billboard(D, "corpse", Vector3(-5.5, 0.02, -18.0), 0.03)
	var corpse2 := Build.billboard(D, "corpse", Vector3(6.2, 0.02, -22.5), 0.03)
	corpse2.flip_h = true
	for i in 10:
		var bone := Build.box(D, Vector3(0.35, 0.06, 0.07), Vector3(rng.randf_range(-8, 8), 0.04, rng.randf_range(-23, -15)), Build.color_mat(Color("cfc6ae")), false)
		bone.rotation_degrees.y = rng.randf_range(0, 180)
	for r in [Rect2(-4.2, -2.0, 1.6, 1.1), Rect2(2.6, 4.4, 1.8, 1.2), Rect2(-9.5, -15.5, 2.2, 1.4), Rect2(5.0, -13.5, 1.8, 1.0)]:
		Build.water(D, r, 0.02)
	Build.motes(D, Vector3(0, 1.6, -8), Vector3(10, 1.5, 17), 70, Color(1.0, 0.8, 0.6, 0.5), "dust", 0.04)

	interact(MONSTER + Vector3(0, 0, 2.6), "Encarar a criatura", _on_monster, "any", 2.4, true, 1.6)


## Fileira de barras de ferro entre dois pontos do chão.
func _bars(parent: Node3D, a: Vector3, b: Vector3, h: float, m: Material) -> void:
	var n := int(a.distance_to(b) / 0.32)
	for i in n + 1:
		var p := a.lerp(b, float(i) / max(n, 1))
		Build.box(parent, Vector3(0.06, h, 0.06), p + Vector3(0, h / 2.0, 0), m, false)
	var mid := (a + b) / 2.0
	var length := a.distance_to(b)
	var ang := rad_to_deg(atan2(-(b - a).z, (b - a).x))
	for y in [0.1, h - 0.1]:
		Build.box(parent, Vector3(length, 0.08, 0.1), mid + Vector3(0, y, 0), m, false, ang)
	Build.box(parent, Vector3(length, h, 0.2), mid + Vector3(0, h / 2.0, 0), Build.color_mat(Color(0, 0, 0, 0)), true, ang)


## Corrente de elos de `a` até `b`. Se `breakable`, os elos caem quando as correntes se partem.
func _chain(parent: Node3D, a: Vector3, b: Vector3, breakable := true) -> void:
	var d := b - a
	var n := int(d.length() / 0.2)
	var m := Build.color_mat(Color("3d3f44"), 0.0, 0.35)
	var up := Vector3.UP if abs(d.normalized().y) < 0.95 else Vector3.RIGHT
	for i in n:
		var link := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.05, 0.22)
		link.mesh = bm
		link.material_override = m
		var p := a.lerp(b, (i + 0.5) / n)
		var bs := Basis.looking_at(d.normalized(), up)
		bs = bs.rotated(d.normalized(), PI / 2.0 if i % 2 == 0 else 0.0)
		link.transform = Transform3D(bs, p)
		parent.add_child(link)
		if breakable:
			_chains.append(link)


func _process(delta: float) -> void:
	if _white_phase:
		return
	if party and party.active and cam.target == party.active:
		var far := party.active.global_position.z < GATE_Z - 0.5
		if far != _far_view:
			_far_view = far
			cam.set_view(VIEW_FAR if far else VIEW_NEAR, -1.0, 1.4)
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = randf_range(2.5, 6.0)
		if party and party.active:
			Audio.sfx("drip", randf_range(-20.0, -12.0), randf_range(0.85, 1.15))


func _begin() -> void:
	objective("Desçam pela masmorra.")
	await say([
		"a: Que frio... tem água pingando do teto.",
		"b: %s? Estou do outro lado desta parede. Tem celas aqui." % Game.name_a,
		"a: Aqui também. E correntes. Muitas correntes.",
		"Algo grande se arrasta mais à frente. Metal raspando pedra.",
		"b: Seja o que for, a gente enfrenta junto.",
	])
	objective("Sigam pelos corredores até as grades ao norte.")
	hints([
		"Há uma placa no chão diante de cada grade.",
		"As duas placas precisam de peso ao mesmo tempo: uma para cada um.",
		"Deixe %s sobre uma placa, troque de personagem e pise na outra." % Game.name_b,
	])


func _on_plate(_pressed: bool) -> void:
	if _gates_open:
		return
	if _plate_a.pressed and _plate_b.pressed:
		_open_gates()
	elif (_plate_a.pressed or _plate_b.pressed) and not Game.get_flag("ch8_plate_hint"):
		Game.set_flag("ch8_plate_hint")
		Audio.sfx("chain_rattle", -12.0)
		Ui.toast("A placa afunda, mas a grade não se move.")


func _open_gates() -> void:
	_gates_open = true
	Game.lock_input()
	await get_tree().create_timer(0.4).timeout
	for g in _gates:
		g.open()
	cam.shake(0.4)
	await get_tree().create_timer(1.6).timeout
	await cam.look_at_point(MONSTER + Vector3(0, 1.2, 1.5), 1.8)
	Audio.sfx("chain_rattle", 0.0)
	cam.shake(0.5)
	await get_tree().create_timer(0.9).timeout
	Audio.sfx("monster_growl", 0.0)
	cam.shake(1.0)
	var t := create_tween()
	t.tween_property(_monster_light, "light_energy", 2.6, 0.4)
	t.tween_property(_monster_light, "light_energy", 1.2, 1.2)
	await get_tree().create_timer(1.2).timeout
	await say([
		"a: O que é... aquilo?",
		"b: Está acorrentado. Não se mexa rápido.",
		"A criatura ergue a cabeça. A voz não sai da boca: sai das paredes.",
		"\"Dois. Faz tanto tempo que não vêm dois.\"",
		"\"Cheguem perto. Os dois. Tenho uma pergunta.\"",
	])
	cam.target = party.active
	Game.unlock_input()
	objective("Aproximem-se da criatura. Os dois.")
	hints([
		"A criatura só fala com os dois perto dela.",
		"Pense no que cresce quando a última tocha se apaga.",
		"A resposta é ESCURIDÃO.",
	])


func _on_monster(ch: Character) -> void:
	if _solved:
		return
	if not _gates_open:
		return
	if not party.both_near(MONSTER, 7.5):
		await say([ch.who + ": Não vou encarar isso sem %s." % Game.char_name("b" if ch.who == "a" else "a")])
		return
	if not _riddle_heard:
		_riddle_heard = true
		Audio.sfx("monster_growl", -6.0, 0.8)
		cam.shake(0.3)
		await say([
			"\"Uma pergunta. Uma resposta. É só isso que eu peço.\"",
			RIDDLE,
			"b: %s... ela está olhando para nós dois." % Game.name_a,
		])
	var lock := SphinxLock.new("A Esfinge", ANSWERS, RIDDLE, [
		"Pense no que acontece quando as tochas se apagam.",
		"Quanto mais dela existe, menos os seus olhos alcançam.",
		"A resposta é ESCURIDÃO.",
	])
	lock.placeholder = "responda"
	lock.on_fail = func(): _fails += 1
	var before := _fails
	var ok := await puzzle(lock)
	if ok:
		_break_chains()
		return
	# Fechou sem acertar: a criatura ameaça (sem game over).
	Audio.sfx("monster_growl", 0.0, 0.9)
	Audio.sfx("chain_rattle", -4.0)
	cam.shake(0.8)
	if _fails > before:
		await say(["\"Errado. As correntes estão ficando frouxas... e eu estou com fome.\""])
	else:
		await say(["\"Fugir não é resposta. A porta daqui só abre para dentro.\""])


func _break_chains() -> void:
	_solved = true
	Game.lock_input()
	await cam.look_at_point(MONSTER + Vector3(0, 1.2, 1.5), 1.2)
	await say([
		"\"...Escuridão.\"",
		"Pela primeira vez, a criatura não parece faminta. Parece triste.",
		"\"Então vocês já sabem onde estão.\"",
	])
	Audio.sfx("chain_rattle", 2.0)
	Audio.sfx("monster_growl", 0.0, 0.7)
	cam.shake(1.4)
	for link in _chains:
		var t := create_tween().set_parallel()
		var drop := Vector3(link.position.x + randf_range(-0.5, 0.5), 0.35 + randf_range(0.0, 0.08), link.position.z + randf_range(-0.5, 0.5))
		t.tween_property(link, "position", drop, randf_range(0.45, 0.9)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(link, "rotation", Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI)), 0.8)
	await get_tree().create_timer(1.0).timeout
	Audio.sfx("flash", 0.0)
	Ui.flash(Color.WHITE, 1.4)
	var fade := create_tween().set_parallel()
	fade.tween_property(party.b.sprite, "modulate:a", 0.0, 1.2)
	fade.tween_property(_monster, "modulate:a", 0.0, 1.2)
	await get_tree().create_timer(1.4).timeout
	await say([
		"a: %s?" % Game.name_b,
		"a: %s! Onde você está?!" % Game.name_b,
	])
	Audio.stop_ambience(2.5)
	Audio.sfx("flash", -2.0, 0.8)
	await Ui.whiteout(2.5)
	_enter_white()
	await get_tree().create_timer(1.2).timeout
	await Ui.clear_whiteout(3.0)
	Game.unlock_input()
	await say([
		"Branco. Silêncio. Nem o eco responde.",
		"a: %s?" % Game.name_b,
		"Não há ninguém para chamar.",
		"Pequenas luzes flutuam no branco. Uma delas pulsa como um coração.",
	])
	objective("Junte as lembranças que flutuam no branco. (0/3)")
	hints([
		"Aproxime-se das luzes que flutuam.",
		"São três lembranças. Toque cada uma.",
		"Com as três, siga a porta de luz ao norte.",
	])


# --- Fase branca --------------------------------------------------------------------

func _build_white() -> void:
	var P := _white
	var marble := Build.mat("marble_white", Color(0.86, 0.88, 0.92), 3.0, 0.4)
	var pale := Build.mat("marble_white", Color(0.62, 0.66, 0.72), 1.5, 0.4)
	var frame_m := Build.mat("marble_white", Color(0.45, 0.48, 0.56), 1.0, 0.4)
	Build.ground(P, Rect2(W.x - 16, -22, 32, 36), 0.0, marble, "stone")
	# Degraus e colunas partidas, como ruínas de um sonho.
	for i in 8:
		var ang := float(i) / 8.0 * TAU
		var r := 11.0 + rng.randf_range(-1.0, 1.5)
		var p := W + Vector3(cos(ang) * r, 0, sin(ang) * r * 0.8 - 4.0)
		if p.z > 9.0 or abs(p.x - W.x) < 3.5:
			continue
		var h := rng.randf_range(1.2, 4.2)
		Build.cylinder(P, 0.45, h, p + Vector3(0, h / 2.0, 0), pale, true, 12)
		Build.box(P, Vector3(1.2, 0.25, 1.2), p + Vector3(0, 0.12, 0), pale, false)
	# Caminho de lajes até o norte.
	for i in 11:
		var slab := Build.box(P, Vector3(1.5, 0.05, 1.5), W + Vector3(rng.randf_range(-0.2, 0.2), 0.025, 7.0 - i * 2.0), pale, false)
		slab.rotation_degrees.y = rng.randf_range(-8, 8)
	for i in 3:
		Build.box(P, Vector3(6.0 - i * 1.2, 0.18, 1.0), W + Vector3(0, 0.09 + i * 0.18, -15.2 - i * 0.9), pale, false)
	# Árvores pálidas e flores brancas.
	for x in [-13.0, -10.5, 10.5, 13.0, -12.0, 12.2]:
		Build.tree(P, "tree_dead", W + Vector3(x, 0, rng.randf_range(-18, -6)), rng.randf_range(0.9, 1.2), true, Color(1.6, 1.6, 1.7))
	Build.scatter(P, ["flower_white", "flower_white", "grass", "fern"], Rect2(W.x - 14, -20, 28, 30), 150, 0.0, rng, [Rect2(W.x - 1.8, -20, 3.6, 30)], 0.035, Color(1.3, 1.3, 1.35))
	Build.motes(P, W + Vector3(0, 1.5, -5), Vector3(13, 1.5, 14), 110, Color(1.0, 0.95, 0.85, 0.8), "dust", 0.05)
	Build.motes(P, W + Vector3(0, 2.0, -5), Vector3(12, 2.0, 12), 40, Color(1.0, 0.92, 0.75, 0.9), "glow", 0.18)
	Build.omni(P, W + Vector3(0, 3.0, 2), Color("fff1dc"), 0.25, 10.0)
	# Limites.
	Build.blocker(P, Vector3(34, 4, 1), W + Vector3(0, 2, 10.5))
	Build.blocker(P, Vector3(34, 4, 1), W + Vector3(0, 2, -21))
	Build.blocker(P, Vector3(6, 4, 1), W + Vector3(0, 2, -15.4))
	Build.blocker(P, Vector3(1, 4, 34), W + Vector3(-15.5, 2, -5))
	Build.blocker(P, Vector3(1, 4, 34), W + Vector3(15.5, 2, -5))

	# Lembranças.
	for i in MEMORIES.size():
		var m: Dictionary = MEMORIES[i]
		var root := Node3D.new()
		root.position = W + (m["pos"] as Vector3)
		P.add_child(root)
		var ring := Build.flat_sprite(root, "glow", Vector3(0, 0.03, 0), Vector3(-90, 0, 0), 0.035, Color(1.0, 0.62, 0.2, 0.55))
		ring.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		ring.transparent = true
		ring.shaded = false
		var orb := Build.billboard(root, "glow", Vector3(0, 1.0, 0), 0.022, 1, 0, Color(1.0, 0.6, 0.18, 1.0), false)
		orb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		orb.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		orb.transparent = true
		var core := Build.sphere(root, 0.24, Vector3(0, 1.45, 0), Build.color_mat(Color(1.0, 0.55, 0.12), 1.6))
		Build.omni(root, Vector3(0, 1.5, 0), Color("ffb060"), 1.6, 4.5)
		Build.motes(root, Vector3(0, 1.3, 0), Vector3(0.7, 0.7, 0.7), 16, Color(1.0, 0.55, 0.15, 1.0), "firefly", 0.07)
		var bob := root.create_tween().set_loops()
		bob.tween_property(orb, "position:y", 1.25, 1.6 + i * 0.2).set_trans(Tween.TRANS_SINE)
		bob.parallel().tween_property(core, "position:y", 1.7, 1.6 + i * 0.2).set_trans(Tween.TRANS_SINE)
		bob.tween_property(orb, "position:y", 1.0, 1.6 + i * 0.2).set_trans(Tween.TRANS_SINE)
		bob.parallel().tween_property(core, "position:y", 1.45, 1.6 + i * 0.2).set_trans(Tween.TRANS_SINE)
		_memory_nodes.append(root)
		var it := interact(root.position, "Tocar a lembrança", _on_memory.bind(i), "a", 1.6, false)
		it.reparent(P)
		_memory_its.append(it)

	# Porta de luz (aparece depois das três lembranças).
	_light_door = Node3D.new()
	_light_door.position = W + Vector3(0, 0.54, -17.8)
	_light_door.visible = false
	P.add_child(_light_door)
	Build.box(_light_door, Vector3(0.35, 3.6, 0.35), Vector3(-1.1, 1.8, 0), frame_m, false)
	Build.box(_light_door, Vector3(0.35, 3.6, 0.35), Vector3(1.1, 1.8, 0), frame_m, false)
	Build.box(_light_door, Vector3(2.6, 0.35, 0.4), Vector3(0, 3.7, 0), frame_m, false)
	Build.box(_light_door, Vector3(1.85, 3.4, 0.08), Vector3(0, 1.7, 0), Build.color_mat(Color(1.0, 0.72, 0.35), 1.1), false)
	var halo := Build.billboard(_light_door, "glow", Vector3(0, 0.2, 0.3), 0.07, 1, 0, Color(1.0, 0.7, 0.3, 0.8), false)
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	halo.transparent = true
	Build.omni(_light_door, Vector3(0, 1.8, 1.2), Color("ffc890"), 0.7, 6.0)
	Build.motes(_light_door, Vector3(0, 1.8, 0.8), Vector3(1.6, 1.8, 1.0), 40, Color(1, 0.95, 0.8, 1), "dust", 0.06)
	var door_it := interact(_light_door.position + Vector3(0, 0, 1.6), "Atravessar a luz", _on_light_door, "a", 1.8, true, 2.2)
	door_it.reparent(P)
	door_it.disable()
	_light_door.set_meta("it", door_it)


func _apply_preset(preset_name: String) -> void:
	var p: Dictionary = PRESETS[preset_name]
	env.background_color = p["bg"]
	env.ambient_light_color = p["ambient"]
	env.ambient_light_energy = p["ambient_e"]
	env.tonemap_exposure = p["exposure"]
	env.fog_light_color = p["fog"]
	env.fog_density = p["fog_d"]
	env.volumetric_fog_density = p["vol"]
	env.volumetric_fog_albedo = p["vol_albedo"]
	env.adjustment_saturation = p["sat"]
	moon.light_color = p["moon"]
	moon.light_energy = p["moon_e"]
	moon.shadow_enabled = p["moon_e"] > 0.0
	moon.visible = p["moon_e"] > 0.0
	if preset_name == "white":
		# O preset puro estoura para branco (ambiente 1,1 + sol 1,1); suaviza para
		# as formas e as lembranças aparecerem.
		env.ambient_light_energy = 0.4
		env.fog_density = 0.004
		env.tonemap_exposure = 0.95
		moon.light_energy = 0.6
		Ui.set_screen_fx(0.45, 0.02, Color(0.55, 0.6, 0.68))
	else:
		Ui.set_screen_fx(0.6, 0.045, Color(0.0, 0.02, 0.06))


func _enter_white() -> void:
	_white_phase = true
	_apply_preset("white")
	Audio.ambience("amb_white", 3.0)
	_dungeon.visible = false
	_white.visible = true
	party.solo("a")
	party.a.teleport(W + Vector3(0, 0, 7))
	party.a.face("up")
	cam.offset = VIEW_NEAR
	cam.bounds = Rect2(W.x - 9, -16, 18, 22)
	cam.target = party.a
	cam.snap()


func _unhandled_input(event: InputEvent) -> void:
	if _white_phase and event.is_action_pressed("switch") and Game.can_control():
		get_viewport().set_input_as_handled()
		Ui.toast("Não há ninguém para chamar.")


func _on_memory(ch: Character, i: int) -> void:
	var root := _memory_nodes[i]
	if root.has_meta("taken"):
		return
	root.set_meta("taken", true)
	_memory_its[i].disable()
	Audio.sfx("music_box", -8.0, 1.0 + i * 0.06)
	var t := create_tween().set_parallel()
	t.tween_property(root, "position", ch.global_position + Vector3(0, 0.4, 0), 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(root, "scale", Vector3(0.2, 0.2, 0.2), 1.2)
	await t.finished
	root.visible = false
	var line: String = MEMORIES[i]["line"]
	Game.add_doc("a", {
		"id": "ch8_lembranca_%d" % (i + 1),
		"title": "Lembrança",
		"body": "[center][i]\"%s\"[/i]\n\n— %s[/center]" % [line, Game.name_b],
		"style": "hand",
	})
	_memories_found += 1
	var lines := ["b: " + line]
	match _memories_found:
		1:
			lines.append("a: A voz dele... vem de todo lugar.")
			lines.append("?: Acorde...")
		2:
			lines.append("a: Eu não lembro de ter esquecido. Só lembro de doer.")
			lines.append("?: Acorde...")
		3:
			lines.append("?: Acorde...")
			lines.append("Ao norte, o branco se abre numa porta de luz.")
	await say(lines)
	objective("Junte as lembranças que flutuam no branco. (%d/3)" % _memories_found)
	if _memories_found >= MEMORIES.size():
		_open_light_door()


func _open_light_door() -> void:
	objective("Atravesse a porta de luz.")
	_light_door.visible = true
	_light_door.scale = Vector3(1, 0.01, 1)
	Audio.sfx("bell", -4.0)
	var t := create_tween()
	t.tween_property(_light_door, "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(_light_door.get_meta("it") as Interactable).enable()


func _on_light_door(ch: Character) -> void:
	Game.lock_input()
	await ch.walk_to(_light_door.position + Vector3(0, 0, 3.0), 1.6)
	ch.face("up")
	await say(["?: Acorde..."])
	Audio.sfx("flash", 0.0)
	await Ui.whiteout(2.2)
	await Ui.fade_out(1.2)
	Ui.clear_whiteout(0.05)
	finish()


# --- Depuração (tools/shot.sh --call=...) --------------------------------------------

func _debug_gates() -> void:
	_gates_open = true
	for g in _gates:
		g.set_open(true, true)
	party.a.teleport(Vector3(-2.5, 0, -14))
	party.b.teleport(Vector3(2.5, 0, -14))
	party.activate("a", true)
	cam.snap()


func _debug_monster() -> void:
	_debug_gates()
	party.a.teleport(Vector3(-1.8, 0, -16.5))
	party.b.teleport(Vector3(1.8, 0, -16.5))
	_far_view = true
	cam.offset = VIEW_FAR
	cam.snap()


func _debug_white() -> void:
	_solved = true
	_enter_white()


func _debug_white_mid() -> void:
	_debug_white()
	party.a.teleport(W + Vector3(-2.5, 0, 1.5))
	cam.snap()


func _debug_door() -> void:
	_debug_white()
	for i in _memory_nodes.size():
		_memory_nodes[i].visible = false
		_memory_nodes[i].set_meta("taken", true)
	for it in _memory_its:
		it.disable()
	_memories_found = 3
	_open_light_door()
	party.a.teleport(W + Vector3(0.8, 0, -12.5))
	cam.offset = Vector3(0, 8.0, 11.0)
	cam.snap()
