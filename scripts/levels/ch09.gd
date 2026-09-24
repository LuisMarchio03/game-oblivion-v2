extends LevelBase
## Capítulo 9 — Quatro e Quinze.
## Casa branca, só A. As quatro pistas impressas do original viram locais da casa:
## garagem (DOPA) → planta à esquerda da saída da biblioteca (INDUZ) → planta no
## canto escuro da galeria, atrás do quadro da nota de R$ 50 (SEDUZ) → a cama onde
## A acordou (SEPARA). Cada local só funciona na sua vez e entrega a frase e a pista
## seguinte. A cada frase, a casa vira um pouco mais hospital (lâmpadas frias, macas,
## cortinas, soro) e o Esquecido aparece mais perto. Com as quatro, o laboratório (a UTI,
## com o leito de B) destranca e o terminal pede as frases. Depois: o Esquecido abaixa a
## mão (o rosto é o de A), B aparece e A escolhe entre lembrar e esquecer.

const H := 3.4  # pé-direito
const GARAGE_Y := -2.4
const BED := Vector3(-7.5, 0, -4.6)
const LAB_DOOR := Vector3(19.0, 0, -7.0)

const CLUES := [
	{
		"id": "ch9_pista1", "title": "Pista 1", "style": "paper",
		"body": "[i]\"Aonde eles se alimentam, desça à esquerda, siga até a escuridão, aonde guardamos nossos carros, aonde jogamos os entulhos.\"[/i]",
	},
	{
		"id": "ch9_pista2", "title": "Pista 2", "style": "paper",
		"body": "[i]\"Local de conhecimento, antes por pergaminhos, agora por impressão; após este local, à esquerda, aquela que purifica o ar, a primeira delas.\"[/i]",
	},
	{
		"id": "ch9_pista3", "title": "Pista 3", "style": "paper",
		"body": "[i]\"Símbolo de valor monetário, ícone nacional, arte; olhe para a onça-pintada e sinta orgulho de sua nação; na escuridão me escondo; aquela que purifica o ar, à esquerda, no fundo.\"[/i]",
	},
	{
		"id": "ch9_pista4", "title": "Pista 4", "style": "paper",
		"body": "[i]\"No início ou no fim, acima ou abaixo, à vista ou escondido... no local mais óbvio, volte ao local do seu pesadelo.\"[/i]",
	},
]

const PHRASES := [
	{"id": "ch9_dopa", "title": "AQUELE QUE TE DOPA", "style": "hand", "body": "[center]seus remédios te cegam[/center]"},
	{"id": "ch9_induz", "title": "AQUELE QUE TE INDUZ", "style": "hand", "body": "[center]suas drogas te traem[/center]"},
	{"id": "ch9_seduz", "title": "AQUELE QUE TE SEDUZ", "style": "hand", "body": "[center]suas influências te destroem[/center]"},
	{"id": "ch9_separa", "title": "AQUELE QUE TE SEPARA", "style": "hand", "body": "[center]seu orgulho te cega[/center]"},
]

## O que o hospital diz depois de cada frase (vozes vazando para o sonho).
const STAGE_BLEED := [
	["Benzodiazepínico no sangue. Dose de quem queria dormir."],
	["Álcool acima do limite. Misturado com o remédio."],
	["Os amigos da festa já depuseram. Ninguém chamou um táxi."],
	["Uma testemunha viu os dois brigando pela chave do carro.", "Quem estava dirigindo?"],
]

const FOUND := [
	["Debaixo do entulho, embrulhado num saco plástico, um bilhete escrito à mão."],
	["Enterrado no vaso, entre as raízes, um papel enrolado."],
	["No canto escuro, dentro do vaso, um bilhete dobrado em quatro."],
	["Debaixo do travesseiro. Estava aqui desde o começo."],
]

const STAGE_OBJECTIVES := [
	"Siga a pista 1. ([J] diário)",
	"Siga a pista 2.",
	"Siga a pista 3.",
	"Siga a pista 4.",
	"O laboratório destrancou. Use o terminal.",
]

const TERMINAL_HINTS := [
	"Cada local entregou uma frase. Estão todas no diário.",
	"Cada pergunta do terminal corresponde a um \"Aquele que te...\".",
	"DOPA: seus remédios te cegam. INDUZ: suas drogas te traem. SEPARA: seu orgulho te cega. SEDUZ: suas influências te destroem.",
]

var _stage := 0
var _busy := false
var _done := false
var _lab_door: Door
var _lab_door_it: Interactable

var _floor: Material
var _wall: Material
var _in_garage := false
# A casa vira hospital aos poucos: um grupo de objetos por frase encontrada.
var _hosp: Array[Node3D] = []
var _warm_lights: Array[OmniLight3D] = []
var _lab_lights: Array[OmniLight3D] = []
# O Esquecido some quando A chega perto (distância no plano).
var _vanish_at := 0.0


func _init() -> void:
	chapter_index = 8
	preset = "white"
	ambience = "amb_white"
	spawn_a = Vector3(-5.6, 0, -3.4)
	spawn_b = Vector3(-4.6, 0, -3.4)
	cam_bounds = Rect2(-33, -13, 54, 15.5)


func _build() -> void:
	_tune_white()
	_solo.call_deferred()
	_floor = Build.mat("marble_white", Color(0.86, 0.88, 0.92), 3.0, 0.4)
	_wall = Build.mat("plaster", Color(0.95, 0.95, 0.97), 2.5)
	_build_corridor()
	_build_kitchen()
	_build_garage()
	_build_bedroom()
	_build_library()
	_build_gallery()
	_build_lab()
	_build_hospital()
	Build.motes(geo, Vector3(0, 1.6, -3), Vector3(22, 1.5, 8), 90, Color(1.0, 0.97, 0.9, 0.7), "dust", 0.04)


## O preset "white" puro estoura para branco; suaviza para a casa ter forma.
func _tune_white() -> void:
	env.ambient_light_energy = 0.42
	env.fog_density = 0.004
	env.tonemap_exposure = 0.95
	moon.light_energy = 0.6
	Ui.set_screen_fx(0.45, 0.02, Color(0.55, 0.6, 0.68))


# --- Planta da casa -------------------------------------------------------------------

func _build_corridor() -> void:
	Build.ground(geo, Rect2(-20, 2, 42, 3.5), 0.0, _floor, "stone")
	Build.box(geo, Vector3(42, 0.6, 0.3), Vector3(1, 0.3, 5.5), _wall)
	Build.wall(geo, Vector3(-20, 0, 2), Vector3(-20, 0, 5.6), H, 0.3, _wall)
	Build.wall(geo, Vector3(22, 0, 2), Vector3(22, 0, 5.6), H, 0.3, _wall)
	# Passadeira e luminárias.
	Build.box(geo, Vector3(38, 0.02, 1.2), Vector3(1, 0.01, 3.9), Build.mat("carpet_red", Color(0.75, 0.72, 0.78), 1.5), false)
	for x in [-15.0, -5.0, 5.0, 16.0]:
		_warm_lights.append(Build.omni(geo, Vector3(x, 2.8, 3.8), Color("fff1dc"), 0.35, 5.0))
	# Plantas do corredor: a certa fica logo à esquerda da saída da biblioteca.
	_plant(Vector3(3.3, 0, 2.55), true)
	interact(Vector3(3.3, 0.4, 2.9), "Examinar a planta", _try_spot.bind(1), "a", 1.0, false)
	for x in [6.7, -2.4, -12.4, 13.0]:
		_plant(Vector3(x, 0, 2.55))
		interact(Vector3(x, 0.4, 2.9), "Examinar a planta", _decoy, "a", 1.0, false)


