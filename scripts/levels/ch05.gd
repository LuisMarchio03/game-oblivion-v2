extends LevelBase
## Capítulo 5 — A Casa (enigma 5 original).
## Fachada de uma casa grande e escura. "SAIA!" sussurrado ao chegar.
## A sobe pela trepadeira (esquerda) e B pela escada de pedra (direita); cada um
## chega a uma varanda isolada no 2º andar. A porta de A mostra LILÁS (B19CD9) e
## A acha as coordenadas do CIANO; a porta de B mostra CIANO (00FFFF) e B acha as
## coordenadas do LILÁS. Com as duas portas abertas, os dois seguem para o sótão.

const FACADE_Z := -6.0        # face sul da fachada
const FLOOR2 := 4.0           # piso do 2º andar / varandas
const DOOR_A_X := -6.5
const DOOR_B_X := 6.5
const STAIR_X := 11.0
const LAYER_ONLY_A := 8       # camada que só A enxerga (fecha a escada para A)
const LILAC := Color8(177, 156, 217)
const CYAN := Color8(0, 255, 255)

var _door_a: Door
var _door_b: Door
var _door_a_it: Interactable
var _door_b_it: Interactable
var _vines_it: Interactable
var _open_a := false
var _open_b := false
var _saia_labels: Array[Label3D] = []
var _docs := {}  # id -> dados (para depuração visual)


func _init() -> void:
	chapter_index = 4
	preset = "house_ext"
	ambience = "amb_forest"
	music = ""
	spawn_a = Vector3(-1.4, 0, 6.5)
	spawn_b = Vector3(1.4, 0, 6.5)
	cam_bounds = Rect2(-10, -6, 20, 13)


# --- Geometria ----------------------------------------------------------------------

func _build() -> void:
	# Chão do quintal e caminho de pedra até a porta.
	Build.ground(geo, Rect2(-16, -20, 32, 32), 0.0, Build.mat("grass", Color(0.85, 0.9, 0.95)), "grass")
	Build.box(geo, Vector3(2.4, 0.03, 12), Vector3(0, 0.015, 1.4), Build.mat("stone_path"), false)
	Build.box(geo, Vector3(7.7, 0.03, 1.4), Vector3(-3.15, 0.012, 0.7), Build.mat("dirt"), false, 120.6)
	Build.box(geo, Vector3(9.9, 0.03, 1.4), Vector3(6.1, 0.012, 3.5), Build.mat("dirt"), false, 5.8)
	# Limites.
	Build.blocker(geo, Vector3(32, 4, 1), Vector3(0, 2, 9.6))
	Build.blocker(geo, Vector3(1, 6, 20), Vector3(-13.5, 3, 0))
	Build.blocker(geo, Vector3(1, 6, 20), Vector3(13.5, 3, 0))
	Build.blocker(geo, Vector3(4, 6, 0.6), Vector3(-11.8, 3, FACADE_Z - 0.2))
	Build.blocker(geo, Vector3(4, 6, 0.6), Vector3(11.8, 3, FACADE_Z - 0.2))

	_build_house()
	_build_balcony_a()
	_build_balcony_b()
	_build_saia()
	_build_nature()


