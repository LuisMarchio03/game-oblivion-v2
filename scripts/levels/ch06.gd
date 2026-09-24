extends LevelBase
## Capítulo 6 — O Sótão (enigma 6 original, texto reescrito).
## O sótão da casa da família de B, dividido ao meio por uma parede de tábuas. A tem a carta
## e o código da canção; B tem a canção e o código da carta. Linha = número da linha;
## número = posição da letra (só letras). Porta de A: MEDO. Porta de B: NOME.
## Terror: passos e arranhões do outro lado da parede; desenhos infantis de duas crianças de
## mãos dadas (do lado de B, um deles foi coberto de azul e só sobrou uma); a voz falsa de B pela
## parede depois que A lê a carta (B nega quando o jogador volta para B); na primeira porta
## aberta, um apagão com o Esquecido parado num canto, que some quando a luz volta; luzes de
## erro nas duas fechaduras; vozes do hospital; lembrança m6 atrás do armário coberto (lado A).

const LETTER := [
	"A noite caiu depressa e a escuridão ficou tão densa que eu mal conseguia respirar",
	"Escrevo esta carta na esperança de que você volte para me buscar",
	"Estou perdido numa floresta escura e não reconheço nenhum caminho",
	"Algo terrível se esconde nas sombras e sussurra o meu nome todas as noites",
]
const SONG := [
	"Dorme criança que a lua já vem",
	"Fecha os olhos e não conte a ninguém",
	"O que se esconde debaixo da cama",
	"Espera acordado e chama por quem ama",
]

var _doors := {}
var _opened := {"a": false, "b": false}
var _landed := {"a": false, "b": false}
var _door_lights := {"a": [], "b": []}
var _scratch: Node3D            # de onde vêm os passos atrás da parede
var _fake_done := false         # A ouviu a voz que imita B
var _denied := false            # B verdadeiro já negou
var _bleed_done := false
var _blackout_done := false
var _dark := false
var _drawings_seen := 0

const MEMORY_POS := Vector3(-8.0, 0, -0.8)


func _init() -> void:
	chapter_index = 5
	preset = "attic"
	ambience = "amb_attic"
	spawn_a = Vector3(-4.5, 0, 2.6)
	spawn_b = Vector3(4.5, 0, 2.6)
	cam_bounds = Rect2(-6, -8, 12, 10)


