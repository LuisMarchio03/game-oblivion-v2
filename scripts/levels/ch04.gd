extends LevelBase
## Capítulo 4 — Dois Caminhos (enigma 4 original).
## A segue pela trilha da esquerda (porta com "GET OUT OF HERE", bilhete em morse,
## píer com a chave pigpen); B pela direita (carroça, corpo de bruços que B não vira, com o
## bilhete em pigpen; caixa com a tabela morse). O portão de ferro ao norte tem dois
## cadeados: o de A pede ESQUECA e o de B pede NUNCA. Juntos: "NUNCA ESQUEÇA".
## Terror: ao ler o morse, A ouve a voz falsa de B ("x:") e o Esquecido passa a patrulhar a
## trilha de A (esconderijos: barco virado no lago, barril no barraco, barril no portão);
## o corpo muda de posição depois que B lê o pigpen; luzes de erro nos dois cadeados;
## vozes do hospital quando o cadeado de A abre; lembrança m4 no canto noroeste do lado de A.

const GATE_Z := -22.2
const TRAIL_Z := 1.0          # onde as trilhas se separam
const LAYER_ONLY_B := 4       # camada que só B enxerga (fecha a trilha de A para B)
const LAYER_ONLY_A := 8       # camada que só A enxerga (fecha a trilha de B para A)
# Patrulha do Esquecido na trilha de A: portão -> barraco -> entrada do píer -> portão.
const PATROL := [Vector3(-5.2, 0, -18.6), Vector3(-5.2, 0, -10.0), Vector3(-6.3, 0, -14.2)]
const CP_A_TRAIL := Vector3(-5.2, 0.05, -1.0)   # ponto seguro no começo da trilha
const CP_A_PIER := Vector3(-12.0, 0.15, -15.0)  # ponto seguro na ponta do píer
const HIDE_BOAT := Vector3(-7.05, 0, -12.5)
const HIDE_BARREL_SHACK := Vector3(-6.7, 0, -7.7)
const HIDE_BARREL_GATE := Vector3(-3.9, 0, -21.1)
const MEMORY_POS := Vector3(-11.7, 0, -20.6)

const MORSE := [
	["A", ".-"], ["B", "-..."], ["C", "-.-."], ["D", "-.."], ["E", "."], ["F", "..-."],
	["G", "--."], ["H", "...."], ["I", ".."], ["J", ".---"], ["K", "-.-"], ["L", ".-.."],
	["M", "--"], ["N", "-."], ["O", "---"], ["P", ".--."], ["Q", "--.-"], ["R", ".-."],
	["S", "..."], ["T", "-"], ["U", "..-"], ["V", "...-"], ["W", ".--"], ["X", "-..-"],
	["Y", "-.--"], ["Z", "--.."],
]

var _gate_l: Mover
var _gate_r: Mover
var _lock_l: Interactable
var _lock_r: Interactable
var _padlock_l: Node3D
var _padlock_r: Node3D
var _open_a := false
var _open_b := false
var _gate_done := false
var _docs := {}  # id -> dados (para depuração visual)
var _corpse: Sprite3D
var _corpse_moved := false
var _door_seen := false
var _fake_heard := false      # A ouviu a voz que imita B
var _patrol_started := false
var _patrol_on := false
var _patrol_paused := false
var _gate_words: Label3D


func _init() -> void:
	chapter_index = 3
	preset = "forest"
	ambience = "amb_forest"
	spawn_a = Vector3(-1.4, 0, 6.0)
	spawn_b = Vector3(1.4, 0, 6.0)
	cam_bounds = Rect2(-9.5, -28, 19, 34)


# --- Geometria ----------------------------------------------------------------------

func _build() -> void:
	var grass := Build.mat("grass")
	var dirt := Build.mat("dirt")
	# Chão: tudo grama, menos o recorte do lago (lado A, x -13.8..-7.8, z -18.5..-11.5).
	Build.ground(geo, Rect2(-15, -11.5, 30, 21.5), 0.0, grass, "grass")
	Build.ground(geo, Rect2(-15, -34, 30, 15.5), 0.0, grass, "grass")
	Build.ground(geo, Rect2(-15, -18.5, 1.2, 7.0), 0.0, grass, "grass")
	Build.ground(geo, Rect2(-7.8, -18.5, 22.8, 7.0), 0.0, grass, "grass")
	# Trilhas de terra.
	Build.box(geo, Vector3(9, 0.02, 3.0), Vector3(0, 0.01, 5.0), dirt, false)
	Build.box(geo, Vector3(2.2, 0.02, 24), Vector3(-5.2, 0.01, -9.5), dirt, false)
	Build.box(geo, Vector3(2.2, 0.02, 24), Vector3(5.2, 0.01, -9.5), dirt, false)
	Build.box(geo, Vector3(3.2, 0.02, 2.0), Vector3(-3.0, 0.011, 2.6), dirt, false)
	Build.box(geo, Vector3(3.2, 0.02, 2.0), Vector3(3.0, 0.011, 2.6), dirt, false)
	Build.box(geo, Vector3(4.2, 0.02, 3.2), Vector3(-2.6, 0.011, -20.3), dirt, false)
	Build.box(geo, Vector3(4.2, 0.02, 3.2), Vector3(2.6, 0.011, -20.3), dirt, false)
	Build.box(geo, Vector3(2.6, 0.02, 10), Vector3(0, 0.01, -27.5), Build.mat("stone_path"), false)

	# Limites do mapa.
	Build.blocker(geo, Vector3(32, 4, 1), Vector3(0, 2, 9.5))
	Build.blocker(geo, Vector3(1, 4, 46), Vector3(-14.0, 2, -12))
	Build.blocker(geo, Vector3(1, 4, 46), Vector3(14.0, 2, -12))
	Build.blocker(geo, Vector3(32, 4, 1), Vector3(0, 2, -33.0))
	# Encruzilhada: mata fechada nas laterais sul, deixando só as duas trilhas.
	Build.blocker(geo, Vector3(8.5, 4, 1.4), Vector3(-9.6, 2, 3.2))
	Build.blocker(geo, Vector3(8.5, 4, 1.4), Vector3(9.6, 2, 3.2))
	# Mata fechada entre as trilhas (do cruzamento até o portão).
	Build.blocker(geo, Vector3(4.4, 4, 20.5), Vector3(0, 2, -8.75))
	# Cada trilha só aceita o seu viajante (camadas de colisão próprias).
	var shut_a := Build.blocker(geo, Vector3(11.6, 4, 0.4), Vector3(-7.9, 2, TRAIL_Z))
	shut_a.collision_layer = LAYER_ONLY_B
	var shut_b := Build.blocker(geo, Vector3(11.6, 4, 0.4), Vector3(7.9, 2, TRAIL_Z))
	shut_b.collision_layer = LAYER_ONLY_A
	zone(Vector3(-7.9, 1, TRAIL_Z + 0.6), Vector3(11.6, 2, 0.9), _wrong_trail.bind("a"), false)
	zone(Vector3(7.9, 1, TRAIL_Z + 0.6), Vector3(11.6, 2, 0.9), _wrong_trail.bind("b"), false)

	_build_crossroads()
	_build_left()
	_build_right()
	_build_gate()
	_build_nature()