func _build_house() -> void:
	var wall := Build.mat("wood_wall", Color(0.55, 0.6, 0.72), 1.6)
	var trim := Build.mat("planks_dark", Color(0.7, 0.72, 0.8), 1.0)
	var fz := FACADE_Z - 0.2  # centro da parede (0,4 de espessura)
	# Fachada com os vãos das portas (térreo: centro; 2º andar: A e B).
	_wall_with_holes(fz, -10.0, 10.0, 0.0, 8.6, 0.4, wall, [
		Rect2(-0.8, 0.0, 1.6, 2.6),
		Rect2(DOOR_A_X - 0.62, FLOOR2, 1.24, 2.5),
		Rect2(DOOR_B_X - 0.62, FLOOR2, 1.24, 2.5),
	])
	# Laterais, fundos e laje do 2º andar (o interior fica no escuro).
	Build.box(geo, Vector3(0.4, 8.6, 10), Vector3(-10.0, 4.3, FACADE_Z - 5.0), wall, true)
	Build.box(geo, Vector3(0.4, 8.6, 10), Vector3(10.0, 4.3, FACADE_Z - 5.0), wall, true)
	Build.box(geo, Vector3(20.4, 8.6, 0.4), Vector3(0, 4.3, FACADE_Z - 10.0), wall, true)
	Build.box(geo, Vector3(19.6, 0.3, 9.6), Vector3(0, FLOOR2 - 0.15, FACADE_Z - 5.0), Build.color_mat(Color("0c0e14")), true)
	# Faixas horizontais entre andares e beiral.
	Build.box(geo, Vector3(20.6, 0.3, 0.3), Vector3(0, FLOOR2 - 0.25, FACADE_Z + 0.1), trim, false)
	Build.box(geo, Vector3(20.8, 0.35, 0.5), Vector3(0, 8.6, FACADE_Z + 0.1), trim, false)
	for x in [-10.0, 10.0]:
		Build.box(geo, Vector3(0.45, 8.6, 0.45), Vector3(x, 4.3, FACADE_Z + 0.05), trim, false)
	# Telhado de duas águas (cumeeira ao longo de X).
	var roof := Build.mat("roof", Color(0.6, 0.62, 0.72), 1.5)
	var ang := rad_to_deg(atan2(4.6, 5.6))
	var front := Build.box(geo, Vector3(21.4, 0.3, 7.5), Vector3(0, 10.9, FACADE_Z - 2.3), roof, false)
	front.rotation_degrees.x = ang
	var back := Build.box(geo, Vector3(21.4, 0.3, 7.5), Vector3(0, 10.9, FACADE_Z - 7.7), roof, false)
	back.rotation_degrees.x = -ang
	# Oitões laterais (triângulos aproximados por faixas).
	for side in [-10.0, 10.0]:
		for i in 5:
			var w := 10.8 * (1.0 - i / 5.0)
			Build.box(geo, Vector3(0.4, 0.92, w), Vector3(side, 8.6 + i * 0.92 + 0.46, FACADE_Z - 5.0), wall, false)
	# Mansarda com a janela redonda do sótão (acesa, fraca).
	var dz := FACADE_Z - 0.4  # face da mansarda
	Build.box(geo, Vector3(3.2, 2.6, 2.4), Vector3(0, 10.3, dz - 1.2), wall, false)
	var dormer_l := Build.box(geo, Vector3(2.2, 0.22, 2.8), Vector3(-0.85, 12.0, dz - 1.2), roof, false)
	dormer_l.rotation_degrees.z = 36
	var dormer_r := Build.box(geo, Vector3(2.2, 0.22, 2.8), Vector3(0.85, 12.0, dz - 1.2), roof, false)
	dormer_r.rotation_degrees.z = -36
	var round_win := Build.cylinder(geo, 0.55, 0.1, Vector3(0, 10.45, dz + 0.03), Build.color_mat(Color("c9a45e"), 0.9), false, 16)
	round_win.rotation_degrees.x = 90
	var ring := Build.cylinder(geo, 0.66, 0.08, Vector3(0, 10.45, dz + 0.01), trim, false, 16)
	ring.rotation_degrees.x = 90
	Build.omni(geo, Vector3(0, 10.45, dz + 0.9), Color("ffb56a"), 0.8, 4.0, false, true)
	# Chaminé.
	Build.box(geo, Vector3(1.1, 3.6, 1.1), Vector3(6.2, 12.0, FACADE_Z - 6.5), Build.mat("brick", Color(0.6, 0.6, 0.7)), false)

	# Janelas (vidro frio emissivo, fraco).
	for p in [Vector2(-8.3, 1.2), Vector2(-3.6, 1.2), Vector2(3.6, 1.2), Vector2(8.3, 1.2),
			Vector2(-3.3, 5.0), Vector2(3.3, 5.0), Vector2(-8.9, 5.0), Vector2(8.9, 5.0)]:
		_window(Vector3(p.x, p.y, FACADE_Z), 0.3 + rng.randf() * 0.35)

	# Porta da frente, pregada por dentro, com alpendre.
	var door_mat := Build.mat("planks_dark", Color(0.8, 0.75, 0.75), 1.0)
	var front_door := Build.door(geo, Vector3(0, 0.0, FACADE_Z - 0.2), 0.0, door_mat, 1.6, 2.6)
	for i in 2:
		var board := Build.box(geo, Vector3(1.9, 0.18, 0.06), Vector3(0, 0.9 + i * 0.9, FACADE_Z - 0.06), trim, false)
		board.rotation_degrees.z = 12 if i == 0 else -9
	Build.box(geo, Vector3(3.6, 0.2, 1.6), Vector3(0, 0.1, FACADE_Z + 0.8), Build.mat("stone_wall"), true)
	Build.box(geo, Vector3(3.2, 0.2, 0.8), Vector3(0, 0.3, FACADE_Z + 0.4), Build.mat("stone_wall"), true)
	for x in [-1.6, 1.6]:
		Build.cylinder(geo, 0.12, 3.2, Vector3(x, 1.6, FACADE_Z + 1.4), trim, true, 8)
	var porch_roof := Build.box(geo, Vector3(4.0, 0.2, 1.9), Vector3(0, 3.3, FACADE_Z + 0.8), Build.mat("roof", Color(0.6, 0.62, 0.72), 1.5), false)
	porch_roof.rotation_degrees.x = 12
	Build.omni(geo, Vector3(0, 2.4, FACADE_Z + 1.4), Color("7e9bd8"), 0.9, 5.0, false, true)
	interact(Vector3(0, 0, FACADE_Z + 1.6), "Tentar a porta da frente", func(ch: Character):
		front_door.rattle()
		await say([ch.who + ": Pregada por dentro. Não vou conseguir entrar por aqui."])
		, "any", 1.2, true, 2.0)