func _build() -> void:
	var floor_mat := Build.mat("wood_floor", Color(1, 1, 1), 2.0)
	var wall_mat := Build.mat("wallpaper_stripes", Color(1, 1, 1), 2.0)
	Build.room(geo, Rect2(-9, -8, 18, 12), 0.0, 3.6, floor_mat, wall_mat,
		[{"side": "n", "at": 5.0, "width": 1.3}, {"side": "n", "at": 13.0, "width": 1.3}],
		Build.mat("ceiling_wood"), "wood", false)
	# Divisória central: tábuas, caixas e lençóis.
	Build.box(geo, Vector3(0.35, 3.6, 12), Vector3(0, 1.8, -2), Build.mat("planks_dark", Color(1, 1, 1), 1.5), true)
	for z in [-7.0, -3.5, 0.5, 3.4]:
		Build.box(geo, Vector3(1.2, 0.9, 0.9), Vector3(-0.8, 0.45, z), Build.mat("wood_wall"), true, 8.0)
		Build.box(geo, Vector3(1.0, 0.7, 0.8), Vector3(0.75, 0.35, z + 1.0), Build.mat("wood_wall"), true, -6.0)
	# Vigas encostadas nas paredes (não passam na frente da câmera).
	for x in [-8.7, 8.7]:
		for z in [-6.0, -2.0, 2.0]:
			Build.box(geo, Vector3(0.25, 3.6, 0.25), Vector3(x, 1.8, z), Build.mat("bark"), true)

	# Alçapões de chegada.
	for x in [-4.5, 4.5]:
		Build.box(geo, Vector3(1.3, 0.03, 1.3), Vector3(x, 0.015, 3.2), Build.color_mat(Color("0a0806")), false)

	# Portas ao norte e patamares atrás delas.
	var door_mat := Build.mat("planks_dark", Color(0.9, 0.95, 1.1), 1.0)
	for who in ["a", "b"]:
		var x := -4.0 if who == "a" else 4.0
		_doors[who] = Build.door(geo, Vector3(x, 0, -8.0), 0.0, door_mat, 1.2, 2.4)
		Build.ground(geo, Rect2(x - 1.2, -11, 2.4, 3.0), 0.0, floor_mat, "wood")
		Build.box(geo, Vector3(0.3, 3.6, 3.0), Vector3(x - 1.35, 1.8, -9.5), wall_mat, true)
		Build.box(geo, Vector3(0.3, 3.6, 3.0), Vector3(x + 1.35, 1.8, -9.5), wall_mat, true)
		Build.box(geo, Vector3(2.4, 3.6, 0.3), Vector3(x, 1.8, -11.1), wall_mat, true)
		Build.omni(geo, Vector3(x, 1.2, -10.3), Color("3b5b92"), 0.8, 3.0)
		var landing := zone(Vector3(x, 1, -9.8), Vector3(2.0, 2, 1.8), _on_landing.bind(who), false)
		landing.name = "Landing_" + who
	Build.blocker(geo, Vector3(18, 4, 0.5), Vector3(0, 2, 4.3))

	# Quadro de exemplo nos dois lados.
	var example := {
		"id": "ch6_quadro",
		"title": "Quadro de giz",
		"body": "[center]ITS COLD HERE\nDONT LEAVE ME\n\n[color=#c0303a]2 = 4[/color]  =  [color=#c0303a]T[/color]\n\nlinha = letra\n(espaços não contam)[/center]",
		"style": "screen",
	}
	for side in [-1.0, 1.0]:
		Build.box(geo, Vector3(0.06, 1.2, 1.8), Vector3(side * 0.21, 1.6, -5.2), Build.color_mat(Color("1d2a24")), false)
		var t := Build.text3d(geo, "ITS COLD HERE\nDONT LEAVE ME\n2 = 4 = T", Vector3(side * 0.25, 1.6, -5.2), 90.0 if side > 0 else -90.0, 40, Color("dfe8e0"), UiTheme.FONT_UI, 0.006)
		t.rotation_degrees.y = 90.0 if side > 0 else -90.0
		t.shaded = false
		doc(Vector3(side * 0.9, 0.5, -5.2), example, "Ler o quadro")

	# --- Lado A: carta emoldurada e placa com o código da canção.
	_frame(Vector3(-7.5, 1.7, -7.84), Color("2c3e5e"))
	doc(Vector3(-7.5, 0.5, -7.1), {
		"id": "ch6_carta",
		"title": "Carta emoldurada",
		"body": _numbered(LETTER),
		"style": "blue",
	}, "Ler a carta", "a")
	_plaque(Vector3(-5.6, 1.5, -7.84), "1=4\n2=21\n3=14\n4=22")
	doc(Vector3(-5.6, 0.5, -7.1), {
		"id": "ch6_placa_a",
		"title": "Placa ao lado da porta",
		"body": "[center][font_size=64]1 = 4\n2 = 21\n3 = 14\n4 = 22[/font_size][/center]",
		"style": "screen",
	}, "Examinar a placa", "a")
	interact(Vector3(-4, 0.5, -7.3), "Tentar abrir a porta", _try_door.bind("a"), "a", 1.1)

	# --- Lado B: canção de ninar num desenho infantil e placa com o código da carta.
	_frame(Vector3(7.5, 1.7, -7.84), Color("5e3a2c"))
	doc(Vector3(7.5, 0.5, -7.1), {
		"id": "ch6_cancao",
		"title": "Desenho infantil com uma canção",
		"body": _numbered(SONG),
		"style": "hand",
	}, "Olhar o desenho", "b")
	_plaque(Vector3(5.6, 1.5, -7.84), "1=40\n2=34\n3=49\n4=32")
	doc(Vector3(5.6, 0.5, -7.1), {
		"id": "ch6_placa_b",
		"title": "Placa ao lado da porta",
		"body": "[center][font_size=64]1 = 40\n2 = 34\n3 = 49\n4 = 32[/font_size][/center]",
		"style": "screen",
	}, "Examinar a placa", "b")
	interact(Vector3(4, 0.5, -7.3), "Tentar abrir a porta", _try_door.bind("b"), "b", 1.1)

	# --- Objetos de cena.
	var sheet := Build.color_mat(Color("b9bcc4"))
	Build.box(geo, Vector3(1.6, 1.1, 0.9), Vector3(-7.4, 0.55, -2.5), sheet, true, 10.0)
	Build.box(geo, Vector3(0.9, 1.7, 0.7), Vector3(7.6, 0.85, -3.5), sheet, true, -8.0)
	Build.box(geo, Vector3(1.0, 0.6, 0.6), Vector3(-6.8, 0.3, 1.8), Build.mat("rust_metal"), true, 30.0)
	Build.box(geo, Vector3(0.7, 0.5, 0.5), Vector3(6.9, 0.25, 1.2), Build.mat("wood_wall"), true, -20.0)
	Build.cylinder(geo, 0.35, 0.8, Vector3(3.0, 0.4, -1.0), Build.mat("rust_metal"), true)
	for p in [Vector3(-8.7, 3.0, -7.7), Vector3(8.7, 3.0, -7.7), Vector3(-0.4, 3.0, 3.6), Vector3(0.4, 3.0, -7.7)]:
		Build.billboard(geo, "cobweb", p, 0.04, 1, 0, Color(1, 1, 1, 0.8), false)
	Build.candle(geo, Vector3(-7.4, 1.1, -2.5), 0.9, 4.5)
	Build.candle(geo, Vector3(6.9, 0.5, 1.2), 0.9, 4.5)
	# Janelas redondas com luar.
	for x in [-6.0, 6.0]:
		var win := Build.cylinder(geo, 0.35, 0.1, Vector3(x, 2.6, -7.83), Build.color_mat(Color("4d6a9c"), 0.6), false, 16)
		win.rotation_degrees.x = 90
		var moonbeam := Build.spot(geo, Vector3(x, 2.6, -7.2), Vector3(x * 0.8, 0, -3.5), Color("8fb0ff"), 2.2, 10.0, 28.0, true)
		_door_lights["a" if x < 0 else "b"].append(moonbeam)
	Build.motes(geo, Vector3(0, 1.6, -2), Vector3(8.5, 1.4, 5.5), 90, Color(0.8, 0.85, 1.0, 0.5), "dust", 0.04)
	_build_horror()