func _build_kitchen() -> void:
	var r := Rect2(-20, -7, 10, 9)
	Build.room(geo, r, 0.0, H, Build.mat("tile_kitchen", Color(0.95, 0.95, 0.95), 2.0), _wall,
		[{"side": "s", "at": 5.0, "width": 1.8}, {"side": "w", "at": 4.0, "width": 2.6}], null, "stone", false)
	var white := Build.color_mat(Color("e8e6e1"))
	var wood := Build.mat("wood_floor", Color(1, 1, 1), 1.0)
	# Bancada, armários e geladeira.
	Build.box(geo, Vector3(5.5, 0.9, 0.7), Vector3(-14.5, 0.45, -6.45), white)
	Build.box(geo, Vector3(5.6, 0.06, 0.75), Vector3(-14.5, 0.93, -6.45), wood, false)
	Build.box(geo, Vector3(0.7, 0.05, 0.45), Vector3(-15.2, 0.97, -6.45), Build.mat("metal"), false)
	Build.box(geo, Vector3(5.5, 0.8, 0.4), Vector3(-14.5, 2.3, -6.6), white, false)
	Build.box(geo, Vector3(0.95, 2.0, 0.8), Vector3(-11.0, 1.0, -6.3), Build.color_mat(Color("f2f2f0"), 0.0, 0.3))
	Build.box(geo, Vector3(0.05, 0.6, 0.05), Vector3(-11.35, 1.3, -5.88), Build.mat("metal"), false)
	# Mesa, cadeiras e fruteira.
	Build.box(geo, Vector3(1.8, 0.08, 1.1), Vector3(-15, 0.78, -2.2), wood)
	for p in [Vector3(-15.8, 0, -2.6), Vector3(-14.2, 0, -2.6), Vector3(-15.8, 0, -1.8), Vector3(-14.2, 0, -1.8)]:
		Build.box(geo, Vector3(0.07, 0.78, 0.07), p + Vector3(0, 0.39, 0), wood, false)
	for x in [-16.3, -13.7]:
		Build.box(geo, Vector3(0.45, 0.06, 0.45), Vector3(x, 0.46, -2.2), wood, false)
		Build.box(geo, Vector3(0.06, 0.5, 0.45), Vector3(x + (-0.2 if x < -15 else 0.2), 0.74, -2.2), wood, false)
	Build.cylinder(geo, 0.2, 0.08, Vector3(-15, 0.86, -2.2), white, false, 12)
	for c in [Color("c43b2c"), Color("e0a526"), Color("7aa33a")]:
		Build.sphere(geo, 0.07, Vector3(-15 + randf_range(-0.1, 0.1), 0.95, -2.2 + randf_range(-0.1, 0.1)), Build.color_mat(c))
	_warm_lights.append(Build.omni(geo, Vector3(-15, 2.8, -2.5), Color("fff4e4"), 0.4, 6.0))


func _build_garage() -> void:
	var y := GARAGE_Y
	var dark_floor := Build.mat("cobble", Color(0.32, 0.32, 0.35), 2.0)
	var dark_wall := Build.mat("stone_wall", Color(0.3, 0.3, 0.33), 2.5)
	Build.ground(geo, Rect2(-36, -9, 16, 13), y, dark_floor, "stone")
	Build.wall(geo, Vector3(-36, y, -9), Vector3(-20, y, -9), H - y, 0.3, dark_wall)
	Build.wall(geo, Vector3(-36, y, -9), Vector3(-36, y, 4), H - y, 0.3, dark_wall)
	Build.wall(geo, Vector3(-20, y, -9), Vector3(-20, y, 4), -y, 0.3, dark_wall)
	Build.wall(geo, Vector3(-20, 0, -9), Vector3(-20, 0, -7), H, 0.3, dark_wall)
	Build.box(geo, Vector3(16, 0.6, 0.3), Vector3(-28, y + 0.3, 4), dark_wall)
	# Teto (só sombra): a luz do dia não entra.
	var lid := Build.box(geo, Vector3(16.4, 0.2, 13.4), Vector3(-28, H + 0.1, -2.5), dark_wall, false)
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# Escada descendo à esquerda da cozinha.
	Build.stairs(geo, Vector3(-26.5, y, -3.0), Vector3(-20.0, 0.0, -3.0), 2.4, 8, Build.mat("stone_path", Color(0.55, 0.55, 0.58), 1.5))
	Build.blocker(geo, Vector3(6.5, 3.0, 0.2), Vector3(-23.25, y + 1.2, -4.35))
	Build.blocker(geo, Vector3(6.5, 3.0, 0.2), Vector3(-23.25, y + 1.2, -1.65))
	var rail := Build.color_mat(Color("2a2b2e"), 0.0, 0.5)
	for i in 5:
		var px := -26.0 + i * 1.5
		var py := y + (px + 26.5) / 6.5 * 2.4
		Build.box(geo, Vector3(0.05, 0.9, 0.05), Vector3(px, py + 0.45, -1.62), rail, false)
	# Carro feito de caixas.
	var car := Node3D.new()
	car.position = Vector3(-32.6, y, 0.6)
	geo.add_child(car)
	var paint := Build.color_mat(Color("4a2a2c"), 0.0, 0.5)
	Build.box(car, Vector3(2.0, 0.8, 4.2), Vector3(0, 0.75, 0), paint)
	Build.box(car, Vector3(1.8, 0.7, 2.2), Vector3(0, 1.5, 0.2), paint, false)
	Build.box(car, Vector3(1.82, 0.5, 2.0), Vector3(0, 1.52, 0.2), Build.color_mat(Color("1b2026"), 0.0, 0.2), false)
	for wx in [-1.02, 1.02]:
		for wz in [-1.4, 1.4]:
			var wheel := Build.cylinder(car, 0.38, 0.3, Vector3(wx, 0.38, wz), Build.color_mat(Color("141414")), false, 12)
			wheel.rotation_degrees.z = 90
	for hx in [-0.65, 0.65]:
		Build.sphere(car, 0.12, Vector3(hx, 0.85, 2.1), Build.color_mat(Color("9a968a"), 0.2))
	Build.box(car, Vector3(0.5, 0.35, 0.5), Vector3(0.4, 2.03, -0.2), Build.mat("planks_dark", Color(0.8, 0.75, 0.7), 1.0), false, 20)
	Build.box(car, Vector3(0.4, 0.3, 0.4), Vector3(-0.3, 2.0, 0.6), Build.mat("planks_dark", Color(0.8, 0.75, 0.7), 1.0), false, -10)
	# Entulho, no fundo escuro.
	var junk := [Build.mat("brick", Color(0.45, 0.4, 0.4), 1.0), Build.mat("cobble", Color(0.4, 0.4, 0.42), 1.0), Build.mat("planks_dark", Color(0.6, 0.6, 0.6), 1.0)]
	var pile := Vector3(-33.6, y, -7.2)
	for i in 16:
		var s := Vector3(rng.randf_range(0.25, 0.8), rng.randf_range(0.15, 0.5), rng.randf_range(0.25, 0.8))
		var p := pile + Vector3(rng.randf_range(-1.2, 1.2), s.y / 2.0 + rng.randf_range(0.0, 0.4), rng.randf_range(-0.8, 0.8))
		var b := Build.box(geo, s, p, junk[i % 3], false, rng.randf_range(0, 90))
		b.rotation_degrees.x = rng.randf_range(-15, 15)
	for i in 3:
		Build.box(geo, Vector3(0.7, 0.4, 0.5), pile + Vector3(-0.9 + i * 0.8, 0.2, 0.9), Build.mat("curtain", Color(0.35, 0.33, 0.3), 1.0), false, rng.randf_range(-20, 20))
	Build.box(geo, Vector3(0.1, 1.6, 1.2), Vector3(-35.5, y + 0.8, -3.5), Build.mat("planks_dark"), false, 8)
	Build.blocker(geo, Vector3(2.8, 2, 1.8), pile + Vector3(0, 1, 0))
	Build.billboard(geo, "cobweb", Vector3(-35.4, y + 2.6, -8.6), 0.045, 1, 0, Color(0.6, 0.6, 0.6))
	# Uma lâmpada fraca perto da escada. O fundo fica no escuro.
	Build.omni(geo, Vector3(-26.5, y + 2.6, -1.0), Color("ffcf8a"), 0.7, 6.0, false, true)
	Build.sphere(geo, 0.08, Vector3(-26.5, y + 2.9, -1.0), Build.color_mat(Color("ffd9a0"), 2.0))
	Build.motes(geo, Vector3(-29, y + 1.4, -3), Vector3(6, 1.2, 5), 40, Color(0.8, 0.8, 0.75, 0.5), "dust", 0.04)
	interact(pile + Vector3(0.6, 0.5, 1.6), "Revirar o entulho", _try_spot.bind(0), "a", 1.5, false)