func _build_crossroads() -> void:
	# Placa de madeira sem inscrição: duas setas, uma para cada lado.
	var wood := Build.mat("planks_dark", Color(1, 1, 1), 1.0)
	Build.box(geo, Vector3(0.16, 2.2, 0.16), Vector3(0, 1.1, 2.2), Build.mat("bark"), true)
	var arrow_l := Build.box(geo, Vector3(1.2, 0.26, 0.06), Vector3(-0.55, 1.85, 2.3), wood, false)
	arrow_l.rotation_degrees.z = 6
	var arrow_r := Build.box(geo, Vector3(1.2, 0.26, 0.06), Vector3(0.55, 1.5, 2.3), wood, false)
	arrow_r.rotation_degrees.z = -8
	Build.text3d(geo, "<", Vector3(-1.05, 1.86, 2.34), 0.0, 48, Color("b8ad96"))
	Build.text3d(geo, ">", Vector3(1.05, 1.44, 2.34), 0.0, 48, Color("b8ad96"))
	Build.omni(geo, Vector3(0, 2.6, 4.0), Color("7b97d6"), 1.0, 7.0)


func _build_left() -> void:
	# --- Barraco com a porta velha.
	var planks := Build.mat("planks_dark", Color(1, 1, 1), 1.5)
	var wood_wall := Build.mat("wood_wall", Color(0.8, 0.8, 0.85), 1.5)
	var sx := -9.4
	var sz := -6.4  # face sul do barraco
	# Paredes (sul com vão da porta).
	Build.box(geo, Vector3(1.7, 3.0, 0.3), Vector3(sx - 1.55, 1.5, sz), wood_wall, true)
	Build.box(geo, Vector3(1.7, 3.0, 0.3), Vector3(sx + 1.55, 1.5, sz), wood_wall, true)
	Build.box(geo, Vector3(1.4, 0.6, 0.3), Vector3(sx, 2.7, sz), wood_wall, true)
	Build.box(geo, Vector3(0.3, 3.0, 3.6), Vector3(sx - 2.25, 1.5, sz - 1.8), wood_wall, true)
	Build.box(geo, Vector3(0.3, 3.0, 3.6), Vector3(sx + 2.25, 1.5, sz - 1.8), wood_wall, true)
	Build.box(geo, Vector3(4.8, 3.0, 0.3), Vector3(sx, 1.5, sz - 3.6), wood_wall, true)
	var roof := Build.box(geo, Vector3(5.4, 0.18, 4.6), Vector3(sx, 3.35, sz - 1.8), Build.mat("roof"), false)
	roof.rotation_degrees.x = -14
	# Porta trancada com o aviso talhado.
	var door := Build.door(geo, Vector3(sx, 0, sz + 0.05), 0.0, planks, 1.2, 2.4)
	Build.text3d(geo, "GET OUT\nOF HERE", Vector3(sx, 1.55, sz + 0.13), 0.0, 44, Color("d23a2e"), UiTheme.FONT_HAND, 0.0065)
	var it := interact(Vector3(sx - 0.2, 0, sz + 0.9), "Forçar a porta", func(_ch):
		door.rattle()
		if not _door_seen:
			_door_seen = true
			await say([
				"a: Trancada. Alguém talhou isso na madeira com uma faca.",
				"a: \"Get out of here\"... Saia daqui.",
				"a: Saia. Por que todo mundo quer que eu saia?",
			])
		, "a", 1.0, true, 2.8)
	it.deny_text = "Não é o meu caminho."
	# Bilhete em morse pregado na parede ao lado da porta. Ao ler, a voz falsa de B.
	Build.flat_sprite(geo, "icon_note", Vector3(sx + 1.25, 1.45, sz + 0.17), Vector3.ZERO, 0.03)
	_doc_then(Vector3(sx + 1.25, 0, sz + 0.9), {
		"id": "ch4_morse",
		"title": "Bilhete pregado na parede",
		"body": "[center][font_size=64]. ... --.- ..- . -.-. .-[/font_size]\n\n\n[i]Pontos e traços, riscados com pressa.\nAlguém queria muito que isto fosse lembrado.[/i][/center]",
		"style": "paper",
	}, "Ler bilhete pregado", "a", 0.9, _after_morse)
	Build.torch(geo, Vector3(sx + 2.2, 1.6, sz + 0.35), 1.3, 6.5)
	Build.billboard(geo, "cobweb", Vector3(sx - 2.1, 2.2, sz + 0.2), 0.03)

	# --- Lago escuro e píer.
	var pond := Rect2(-13.8, -18.5, 6.0, 7.0)
	Build.ground(geo, pond, -0.9, Build.mat("dirt_dark"), "dirt")
	Build.water(geo, pond, -0.32)
	var pz := -15.0
	var pier_mat := Build.mat("planks_dark", Color(0.85, 0.8, 0.75), 1.0)
	Build.box(geo, Vector3(5.8, 0.1, 1.5), Vector3(-10.3, 0.05, pz), pier_mat, true, 0.0, "wood")
	for x in [-12.8, -11.0, -9.2]:
		for z in [pz - 0.7, pz + 0.7]:
			Build.cylinder(geo, 0.09, 1.3, Vector3(x, -0.4, z), Build.mat("bark"), false, 6)
	Build.cylinder(geo, 0.08, 1.1, Vector3(-13.0, 0.55, pz - 0.7), Build.mat("bark"), false, 6)
	# Bloqueios ao redor do lago (só o píer é caminhável).
	Build.blocker(geo, Vector3(6.2, 4, pond.end.y - (pz + 0.75)), Vector3(pond.get_center().x, 2, (pz + 0.75 + pond.end.y) / 2.0))
	Build.blocker(geo, Vector3(6.2, 4, (pz - 0.75) - pond.position.y), Vector3(pond.get_center().x, 2, (pond.position.y + pz - 0.75) / 2.0))
	Build.blocker(geo, Vector3(0.4, 4, 1.6), Vector3(-13.4, 2, pz))
	# Caixa de ferramentas na ponta do píer: a chave pigpen.
	_toolbox(Vector3(-12.6, 0.1, pz + 0.2), 90.0)
	_doc_then(Vector3(-12.3, 0.1, pz), {
		"id": "ch4_pigpen_key",
		"title": "Papel dobrado dentro da caixa de ferramentas",
		"body": "[center][i]Guardado entre chaves de fenda enferrujadas.[/i][/center]",
		"style": "pigpen_key",
	}, "Abrir caixa de ferramentas", "a", 1.1, _after_key)
	Build.omni(geo, Vector3(-12.0, 1.4, pz + 0.6), Color("8fb0e8"), 1.0, 5.0)
	for i in 14:
		var a := rng.randf() * TAU
		Build.billboard(geo, "reeds", Vector3(-10.8 + cos(a) * 3.1, -0.3, -15 + sin(a) * 3.6), 0.035)
	_build_left_horror()