func _frame(pos: Vector3, color: Color) -> void:
	Build.box(geo, Vector3(1.3, 1.0, 0.08), pos, Build.color_mat(Color("2a1d14")), false)
	Build.box(geo, Vector3(1.1, 0.8, 0.1), pos + Vector3(0, 0, 0.02), Build.color_mat(color, 0.25), false)


func _plaque(pos: Vector3, text: String) -> void:
	Build.box(geo, Vector3(0.7, 0.8, 0.06), pos, Build.color_mat(Color("0d1a33")), false)
	var l := Build.text3d(geo, text, pos + Vector3(0, 0, 0.05), 0.0, 38, Color("b9c8dc"), UiTheme.FONT_UI, 0.005)
	l.shaded = false


func _numbered(lines: Array) -> String:
	var out := ""
	for i in lines.size():
		out += "%d- %s\n\n" % [i + 1, lines[i]]
	return out


## Letra na posição `pos` (1-based) da linha, contando só letras.
static func letter_at(line: String, pos: int) -> String:
	var only := ""
	for c in line:
		var n := Game.normalize(c)
		if n != "" and not (n >= "0" and n <= "9"):
			only += n
	return only[pos - 1] if pos >= 1 and pos <= only.length() else ""




# --- Terror: desenhos, lembrança, luzes das fechaduras ----------------------------------