func _build_balcony_a() -> void:
	var wood := Build.mat("planks_dark", Color(0.85, 0.82, 0.8), 1.0)
	var x0 := -9.6
	var x1 := -3.6
	var zf := -3.4  # borda da frente
	_balcony(x0, x1, zf, wood, [])
	# Porta de A.
	_door_a = Build.door(geo, Vector3(DOOR_A_X, FLOOR2, FACADE_Z - 0.2), 0.0, Build.mat("planks_dark", Color(0.75, 0.7, 0.8), 1.0), 1.2, 2.4)
	_vestibule(DOOR_A_X)
	_swatch_plate(Vector3(DOOR_A_X + 0.95, FLOOR2 + 1.35, FACADE_Z + 0.02), LILAC)
	_door_a_it = interact(Vector3(DOOR_A_X, FLOOR2, FACADE_Z + 0.8), "Examinar a porta", _try_door.bind("a"), "a", 1.0, true, 2.4)
	# Bilhete de A: as coordenadas do CIANO (a cor da porta de B).
	Build.box(geo, Vector3(0.7, 0.5, 0.5), Vector3(x0 + 0.8, FLOOR2 + 0.25, FACADE_Z + 0.6), Build.mat("wood_wall"), true)
	Build.flat_sprite(geo, "icon_note", Vector3(x0 + 0.8, FLOOR2 + 0.52, FACADE_Z + 0.6), Vector3(-90, 15, 0), 0.025)
	doc(Vector3(x0 + 0.8, FLOOR2, FACADE_Z + 1.3), {
		"id": "ch5_ciano",
		"title": "Bilhete azul, preso no caixote",
		"body": "[center]Coordenadas para o CIANO:\n\n0 para o vermelho\n255 para o verde\n255 para o azul[/center]",
		"style": "blue",
	}, "Ler bilhete", "a", 1.0)
	Build.candle(geo, Vector3(x0 + 0.55, FLOOR2 + 0.5, FACADE_Z + 0.45), 0.8, 4.0)

	# Trepadeira pendurada na frente da varanda.
	var vx := DOOR_A_X + 1.4
	for i in 3:
		Build.flat_sprite(geo, "vines", Vector3(vx - 0.5 + i * 0.5, 1.9 + (i % 2) * 0.3, zf + 0.12), Vector3(0, 0, 0), 0.062, Color(0.8, 0.95, 0.85))
	Build.flat_sprite(geo, "vines", Vector3(vx, 5.1, zf + 0.1), Vector3(0, 0, 180), 0.03, Color(0.8, 0.95, 0.85))
	_vines_it = interact(Vector3(vx, 0, zf + 0.75), "Subir pela trepadeira", _climb_vines, "a", 1.0, true, 2.2)
	_vines_it.deny_text = "Essa trepadeira não aguenta o meu peso. Vou pela escada."