## Esconderijos da trilha de A e a lembrança escondida no canto noroeste.
func _build_left_horror() -> void:
	var hull := Build.mat("planks_dark", Color(0.7, 0.68, 0.66), 1.0)
	# Barco virado na margem do lago (casco para cima).
	var boat := Node3D.new()
	boat.position = HIDE_BOAT
	boat.rotation_degrees.y = 8.0
	geo.add_child(boat)
	Build.box(boat, Vector3(0.95, 0.12, 2.3), Vector3(0, 0.62, 0), hull, false)
	for sx in [-1.0, 1.0]:
		var side := Build.box(boat, Vector3(0.1, 0.55, 2.3), Vector3(sx * 0.5, 0.3, 0), hull, false)
		side.rotation_degrees.z = sx * -14.0
	Build.box(boat, Vector3(0.9, 0.5, 0.1), Vector3(0, 0.3, 1.15), hull, false)
	var bow := Build.box(boat, Vector3(0.7, 0.45, 0.5), Vector3(0, 0.3, -1.3), hull, false)
	bow.rotation_degrees.y = 45.0
	var oar := Build.box(geo, Vector3(0.08, 0.04, 1.7), HIDE_BOAT + Vector3(0.75, 0.03, 0.6), Build.mat("bark"), false, 30.0)
	oar.rotation_degrees.x = 4.0
	hide_spot(HIDE_BOAT + Vector3(0.1, 0, 0), "Esconder-se sob o barco", "a")
	# Barris: encostado no barraco e junto ao portão.
	_barrel(HIDE_BARREL_SHACK)
	_barrel(HIDE_BARREL_SHACK + Vector3(0.1, 0, 0.75), 0.8)
	hide_spot(HIDE_BARREL_SHACK, "Esconder-se atrás do barril", "a")
	_barrel(HIDE_BARREL_GATE)
	hide_spot(HIDE_BARREL_GATE, "Esconder-se atrás do barril", "a")

	# Lembrança m4: placa de estrada caída e um rádio de carro no mato, no canto escuro.
	var m := MEMORY_POS
	var post := Build.box(geo, Vector3(0.1, 1.9, 0.1), m + Vector3(0.6, 0.6, -0.5), Build.mat("rust_metal"), false)
	post.rotation_degrees.z = 38.0
	var sign_mat := Build.color_mat(Color("2f4a38"), 0.0, 0.6)
	var plate := Build.box(geo, Vector3(1.2, 0.5, 0.05), m + Vector3(1.25, 1.2, -0.5), sign_mat, false)
	plate.rotation_degrees.z = 38.0
	var words := Build.text3d(geo, "PONTE  200 m", m + Vector3(1.25, 1.2, -0.46), 0.0, 30, Color("c9d2c0"), UiTheme.FONT_UI, 0.006)
	words.rotation_degrees.z = 38.0
	var radio := Build.box(geo, Vector3(0.45, 0.14, 0.3), m + Vector3(-0.1, 0.07, 0.15), Build.color_mat(Color("15171a"), 0.0, 0.5), false, 20.0)
	Build.box(radio, Vector3(0.08, 0.04, 0.02), Vector3(0.12, 0.03, 0.16), Build.color_mat(Color("4cff7a"), 2.0), false)
	Build.billboard(geo, "reeds", m + Vector3(-0.6, 0, 0.6), 0.04)
	Build.billboard(geo, "fern", m + Vector3(0.4, 0, 0.7), 0.045)
	zone(m, Vector3(4, 2, 3.4), func(ch: Character):
		if ch.who == "a":
			Audio.sfx_at("radio_static", radio, -8.0, 12.0))
	memory(m, "m4", "A música",
		"Três e cinquenta. %s cantava alto, desafinando de propósito.\n\nToda vez que eu ria, cantava mais alto.\n\nNão entendi por quê." % Game.name_b)


func _barrel(pos: Vector3, k := 1.0) -> void:
	var wood := Build.mat("planks_dark", Color(0.75, 0.6, 0.45), 1.0)
	Build.cylinder(geo, 0.34 * k, 0.95 * k, pos + Vector3(0, 0.475 * k, 0), wood, false, 10)
	var band := Build.color_mat(Color("2a2d31"), 0.0, 0.45)
	for y in [0.2, 0.75]:
		Build.cylinder(geo, 0.355 * k, 0.05, pos + Vector3(0, y * k, 0), band, false, 10)