func _build_horror() -> void:
	# Caixotes com vela junto das portas: as luzes que o erro apaga, junto do luar da janela.
	var ca := Build.candle(geo, Vector3(-0.8, 0.9, -7.0), 0.9, 4.0)
	var cb := Build.candle(geo, Vector3(0.75, 0.7, -6.0), 0.9, 4.0)
	_door_lights["a"].append(_light_of(ca))
	_door_lights["b"].append(_light_of(cb))
	for side in ["a", "b"]:
		for l in _door_lights[side]:
			dread_light(l, side)
	# Desenhos infantis pregados na parede norte, um par de cada lado.
	_drawing(Vector3(-2.3, 1.5, -7.82), false, 4.0)
	_drawing(Vector3(-1.25, 1.95, -7.82), false, -7.0)
	_drawing(Vector3(2.3, 1.5, -7.82), true, -3.0)
	_drawing(Vector3(1.3, 1.95, -7.82), false, 6.0)
	interact(Vector3(-2.1, 0.5, -7.1), "Olhar os desenhos", _look_drawings, "a", 1.1)
	interact(Vector3(2.1, 0.5, -7.1), "Olhar os desenhos", _look_drawings, "b", 1.1)
	# Origem dos passos e arranhões atrás da parede de tábuas.
	_scratch = Node3D.new()
	_scratch.name = "Arranhoes"
	geo.add_child(_scratch)

	# Lembrança m6: atrás de um armário coberto, numa goteira no canto oeste.
	var sheet := Build.color_mat(Color("b9bcc4"))
	Build.box(geo, Vector3(1.0, 1.9, 0.7), Vector3(-7.9, 0.95, 0.3), sheet, true, 4.0)
	Build.box(geo, Vector3(0.8, 0.12, 0.5), Vector3(-7.9, 1.96, 0.3), sheet, false, -6.0)
	var puddle := Build.color_mat(Color("16283f"), 0.15, 0.05)
	Build.box(geo, Vector3(1.6, 0.01, 0.9), Vector3(-7.45, 0.006, -0.85), puddle, false, 8.0)
	Build.cylinder(geo, 0.2, 0.32, Vector3(-8.55, 0.16, -1.25), Build.mat("rust_metal"), false, 10)
	zone(MEMORY_POS, Vector3(3.0, 2, 2.4), func(ch: Character):
		if ch.who == "a":
			Audio.sfx_at("drip", _scratch, -30.0, 1.0)
			Audio.sfx("drip", -12.0)
		, false)
	memory(MEMORY_POS, "m6", "Um segundo",
		"Fechei os olhos só por um segundo.\n\nSó um.\n\nQuando abri, %s gritava o meu nome." % Game.name_b)


func _light_of(n: Node) -> Light3D:
	if n is Light3D:
		return n
	for c in n.get_children():
		if c is Light3D:
			return c
	return null


## Cada erro apaga primeiro as luzes da porta que está sendo tentada.
func _focus_dread(side: String) -> void:
	dread_focus(side)


## Desenho de giz de cera: duas crianças de mãos dadas debaixo do sol. Em `covered`, alguém
## pintou a folha de azul por cima, com força; de uma das crianças só sobrou a mão.
func _drawing(pos: Vector3, covered: bool, tilt: float) -> void:
	var s := Sprite3D.new()
	s.texture = _drawing_tex(covered)
	s.pixel_size = 0.017
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.double_sided = true
	s.position = pos
	s.rotation_degrees.z = tilt
	geo.add_child(s)
	Build.sphere(geo, 0.022, pos + Vector3(0, 0.27, 0.02), Build.color_mat(Color("b3283f"), 0.2))