func _build_bedroom() -> void:
	var r := Rect2(-10, -7, 10, 9)
	Build.room(geo, r, 0.0, H, Build.mat("wood_floor", Color(0.95, 0.93, 0.9), 2.0), _wall,
		[{"side": "s", "at": 5.0, "width": 1.8}], null, "wood", false)
	var wood := Build.mat("wood_floor", Color(1, 1, 1), 1.0)
	var sheet := Build.mat("bed_cloth", Color(1, 1, 1), 1.0)
	# Cama (onde tudo começou).
	Build.box(geo, Vector3(2.1, 0.45, 2.7), BED + Vector3(0, 0.225, 0), wood)
	Build.box(geo, Vector3(2.0, 0.25, 2.55), BED + Vector3(0, 0.57, 0), Build.color_mat(Color("f1f0ec")), false)
	Build.box(geo, Vector3(2.04, 0.12, 1.6), BED + Vector3(0, 0.72, 0.5), sheet, false)
	Build.box(geo, Vector3(1.4, 0.18, 0.5), BED + Vector3(0, 0.78, -0.9), Build.color_mat(Color("ffffff")), false)
	Build.box(geo, Vector3(2.2, 1.3, 0.12), BED + Vector3(0, 0.65, -1.4), wood, false)
	# Criado-mudo, abajur, guarda-roupa, janela e tapete.
	Build.box(geo, Vector3(0.6, 0.6, 0.5), BED + Vector3(1.5, 0.3, -1.0), wood)
	Build.cylinder(geo, 0.05, 0.35, BED + Vector3(1.5, 0.78, -1.0), Build.color_mat(Color("c9c3b5")), false, 8)
	Build.cylinder(geo, 0.18, 0.22, BED + Vector3(1.5, 1.05, -1.0), Build.color_mat(Color("fff0d8"), 1.2), false, 10)
	Build.omni(geo, BED + Vector3(1.5, 1.3, -0.6), Color("ffd9a8"), 0.6, 4.0)
	Build.box(geo, Vector3(1.4, 2.4, 0.6), Vector3(-1.2, 1.2, -6.4), Build.color_mat(Color("e4ded4")))
	Build.box(geo, Vector3(0.02, 2.2, 0.02), Vector3(-1.2, 1.2, -6.09), Build.color_mat(Color("b8b0a2")), false)
	Build.box(geo, Vector3(2.0, 1.4, 0.05), Vector3(-4.0, 1.9, -6.82), Build.color_mat(Color("dfeaf6"), 1.4), false)
	Build.box(geo, Vector3(0.06, 1.4, 0.08), Vector3(-4.0, 1.9, -6.78), Build.color_mat(Color("c9c3b5")), false)
	Build.box(geo, Vector3(3.0, 0.02, 2.0), Vector3(-5.2, 0.01, -2.0), Build.mat("carpet_red", Color(0.8, 0.75, 0.82), 1.0), false)
	Build.omni(geo, Vector3(-4.0, 2.0, -5.5), Color("dfeaf6"), 0.5, 5.0)
	interact(BED + Vector3(1.0, 0.4, 1.6), "Examinar a cama", _try_spot.bind(3), "a", 1.4, false)