func _build_right() -> void:
	# --- Carroça quebrada.
	var cx := 7.6
	var cz := -6.0
	var wood := Build.mat("planks_dark", Color(0.9, 0.85, 0.8), 1.0)
	var bed := Build.box(geo, Vector3(2.6, 0.5, 1.5), Vector3(cx, 0.75, cz), wood, false)
	bed.rotation_degrees.z = -9
	bed.rotation_degrees.y = 12
	Build.box(bed, Vector3(2.6, 0.5, 0.08), Vector3(0, 0.4, 0.72), wood, false)
	var side := Build.box(bed, Vector3(2.6, 0.45, 0.08), Vector3(0, 0.45, -0.72), wood, false)
	side.rotation_degrees.x = 6
	var wheel_mat := Build.mat("bark", Color(0.8, 0.75, 0.7), 1.0)
	var w1 := Build.cylinder(geo, 0.6, 0.12, Vector3(cx + 0.9, 0.6, cz + 0.95), wheel_mat, false, 10)
	w1.rotation_degrees = Vector3(90, 12, 0)
	var w2 := Build.cylinder(geo, 0.6, 0.12, Vector3(cx + 0.7, 0.6, cz - 0.95), wheel_mat, false, 10)
	w2.rotation_degrees = Vector3(90, 12, 0)
	var w3 := Build.cylinder(geo, 0.6, 0.12, Vector3(cx - 2.2, 0.07, cz + 1.4), wheel_mat, false, 10)
	w3.rotation_degrees = Vector3(0, 0, 4)
	var shaft := Build.box(geo, Vector3(2.2, 0.1, 0.1), Vector3(cx + 2.3, 0.3, cz + 0.3), wood, false)
	shaft.rotation_degrees = Vector3(0, 20, -10)
	Build.blocker(geo, Vector3(2.8, 2, 1.8), Vector3(cx, 1, cz))
	# Sacos e caixotes caídos.
	Build.box(geo, Vector3(0.6, 0.5, 0.6), Vector3(cx + 1.6, 0.25, cz + 1.3), Build.mat("wood_wall"), true, 25.0)
	Build.sphere(geo, 0.32, Vector3(cx - 1.3, 0.22, cz - 1.1), Build.color_mat(Color("5c4d3a")))

	# --- O corpo com o bilhete em pigpen: veste a jaqueta verde-escura de B.
	_corpse = Build.billboard(geo, "corpse", Vector3(cx - 1.8, 0, cz + 1.9), 0.032, 1, 0, Color(0.62, 0.86, 0.6))
	_corpse.flip_h = true
	# Um retalho verde da manga rasgada, caído ao lado.
	var rag := Build.box(geo, Vector3(0.28, 0.02, 0.12), Vector3(cx - 1.1, 0.02, cz + 2.35), Build.color_mat(Color("2f4a2c")), false, 35.0)
	rag.rotation_degrees.x = 3.0
	Build.decal(geo, "res://assets/legacy/blood_hand.png", Vector3(cx - 1.4, 0.2, cz + 2.2), Vector3(0.7, 1.0, 0.9), Vector3.ZERO, Color(0.55, 0.1, 0.1, 0.8))
	var pig := {
		"id": "ch4_pigpen",
		"title": "Bilhete na mão do corpo",
		"cipher": "NUNCA",
		"body": "[center][i]O papel está preso entre os dedos frios.\nSão desenhos, não letras.[/i][/center]",
		"style": "pigpen",
	}
	_docs[pig["id"]] = pig
	interact(Vector3(cx - 1.8, 0, cz + 2.4), "Examinar o corpo", _examine_corpse.bind(pig), "b", 1.2)
	Build.torch(geo, Vector3(cx + 2.4, 1.2, cz + 2.0), 1.4, 7.0)
	Build.box(geo, Vector3(0.12, 1.3, 0.12), Vector3(cx + 2.4, 0.3, cz + 2.0), Build.mat("bark"), false)

	# --- Toco e caixa de ferramentas com a tabela morse.
	var tx := 10.4
	var tz := -14.2
	Build.cylinder(geo, 0.55, 0.7, Vector3(tx - 0.2, 0.35, tz - 0.9), Build.mat("bark", Color(0.62, 0.5, 0.4)), true, 9)
	var trunk := Build.cylinder(geo, 0.3, 3.2, Vector3(tx - 2.6, 0.3, tz - 1.4), Build.mat("bark", Color(0.55, 0.45, 0.36)), false, 8)
	trunk.rotation_degrees = Vector3(0, 30, 90)
	var trunk_block := Build.blocker(geo, Vector3(3.2, 1.2, 0.8), Vector3(tx - 2.6, 0.6, tz - 1.4))
	trunk_block.rotation_degrees.y = 30
	_toolbox(Vector3(tx - 0.2, 0.7, tz - 0.9), -10.0)
	doc(Vector3(tx - 0.2, 0, tz), {
		"id": "ch4_morse_table",
		"title": "Tabela gasta na caixa",
		"body": "[center][table=4]%s[/table][/center]" % _morse_table_cells(),
		"style": "paper",
	}, "Abrir caixa de ferramentas", "b", 1.2)
	Build.omni(geo, Vector3(tx, 1.8, tz + 0.6), Color("8fb0e8"), 1.0, 5.0)
	var crow := Build.billboard(geo, "crow", Vector3(tx - 3.4, 0.6, tz - 1.8), 0.035, 2)
	var ca := SpriteAnim.new()
	ca.frames = 2
	ca.fps = 1.1
	crow.add_child(ca)


func _morse_table_cells() -> String:
	# Quatro colunas: letra | código | letra | código (A–M à esquerda, N–Z à direita).
	var out := ""
	for i in 13:
		var l: Array = MORSE[i]
		var r: Array = MORSE[i + 13]
		out += "[cell][b]%s[/b]   [/cell][cell]%s          [/cell][cell][b]%s[/b]   [/cell][cell]%s[/cell]" % [l[0], l[1], r[0], r[1]]
	return out


func _toolbox(pos: Vector3, rot_y: float) -> void:
	var rust := Build.mat("rust_metal", Color.WHITE, 0.6)
	var b := Build.box(geo, Vector3(0.7, 0.32, 0.36), pos + Vector3(0, 0.16, 0), rust, false, rot_y)
	Build.box(b, Vector3(0.5, 0.05, 0.05), Vector3(0, 0.24, 0), Build.color_mat(Color("22262b"), 0.0, 0.4), false)
	Build.box(b, Vector3(0.05, 0.1, 0.05), Vector3(-0.22, 0.2, 0), Build.color_mat(Color("22262b"), 0.0, 0.4), false)
	Build.box(b, Vector3(0.05, 0.1, 0.05), Vector3(0.22, 0.2, 0), Build.color_mat(Color("22262b"), 0.0, 0.4), false)