func _drawing_tex(covered: bool) -> ImageTexture:
	var w := 48
	var h := 36
	var paper := Color("e9e2cf")
	var ink := Color("1a1a1a")
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(paper)
	# Chão verde e sol no canto.
	for x in range(1, w - 1):
		for y in range(29 + int(round(sin(x * 0.5))), h - 1):
			if (x + y) % 3 != 0:
				_px(img, x, y, Color("3f8f3a"))
	_circle(img, 40, 6, 3, Color("e8b830"))
	# Duas crianças de mãos dadas.
	for c in [[17, 0], [29, 1]]:
		var x: int = c[0]
		_circle(img, x, 14, 2, ink)
		_line(img, x, 17, x, 23, ink)
		_line(img, x, 23, x - 2, 28, ink)
		_line(img, x, 23, x + 2, 28, ink)
		_line(img, x, 18, x + (3 if c[1] == 0 else -3), 21, ink)
	_line(img, 20, 21, 26, 21, ink)
	if covered:
		# Giz azul riscado por cima, com força, apagando a criança da direita.
		for y in range(2, h - 2):
			for x in range(23, w - 2):
				if (x * 3 + y * 5) % 7 < 5 or y % 3 == 0:
					img.set_pixel(x, y, Color("2d5fb8") if (x * 7 + y * 3) % 11 < 7 else Color("4f86d9"))
		_line(img, 20, 21, 25, 21, ink)
		_rect(img, 24, 20, 25, 22, ink)
	return ImageTexture.create_from_image(img)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(img, x, y, c)


func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r + r:
				_px(img, x, y, c)


func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var n := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		_px(img, int(round(lerpf(x0, x1, t))), int(round(lerpf(y0, y1, t))), c)


func _look_drawings(ch: Character) -> void:
	_drawings_seen += 1
	if ch.who == "a":
		await say([
			"a: Desenhos de criança. Giz de cera.",
			"a: Sempre as mesmas duas. De mãos dadas.",
		])
	else:
		await say([
			"b: Eu desenhava isso. Nós dois.",
			"b: Mas neste alguém pintou por cima. De azul, até rasgar o papel.",
			"b: Só sobrou uma mão.",
		])


# --- Roteiro ------------------------------------------------------------------------

func _begin() -> void:
	objective("Encontrem a saída do sótão.")
	party.switched.connect(_on_switched)
	await say([
		"a: Subi por um alçapão. Tem uma parede de tábuas no meio do sótão.",
		"b: Estou do outro lado dela. Consigo te ouvir, mas não te ver.",
		"b: Esse cheiro de poeira... eu já estive aqui. Faz muito tempo.",
		"b: Tem uma porta aqui. Trancada, com uma placa de números do lado.",
		"a: Aqui também. E um quadro de giz com um exemplo esquisito.",
	])
	hints([
		"O quadro de giz ensina a ler as placas: \"2 = 4\" é a 4ª letra da 2ª linha. Espaços e pontuação não contam.",
		"A placa de %s serve para o texto que está com %s, e vice-versa. Anote num papel." % [Game.name_b, Game.name_a],
		"A porta de %s: carta de %s + placa de %s = NOME." % [Game.name_b, Game.name_a, Game.name_b],
		"A porta de %s: canção de %s + placa de %s = MEDO." % [Game.name_a, Game.name_b, Game.name_a],
	])
	_scratch_loop()


## Passos e arranhões do outro lado da parede, perto de quem está jogando.
func _scratch_loop() -> void:
	var first := true
	while is_inside_tree() and not _finishing:
		await get_tree().create_timer(rng.randf_range(10.0, 17.0), false).timeout
		if _finishing or _dark or not Game.can_control():
			continue
		var ch := party.active
		var x := ch.global_position.x
		if absf(x) > 2.8:
			continue
		var other := party.other(ch)
		_scratch.global_position = Vector3(0.6 if x < 0.0 else -0.6, 1.0, ch.global_position.z + rng.randf_range(-0.8, 0.8))
		Audio.sfx_at("glass_squeak", _scratch, -12.0, 14.0)
		for i in 3:
			await get_tree().create_timer(0.45, false).timeout
			Audio.sfx_at("stalker_step", _scratch, -4.0, 14.0)
		if first and Game.can_control() and other.global_position.distance_to(_scratch.global_position) > 3.0:
			first = false
			await say([
				ch.who + ": Tem alguma coisa arranhando a parede. Do outro lado.",
				ch.who + ": %s, é você?" % Game.char_name(other.who),
				other.who + ": Não. Eu não estou aí.",
			])