func _build_library() -> void:
	var r := Rect2(0, -7, 10, 9)
	Build.room(geo, r, 0.0, H, Build.mat("wood_floor", Color(1, 1, 1), 2.0), _wall,
		[{"side": "s", "at": 5.0, "width": 1.8}], null, "wood", false)
	var shelf_m := Build.mat("planks_dark", Color(0.95, 0.9, 0.85), 1.0)
	var book_colors := [Color("7a2e2e"), Color("2e4a7a"), Color("3d6b45"), Color("b08a3a"), Color("5a3d6b"), Color("d8d0c0"), Color("8a5a3a")]
	for sx in [1.4, 3.6, 6.4, 8.6]:
		Build.box(geo, Vector3(2.0, 2.8, 0.5), Vector3(sx, 1.4, -6.55), shelf_m)
		for row in 4:
			var y := 0.35 + row * 0.66
			Build.box(geo, Vector3(1.9, 0.04, 0.46), Vector3(sx, y - 0.02, -6.28), shelf_m, false)
			var x: float = sx - 0.88
			while x < sx + 0.85:
				var w := rng.randf_range(0.06, 0.14)
				var h := rng.randf_range(0.36, 0.52)
				Build.box(geo, Vector3(w, h, 0.3), Vector3(x + w / 2.0, y + h / 2.0, -6.2), Build.color_mat(book_colors[rng.randi_range(0, book_colors.size() - 1)]), false)
				x += w + 0.01
	# Mesa de leitura, livro aberto, globo e poltrona.
	var wood := Build.mat("wood_floor", Color(1, 1, 1), 1.0)
	Build.box(geo, Vector3(2.2, 0.08, 1.2), Vector3(4.2, 0.8, -2.8), wood)
	for p in [Vector3(3.2, 0, -3.3), Vector3(5.2, 0, -3.3), Vector3(3.2, 0, -2.3), Vector3(5.2, 0, -2.3)]:
		Build.box(geo, Vector3(0.08, 0.8, 0.08), p + Vector3(0, 0.4, 0), wood, false)
	Build.box(geo, Vector3(0.7, 0.03, 0.45), Vector3(4.0, 0.86, -2.8), Build.color_mat(Color("f4efe2")), false, 6)
	Build.cylinder(geo, 0.04, 0.4, Vector3(8.6, 0.2, -3.0), wood, false, 8)
	Build.sphere(geo, 0.32, Vector3(8.6, 0.72, -3.0), Build.color_mat(Color("5b86a8")))
	Build.box(geo, Vector3(0.9, 0.5, 0.9), Vector3(1.4, 0.25, -2.2), Build.color_mat(Color("8a4a3a")))
	Build.box(geo, Vector3(0.9, 0.8, 0.2), Vector3(1.4, 0.7, -2.6), Build.color_mat(Color("8a4a3a")), false)
	_warm_lights.append(Build.omni(geo, Vector3(4.2, 2.4, -3.5), Color("ffe6c0"), 0.55, 6.0))
	Build.text3d(geo, "BIBLIOTECA", Vector3(5.0, 2.95, -6.24), 0.0, 40, Color("6a5a48"))
	doc(Vector3(4.0, 0.6, -2.1), {
		"id": "ch9_livro",
		"title": "Livro aberto",
		"body": "Uma página sublinhada a lápis:\n\n[i]\"Quem esquece o caminho de casa ainda pode perguntar por ele.\"[/i]",
		"style": "paper",
	}, "Ler o livro aberto", "a", 1.2)


func _build_gallery() -> void:
	var r := Rect2(10, -7, 12, 9)
	Build.room(geo, r, 0.0, H, Build.mat("marble_white", Color(0.74, 0.76, 0.8), 2.0, 0.4), _wall,
		[{"side": "s", "at": 6.0, "width": 1.8}, {"side": "n", "at": LAB_DOOR.x - 10.0, "width": 1.4}], null, "stone", false)
	# Canto escuro, no fundo à esquerda.
	var shade := Build.color_mat(Color("2a2d33"))
	Build.box(geo, Vector3(3.0, H, 0.04), Vector3(11.65, H / 2.0, -6.83), shade, false)
	Build.box(geo, Vector3(0.04, H, 3.0), Vector3(10.17, H / 2.0, -5.5), shade, false)
	Build.box(geo, Vector3(3.0, 0.02, 3.0), Vector3(11.65, 0.01, -5.5), Build.mat("planks_dark", Color(0.35, 0.35, 0.38), 1.0), false)
	Build.box(geo, Vector3(0.7, H - 0.2, 0.08), Vector3(13.4, (H - 0.2) / 2.0, -6.75), Build.mat("curtain", Color(0.45, 0.4, 0.45), 1.0), false)
	var roof := Build.box(geo, Vector3(3.4, 0.1, 3.4), Vector3(11.7, H + 0.2, -5.4), shade, false)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_plant(Vector3(10.95, 0, -6.2))
	interact(Vector3(11.3, 0.4, -5.6), "Examinar a planta no escuro", _try_spot.bind(2), "a", 1.2, false)
	_plant(Vector3(21.2, 0, -6.2))
	interact(Vector3(20.9, 0.4, -5.6), "Examinar a planta", _decoy, "a", 1.0, false)
	# O quadro da nota de R$ 50.
	_bill_painting(Vector3(16.0, 1.95, -6.85))
	Build.spot(geo, Vector3(16.0, 3.3, -4.4), Vector3(16.0, 1.9, -6.8), Color("ffe2b8"), 2.4, 7.0, 28.0, false)
	interact(Vector3(16.0, 0.5, -5.6), "Observar o quadro", _on_painting, "a", 1.4, false)
	# Outros quadros e bancos.
	for q in [[Vector3(12.9, 1.9, -6.83), Color("7a9ab8"), Vector2(1.0, 1.3)], [Vector3(21.85, 1.9, -3.0), Color("c8a0a0"), Vector2(1.4, 1.0)]]:
		var pos: Vector3 = q[0]
		var sz: Vector2 = q[2]
		var rot := -90.0 if pos.x > 21.0 else 0.0
		Build.box(geo, Vector3(sz.x + 0.14, sz.y + 0.14, 0.06), pos, Build.color_mat(Color("3a2a1e")), false, rot)
		Build.box(geo, Vector3(sz.x, sz.y, 0.07), pos, Build.color_mat(q[1]), false, rot)
	for bx in [14.5, 18.0]:
		Build.box(geo, Vector3(1.6, 0.1, 0.5), Vector3(bx, 0.45, -2.0), Build.mat("wood_floor", Color(1, 1, 1), 1.0))
		for lx in [-0.65, 0.65]:
			Build.box(geo, Vector3(0.08, 0.4, 0.4), Vector3(bx + lx, 0.2, -2.0), Build.color_mat(Color("3a3a3a")), false)
	_warm_lights.append(Build.omni(geo, Vector3(18.0, 2.8, -2.5), Color("fff4e4"), 0.35, 6.0))
	Build.text3d(geo, "GALERIA", Vector3(16.0, 3.1, -6.83), 0.0, 32, Color("7a7466"))
	# Porta do laboratório.
	_lab_door = Build.door(geo, LAB_DOOR, 0.0, Build.mat("wood_wall", Color(0.95, 0.95, 0.97), 1.0))
	Build.box(geo, Vector3(0.18, 0.28, 0.05), LAB_DOOR + Vector3(0.8, 1.2, 0.2), Build.color_mat(Color("20262c")), false)
	_lab_door.set_meta("led", Build.sphere(geo, 0.035, LAB_DOOR + Vector3(0.8, 1.28, 0.24), Build.color_mat(Color("e0303a"), 2.0)))
	Build.text3d(geo, "LABORATÓRIO", LAB_DOOR + Vector3(0, 2.75, 0.17), 0.0, 28, Color("5a6a78"))
	_lab_door_it = interact(LAB_DOOR + Vector3(0, 0.5, 0.8), "Abrir a porta", _on_lab_door, "a", 1.2, false)