func _build_balcony_b() -> void:
	var wood := Build.mat("planks_dark", Color(0.85, 0.82, 0.8), 1.0)
	var x0 := 3.6
	var x1 := STAIR_X + 0.7
	var zf := -3.4
	_balcony(x0, x1, zf, wood, [Vector2(STAIR_X - 0.7, STAIR_X + 0.7)])
	# Escada de pedra do lado direito, subindo para o norte.
	var stone := Build.mat("stone_wall", Color(0.8, 0.82, 0.88), 1.2)
	Build.stairs(geo, Vector3(STAIR_X, 0, 2.4), Vector3(STAIR_X, FLOOR2, zf), 1.4, 12, stone)
	Build.blocker(geo, Vector3(0.3, 7, 6.2), Vector3(STAIR_X - 0.85, 3.5, (2.4 + zf) / 2.0))
	Build.blocker(geo, Vector3(0.3, 7, 6.2), Vector3(STAIR_X + 0.85, 3.5, (2.4 + zf) / 2.0))
	# Mureta externa (visual).
	var steps := 12
	for i in steps:
		var z := 2.4 + (zf - 2.4) * (i + 0.5) / steps
		var y := FLOOR2 * (i + 1) / steps
		Build.box(geo, Vector3(0.22, 0.5, (2.4 - zf) / steps + 0.02), Vector3(STAIR_X + 0.8, y + 0.25, z), stone, false)
	Build.torch(geo, Vector3(STAIR_X + 0.85, 1.4, 2.5), 1.3, 6.0)
	# Só B usa a escada.
	var shut := Build.blocker(geo, Vector3(1.6, 3, 0.3), Vector3(STAIR_X, 1.5, 2.75))
	shut.collision_layer = LAYER_ONLY_A
	zone(Vector3(STAIR_X, 1, 3.3), Vector3(1.8, 2, 0.9), func(ch: Character):
		if ch.who == "a" and ch.active:
			Ui.toast("%s: A escada é o caminho de %s. Eu vou pela trepadeira." % [Game.name_a, Game.name_b])
		, false)
	# Porta de B.
	_door_b = Build.door(geo, Vector3(DOOR_B_X, FLOOR2, FACADE_Z - 0.2), 0.0, Build.mat("planks_dark", Color(0.7, 0.78, 0.8), 1.0), 1.2, 2.4)
	_vestibule(DOOR_B_X)
	_swatch_plate(Vector3(DOOR_B_X - 0.95, FLOOR2 + 1.35, FACADE_Z + 0.02), CYAN)
	_door_b_it = interact(Vector3(DOOR_B_X, FLOOR2, FACADE_Z + 0.8), "Examinar a porta", _try_door.bind("b"), "b", 1.0, true, 2.4)
	# Bilhete de B: as coordenadas do LILÁS (a cor da porta de A).
	Build.box(geo, Vector3(0.7, 0.5, 0.5), Vector3(9.0, FLOOR2 + 0.25, FACADE_Z + 0.6), Build.mat("wood_wall"), true)
	Build.flat_sprite(geo, "icon_note", Vector3(9.0, FLOOR2 + 0.52, FACADE_Z + 0.6), Vector3(-90, -10, 0), 0.025)
	doc(Vector3(9.0, FLOOR2, FACADE_Z + 1.3), {
		"id": "ch5_lilas",
		"title": "Bilhete azul, preso no caixote",
		"body": "[center]Coordenadas para o LILÁS:\n\n177 / 156 / 217[/center]",
		"style": "blue",
	}, "Ler bilhete", "b", 1.0)
	Build.candle(geo, Vector3(9.25, FLOOR2 + 0.5, FACADE_Z + 0.45), 0.8, 4.0)


## Varanda do 2º andar: piso, guarda-corpo, pilares e bloqueios. `gaps` = trechos
## da borda da frente sem guarda-corpo (Vector2(x_ini, x_fim)).
func _balcony(x0: float, x1: float, zf: float, wood: Material, gaps: Array) -> void:
	var depth := zf - FACADE_Z
	var cx := (x0 + x1) / 2.0
	var cz := (FACADE_Z + zf) / 2.0
	Build.box(geo, Vector3(x1 - x0, 0.25, depth), Vector3(cx, FLOOR2 - 0.125, cz), wood, true, 0.0, "wood")
	var post_mat := Build.mat("planks_dark", Color(0.6, 0.6, 0.66), 1.0)
	# Pilares até o chão.
	for x in [x0 + 0.2, x1 - 0.2]:
		Build.box(geo, Vector3(0.22, FLOOR2, 0.22), Vector3(x, FLOOR2 / 2.0, zf - 0.15), post_mat, true)
	# Guarda-corpo: montantes e corrimão (com vãos).
	var segs := [[x0, x1]]
	for g in gaps:
		var out := []
		for s in segs:
			if g.x > s[0] and g.x < s[1]:
				out.append([s[0], g.x])
			if g.y > s[0] and g.y < s[1]:
				out.append([g.y, s[1]])
			if g.x >= s[1] or g.y <= s[0]:
				out.append(s)
		segs = out
	for s in segs:
		var a: float = s[0]
		var b: float = s[1]
		Build.box(geo, Vector3(b - a, 0.08, 0.1), Vector3((a + b) / 2.0, FLOOR2 + 1.0, zf - 0.08), post_mat, false)
		Build.box(geo, Vector3(b - a, 0.06, 0.08), Vector3((a + b) / 2.0, FLOOR2 + 0.15, zf - 0.08), post_mat, false)
		var n := int((b - a) / 0.35)
		for i in n + 1:
			Build.box(geo, Vector3(0.05, 0.9, 0.05), Vector3(a + (b - a) * i / max(n, 1), FLOOR2 + 0.55, zf - 0.08), post_mat, false)
		Build.blocker(geo, Vector3(b - a, 3.0, 0.3), Vector3((a + b) / 2.0, FLOOR2 + 1.5, zf - 0.05))
	# Laterais.
	for x in [x0, x1]:
		Build.box(geo, Vector3(0.08, 0.08, depth), Vector3(x, FLOOR2 + 1.0, cz), post_mat, false)
		for i in 7:
			Build.box(geo, Vector3(0.05, 0.9, 0.05), Vector3(x, FLOOR2 + 0.55, FACADE_Z + depth * (i + 0.5) / 7.0), post_mat, false)
		Build.blocker(geo, Vector3(0.3, 3.0, depth + 0.2), Vector3(x, FLOOR2 + 1.5, cz))
	# Embaixo da varanda: ninguém passa (e não alcança as portas de baixo).
	Build.blocker(geo, Vector3(x1 - x0, FLOOR2 - 0.4, depth - 0.3), Vector3(cx, (FLOOR2 - 0.4) / 2.0, FACADE_Z + (depth - 0.3) / 2.0))
	for i in 5:
		var bx := x0 + 0.5 + (x1 - x0 - 1.0) * rng.randf()
		Build.billboard(geo, ["bush", "fern", "bush"][i % 3], Vector3(bx, 0, zf - 0.4), 0.05, 1, 0, Color(0.75, 0.85, 0.9))
	Build.box(geo, Vector3(0.9, 0.8, 0.8), Vector3(x0 + 1.4, 0.4, zf - 1.0), Build.mat("wood_wall", Color(0.7, 0.7, 0.75)), false, 10.0)
	Build.omni(geo, Vector3(cx, FLOOR2 + 2.2, zf + 0.6), Color("7e9bd8"), 0.8, 6.0)