func _process(_delta: float) -> void:
	# A voz que imita B vem pela parede: depois da carta, com A encostando nas tábuas.
	if _fake_done or _finishing or _dark or not Game.can_control():
		return
	var a := party.a
	if party.active != a or a.global_position.x < -2.4 or not Game.has_doc("a", "ch6_carta"):
		return
	if a.global_position.distance_to(party.b.global_position) < 4.0:
		return
	_fake_done = true
	_fake_voice()


func _fake_voice() -> void:
	_scratch.global_position = Vector3(0.6, 1.2, party.a.global_position.z)
	Audio.sfx_at("stalker_step", _scratch, -6.0, 12.0)
	await get_tree().create_timer(0.6, false).timeout
	await say([
		"x: %s. Encosta aqui. Na parede." % Game.name_a,
		"x: Eu estou bem do outro lado. Consegue me ouvir respirar?",
		"x: Não abre a porta. Lá embaixo dói. Fica aqui comigo.",
		"a: %s...?" % Game.name_b,
	])
	Audio.sfx("breath", -8.0)
	await get_tree().create_timer(1.5, false).timeout
	_hospital()


## O hospital vaza: alguém pede que conversem com o paciente.
func _hospital() -> void:
	if _bleed_done:
		return
	_bleed_done = true
	bleed(["Pode conversar. Dizem que eles escutam.", "Fala o nome. Fala do que tem medo."])


## O B verdadeiro nega ter falado (na primeira vez que o jogador volta para B).
func _on_switched(who: String) -> void:
	if who != "b" or not _fake_done or _denied:
		return
	_denied = true
	await get_tree().create_timer(0.3, false).timeout
	await say(_denial())


func _denial() -> Array:
	return [
		"b: Ouvi você me chamar pela parede.",
		"b: Não fui eu que respondi.",
	]


func _try_door(ch: Character, who: String) -> void:
	if _opened[who]:
		return
	var answer := "MEDO" if who == "a" else "NOME"
	var lock := CodeLock.new("Porta trancada", [answer],
		"Uma fechadura de letras. Quatro espaços.",
		["A placa ao lado da porta tem quatro pares de números.",
		"Os números não servem para o texto deste lado. Pergunte (troque) para o outro lado.",
		"A resposta é %s." % answer])
	lock.max_len = 4
	lock.placeholder = "????"
	_doors[who].rattle()
	_focus_dread(who)
	if await puzzle(lock):
		_opened[who] = true
		Audio.sfx("lock_open", -2.0)
		_doors[who].open()
		if _opened["a"] and _opened["b"]:
			var other := "b" if ch.who == "a" else "a"
			var lines := [
				"%s: Abriu. Tem uma escada estreita descendo." % ch.who,
				"%s: A minha também. Vejo você lá embaixo?" % other,
			]
			if _fake_done and not _denied:
				_denied = true
				lines.append_array(_denial())
			await say(lines)
			objective("Desçam pelas duas escadas ao mesmo tempo.")
		else:
			Audio.sfx("whisper_saia", -10.0)
			await say(["%s: Uma porta abriu. Falta a outra." % ch.who])
			await _blackout()
			_hospital()


# --- Apagão --------------------------------------------------------------------------