## Quadro com a nota de cinquenta reais (onça-pintada).
func _bill_painting(c: Vector3) -> void:
	Build.box(geo, Vector3(3.1, 1.75, 0.1), c, Build.color_mat(Color("3a2a1e")), false)
	Build.box(geo, Vector3(2.9, 1.55, 0.04), c + Vector3(0, 0, 0.06), Build.color_mat(Color("c9884c")), false)
	Build.box(geo, Vector3(0.7, 1.55, 0.042), c + Vector3(-1.1, 0, 0.061), Build.color_mat(Color("e3b57c")), false)
	Build.box(geo, Vector3(2.9, 0.12, 0.042), c + Vector3(0, -0.62, 0.062), Build.color_mat(Color("a8683a")), false)
	var ink := Color("4a2410")
	Build.text3d(geo, "50", c + Vector3(0.95, 0.12, 0.09), 0.0, 120, ink, UiTheme.FONT_SERIF, 0.007)
	Build.text3d(geo, "REAIS", c + Vector3(0.95, -0.32, 0.09), 0.0, 36, ink, UiTheme.FONT_SERIF, 0.006)
	Build.text3d(geo, "BANCO CENTRAL DO BRASIL", c + Vector3(0.2, 0.62, 0.09), 0.0, 22, ink, UiTheme.FONT_SERIF, 0.006)
	Build.text3d(geo, "ONÇA-PINTADA", c + Vector3(-0.45, -0.5, 0.09), 0.0, 26, ink, UiTheme.FONT_SERIF, 0.006)
	# A onça: corpo, cabeça, orelhas, cauda e pintas.
	var fur := Build.color_mat(Color("e09a2e"), 0.1)
	var spot := Build.color_mat(Color("2a1a0e"))
	var body := Build.sphere(geo, 0.3, c + Vector3(-0.3, -0.1, 0.1), fur)
	body.scale = Vector3(1.5, 0.7, 0.15)
	var head := Build.sphere(geo, 0.17, c + Vector3(-0.85, 0.08, 0.11), fur)
	head.scale = Vector3(1.0, 0.95, 0.2)
	for ex in [-0.95, -0.75]:
		var ear := Build.sphere(geo, 0.05, c + Vector3(ex, 0.23, 0.11), fur)
		ear.scale = Vector3(1, 1, 0.3)
	for ex in [-0.91, -0.79]:
		Build.sphere(geo, 0.022, c + Vector3(ex, 0.1, 0.14), Build.color_mat(Color("1a2a10")))
	var tail := Build.box(geo, Vector3(0.45, 0.06, 0.03), c + Vector3(0.3, 0.02, 0.1), fur, false, 0.0)
	tail.rotation_degrees.z = 25
	for i in 12:
		var sp := Build.sphere(geo, 0.028, c + Vector3(-0.3 + rng.randf_range(-0.36, 0.36), -0.1 + rng.randf_range(-0.14, 0.14), 0.15), spot)
		sp.scale = Vector3(1, 1, 0.3)
	for lx in [-0.6, -0.4, -0.1, 0.1]:
		Build.box(geo, Vector3(0.07, 0.25, 0.03), c + Vector3(lx, -0.33, 0.1), fur, false)


func _build_lab() -> void:
	var r := Rect2(13, -16, 10, 9)
	Build.room(geo, r, 0.0, H, Build.mat("tile_bath", Color(0.95, 0.97, 1.0), 1.5), Build.mat("plaster", Color(0.85, 0.9, 0.95), 2.5),
		[{"side": "s", "at": LAB_DOOR.x - 13.0, "width": 1.4}], null, "stone", false)
	# Terminal.
	var desk := Build.color_mat(Color("c8ccd2"), 0.0, 0.4)
	Build.box(geo, Vector3(2.4, 0.08, 0.9), Vector3(18.0, 0.8, -15.1), desk)
	Build.box(geo, Vector3(2.4, 0.78, 0.08), Vector3(18.0, 0.39, -15.5), desk, false)
	Build.box(geo, Vector3(1.1, 0.75, 0.1), Vector3(18.0, 1.3, -15.3), Build.color_mat(Color("22272e")), false)
	Build.box(geo, Vector3(1.0, 0.64, 0.02), Vector3(18.0, 1.3, -15.24), Build.color_mat(Color("3fb8e0"), 2.2), false)
	Build.text3d(geo, "> _", Vector3(17.75, 1.4, -15.22), 0.0, 40, Color("dff8ff"), UiTheme.FONT_UI, 0.006)
	Build.box(geo, Vector3(0.7, 0.03, 0.25), Vector3(18.0, 0.86, -14.85), Build.color_mat(Color("2a2e34")), false)
	_lab_lights.append(Build.omni(geo, Vector3(18.0, 1.5, -14.4), Color("7fd6f2"), 0.8, 4.0))
	# O leito de B: vazio, soro e monitor.
	var sheet := Build.color_mat(Color("f4f6f8"))
	Build.box(geo, Vector3(1.0, 0.6, 2.1), Vector3(14.6, 0.3, -12.5), Build.color_mat(Color("aab4be"), 0.0, 0.4))
	Build.box(geo, Vector3(1.02, 0.12, 1.9), Vector3(14.6, 0.66, -12.4), sheet, false)
	Build.box(geo, Vector3(0.7, 0.14, 0.35), Vector3(14.6, 0.75, -13.3), sheet, false)
	Build.cylinder(geo, 0.02, 1.9, Vector3(15.4, 0.95, -13.4), Build.color_mat(Color("9aa2aa")), false, 6)
	Build.box(geo, Vector3(0.2, 0.3, 0.06), Vector3(15.4, 1.75, -13.4), Build.color_mat(Color("d8eef6", 0.8)), false)
	Build.box(geo, Vector3(0.5, 0.4, 0.3), Vector3(14.0, 1.4, -15.7), Build.color_mat(Color("22272e")), false)
	Build.box(geo, Vector3(0.44, 0.3, 0.02), Vector3(14.0, 1.4, -15.54), Build.color_mat(Color("38d07a"), 1.8), false)
	Build.text3d(geo, "LEITO %d" % Game.number_b, Vector3(14.6, 2.3, -15.8), 0.0, 36, Color("4a5a68"), UiTheme.FONT_UI)
	# Estantes com frascos.
	for sx in [21.0, 22.2]:
		Build.box(geo, Vector3(1.1, 2.0, 0.4), Vector3(sx, 1.0, -15.6), desk)
		for i in 5:
			var col: Color = [Color("7ad0c8"), Color("e0a0c0"), Color("b0d080"), Color("f0d070")][i % 4]
			Build.cylinder(geo, 0.06, 0.22, Vector3(sx - 0.4 + i * 0.2, 2.11, -15.5), Build.color_mat(Color(col, 0.8), 0.6), false, 8)
	_lab_lights.append(Build.omni(geo, Vector3(18.0, 2.9, -11.5), Color("e4f2ff"), 0.5, 7.0))
	for l in _lab_lights:
		dread_light(l)
	interact(Vector3(18.0, 0.5, -14.2), "Usar o terminal", _on_terminal, "a", 1.3, false)


# --- A casa vira hospital -------------------------------------------------------------