## Vão escuro atrás da porta do 2º andar (piso para entrar e a escada estreita).
func _vestibule(x: float) -> void:
	var dark := Build.color_mat(Color("07080c"))
	var z := FACADE_Z - 0.4
	Build.box(geo, Vector3(1.6, 0.2, 2.2), Vector3(x, FLOOR2 - 0.1, z - 1.1), Build.mat("planks_dark", Color(0.4, 0.4, 0.45)), true, 0.0, "wood")
	Build.box(geo, Vector3(1.6, 3.0, 0.1), Vector3(x, FLOOR2 + 1.5, z - 2.2), dark, true)
	Build.box(geo, Vector3(0.1, 3.0, 2.2), Vector3(x - 0.8, FLOOR2 + 1.5, z - 1.1), dark, true)
	Build.box(geo, Vector3(0.1, 3.0, 2.2), Vector3(x + 0.8, FLOOR2 + 1.5, z - 1.1), dark, true)
	for i in 4:
		Build.box(geo, Vector3(1.2, 0.18, 0.35), Vector3(x, FLOOR2 + 0.09 + i * 0.3, z - 1.2 - i * 0.3), Build.mat("planks_dark", Color(0.35, 0.33, 0.35)), false)
	Build.omni(geo, Vector3(x, FLOOR2 + 2.4, z - 1.6), Color("b07a4a"), 0.25, 2.5, false, true)


func _swatch_plate(pos: Vector3, c: Color) -> void:
	Build.box(geo, Vector3(0.46, 0.46, 0.05), pos, Build.color_mat(Color("22262c"), 0.0, 0.4), false)
	Build.box(geo, Vector3(0.34, 0.34, 0.04), pos + Vector3(0, 0, 0.02), Build.color_mat(c, 0.55), false)
	# Teclado abaixo da amostra.
	Build.box(geo, Vector3(0.3, 0.36, 0.05), pos + Vector3(0, -0.5, 0), Build.color_mat(Color("2c3036"), 0.0, 0.35), false)
	for r in 4:
		for k in 4:
			Build.box(geo, Vector3(0.05, 0.05, 0.03), pos + Vector3(-0.09 + k * 0.06, -0.37 - r * 0.08, 0.03), Build.color_mat(Color("9aa4b0"), 0.1), false)


func _window(pos: Vector3, glow: float) -> void:
	var frame := Build.mat("planks_dark", Color(0.6, 0.6, 0.66), 1.0)
	var w := 1.2
	var h := 1.6
	var c := pos + Vector3(0, h / 2.0, 0.06)
	Build.box(geo, Vector3(w, h, 0.05), c, Build.color_mat(Color("4f74b0"), glow), false)
	Build.box(geo, Vector3(w + 0.2, 0.12, 0.14), c + Vector3(0, h / 2.0 + 0.06, 0.02), frame, false)
	Build.box(geo, Vector3(w + 0.3, 0.12, 0.25), c + Vector3(0, -h / 2.0 - 0.06, 0.06), frame, false)
	Build.box(geo, Vector3(0.1, h, 0.1), c + Vector3(-w / 2.0, 0, 0.03), frame, false)
	Build.box(geo, Vector3(0.1, h, 0.1), c + Vector3(w / 2.0, 0, 0.03), frame, false)
	Build.box(geo, Vector3(0.06, h, 0.06), c + Vector3(0, 0, 0.04), frame, false)
	Build.box(geo, Vector3(w, 0.06, 0.06), c + Vector3(0, 0.1, 0.04), frame, false)
	Build.omni(geo, c + Vector3(0, 0, 0.8), Color("5f86c9"), glow * 0.9, 3.0)