## Tudo apaga; nos clarões, o Esquecido está parado num canto; quando a luz volta, sumiu.
func _blackout() -> void:
	if _blackout_done or _finishing:
		return
	_blackout_done = true
	_dark = true
	Game.lock_input()
	await get_tree().create_timer(0.8).timeout
	var saved := []
	for n in geo.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		var flick := []
		for c in l.get_children():
			if c is Flicker and c.is_processing():
				c.set_process(false)
				flick.append(c)
		saved.append([l, l.light_energy, flick])
	var lamps := [party.a.lamp.light_energy, party.b.lamp.light_energy]
	var amb := env.ambient_light_energy
	var moon_e := moon.light_energy
	Audio.sfx("light_out", -2.0)
	_scale_lights(saved, 0.0)
	party.a.lamp.light_energy = 0.0
	party.b.lamp.light_energy = 0.0
	env.ambient_light_energy = amb * 0.12
	moon.light_energy = 0.0
	await get_tree().create_timer(1.4).timeout
	var ch := party.active
	var side := -1.0 if ch.global_position.x < 0.0 else 1.0
	var corner := Vector3(side * 7.3, 0, -6.9)
	if ch.global_position.distance_to(corner) < 3.0:
		corner = Vector3(side * 7.9, 0, 2.9)
	var s := spawn_stalker()
	s.hunting = false
	s.appear(corner, 0.0)
	var reveal := Build.omni(geo, corner + Vector3(0, 2.0, 1.1), Color("aebde0"), 0.0, 3.0)
	for i in 3:
		_scale_lights(saved, 0.45)
		reveal.light_energy = 0.9
		env.ambient_light_energy = amb * 0.5
		if i == 0:
			Audio.sfx("dread_sting", -4.0)
		await get_tree().create_timer(0.09 + i * 0.05).timeout
		_scale_lights(saved, 0.0)
		reveal.light_energy = 0.0
		env.ambient_light_energy = amb * 0.12
		await get_tree().create_timer(0.6).timeout
	reveal.queue_free()
	Audio.sfx("breath", -6.0)
	await get_tree().create_timer(0.8).timeout
	s.vanish(0.0)
	await get_tree().create_timer(0.3).timeout
	# A luz volta. O canto está vazio.
	for e in saved:
		var l: Light3D = e[0]
		if is_instance_valid(l):
			create_tween().tween_property(l, "light_energy", e[1], 0.5)
			for f in e[2]:
				f.set_process(true)
	party.a.lamp.light_energy = lamps[0]
	party.b.lamp.light_energy = lamps[1]
	create_tween().tween_property(env, "ambient_light_energy", amb, 0.5)
	moon.light_energy = moon_e
	await get_tree().create_timer(0.6).timeout
	_dark = false
	Game.unlock_input()
	var other := party.other(ch).who
	await say([
		ch.who + ": ...Tinha alguém no canto. Parado. Olhando.",
		other + ": A luz apagou aqui também. Você está bem?",
		ch.who + ": Quando a luz voltou, não tinha mais ninguém.",
	])


func _scale_lights(saved: Array, k: float) -> void:
	for e in saved:
		var l: Light3D = e[0]
		if is_instance_valid(l):
			l.light_energy = e[1] * k


func _on_landing(ch: Character, who: String) -> void:
	if ch.who != who or not _opened[who]:
		return
	_landed[who] = true
	if _landed["a"] and _landed["b"]:
		if stalker and stalker.visible:
			stalker.vanish(0.0)
		finish()
	elif ch == party.active:
		Ui.toast("Esperando %s chegar à outra escada." % Game.char_name("b" if who == "a" else "a"))


# --- Depuração (tools/shot.sh --call=...) ------------------------------------------

## A olhando os desenhos da parede norte.
func _debug_drawings() -> void:
	party.a.teleport(Vector3(-2.1, 0.05, -6.6))
	cam.snap()


## Apagão no meio: o Esquecido no canto, num clarão.
func _debug_blackout() -> void:
	party.a.teleport(Vector3(-4.0, 0.05, -6.8))
	cam.snap()
	for n in geo.find_children("*", "Light3D", true, false):
		(n as Light3D).light_energy *= 0.4
		for c in n.get_children():
			if c is Flicker:
				c.set_process(false)
	env.ambient_light_energy *= 0.4
	spawn_stalker().appear(Vector3(-7.3, 0, -6.9), 0.0)


func _debug_memory() -> void:
	party.a.teleport(MEMORY_POS + Vector3(1.0, 0.05, 0.0))
	cam.snap()