func _build_hospital() -> void:
	for i in 4:
		var g := Node3D.new()
		g.name = "Hospital%d" % i
		g.visible = false
		geo.add_child(g)
		_hosp.append(g)
	var steel := Build.color_mat(Color("b8c0c8"), 0.0, 0.35)
	var sheet := Build.color_mat(Color("eef2f4"))
	var green := Build.color_mat(Color("9fc4b8"), 0.0, 0.9)
	# 0 — corredor: lâmpadas frias, maca e soro.
	for x in [-15.0, -5.0, 5.0, 16.0]:
		Build.box(_hosp[0], Vector3(1.4, 0.06, 0.2), Vector3(x, 3.3, 3.8), Build.color_mat(Color("e8f6ff"), 2.0), false)
		Build.omni(_hosp[0], Vector3(x, 2.9, 3.8), Color("dff2ff"), 0.5, 5.5, false, true)
	_gurney(_hosp[0], Vector3(-8.5, 0, 4.85), steel, sheet)
	_iv_stand(_hosp[0], Vector3(12.0, 0, 5.0), steel)
	_iv_stand(_hosp[0], Vector3(-1.0, 0, 5.05), steel)
	# 1 — cozinha e biblioteca: carrinho de remédios, cadeira de rodas.
	Build.box(_hosp[1], Vector3(0.9, 0.9, 0.55), Vector3(-17.5, 0.45, -4.5), steel)
	for i in 6:
		Build.cylinder(_hosp[1], 0.04, 0.12, Vector3(-17.8 + i * 0.12, 0.96, -4.5), Build.color_mat(Color("f0c060"), 0.3), false, 6)
	_wheelchair(_hosp[1], Vector3(7.8, 0, -1.2), steel)
	Build.omni(_hosp[1], Vector3(-15, 2.9, -2.5), Color("dff2ff"), 0.45, 6.0, false, true)
	Build.omni(_hosp[1], Vector3(4.2, 2.9, -3.5), Color("dff2ff"), 0.45, 6.0, false, true)
	# 2 — galeria: quadros cobertos por lençóis, placa da UTI.
	for q in [Vector3(12.9, 1.9, -6.76), Vector3(16.0, 1.95, -6.74)]:
		var w := 1.3 if q.x < 14.0 else 3.3
		Build.box(_hosp[2], Vector3(w, 2.0, 0.05), q + Vector3(0, -0.05, 0.08), sheet, false)
	Build.text3d(_hosp[2], "UTI", LAB_DOOR + Vector3(0, 3.1, 0.17), 0.0, 40, Color("b0303a"), UiTheme.FONT_UI)
	_wheelchair(_hosp[2], Vector3(20.6, 0, -1.4), steel)
	Build.omni(_hosp[2], Vector3(18.0, 2.9, -2.5), Color("dff2ff"), 0.45, 6.0, false, true)
	# 3 — o quarto: a cama de A vira leito, com cortina, soro e monitor.
	Build.box(_hosp[3], Vector3(0.05, 2.3, 3.0), BED + Vector3(-1.45, 1.15, 0.1), green, false)
	Build.box(_hosp[3], Vector3(0.05, 0.05, 3.2), BED + Vector3(-1.45, 2.35, 0.1), steel, false)
	for sx in [-1.08, 1.08]:
		Build.box(_hosp[3], Vector3(0.04, 0.3, 1.4), BED + Vector3(sx, 0.95, 0.2), steel, false)
	_iv_stand(_hosp[3], BED + Vector3(-1.0, 0, -1.0), steel)
	Build.box(_hosp[3], Vector3(0.5, 0.4, 0.3), BED + Vector3(1.5, 1.5, -1.25), Build.color_mat(Color("22272e")), false)
	Build.box(_hosp[3], Vector3(0.44, 0.3, 0.02), BED + Vector3(1.5, 1.5, -1.09), Build.color_mat(Color("38d07a"), 1.8), false)
	Build.text3d(_hosp[3], "LEITO %d" % Game.number_a, BED + Vector3(0, 2.4, -1.43), 0.0, 36, Color("4a5a68"), UiTheme.FONT_UI)
	Build.omni(_hosp[3], BED + Vector3(0, 2.8, 0.5), Color("dff2ff"), 0.5, 5.0, false, true)


func _gurney(parent: Node3D, pos: Vector3, steel: Material, sheet: Material) -> void:
	Build.box(parent, Vector3(2.0, 0.08, 0.7), pos + Vector3(0, 0.85, 0), steel)
	Build.box(parent, Vector3(1.9, 0.14, 0.64), pos + Vector3(0, 0.95, 0), sheet, false)
	for lx in [-0.9, 0.9]:
		for lz in [-0.28, 0.28]:
			Build.box(parent, Vector3(0.04, 0.85, 0.04), pos + Vector3(lx, 0.42, lz), steel, false)
	# Um lençol que ainda tem a forma de alguém.
	var lump := Build.sphere(parent, 0.3, pos + Vector3(0.2, 1.05, 0), sheet)
	lump.scale = Vector3(2.6, 0.45, 0.9)


func _iv_stand(parent: Node3D, pos: Vector3, steel: Material) -> void:
	Build.cylinder(parent, 0.02, 1.9, pos + Vector3(0, 0.95, 0), steel, false, 6)
	Build.box(parent, Vector3(0.5, 0.03, 0.03), pos + Vector3(0, 1.88, 0), steel, false)
	Build.box(parent, Vector3(0.16, 0.26, 0.06), pos + Vector3(0.18, 1.7, 0), Build.color_mat(Color(0.85, 0.93, 1.0, 0.8), 0.4), false)
	Build.cylinder(parent, 0.22, 0.04, pos + Vector3(0, 0.03, 0), steel, false, 8)


func _wheelchair(parent: Node3D, pos: Vector3, steel: Material) -> void:
	Build.box(parent, Vector3(0.6, 0.08, 0.6), pos + Vector3(0, 0.5, 0), Build.color_mat(Color("30343a")), true)
	Build.box(parent, Vector3(0.6, 0.6, 0.06), pos + Vector3(0, 0.85, -0.3), Build.color_mat(Color("30343a")), false)
	for wx in [-0.34, 0.34]:
		var wheel := Build.cylinder(parent, 0.32, 0.04, pos + Vector3(wx, 0.32, 0), steel, false, 14)
		wheel.rotation_degrees.z = 90


## Mostra o próximo pedaço do hospital: lâmpadas quentes apagam, as frias acendem.
func _hospitalize(step: int) -> void:
	if step < 0 or step >= _hosp.size():
		return
	Audio.sfx("light_out", -6.0)
	Audio.sfx("radio_static", -10.0)
	await Ui.flash(Color(0.85, 0.95, 1.0), 0.35)
	_hosp[step].visible = true
	var cold := {0: [0, 1, 2, 3], 1: [4, 5], 2: [6]}
	for i in cold.get(step, []):
		if i < _warm_lights.size():
			create_tween().tween_property(_warm_lights[i], "light_energy", 0.0, 0.3)
	if step == 3:
		Audio.ambience("amb_hospital", 4.0)
		var t := create_tween().set_parallel()
		t.tween_property(env, "ambient_light_color", Color("c8dcec"), 3.0)
		t.tween_property(moon, "light_color", Color("d8ecff"), 3.0)