## Parede no plano XY (em z fixo) de x0..x1 e y0..y1, com vãos (Rect2 em x/y).
func _wall_with_holes(z: float, x0: float, x1: float, y0: float, y1: float, thick: float, m: Material, holes: Array) -> void:
	var xs := [x0, x1]
	for h in holes:
		xs.append((h as Rect2).position.x)
		xs.append((h as Rect2).end.x)
	xs.sort()
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		if xb - xa < 0.01:
			continue
		var cuts := []
		for h in holes:
			var r := h as Rect2
			if r.position.x <= xa + 0.001 and r.end.x >= xb - 0.001:
				cuts.append([r.position.y, r.end.y])
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var cur := y0
		for c in cuts:
			if c[0] > cur + 0.01:
				Build.box(geo, Vector3(xb - xa, c[0] - cur, thick), Vector3((xa + xb) / 2.0, (cur + c[0]) / 2.0, z), m, true)
			cur = max(cur, c[1])
		if y1 > cur + 0.01:
			Build.box(geo, Vector3(xb - xa, y1 - cur, thick), Vector3((xa + xb) / 2.0, (cur + y1) / 2.0, z), m, true)


func _build_saia() -> void:
	# "SAIA" escrito em volta da porta da frente: some e aparece.
	var spots := [
		[Vector3(0, 3.0, FACADE_Z + 0.3), 150, Color("f2f2f2")],
		[Vector3(-1.7, 2.3, FACADE_Z + 0.3), 70, Color("e8e8e8")],
		[Vector3(1.8, 2.6, FACADE_Z + 0.3), 80, Color("c21e1e")],
		[Vector3(-2.2, 1.2, FACADE_Z + 0.3), 56, Color("c21e1e")],
		[Vector3(2.4, 1.0, FACADE_Z + 0.3), 64, Color("f2f2f2")],
		[Vector3(-0.9, 0.55, FACADE_Z + 1.9), 60, Color("f2f2f2")],
		[Vector3(1.0, 0.45, FACADE_Z + 2.1), 48, Color("c21e1e")],
		[Vector3(-3.6, 3.2, FACADE_Z + 0.3), 44, Color("f2f2f2")],
		[Vector3(3.6, 3.4, FACADE_Z + 0.3), 44, Color("c21e1e")],
	]
	for s in spots:
		var text := "SAIA!" if s[1] >= 150 else "SAIA"
		var l := Build.text3d(geo, text, s[0], 0.0, s[1], s[2], UiTheme.FONT_UI, 0.008)
		l.shaded = false
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.6)
		l.visible = false
		_saia_labels.append(l)


func _build_nature() -> void:
	# Árvores só nas laterais e ao fundo, para não tapar a fachada.
	for side in [-1.0, 1.0]:
		for i in 7:
			var p := Vector3(side * rng.randf_range(11.8, 15.5), 0, rng.randf_range(-16, 8))
			Build.tree(geo, ["tree_pine", "tree_dead", "tree_oak"][rng.randi_range(0, 2)], p, rng.randf_range(0.9, 1.5), false)
	for i in 12:
		Build.tree(geo, ["tree_pine", "tree_dead"][i % 2], Vector3(-15 + i * 2.7 + rng.randf_range(-0.5, 0.5), 0, -18 + rng.randf_range(-1, 1)), rng.randf_range(1.3, 1.8), false)
	# Arbustos colados na fachada e mato no quintal.
	for i in 12:
		var x := rng.randf_range(-9.5, 9.5)
		if abs(x) < 2.2 or (x < -3.4 and x > -9.8) or (x > 3.4):
			continue
		Build.billboard(geo, "bush", Vector3(x, 0, FACADE_Z + 0.5), 0.05, 1, 0, Color(0.75, 0.85, 0.9))
	Build.scatter(geo, ["grass", "grass", "fern", "flower_white", "bush"], Rect2(-12.5, -5.5, 25, 14.5), 120, 0.0, rng,
		[Rect2(-1.4, -6, 2.8, 16), Rect2(-10, -6, 20, 2.8), Rect2(STAIR_X - 1.2, -4, 2.4, 7.5)])
	# Cerca de ferro ao sul (com o portão aberto no caminho).
	var iron := Build.color_mat(Color("24272c"), 0.0, 0.45)
	for side in [-1.0, 1.0]:
		Build.box(geo, Vector3(10.5, 0.06, 0.06), Vector3(side * 6.9, 1.1, 9.0), iron, false)
		Build.box(geo, Vector3(10.5, 0.06, 0.06), Vector3(side * 6.9, 0.3, 9.0), iron, false)
		for i in 26:
			Build.box(geo, Vector3(0.05, 1.3, 0.05), Vector3(side * (1.7 + i * 0.4), 0.65, 9.0), iron, false)
	var crow := Build.billboard(geo, "crow", Vector3(-10.0, 8.8, FACADE_Z + 0.1), 0.04, 2)
	var ca := SpriteAnim.new()
	ca.frames = 2
	ca.fps = 1.2
	crow.add_child(ca)
	Build.billboard(geo, "cobweb", Vector3(-9.4, FLOOR2 + 1.6, FACADE_Z + 0.2), 0.03)
	Build.billboard(geo, "cobweb", Vector3(9.4, FLOOR2 + 1.8, FACADE_Z + 0.2), 0.03)
	Build.motes(geo, Vector3(0, 1.5, 1), Vector3(11, 1.5, 6), 60, Color(0.7, 1.0, 0.8, 0.8), "firefly", 0.05)
	Build.motes(geo, Vector3(0, 3.0, -4), Vector3(10, 3.0, 2), 50, Color(0.8, 0.9, 1.0, 0.45), "dust", 0.05)
	# Luar e luz fria no quintal.
	Build.omni(geo, Vector3(-5, 3.0, 3.5), Color("6f8cc9"), 0.9, 8.0)
	Build.omni(geo, Vector3(5, 3.0, 3.5), Color("6f8cc9"), 0.9, 8.0)
	Build.spot(geo, Vector3(0, 12, 6), Vector3(0, 4, FACADE_Z), Color("8aa6de"), 1.6, 22.0, 32.0, true)


