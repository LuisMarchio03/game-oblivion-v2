extends LevelBase
## Capítulo 6 — O Sótão (enigma 6 original, texto reescrito).
## Sótão dividido ao meio. A tem a carta e o código da canção; B tem a canção e o
## código da carta. Linha = número da linha; número = posição da letra (só letras).
## Porta de A: MEDO. Porta de B: NOME.

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
		Build.spot(geo, Vector3(x, 2.6, -7.2), Vector3(x * 0.8, 0, -3.5), Color("8fb0ff"), 2.2, 10.0, 28.0, true)
	Build.motes(geo, Vector3(0, 1.6, -2), Vector3(8.5, 1.4, 5.5), 90, Color(0.8, 0.85, 1.0, 0.5), "dust", 0.04)


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


func _begin() -> void:
	objective("Encontrem a saída do sótão.")
	await say([
		"a: Subi por um alçapão. Tem uma parede de tábuas no meio do sótão.",
		"b: Estou do outro lado dela. Consigo te ouvir, mas não te ver.",
		"b: Tem uma porta aqui. Trancada, com uma placa de números do lado.",
		"a: Aqui também. E um quadro de giz com um exemplo esquisito.",
	])
	hints([
		"O quadro de giz ensina a ler as placas: \"2 = 4\" é a 4ª letra da 2ª linha. Espaços e pontuação não contam.",
		"A placa de %s serve para o texto que está com %s, e vice-versa. Anote num papel." % [Game.name_b, Game.name_a],
		"A porta de %s: carta de %s + placa de %s = NOME." % [Game.name_b, Game.name_a, Game.name_b],
		"A porta de %s: canção de %s + placa de %s = MEDO." % [Game.name_a, Game.name_b, Game.name_a],
	])


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
	if await puzzle(lock):
		_opened[who] = true
		Audio.sfx("lock_open", -2.0)
		_doors[who].open()
		if _opened["a"] and _opened["b"]:
			await say([
				"%s: Abriu. Tem uma escada estreita descendo." % ch.who,
				"%s: A minha também. Vejo você lá embaixo?" % ("b" if ch.who == "a" else "a"),
			])
			objective("Desçam pelas duas escadas ao mesmo tempo.")
		else:
			Audio.sfx("whisper_saia", -10.0)
			await say(["%s: Uma porta abriu. Falta a outra." % ch.who])


func _on_landing(ch: Character, who: String) -> void:
	if ch.who != who or not _opened[who]:
		return
	_landed[who] = true
	if _landed["a"] and _landed["b"]:
		finish()
	elif ch == party.active:
		Ui.toast("Esperando %s chegar à outra escada." % Game.char_name("b" if who == "a" else "a"))