## O Esquecido aparece parado e some quando A chega a `near` metros (ou depois de `life` s).
func _apparition(pos: Vector3, near := 6.0, life := 25.0) -> void:
	var s := spawn_stalker()
	if s.is_active():
		await s.vanish(0.2)
	s.appear(pos, 1.2)
	_vanish_at = near
	Audio.sfx("dread_sting", -10.0)
	await get_tree().create_timer(life).timeout
	if s.is_active() and not _done:
		s.vanish(1.5)


## A garagem é escura de verdade: ao descer, a luz da casa se apaga aos poucos.
func _process(_delta: float) -> void:
	if party == null or party.active == null:
		return
	if stalker and stalker.is_active() and _vanish_at > 0.0 and stalker.distance_to_active() < _vanish_at:
		_vanish_at = 0.0
		Audio.sfx("whisper_many", -14.0)
		stalker.vanish(0.4)
	var p := party.active.global_position
	var g := p.x < -20.2 and p.y < -0.6
	if g == _in_garage:
		return
	_in_garage = g
	var t := create_tween().set_parallel()
	t.tween_property(env, "ambient_light_energy", 0.2 if g else 0.42, 1.4)
	t.tween_property(env, "fog_density", 0.0 if g else 0.004, 1.4)
	t.tween_property(env, "background_color", Color("1c1f24") if g else PRESETS["white"]["bg"], 1.4)
	t.tween_property(moon, "light_energy", 0.12 if g else 0.6, 1.4)


## Planta em vaso (cilindro + folhagem em billboard).
func _plant(pos: Vector3, big := false) -> void:
	var s := 1.2 if big else 1.0
	Build.cylinder(geo, 0.24 * s, 0.5 * s, pos + Vector3(0, 0.25 * s, 0), Build.color_mat(Color("e9e2d6"), 0.0, 0.6), true, 12)
	Build.cylinder(geo, 0.27 * s, 0.06, pos + Vector3(0, 0.5 * s, 0), Build.color_mat(Color("d6cfc2"), 0.0, 0.6), false, 12)
	Build.cylinder(geo, 0.22 * s, 0.02, pos + Vector3(0, 0.52 * s, 0), Build.color_mat(Color("3a2c22")), false, 12)
	Build.billboard(geo, "bush", pos + Vector3(0, 0.48 * s, 0.02), 0.036 * s)
	var f := Build.billboard(geo, "fern", pos + Vector3(0.02, 0.8 * s, 0.03), 0.045 * s)
	f.flip_h = randf() < 0.5


# --- Fluxo ----------------------------------------------------------------------------

## Só A nesta casa (antes do primeiro quadro desenhado).
func _solo() -> void:
	party.solo("a")
	party.b.teleport(Vector3(0, -40, 0))


func _begin() -> void:
	objective("")
	await say([
		"Você acorda numa cama. O lençol está frio.",
		"a: ...branco. Tudo aqui é branco.",
		"a: %s? Você está aqui?" % Game.name_b,
		"Nenhuma resposta. Só o zumbido baixo de uma máquina, em algum lugar da casa.",
		"a: Tem um papel no meu bolso.",
	])
	await Ui.read_doc("a", CLUES[0])
	await say(["?: Quatro coisas trouxeram você até aqui. Encontre as quatro."])
	_update_stage()
	bleed(["Leito %d. Sinais estáveis. Sem resposta a estímulo." % Game.number_a])


func _update_stage() -> void:
	objective(STAGE_OBJECTIVES[_stage])
	match _stage:
		0:
			hints([
				"\"Aonde eles se alimentam\": a cozinha.",
				"Na cozinha, uma escada à esquerda desce para a escuridão da garagem.",
				"Reviste o entulho no fundo escuro da garagem, depois do carro.",
			])
		1:
			hints([
				"\"Local de conhecimento\", de livros impressos: a biblioteca.",
				"Saia da biblioteca pela porta e olhe logo à esquerda, no corredor.",
				"Examine a primeira planta à esquerda da porta da biblioteca.",
			])
		2:
			hints([
				"A onça-pintada está na nota de cinquenta reais. Procure o quadro na galeria.",
				"Na galeria, a planta que \"se esconde na escuridão\" fica no fundo, à esquerda.",
				"Examine a planta no canto escuro, no fundo à esquerda da galeria.",
			])
		3:
			hints([
				"\"Volte ao local do seu pesadelo\": onde tudo começou neste capítulo.",
				"O local mais óbvio é onde você acordou.",
				"Examine a cama do quarto.",
			])
		_:
			hints(TERMINAL_HINTS)


func _try_spot(_ch: Character, idx: int) -> void:
	if _busy or _done:
		return
	if _stage < idx:
		await say(["a: Nada aqui... ainda."])
		return
	if _stage > idx:
		await say(["a: Já encontrei o que havia aqui."])
		return
	_busy = true
	_stage += 1
	Audio.sfx("key_pickup", -6.0)
	await say(FOUND[idx])
	await Ui.read_doc("a", PHRASES[idx])
	if idx + 1 < CLUES.size():
		await Ui.read_doc("a", CLUES[idx + 1])
	_busy = false
	_update_stage()
	await _hospitalize(idx)
	bleed(STAGE_BLEED[idx])
	match idx:
		0:
			_apparition(Vector3(20.6, 0, 3.8), 7.0)
		1:
			_apparition(Vector3(16.0, 0, 3.4), 6.0)
		2:
			_apparition(BED + Vector3(1.3, 0, 1.6), 5.5, 40.0)
	if _stage >= 4:
		_unlock_lab()


func _decoy(_ch: Character) -> void:
	await say(["a: Só terra úmida e folhas."])


func _on_painting(_ch: Character) -> void:
	if _stage == 2:
		await say([
			"Uma nota de cinquenta reais, pintada em tamanho grande. A onça-pintada encara você.",
			"a: \"Sinta orgulho de sua nação\"... e ela não olha para mim. Olha para o fundo, à esquerda. Para o escuro.",
		])
	else:
		await say(["Uma nota de cinquenta reais, pintada em tamanho grande. A onça-pintada encara você."])


func _on_lab_door(_ch: Character) -> void:
	if _lab_door.is_open:
		return
	_lab_door.rattle()
	await say(["a: Trancada. A luz da fechadura está vermelha."])


func _unlock_lab() -> void:
	Game.lock_input()
	await get_tree().create_timer(0.4).timeout
	Audio.sfx("lock_open", 0.0)
	var led: MeshInstance3D = _lab_door.get_meta("led")
	led.material_override = Build.color_mat(Color("38d07a"), 2.0)
	await say([
		"Um clique distante ecoa pela casa. Depois, um bipe. E outro.",
		"a: O laboratório... a porta da galeria.",
	])
	_lab_door.open()
	_lab_door_it.disable()
	Game.unlock_input()