# --- Roteiro ------------------------------------------------------------------------

func doc(pos: Vector3, data: Dictionary, prompt := "Ler", who := "any", radius := 1.4) -> Interactable:
	_docs[data["id"]] = data
	return super(pos, data, prompt, who, radius)


func _begin() -> void:
	party.a.collision_mask = 1 | LAYER_ONLY_A
	objective("Aproximem-se da casa.")
	# Mostra a fachada inteira antes de devolver o controle.
	Game.lock_input()
	cam.set_view(Vector3(0, 7.5, 17.0), 40.0, 1.6)
	await cam.look_at_point(Vector3(0, 3.5, -2.0), 1.6)
	await say([
		"b: Uma casa. No meio do nada.",
		"a: Tem luz nas janelas... mas não tem ninguém lá dentro. Eu sinto.",
	])
	cam.set_view(Vector3(0, 7.2, 8.6), 34.0, 1.4)
	cam.target = party.active
	Game.unlock_input()
	zone(Vector3(0, 1, 1.5), Vector3(24, 2, 3.0), func(_ch): _saia(), true)


func _saia() -> void:
	Game.lock_input()
	Audio.sfx("whisper_saia", 0.0)
	Audio.sfx("heartbeat", -6.0)
	await get_tree().create_timer(0.5).timeout
	# As palavras piscam na fachada.
	for i in 7:
		for l in _saia_labels:
			l.visible = rng.randf() < 0.75
		await get_tree().create_timer(0.12 + rng.randf() * 0.12).timeout
	for l in _saia_labels:
		l.visible = true
	cam.shake(0.5)
	if not Game.get_flag("ch5_jumpscare"):
		Game.set_flag("ch5_jumpscare")
		await Ui.jumpscare("res://assets/legacy/face_hand.png", 0.6)
	await get_tree().create_timer(0.4).timeout
	# Depois do susto, continuam piscando fraco.
	for l in _saia_labels:
		_blink_forever(l)
	Game.unlock_input()
	await say([
		"?: Saia...",
		"b: Você ouviu isso?",
		"a: Veio de dentro. \"Saia\"...",
		"b: A porta da frente está pregada. Mas lá em cima tem duas portas, uma em cada varanda.",
		"a: Do meu lado tem uma trepadeira. Eu subo por ela.",
		"b: Do meu, uma escada de pedra. Nos vemos lá dentro.",
	])
	objective("%s sobe pela trepadeira, %s pela escada. Abram as portas do andar de cima." % [Game.name_a, Game.name_b])
	hints([
		"Cada porta mostra uma cor e pede um código hexadecimal. As coordenadas da cor da porta de %s estão com %s, e vice-versa." % [Game.name_a, Game.name_b],
		"Cada número de 0 a 255 vira dois dígitos hexadecimais: divida por 16 (o resultado é o 1º dígito, o resto é o 2º). 255 = FF, 177 = B1.",
		"Porta de %s (lilás): B19CD9. Porta de %s (ciano): 00FFFF." % [Game.name_a, Game.name_b],
	])