func _build_gate() -> void:
	var stone := Build.mat("stone_wall", Color(0.85, 0.87, 0.92), 2.0)
	# Muro ao norte com vão para o portão (x de -2.4 a 2.4).
	Build.box(geo, Vector3(11.6, 3.4, 0.6), Vector3(-8.2, 1.7, GATE_Z), stone, true)
	Build.box(geo, Vector3(11.6, 3.4, 0.6), Vector3(8.2, 1.7, GATE_Z), stone, true)
	# Pilares e pilar central (o muro baixo central separa os dois lados até o portão).
	for x in [-2.6, 2.6]:
		Build.box(geo, Vector3(0.7, 4.0, 0.9), Vector3(x, 2.0, GATE_Z), stone, true)
		Build.sphere(geo, 0.28, Vector3(x, 4.25, GATE_Z), stone)
	Build.box(geo, Vector3(0.6, 4.0, 0.9), Vector3(0, 2.0, GATE_Z), stone, true)
	Build.box(geo, Vector3(0.6, 2.6, 3.6), Vector3(0, 1.3, GATE_Z + 2.2), stone, true)
	var candle := Build.candle(geo, Vector3(0, 2.6, GATE_Z + 3.6), 1.2, 5.0)
	# Duas folhas de ferro (deslizam para dentro do muro).
	_gate_l = _gate_leaf(-1.27, -2.3)
	_gate_r = _gate_leaf(1.27, 2.3)
	# Cadeados (lado A à esquerda, lado B à direita).
	_padlock_l = _padlock(Vector3(-0.72, 1.25, GATE_Z + 0.14))
	_padlock_r = _padlock(Vector3(0.72, 1.25, GATE_Z + 0.14))
	_lock_l = interact(Vector3(-1.1, 0, GATE_Z + 1.0), "Examinar cadeado", _try_lock.bind("a"), "a", 1.2, true, 2.0)
	_lock_l.deny_text = "Esse cadeado não está do meu lado."
	_lock_r = interact(Vector3(1.1, 0, GATE_Z + 1.0), "Examinar cadeado", _try_lock.bind("b"), "b", 1.2, true, 2.0)
	_lock_r.deny_text = "Esse cadeado não está do meu lado."
	# Tochas do portão. Cada erro num cadeado apaga uma luz daqui.
	var torch_l := Build.torch(geo, Vector3(-3.3, 1.8, GATE_Z + 0.5), 1.5, 7.5)
	var torch_r := Build.torch(geo, Vector3(3.3, 1.8, GATE_Z + 0.5), 1.5, 7.5)
	for n in [torch_l, _padlock_l, candle, _padlock_r, torch_r]:
		var l := _light_of(n)
		if l:
			dread_light(l)
	# O pedido escrito sobre o portão (aparece quando ele abre).
	_gate_words = Build.text3d(geo, "NUNCA ESQUEÇA", Vector3(0, 4.35, GATE_Z + 0.5), 0.0, 44, Color("e8e1d2"), UiTheme.FONT_HAND, 0.0075)
	_gate_words.shaded = false
	_gate_words.modulate.a = 0.0
	# Além do portão: a estrada ao norte e a saída.
	Build.torch(geo, Vector3(-1.8, 1.2, -29.5))
	Build.torch(geo, Vector3(1.8, 1.2, -29.5))
	Build.blocker(geo, Vector3(8, 4, 1), Vector3(-6.4, 2, -26.5))
	Build.blocker(geo, Vector3(8, 4, 1), Vector3(6.4, 2, -26.5))
	exit_zone(Vector3(0, 1, -30.5), Vector3(5, 2, 2))


func _gate_leaf(x: float, open_dx: float) -> Mover:
	var iron := Build.color_mat(Color("2a2d31"), 0.0, 0.45)
	var mv := Build.mover(geo, Vector3(1.95, 0.12, 0.12), Vector3(x, 3.0, GATE_Z), Vector3(open_dx, 0, 0), iron)
	mv.sound = "gate_open"
	mv.time = 2.2
	Build.box(mv, Vector3(1.95, 0.12, 0.12), Vector3(0, -2.2, 0), iron, false)
	Build.box(mv, Vector3(1.95, 0.08, 0.1), Vector3(0, -1.2, 0), iron, false)
	for i in 8:
		var bx := -0.9 + i * (1.8 / 7.0)
		Build.box(mv, Vector3(0.05, 3.1, 0.05), Vector3(bx, -1.45, 0), iron, false)
		Build.sphere(mv, 0.05, Vector3(bx, 0.15, 0), iron)
	Build.blocker(mv, Vector3(1.95, 3.2, 0.3), Vector3(0, -1.5, 0))
	return mv