func _on_terminal(_ch: Character) -> void:
	if _done:
		return
	if _stage < 4:
		Audio.sfx("monitor_beep", -10.0)
		await say(["A tela pisca: AGUARDANDO QUATRO RESPOSTAS."])
		return
	var term := TerminalPanel.new("TERMINAL", [
		{"q": "AQUELE QUE TE DOPA", "answers": ["seus remédios te cegam"]},
		{"q": "AQUELE QUE TE INDUZ", "answers": ["suas drogas te traem", "suas drogas te tracam"]},
		{"q": "AQUELE QUE TE SEPARA", "answers": ["seu orgulho te cega"]},
		{"q": "AQUELE QUE TE SEDUZ", "answers": ["suas influências te destroem"]},
	], "Quatro perguntas. As respostas estão espalhadas pela casa.", TERMINAL_HINTS)
	if await puzzle(term):
		_finale()


func _finale() -> void:
	_done = true
	Game.lock_input()
	var a := party.a
	a.face("up")
	# As luzes morrem. Sobra a tela do terminal.
	Audio.sfx("light_out", -2.0)
	Audio.sfx("flatline", -14.0)
	cam.shake(0.3)
	for l in _lab_lights:
		if l != _lab_lights[0]:
			create_tween().tween_property(l, "light_energy", 0.0, 0.2)
	var t := create_tween().set_parallel()
	t.tween_property(env, "ambient_light_energy", 0.03, 0.6)
	t.tween_property(moon, "light_energy", 0.0, 0.6)
	t.tween_property(env, "fog_density", 0.0, 0.6)
	t.tween_property(env, "background_color", Color("050608"), 0.6)
	Audio.stop_ambience(1.5)
	await get_tree().create_timer(1.0).timeout
	await say(["A tela se apaga. Passos molhados, atrás de você."])
	# O Esquecido entra pela porta e anda até A.
	var s := spawn_stalker()
	s.hunting = false
	s.appear(LAB_DOOR + Vector3(0, 0, -1.2), 0.6)
	Ui.set_dread(0.7)
	a.face("down")
	cam.target = s
	await s.walk_to(a.global_position + Vector3(-1.5, 0, 0.4), 1.1)
	a.face("left")
	cam.target = a
	await say([
		"?: Chega. Você já leu o bastante.",
		"a: Quem é você?",
	])
	Audio.sfx("dread_sting", -2.0)
	Ui.flash(Color(0.5, 0.0, 0.02), 0.5)
	s.reveal()
	Build.omni(geo, s.global_position + Vector3(0.3, 2.0, 0.9), Color("c0303a"), 1.4, 4.0, false, true)
	Ui.set_dread(0.95)
	await get_tree().create_timer(1.2).timeout
	await say([
		"A mão desce devagar. O rosto é o seu.",
		"Os olhos fundos. A mão vermelha. Não é o seu sangue.",
		"?: Eu sou o que você decidiu esquecer.",
		"?: Lá fora tem dois leitos. O %d e o %d. Um deles não vai acordar." % [Game.number_a, Game.number_b],
		"?: Aqui dentro, ninguém morreu. Aqui, a culpa não é sua.",
		"?: Fica. Eu seguro a mão no seu rosto. Para sempre.",
	])
	# B aparece na porta da UTI.
	var b := party.b
	b.process_mode = Node.PROCESS_MODE_INHERIT
	b.collision_layer = 2
	b.teleport(LAB_DOOR + Vector3(0.8, 0, -0.6))
	b.visible = true
	Audio.sfx("door_open", -6.0)
	Ui.set_dread(0.3)
	await b.walk_to(a.global_position + Vector3(1.5, 0, 0.6), 2.0)
	b.face("left")
	await say([
		"b: %s." % Game.name_a,
		"b: Olha para mim. Não para isso.",
		"b: Naquela noite eu pedi a chave. Você passou direto.",
		"b: Eu cantei a estrada inteira para você não dormir.",
		"b: Depois eu gritei para você sair do carro. Você saiu. Era tudo o que eu queria.",
		"b: Agora eu grito de novo. Sai daqui. Acorda.",
		"?: Se acordar, vai lembrar. Todo dia. Da ponte, da água, da chave.",
		"b: Vai doer. E você vai continuar mesmo assim.",
	])
	if Game.all_memories():
		await say(["b: Você achou todas. Todas as partes daquela noite. Não precisa mais fugir de nenhuma."])
	var pick := await Ui.choose("O que você faz?", ["Lembrar", "Esquecer"])
	if pick == 0:
		Game.ending = "hope" if Game.all_memories() else "remember"
		await say([
			"a: Eu lembro.",
			"a: Fui eu que dirigi. Eu não entreguei a chave. Eu fechei os olhos.",
			"a: E %s abriu o meu cinto." % Game.name_b,
		])
		Audio.sfx("flash", -4.0)
		s.vanish(1.5)
		await Ui.whiteout(2.5)
	else:
		Game.ending = "forget"
		await say(["a: Eu não quero lembrar."])
		Audio.sfx("whisper_many", -4.0)
		b.visible = false
		s.reveal()
		await s.walk_to(a.global_position + Vector3(0, 0, 0.5), 0.8)
		await say(["Uma mão fria cobre o seu rosto. Não dói. Não pesa. Não há mais nada para lembrar."])
		await Ui.fade_out(2.0)
	Ui.set_dread(0.0, true)
	finish()


# --- Depuração (tools/shot.sh --call=...) --------------------------------------------

func _debug_garage() -> void:
	party.a.teleport(Vector3(-30.5, GARAGE_Y, -5.8))
	_process(0.0)
	cam.snap()


func _debug_stairs() -> void:
	party.a.teleport(Vector3(-19.0, 0, -3.0))
	cam.snap()


func _debug_library() -> void:
	party.a.teleport(Vector3(4.2, 0, 3.6))
	cam.snap()


func _debug_gallery() -> void:
	party.a.teleport(Vector3(15.0, 0, -3.8))
	cam.snap()


func _debug_lab() -> void:
	_stage = 4
	_lab_door.open()
	party.a.teleport(Vector3(18.0, 0, -12.0))
	cam.snap()


func _debug_reveal() -> void:
	_debug_lab()
	env.ambient_light_energy = 0.08
	moon.light_energy = 0.05
	env.background_color = Color("050608")
	for l in _lab_lights.slice(1):
		l.light_energy = 0.0
	var s := spawn_stalker()
	env.ambient_light_energy = 0.03
	env.fog_density = 0.0
	moon.light_energy = 0.0
	s.appear(party.a.global_position + Vector3(-1.5, 0, 0.4), 0.0)
	s.reveal()
	Build.omni(geo, s.global_position + Vector3(0.3, 2.0, 0.9), Color("c0303a"), 1.4, 4.0, false, true)
	party.b.process_mode = Node.PROCESS_MODE_INHERIT
	party.b.visible = true
	party.b.teleport(party.a.global_position + Vector3(1.5, 0, 0.6))
	cam.snap()


func _debug_hospital() -> void:
	for i in 4:
		_hosp[i].visible = true
	for l in _warm_lights:
		l.light_energy = 0.0
	party.a.teleport(BED + Vector3(1.5, 0, 3.5))
	cam.snap()