func _blink_forever(l: Label3D) -> void:
	var base := l.modulate
	var t := create_tween().set_loops()
	t.tween_interval(rng.randf_range(0.8, 3.5))
	t.tween_property(l, "modulate:a", 0.0, 0.08)
	t.tween_interval(rng.randf_range(0.05, 0.4))
	t.tween_property(l, "modulate:a", base.a * rng.randf_range(0.35, 0.8), 0.08)


func _climb_vines(ch: Character) -> void:
	_vines_it.disable()
	var x := ch.global_position.x
	Audio.sfx("breath", -8.0)
	await ch.climb([
		Vector3(x, 0.4, -3.05),
		Vector3(x, 2.0, -3.1),
		Vector3(x, FLOOR2 + 0.3, -3.15),
		Vector3(x, FLOOR2 + 0.05, -4.0),
	], 3.4)
	await say(["a: Consegui. Tem uma porta aqui em cima... e um bilhete."])


func _try_door(ch: Character, side: String) -> void:
	if (side == "a" and _open_a) or (side == "b" and _open_b):
		return
	var lock: CodeLock
	if side == "a":
		lock = CodeLock.new("Porta de %s" % Game.name_a, ["B19CD9", "#B19CD9"],
			"Uma placa de vidro [color=#b19cd9]lilás[/color] sobre um teclado de dezesseis teclas.",
			["A cor é lilás. Quem encontrou as coordenadas do lilás?", "Converta cada número para hexadecimal: 177 = B1, 156 = 9C, 217 = D9.", "B19CD9"])
		lock.swatch = LILAC
	else:
		lock = CodeLock.new("Porta de %s" % Game.name_b, ["00FFFF", "#00FFFF"],
			"Uma placa de vidro [color=#00ffff]ciano[/color] sobre um teclado de dezesseis teclas.",
			["A cor é ciano. Quem encontrou as coordenadas do ciano?", "Converta cada número para hexadecimal: 0 = 00, 255 = FF.", "00FFFF"])
		lock.swatch = CYAN
	lock.keypad = "0123456789ABCDEF"
	lock.prefix = "#"
	lock.max_len = 7
	lock.placeholder = "RRGGBB"
	var ok := await puzzle(lock)
	if not ok:
		return
	Audio.sfx("lock_open", 0.0)
	if side == "a":
		_open_a = true
		_door_a_it.disable()
		_door_a.open()
	else:
		_open_b = true
		_door_b_it.disable()
		_door_b.open()
	await get_tree().create_timer(1.0).timeout
	if _open_a and _open_b:
		await _ending()
	else:
		var other := Game.char_name("b" if side == "a" else "a")
		await say([
			ch.who + ": Abriu. Tem uma escada estreita subindo no escuro.",
			ch.who + ": Não vou subir sem %s." % other,
		])


func _ending() -> void:
	Game.lock_input()
	Audio.sfx("success", -4.0)
	await say([
		"a: A minha porta abriu. Tem uma escada subindo.",
		"b: A minha também. As duas vão para o mesmo lugar... para cima.",
		"a: O sótão.",
		"?: ...não deviam ter entrado.",
	])
	party.a.walk_to(Vector3(DOOR_A_X, FLOOR2, FACADE_Z - 1.0), 2.0)
	party.b.walk_to(Vector3(DOOR_B_X, FLOOR2, FACADE_Z - 1.0), 2.0)
	await get_tree().create_timer(1.2).timeout
	Game.unlock_input()
	finish()


## Depuração (tools/shot.sh --call=...).
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


func _debug_b_stairs() -> void:
	_debug_hold("b", Vector3(STAIR_X, 0, 3.4), "move_up", 4.0)


func _debug_a_stairs() -> void:
	_debug_hold("a", Vector3(STAIR_X, 0, 4.4), "move_up", 3.0)


func _debug_climb() -> void:
	await get_tree().create_timer(2.5).timeout
	Game.reset_input_lock()
	party.a.teleport(Vector3(DOOR_A_X + 1.4, 0, -2.8))
	_climb_vines(party.a)


func _debug_wide() -> void:
	cam.set_view(Vector3(0, 7.5, 17.0), 40.0, 0.01)
	cam.look_at_point(Vector3(0, 3.5, -2.0), 0.01)


func _debug_saia() -> void:
	for l in _saia_labels:
		l.visible = true


func _debug_up() -> void:
	party.a.teleport(Vector3(DOOR_A_X, FLOOR2 + 0.05, -4.6))
	party.b.teleport(Vector3(DOOR_B_X, FLOOR2 + 0.05, -4.6))
	cam.snap()


func _debug_doc_ciano() -> void:
	Ui.read_doc("a", _docs["ch5_ciano"])


func _debug_lock_a() -> void:
	_try_door(party.a, "a")