func _padlock(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	geo.add_child(root)
	# Corrente enrolada nas barras.
	var chain := Build.color_mat(Color("4d5157"), 0.0, 0.35)
	for i in 4:
		var link := Build.box(root, Vector3(0.28, 0.05, 0.05), Vector3((i - 1.5) * 0.18, 0.28 + (i % 2) * 0.03, -0.03), chain, false)
		link.rotation_degrees.z = 20 if i % 2 == 0 else -20
	Build.flat_sprite(root, "res://assets/legacy/padlock.png", Vector3.ZERO, Vector3.ZERO, 0.00075)
	Build.omni(root, Vector3(0, 0.2, 0.6), Color("ffcf8a"), 0.35, 1.6)
	return root


func _build_nature() -> void:
	# Mata fechada entre as trilhas: arbustos altos e espinheiros (não tapam a câmera)
	# e pinheiros só no miolo, longe do portão.
	Build.scatter(geo, ["bush", "bush", "bush", "fern"], Rect2(-2.1, -19.6, 4.2, 20.8), 90, 0.0, rng, [], 0.06, Color(0.8, 0.85, 0.9))
	for i in 40:
		_tree_at(Vector2(rng.randf_range(-1.7, 1.7), rng.randf_range(-12, 0.8)), ["tree_pine", "tree_pine", "tree_oak", "tree_dead"], 0.8, 1.1, false)
	# Mata ao sul da encruzilhada e nas laterais.
	for side in [-1.0, 1.0]:
		for i in 7:
			_tree_at(Vector2(side * rng.randf_range(6.5, 13.5), rng.randf_range(2.6, 4.0)), ["tree_pine"], 0.8, 1.2, false)
		for i in 12:
			_tree_at(Vector2(side * rng.randf_range(11.8, 13.6), rng.randf_range(-30, 0)), ["tree_pine", "tree_dead"], 0.9, 1.4, false)
	# Árvores soltas pelas trilhas, fora das áreas de interesse.
	var avoid := [
		Rect2(-13.8, -18.8, 6.4, 7.6),   # lago
		Rect2(-12.2, -10.6, 5.8, 5.4),   # barraco
		Rect2(-6.8, -22, 3.2, 24),       # trilha A
		Rect2(3.6, -22, 3.2, 24),        # trilha B
		Rect2(4.2, -9.2, 7.0, 6.4),      # carroça
		Rect2(6.6, -16.8, 5.2, 4.2),     # toco
		Rect2(-5, -23.5, 10, 4),         # portão
		Rect2(-8.0, -14.0, 1.8, 3.2),    # barco virado
		Rect2(-7.4, -8.6, 1.4, 2.2),     # barril do barraco
		Rect2(-13.6, -22.0, 8.8, 3.6),   # canto da lembrança
	]
	for i in 60:
		var p := Vector2(rng.randf_range(-13, 13), rng.randf_range(-20.5, 0.5))
		if abs(p.x) < 2.6:
			continue
		var ok := true
		for r in avoid:
			if (r as Rect2).has_point(p):
				ok = false
		if ok:
			_tree_at(p, ["tree_pine", "tree_pine", "tree_dead", "tree_oak"], 0.8, 1.3, true)
	# Moldura escura ao norte, além do muro.
	for i in 14:
		Build.tree(geo, "tree_pine", Vector3(-14 + i * 2.1 + rng.randf_range(-0.4, 0.4), 0, -31.5 + rng.randf_range(-0.8, 0.8)), rng.randf_range(1.0, 1.5), false)
	for i in 8:
		_tree_at(Vector2([-1, 1][i % 2] * rng.randf_range(3.5, 11), rng.randf_range(-29, -24)), ["tree_dead"], 0.9, 1.2, false)
	Build.scatter(geo, ["grass", "grass", "fern", "bush", "flower_white"], Rect2(-13.5, -32, 27, 40), 220, 0.0, rng,
		[Rect2(-13.8, -18.8, 6.4, 7.6), Rect2(-6.4, -22, 2.4, 24), Rect2(4.0, -22, 2.4, 24), Rect2(-4.6, 3.4, 9.2, 3.4), Rect2(-1.4, -32, 2.8, 9.6)])
	Build.motes(geo, Vector3(-7, 1.2, -10), Vector3(5, 1.2, 10), 45, Color(0.7, 1.0, 0.8, 0.9), "firefly", 0.05)
	Build.motes(geo, Vector3(7, 1.2, -10), Vector3(5, 1.2, 10), 45, Color(0.7, 1.0, 0.8, 0.9), "firefly", 0.05)
	Build.motes(geo, Vector3(0, 1.0, -22), Vector3(6, 1.0, 3), 40, Color(0.8, 0.9, 1.0, 0.5), "dust", 0.05)
	# Luar frio ao longo das trilhas.
	Build.omni(geo, Vector3(-5.5, 2.4, -1.5), Color("6f8cc9"), 0.9, 7.0)
	Build.omni(geo, Vector3(5.5, 2.4, -1.5), Color("6f8cc9"), 0.9, 7.0)
	Build.omni(geo, Vector3(-5.5, 2.4, -17), Color("6f8cc9"), 0.8, 7.0)
	Build.omni(geo, Vector3(5.5, 2.4, -17), Color("6f8cc9"), 0.8, 7.0)


## Pontos que a câmera precisa enxergar: árvore alta logo ao sul deles tapa a visão.
const VIEW_POINTS := [
	Vector2(-1.4, 6), Vector2(1.4, 6), Vector2(-9.4, -5.5), Vector2(-9.4, -4.0), Vector2(-12.3, -15), Vector2(-10, -15),
	Vector2(-7.5, -15), Vector2(6, -3.5), Vector2(7.6, -4.5), Vector2(10.2, -13.8), Vector2(-1.1, -21), Vector2(1.1, -21),
	Vector2(0, -25), Vector2(0, -29), Vector2(-7.05, -12.5), Vector2(-6.7, -7.7), Vector2(-11.7, -20.6),
]


func _clear_view(p: Vector2) -> bool:
	var pts := VIEW_POINTS.duplicate()
	for z in range(-21, 3, 2):
		pts.append(Vector2(-5.2, z))
		pts.append(Vector2(5.2, z))
	for q in pts:
		var d: float = p.y - q.y
		if d > -1.0 and d < 10.0 and absf(p.x - q.x) < 3.3:
			return false
	return true


func _tree_at(p: Vector2, kinds: Array, smin: float, smax: float, collide: bool) -> void:
	if not _clear_view(p):
		return
	Build.tree(geo, kinds[rng.randi_range(0, kinds.size() - 1)], Vector3(p.x, 0, p.y), rng.randf_range(smin, smax), collide)


# --- Roteiro ------------------------------------------------------------------------

func doc(pos: Vector3, data: Dictionary, prompt := "Ler", who := "any", radius := 1.4) -> Interactable:
	_docs[data["id"]] = data
	return super(pos, data, prompt, who, radius)


## Documento que, depois de lido, chama `after(ch)`.
func _doc_then(pos: Vector3, data: Dictionary, prompt: String, who: String, radius: float, after: Callable) -> Interactable:
	_docs[data["id"]] = data
	return interact(pos, prompt, func(ch: Character):
		await Ui.read_doc(ch.who, data)
		await after.call(ch), who, radius)


func _light_of(n: Node) -> Light3D:
	if n is Light3D:
		return n
	for c in n.get_children():
		if c is Light3D:
			return c
	return null


func _begin() -> void:
	# Cada trilha só deixa passar quem a escolheu.
	party.a.collision_mask = 1 | LAYER_ONLY_A
	party.b.collision_mask = 1 | LAYER_ONLY_B
	objective("Escolham um caminho.")
	await say([
		"Há dois caminhos à frente de vocês. Qual lado cada um seguirá?",
		"a: Eu vou pela esquerda.",
		"b: Então eu fico com a direita. Qualquer coisa, grita o meu nome.",
		"a: E se os caminhos não se encontrarem?",
		"b: Eles se encontram. Eu vou estar lá no fim. Eu sempre estou.",
	])
	objective("%s pela esquerda, %s pela direita. Sigam até o fim da trilha." % [Game.name_a, Game.name_b])
	hints([
		"O bilhete de %s está em código morse, mas a tabela morse está com %s. O bilhete de %s está em pigpen, e a chave pigpen está com %s. Na trilha de %s, corra (Shift) ou esconda-se no barco virado e nos barris." % [Game.name_a, Game.name_b, Game.name_b, Game.name_a, Game.name_a],
		"Na tabela, \".\" é E e \"...\" é S. Na chave pigpen, cada letra é o desenho da casa onde ela mora: o \"N\" é a casa com ponto no meio da segunda grade.",
		"Cadeado de %s: ESQUECA. Cadeado de %s: NUNCA. Juntos: \"Nunca esqueça\"." % [Game.name_a, Game.name_b],
	])
	# Quem sobe a trilha de A sem ler o bilhete também desperta a patrulha.
	zone(Vector3(-5.2, 1, -9.0), Vector3(3.6, 2, 1.0), func(ch: Character):
		if ch.who == "a":
			_start_patrol(false)
		, false)
	# Aviso quando cada um chega ao portão.
	var seen := {}
	zone(Vector3(0, 1, GATE_Z + 3.0), Vector3(10, 2, 4), func(ch: Character):
		if _gate_done or seen.has(ch.who):
			return
		seen[ch.who] = true
		objective("Abram os dois cadeados do portão.")
		await say([ch.who + ": Um portão de ferro. Tem um cadeado com corrente do meu lado."])
		, false)


func _wrong_trail(ch: Character, trail: String) -> void:
	if ch.who == trail or not ch.active:
		return
	var owner_name := Game.char_name(trail)
	Ui.toast("%s: Esse é o caminho de %s. Eu vou pelo meu lado." % [Game.char_name(ch.who), owner_name])


# --- O corpo (lado de B) -------------------------------------------------------------

func _examine_corpse(ch: Character, data: Dictionary) -> void:
	if _corpse_moved:
		await Ui.read_doc(ch.who, data)
		return
	await say([
		"b: Tem alguém caído aqui. De bruços.",
		"b: Não vou virar.",
		"b: Tem um papel preso nos dedos.",
	])
	# Enquanto B lê, o corpo muda de posição.
	get_tree().create_timer(0.6).timeout.connect(_shift_corpse)
	await Ui.read_doc(ch.who, data)
	_shift_corpse()
	Audio.sfx("dread_sting", -6.0)
	Audio.sfx("breath", -10.0)
	cam.shake(0.25)
	await say([
		"b: ...não estava assim.",
	])


func _shift_corpse() -> void:
	if _corpse_moved or _corpse == null:
		return
	_corpse_moved = true
	var from := _corpse.position
	_corpse.position = from + Vector3(-0.9, 0, 0.75)
	_corpse.flip_h = false
	# Rastro de arrasto no chão, entre onde estava e onde está.
	Build.decal(geo, "res://assets/legacy/blood_hand.png", from.lerp(_corpse.position, 0.5) + Vector3(0, 0.2, 0), Vector3(0.6, 1.0, 0.8), Vector3(0, 50, 0), Color(0.45, 0.08, 0.08, 0.7))


# --- O Esquecido na trilha de A ------------------------------------------------------

func _after_morse(_ch: Character) -> void:
	if _fake_heard or _open_a:
		return
	_fake_heard = true
	Audio.sfx("whisper_many", -16.0)
	await get_tree().create_timer(0.6).timeout
	await say([
		"x: %s. Volta." % Game.name_a,
		"x: Não precisa ler isso. Não precisa abrir nada.",
		"x: Fica aqui comigo. Aqui ninguém se machuca.",
		"a: %s? Você não estava do outro lado?" % Game.name_b,
	])
	await _start_patrol(true)


func _start_patrol(after_voice: bool) -> void:
	if _patrol_started or _open_a:
		return
	_patrol_started = true
	var s := spawn_stalker()
	s.sight = 5.5
	s.walk_speed = 1.3
	s.chase_speed = 3.4
	s.appear(PATROL[0], 1.2)
	set_checkpoint(CP_A_TRAIL, party.b.global_position)
	Game.lock_input()
	Audio.sfx("dread_sting", -4.0)
	await cam.look_at_point(PATROL[0] + Vector3(0, 1.0, 0), 1.4)
	await get_tree().create_timer(1.3).timeout
	cam.target = party.active
	Game.unlock_input()
	var lines := []
	if after_voice:
		lines.append("a: Não era %s." % Game.name_b)
	lines.append_array([
		"a: Tem alguém no fim da trilha.",
		"a: Vindo para cá.",
	])
	await say(lines)
	objective("Cheguem ao portão. Na trilha de %s: corra (Shift) ou esconda-se." % Game.name_a)
	s.patrol(PATROL, 1)
	_patrol_on = true


func _process(_delta: float) -> void:
	if not _patrol_on or stalker == null or _finishing:
		return
	# Só caça quando o jogador está com A (com B na tela, ele passa reto).
	stalker.hunting = party.active == party.a
	# B não é caçado: o ponto seguro de B acompanha B pelo lado direito.
	if party.b.global_position.x > 2.5 and party.b.is_on_floor():
		checkpoint_b = party.b.global_position
	var az := party.a.global_position.z
	if _patrol_paused:
		if az < -2.5 and Game.can_control():
			_patrol_paused = false
			stalker.appear(PATROL[0], 0.8)
			stalker.patrol(PATROL, 1)
	elif az > 0.5:
		# A voltou para a encruzilhada: a trilha fica quieta.
		_patrol_paused = true
		stalker.vanish(0.8)
	elif stalker.global_position.z > -3.0 and (stalker.state == Stalker.CHASE or stalker.state == Stalker.SEARCH):
		stalker.patrol(PATROL, 1)


## Depois de alcançar A: os dois já voltaram ao ponto seguro; ele recomeça no píer.
func _caught(_ch: Character) -> void:
	if stalker == null or not _patrol_on:
		if stalker:
			stalker.vanish(0.0)
		return
	stalker.global_position = PATROL[2]
	stalker.patrol(PATROL, 0)


func _after_key(_ch: Character) -> void:
	if _patrol_on:
		checkpoint_a = CP_A_PIER
	await _check_a_done()


## A terminou o que tinha a fazer na trilha (cadeado aberto e chave pigpen lida).
func _check_a_done() -> void:
	if not _patrol_on or not _open_a or not Game.has_doc("a", "ch4_pigpen_key"):
		return
	_end_patrol()
	await say([
		"a: Os passos pararam.",
		"a: ...Ou foram para outro lugar.",
	])


func _end_patrol(fade := 1.2) -> void:
	_patrol_on = false
	if stalker and stalker.visible:
		stalker.vanish(fade)


# --- Cadeados e portão ---------------------------------------------------------------

func _try_lock(ch: Character, side: String) -> void:
	if (side == "a" and _open_a) or (side == "b" and _open_b):
		return
	var lock: CodeLock
	if side == "a":
		lock = CodeLock.new("Cadeado de letras", ["ESQUECA"],
			"Um cadeado pesado prende a corrente do seu lado. Sete letras.",
			["O bilhete da porta está em morse. Quem tem a tabela?", "E = .   S = ...   Q = --.-   U = ..-   C = -.-.   A = .-", "ESQUECA"])
		lock.max_len = 7
	else:
		lock = CodeLock.new("Cadeado de letras", ["NUNCA"],
			"Um cadeado pesado prende a corrente do seu lado. Cinco letras.",
			["O bilhete do corpo está em pigpen. Quem tem a chave?", "Quadrado fechado com ponto (centro da 2ª grade) = N. O \"V\" de ponta para cima, sem ponto = U.", "NUNCA"])
		lock.max_len = 5
	lock.placeholder = "letras"
	var ok := await puzzle(lock)
	if not ok:
		return
	Audio.sfx("lock_open", 0.0)
	var pad := _padlock_l if side == "a" else _padlock_r
	var t := create_tween()
	t.tween_property(pad, "position:y", 0.05, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(pad, "rotation_degrees:z", -70.0 if side == "a" else 70.0, 0.4)
	if side == "a":
		_open_a = true
		_lock_l.disable()
		# "Esqueça" abre o cadeado; o hospital vaza (o resultado só chega no cap. 8).
		bleed(["Colheram sangue dos dois?", "Colheram. O resultado sai amanhã."])
	else:
		_open_b = true
		_lock_r.disable()
	if _open_a and _open_b:
		await _open_gate()
	else:
		var other := Game.char_name("b" if side == "a" else "a")
		await say([
			ch.who + ": Abriu. Mas a corrente ainda está presa no cadeado de %s." % other,
		])
		if side == "a":
			await _check_a_done()


func _open_gate() -> void:
	_gate_done = true
	_end_patrol(0.3)
	await get_tree().create_timer(0.6).timeout
	Game.lock_input()
	await cam.look_at_point(Vector3(0, 1.2, GATE_Z), 1.2)
	_gate_l.open()
	_gate_r.open()
	cam.shake(0.35)
	create_tween().tween_property(_gate_words, "modulate:a", 0.85, 2.0)
	await get_tree().create_timer(2.4).timeout
	Audio.sfx("success", -4.0)
	cam.target = party.active
	Game.unlock_input()
	var lines := [
		"O portão range e se abre. Em cima dele, alguém escreveu: NUNCA ESQUEÇA.",
		"b: O seu cadeado e o meu.",
		"a: Parece um pedido.",
	]
	if _fake_heard:
		lines.append_array([
			"a: Lá no barraco. Você me chamou?",
			"b: Não.",
		])
	if _corpse_moved:
		lines.append_array([
			"b: Tinha um corpo do meu lado.",
			"a: De quem?",
			"b: Não virei para ver.",
		])
	lines.append("a: Vem. A gente não se separa mais.")
	await say(lines)
	objective("Atravessem o portão juntos.")


# --- Depuração (tools/shot.sh --call=...) ------------------------------------------

func _debug_doc_morse() -> void:
	Ui.read_doc("a", _docs["ch4_morse"])


func _debug_doc_table() -> void:
	Ui.read_doc("b", _docs["ch4_morse_table"])


func _debug_doc_key() -> void:
	Ui.read_doc("a", _docs["ch4_pigpen_key"])


func _debug_doc_pigpen() -> void:
	Ui.read_doc("b", _docs["ch4_pigpen"])


func _debug_hold(who: String, pos: Vector3, action: String, secs: float) -> void:
	await get_tree().create_timer(4.5).timeout
	Ui.close_all_panels()
	Game.reset_input_lock()
	cam.set_view(Vector3(0, 7.2, 8.6), 34.0, 0.01)
	party.activate(who, true)
	party.get_char(who).teleport(pos)
	Input.action_press(action)
	await get_tree().create_timer(secs).timeout
	Input.action_release(action)


func _debug_b_left() -> void:
	_debug_hold("b", Vector3(-5.2, 0, 3.4), "move_up", 3.0)


func _debug_a_left() -> void:
	_debug_hold("a", Vector3(-5.2, 0, 3.4), "move_up", 3.0)


func _debug_open_gate() -> void:
	_gate_l.set_open(true, true)
	_gate_r.set_open(true, true)
	_gate_words.modulate.a = 0.85


## A na frente do barraco e o Esquecido patrulhando a trilha.
func _debug_patrol() -> void:
	party.a.teleport(Vector3(-6.4, 0.05, -5.2))
	cam.snap()
	var s := spawn_stalker()
	s.appear(Vector3(-5.4, 0, -9.4), 0.0)


## O corpo depois de mudar de posição (B ao lado).
func _debug_corpse() -> void:
	party.activate("b", true)
	party.b.teleport(Vector3(6.2, 0.05, -2.8))
	_shift_corpse()
	cam.snap()


func _debug_memory() -> void:
	party.a.teleport(MEMORY_POS + Vector3(1.2, 0.05, 0.6))
	cam.snap()
