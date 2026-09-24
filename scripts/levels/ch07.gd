extends LevelBase
## Capítulo 7 — O Saguão (a casa da família de B; enigma 7 original).
## A e B descem do sótão ao saguão da casa onde B cresceu. A porta do subterrâneo tem
## quatro cadeados (I–IV), um por cômodo, e duas rodas que só giram juntas.
##   Quarto (I):     o quarto de infância de B (foto de A e B crianças). VLOHQFLR na
##                   parede + "CÉSAR DISSE: +3" (cozinha) → armário SILENCIO.
##   Cozinha (II):   a cozinha da mãe de B. Dardos no vermelho 17 + 6 + 19 → despensa 42.
##   Escritório (III): o piano do pai de B. Bilhete do travesseiro + carta → piano C G A F.
##   Banheiro (IV):  o espelho repete ACORDE → armário ACORDE. Do espelho sai a voz falsa
##                   de B pedindo para A não acordar; depois, B de verdade nega.
## Cada chave fica com quem a pegou; cada cadeado só abre com a sua chave.
## Terror: com a primeira chave, todas as portas se abrem e o Esquecido passa a patrulhar
## o saguão e os quatro cômodos (um esconderijo em cada cômodo e um no saguão). Cada
## cadeado aberto muda o ponto seguro. Com os quatro, a patrulha some e quem segura uma
## roda sozinho é caçado. Voz do hospital no primeiro cadeado. Lembrança m7 na banheira.
## Depois, um segura uma roda e o outro gira a outra.

const ROMAN := ["", "I", "II", "III", "IV"]
const ROOMS := ["", "Quarto", "Cozinha", "Escritório", "Banheiro"]
const GATE_Z := -12.0
const LOCK_X := [0.0, -0.96, -0.32, 0.32, 0.96]
const LOCK_Y := 1.3
const WHEEL_X := 2.5
const WHEEL_STAND_Z := -11.2
const DARTS := [20, 17, 6, 3, 19]
const PIANO_SEQ := ["C", "G", "A", "F"]
## ACORDE 7×, SONO 6×, FUJA 5×, NOITE 5×, MEDO 4×.
const MIRROR_WORDS := [
	"SONO", "ACORDE", "FUJA", "NOITE", "MEDO",
	"ACORDE", "SONO", "NOITE", "ACORDE", "FUJA",
	"MEDO", "SONO", "ACORDE", "NOITE", "FUJA",
	"SONO", "MEDO", "ACORDE", "FUJA", "NOITE",
	"SONO", "ACORDE", "MEDO", "NOITE", "FUJA",
	"SONO", "ACORDE",
]

const DOC_PAI := {
	"id": "ch7_carta_pai",
	"title": "Carta sobre a mesa",
	"style": "paper",
	"body": "[font_size=30]Meu pai me forçou a estudar de novo. Ele insiste que eu toque tão bem quanto ele. Mas eu não quero isso, não quero ser como ele. Todas as noites ele me força. Eu já decorei. Sonho com isso todas as noites.[/font_size]\n\n[center][font_size=34]C    D    E    F    G    A    B\nDÓ   RÉ   MI   FÁ   SOL  LÁ   SI[/font_size]\n\n[font_size=30]UT queant laxis\nREsonare fibris\nMIra gestorum\nFAmuli tuorum\nSOLve polluti\nLAbii reatum\nSancte Iohannes[/font_size][/center]",
}

var _room_doors := {}
var _room_its := {}
var _locks := {}
var _lock_its := {}
var _lock_open := {1: false, 2: false, 3: false, 4: false}
var _locks_open := 0
var _chains: Node3D
var _wheels := {}
var _gate_l: Door
var _gate_r: Door
var _gate_open := false
var _busy_scene := false
var _pit_light: OmniLight3D
var _bath_light: OmniLight3D
var _wardrobe_door: Node3D
var _wardrobe_it: Interactable
var _pantry_door: Node3D
var _pantry_it: Interactable
var _piano_it: Interactable
var _cabinet_door: Node3D
var _cabinet_it: Interactable
var _anchors := {}
var _amb_t := 7.0
var _tick_t := 0.0
var _skip_intro := false
var _lustre_light: OmniLight3D
## Luzes de cada cômodo (e do saguão, índice 0) que apagam quando alguém erra ali.
var _room_lights := {0: [], 1: [], 2: [], 3: [], 4: []}
var _patrol_started := false
var _patrol_on := false
var _chase_warned := false
var _fake_pending := false

## Rota do Esquecido: saguão → quarto → cozinha → pé da escada → banheiro → escritório.
const PATROL := [
	Vector3(0, 0, -7.8),
	Vector3(-5.6, 0, -8.25), Vector3(-10.0, 0, -8.25), Vector3(-12.8, 0, -7.0),
	Vector3(-10.0, 0, -8.25), Vector3(-5.6, 0, -8.25),
	Vector3(-5.2, 0, -2.6),
	Vector3(-5.6, 0, -0.75), Vector3(-9.0, 0, -0.75), Vector3(-13.4, 0, 1.0),
	Vector3(-9.0, 0, -0.75), Vector3(-5.6, 0, -0.75),
	Vector3(-3.0, 0, -5.5), Vector3(3.0, 0, -5.5),
	Vector3(5.6, 0, -0.75), Vector3(10.2, 0, -0.75), Vector3(12.8, 0, 1.3),
	Vector3(10.2, 0, -0.75), Vector3(5.6, 0, -0.75),
	Vector3(5.2, 0, -5.4),
	Vector3(5.6, 0, -8.25), Vector3(10.0, 0, -8.25), Vector3(12.0, 0, -9.6),
	Vector3(10.0, 0, -8.25), Vector3(5.6, 0, -8.25),
]
const LANDING_A := Vector3(-0.8, 3.2, 1.7)
const LANDING_B := Vector3(0.8, 3.2, 1.7)
const TUB_MEMORY := Vector3(15.9, 0.0, -1.75)


func _init() -> void:
	chapter_index = 6
	preset = "house"
	ambience = "amb_house"
	spawn_a = Vector3(-0.8, 3.2, 1.7)
	spawn_b = Vector3(0.8, 3.2, 1.7)
	cam_bounds = Rect2(-12, -11.5, 24, 14.5)


# --- Montagem ----------------------------------------------------------------------

func _build() -> void:
	_build_shell()
	_build_hall()
	_build_stairs()
	_build_gate()
	_build_room_doors()
	_build_bedroom()
	_build_kitchen()
	_build_office()
	_build_bathroom()
	_build_pit()
	_build_hiding()
	_build_dread()
	memory(TUB_MEMORY, "m7", "Saia",
		"\"SAIA!\"\n\n%s me empurrou pela janela quebrada. Eu subi. Eu respirei.\n\nOlhei para baixo. Os faróis ainda estavam acesos lá no fundo.\n\n%s não subiu." % [Game.name_b, Game.name_b])


## Parede reta com vãos. `gaps` = [[posição ao longo, largura, altura do vão], ...].
func _wall_gaps(a: Vector3, b: Vector3, h: float, m: Material, gaps: Array = [], t := 0.3) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var cuts := gaps.duplicate()
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var cur := 0.0
	for g in cuts:
		var g0: float = float(g[0]) - float(g[1]) / 2.0
		var g1: float = float(g[0]) + float(g[1]) / 2.0
		var gh: float = float(g[2]) if g.size() > 2 else 2.5
		if g0 > cur + 0.01:
			Build.wall(geo, a + dir * cur, a + dir * g0, h, t, m)
		if h > gh + 0.05:
			var la := a + dir * g0
			var lb := a + dir * g1
			la.y += gh
			lb.y += gh
			Build.wall(geo, la, lb, h - gh, t, m, false)
		cur = g1
	if cur < length - 0.01:
		Build.wall(geo, a + dir * cur, b, h, t, m)


func _build_shell() -> void:
	var checker := Build.mat("tile_checker", Color(0.95, 0.93, 0.9), 1.6)
	var damask := Build.mat("wallpaper_damask", Color(0.9, 0.85, 0.85), 2.0)
	var stripes := Build.mat("wallpaper_stripes", Color(0.85, 0.85, 0.9), 2.0)
	var ktile := Build.mat("tile_kitchen", Color(0.9, 0.88, 0.82), 1.2)
	var btile := Build.mat("tile_bath", Color(0.85, 0.9, 0.95), 1.0)
	var wwall := Build.mat("wood_wall", Color(0.9, 0.85, 0.8), 2.0)
	var wfloor := Build.mat("wood_floor", Color(0.9, 0.85, 0.8), 2.0)
	var skirt := Build.mat("planks_dark", Color(0.8, 0.75, 0.7), 1.0)
	# Pisos.
	Build.ground(geo, Rect2(-7, -12, 14, 15), 0.0, checker, "stone")
	Build.ground(geo, Rect2(-17, -12, 10, 7.5), 0.0, wfloor, "wood")
	Build.ground(geo, Rect2(-17, -4.5, 10, 7.5), 0.0, ktile, "stone")
	Build.ground(geo, Rect2(7, -12, 10, 7.5), 0.0, Build.mat("planks_dark", Color(1, 0.95, 0.9), 1.5), "wood")
	Build.ground(geo, Rect2(7, -4.5, 10, 7.5), 0.0, btile, "stone")
	# Saguão: pé-direito alto. Vãos das portas dos cômodos e da porta do subterrâneo.
	var side_gaps := [[3.75, 1.3, 2.5], [11.25, 1.3, 2.5]]
	_wall_gaps(Vector3(-7, 0, -12), Vector3(7, 0, -12), 6.5, damask, [[7.0, 2.8, 3.1]])
	_wall_gaps(Vector3(-7, 0, -12), Vector3(-7, 0, 3), 6.5, damask, side_gaps)
	_wall_gaps(Vector3(7, 0, -12), Vector3(7, 0, 3), 6.5, damask, side_gaps)
	# Revestimento do lado de dentro dos cômodos (mesma parede, outro papel).
	_wall_gaps(Vector3(-7.17, 0, -12), Vector3(-7.17, 0, -4.5), 3.5, stripes, [[3.75, 1.3, 2.5]], 0.04)
	_wall_gaps(Vector3(-7.17, 0, -4.5), Vector3(-7.17, 0, 3), 3.5, ktile, [[3.75, 1.3, 2.5]], 0.04)
	_wall_gaps(Vector3(7.17, 0, -12), Vector3(7.17, 0, -4.5), 3.5, wwall, [[3.75, 1.3, 2.5]], 0.04)
	_wall_gaps(Vector3(7.17, 0, -4.5), Vector3(7.17, 0, 3), 3.5, btile, [[3.75, 1.3, 2.5]], 0.04)
	# Cômodos: fundo e laterais altas; divisória entre norte e sul baixa (diorama).
	Build.wall(geo, Vector3(-17, 0, -12), Vector3(-7, 0, -12), 3.5, 0.3, stripes)
	Build.wall(geo, Vector3(-17, 0, -12), Vector3(-17, 0, -4.5), 3.5, 0.3, stripes)
	Build.wall(geo, Vector3(-17, 0, -4.5), Vector3(-17, 0, 3), 3.5, 0.3, ktile)
	Build.wall(geo, Vector3(-17, 0, -4.5), Vector3(-7, 0, -4.5), 0.6, 0.3, skirt)
	Build.wall(geo, Vector3(7, 0, -12), Vector3(17, 0, -12), 3.5, 0.3, wwall)
	Build.wall(geo, Vector3(17, 0, -12), Vector3(17, 0, -4.5), 3.5, 0.3, wwall)
	Build.wall(geo, Vector3(17, 0, -4.5), Vector3(17, 0, 3), 3.5, 0.3, btile)
	Build.wall(geo, Vector3(7, 0, -4.5), Vector3(17, 0, -4.5), 0.6, 0.3, skirt)
	# Frente baixa da casa inteira + bloqueio alto (inclui o patamar da escada).
	Build.wall(geo, Vector3(-17, 0, 3), Vector3(17, 0, 3), 0.6, 0.3, skirt)
	Build.blocker(geo, Vector3(35, 9, 0.4), Vector3(0, 4.5, 3.3))
	# Rodapés do saguão.
	Build.box(geo, Vector3(14, 0.25, 0.06), Vector3(0, 0.125, -11.82), skirt, false)


func _build_hall() -> void:
	var gold := Build.color_mat(Color("8a6a2a"), 0.0, 0.35)
	var wood := Build.mat("planks_dark", Color(0.9, 0.8, 0.7), 1.0)
	# Tapete do pé da escada até a porta do subterrâneo.
	Build.box(geo, Vector3(1.8, 0.02, 6.2), Vector3(0, 0.011, -8.2), Build.mat("carpet_red", Color(0.8, 0.7, 0.7), 1.0), false)

	# Lustre.
	var lustre := Node3D.new()
	lustre.position = Vector3(0, 6.0, -7.5)
	geo.add_child(lustre)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 0.92
	ring.mesh = tm
	ring.material_override = gold
	lustre.add_child(ring)
	Build.box(lustre, Vector3(0.05, 1.6, 0.05), Vector3(0, 0.8, 0), gold, false)
	Build.sphere(lustre, 0.2, Vector3(0, -0.05, 0), gold)
	for k in 8:
		var ang := k * TAU / 8.0
		var p := Vector3(cos(ang) * 0.87, 0.04, sin(ang) * 0.87)
		var arm := Build.box(lustre, Vector3(0.87, 0.03, 0.03), p * 0.5, gold, false)
		arm.rotation.y = -ang
		Build.cylinder(lustre, 0.03, 0.14, p + Vector3(0, 0.07, 0), Build.color_mat(Color("d8d0bc")), false, 6)
		var fl := Build.billboard(lustre, "flame", p + Vector3(0, 0.14, 0), 0.009, 4, k % 4, Color(1.4, 1.2, 0.9), false)
		var an := SpriteAnim.new()
		an.frames = 4
		an.fps = 9
		fl.add_child(an)
	_lustre_light = Build.omni(lustre, Vector3(0, -0.6, 0), Color("ffbf78"), 2.2, 13.0, true, true)
	var sway := create_tween().set_loops()
	sway.tween_property(lustre, "rotation_degrees:z", 1.2, 3.2).set_trans(Tween.TRANS_SINE)
	sway.tween_property(lustre, "rotation_degrees:z", -1.2, 3.2).set_trans(Tween.TRANS_SINE)

	# Janela redonda acima da porta: feixe de luar.
	var win := Build.cylinder(geo, 0.55, 0.05, Vector3(0, 4.25, -11.84), Build.color_mat(Color("6d8fd0"), 0.7), false, 16)
	win.rotation_degrees.x = 90
	Build.box(geo, Vector3(1.1, 0.05, 0.08), Vector3(0, 4.25, -11.8), wood, false)
	Build.box(geo, Vector3(0.05, 1.1, 0.08), Vector3(0, 4.25, -11.8), wood, false)
	_room_lights[0].append(Build.spot(geo, Vector3(0, 4.4, -11.4), Vector3(0, 0, -7.5), Color("7f9ee0"), 2.2, 9.0, 22.0, false))

	# Quadros e mesinhas com velas ao norte.
	_painting(Vector3(-5.1, 2.7, -11.8), 0.0, Vector2(1.2, 1.5), Color("1d2430"), "landscape")
	_painting(Vector3(5.1, 2.7, -11.8), 0.0, Vector2(1.2, 1.5), Color("2a1c1c"), "portrait")
	for x in [-5.1, 5.1]:
		Build.box(geo, Vector3(1.1, 0.08, 0.5), Vector3(x, 0.84, -11.55), wood, false)
		for lx in [-0.45, 0.45]:
			Build.box(geo, Vector3(0.06, 0.8, 0.06), Vector3(x + lx, 0.4, -11.55), wood, false)
		Build.blocker(geo, Vector3(1.1, 1, 0.5), Vector3(x, 0.5, -11.55))
		_room_lights[0].append(_light_of(Build.candle(geo, Vector3(x - 0.25, 0.88, -11.55), 0.7, 3.5)))
	# Quadros nas paredes laterais, entre as portas.
	_painting(Vector3(-6.83, 2.6, -4.5), 90.0, Vector2(1.0, 1.3), Color("20283a"), "portrait")
	_painting(Vector3(6.83, 2.6, -4.5), -90.0, Vector2(1.0, 1.3), Color("22301f"), "landscape")

	# Relógio de pêndulo parado entre o Quarto e a Cozinha.
	var clock := Node3D.new()
	clock.position = Vector3(-6.55, 0, -4.5)
	geo.add_child(clock)
	Build.box(clock, Vector3(0.5, 2.3, 0.7), Vector3(0, 1.15, 0), wood, false)
	Build.blocker(clock, Vector3(0.5, 2.3, 0.7), Vector3(0, 1.15, 0))
	var face := Build.cylinder(clock, 0.24, 0.04, Vector3(0.26, 1.85, 0), Build.color_mat(Color("d8cfb8")), false, 16)
	face.rotation_degrees.z = 90
	Build.box(clock, Vector3(0.02, 0.2, 0.02), Vector3(0.29, 1.9, 0), Build.color_mat(Color("111111")), false)
	var pend := Build.box(clock, Vector3(0.02, 0.6, 0.02), Vector3(0.27, 1.1, 0), gold, false)
	var ps := create_tween().set_loops()
	ps.tween_property(pend, "rotation_degrees:x", 8.0, 1.0).set_trans(Tween.TRANS_SINE)
	ps.tween_property(pend, "rotation_degrees:x", -8.0, 1.0).set_trans(Tween.TRANS_SINE)
	_anchors["clock"] = clock

	# Plantas mortas nos cantos da frente e teias no alto.
	for p in [Vector3(-6.2, 0, 2.2), Vector3(6.2, 0, 2.2), Vector3(-6.3, 0, -6.4), Vector3(6.2, 0, -10.6)]:
		Build.cylinder(geo, 0.25, 0.5, p + Vector3(0, 0.25, 0), Build.mat("brick", Color(0.7, 0.6, 0.55), 1.0), true, 10)
		Build.billboard(geo, "fern", p + Vector3(0, 0.45, 0), 0.03, 1, 0, Color(0.55, 0.5, 0.4))
	for p in [Vector3(-6.6, 5.2, -11.6), Vector3(6.6, 5.2, -11.6)]:
		Build.billboard(geo, "cobweb", p, 0.05, 1, 0, Color(0.8, 0.8, 0.85))

	# Sangue: arrastado do pé da escada até a porta.
	_blood(Vector3(0.7, 0.025, -10.4), Vector3(-90, 25, 0), 0.0018)
	_blood(Vector3(-0.5, 0.025, -7.6), Vector3(-90, -150, 0), 0.0012)
	_blood(Vector3(-2.6, 0.025, -5.8), Vector3(-90, 70, 0), 0.0010)

	Build.motes(geo, Vector3(0, 2.2, -5), Vector3(6, 2, 6), 70, Color(0.9, 0.85, 0.7, 0.5), "dust", 0.04)


func _painting(pos: Vector3, rot_y: float, size: Vector2, canvas: Color, kind: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	geo.add_child(root)
	Build.box(root, Vector3(size.x + 0.18, size.y + 0.18, 0.06), Vector3.ZERO, Build.color_mat(Color("5a4320"), 0.0, 0.5), false)
	Build.box(root, Vector3(size.x, size.y, 0.07), Vector3(0, 0, 0.005), Build.color_mat(canvas), false)
	if kind == "portrait":
		var head := Build.sphere(root, 0.2, Vector3(0, size.y * 0.12, 0.04), Build.color_mat(Color("b8aa98")))
		head.scale = Vector3(1.0, 1.3, 0.25)
		Build.box(root, Vector3(size.x * 0.7, size.y * 0.35, 0.02), Vector3(0, -size.y * 0.3, 0.04), Build.color_mat(Color("120c0c")), false)
		# Olhos riscados.
		for ex in [-0.07, 0.07]:
			var e := Build.box(root, Vector3(0.1, 0.025, 0.02), Vector3(ex, size.y * 0.15, 0.1), Build.color_mat(Color("5a0a0e")), false)
			e.rotation_degrees.z = 20.0 if ex < 0 else -20.0
	else:
		Build.box(root, Vector3(size.x, size.y * 0.3, 0.02), Vector3(0, -size.y * 0.35, 0.04), Build.color_mat(Color("141a14")), false)
		Build.flat_sprite(root, "tree_dead", Vector3(0.1, -0.05, 0.05), Vector3.ZERO, 0.012, Color(0.5, 0.55, 0.6))
		Build.sphere(root, 0.08, Vector3(-0.3, size.y * 0.3, 0.04), Build.color_mat(Color("c9d2e0"), 0.4))
	return root


func _blood(pos: Vector3, rot: Vector3, pixel := 0.0012) -> Sprite3D:
	var s := Build.flat_sprite(geo, "res://assets/legacy/blood_hand.png", pos, rot, pixel, Color(0.8, 0.75, 0.75))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


func _build_stairs() -> void:
	var wood := Build.mat("planks_dark", Color(0.9, 0.8, 0.7), 1.0)
	var rail_mat := Build.color_mat(Color("2a1c12"), 0.0, 0.5)
	# Patamar (saída do sótão) e escadaria até o saguão.
	Build.box(geo, Vector3(6, 3.2, 3), Vector3(0, 1.6, 1.5), wood, true, 0.0, "wood")
	Build.box(geo, Vector3(1.6, 0.02, 2.6), Vector3(0, 3.21, 1.6), Build.mat("carpet_red", Color(0.8, 0.7, 0.7), 1.0), false)
	Build.stairs(geo, Vector3(0, 0, -5), Vector3(0, 3.2, 0), 2.4, 12, Build.mat("carpet_red", Color(0.85, 0.75, 0.75), 1.0))
	# Laterais da escada (longarinas) e corrimãos.
	var slope := rad_to_deg(atan2(3.2, 5.0))
	for sx in [-1.25, 1.25]:
		var rail := Build.box(geo, Vector3(0.08, 0.08, 5.95), Vector3(sx, 1.6 + 1.0, -2.5), rail_mat, false)
		rail.rotation_degrees.x = -slope
		for i in 6:
			var z := -4.6 + i * 0.9
			var top := (z + 5.0) / 5.0 * 3.2
			Build.box(geo, Vector3(0.05, 1.0, 0.05), Vector3(sx, top + 0.5, z), rail_mat, false)
		Build.blocker(geo, Vector3(0.1, 6, 4.3), Vector3(sx * 1.04, 3, -2.15))
	# Guarda-corpo do patamar.
	for seg in [[Vector3(-3, 3.2, 0), Vector3(-3, 3.2, 3)], [Vector3(3, 3.2, 0), Vector3(3, 3.2, 3)], [Vector3(-3, 3.2, 0), Vector3(-1.2, 3.2, 0)], [Vector3(1.2, 3.2, 0), Vector3(3, 3.2, 0)]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		Build.wall(geo, a + Vector3(0, 0.95, 0), b + Vector3(0, 0.95, 0), 0.08, 0.08, rail_mat, false)
		var n := int(a.distance_to(b) / 0.45)
		for i in n + 1:
			var p := a.lerp(b, float(i) / max(n, 1))
			Build.box(geo, Vector3(0.04, 0.95, 0.04), p + Vector3(0, 0.475, 0), rail_mat, false)
		var mid := (a + b) / 2.0
		var d := b - a
		Build.blocker(geo, Vector3(max(abs(d.x), 0.15), 2.5, max(abs(d.z), 0.15)), mid + Vector3(0, 1.25, 0))
	Build.candle(geo, Vector3(-2.9, 4.2, 0.05), 0.8, 4.0)
	Build.candle(geo, Vector3(2.9, 4.2, 0.05), 0.8, 4.0)
	# Escada de mão para o alçapão do sótão.
	for lx in [-2.55, -1.95]:
		Build.box(geo, Vector3(0.07, 3.8, 0.07), Vector3(lx, 3.2 + 1.9, 2.6), wood, false)
	for i in 8:
		Build.box(geo, Vector3(0.6, 0.05, 0.05), Vector3(-2.25, 3.5 + i * 0.45, 2.6), wood, false)
	Build.omni(geo, Vector3(-2.25, 6.2, 2.4), Color("7f95c8"), 0.9, 5.0)
	# Baú e caixas esquecidos no patamar.
	Build.box(geo, Vector3(0.9, 0.55, 0.55), Vector3(2.2, 3.2 + 0.275, 2.3), Build.mat("planks_dark", Color(0.7, 0.6, 0.5), 0.8), true)
	Build.box(geo, Vector3(0.5, 0.5, 0.5), Vector3(1.6, 3.2 + 0.25, 2.55), Build.mat("wood_wall", Color(0.8, 0.7, 0.6), 0.8), true, 20.0)


func _build_gate() -> void:
	var iron := Build.mat("rust_metal", Color(0.75, 0.7, 0.68), 1.0)
	var stone := Build.mat("stone_wall", Color(0.7, 0.7, 0.75), 1.5)
	var dark := Build.color_mat(Color("1a1512"), 0.0, 0.5)
	var chain_mat := Build.color_mat(Color("4a4d52"), 0.0, 0.3)
	# Moldura de pedra.
	for x in [-1.55, 1.55]:
		Build.box(geo, Vector3(0.35, 3.4, 0.5), Vector3(x, 1.7, GATE_Z), stone, false)
	Build.box(geo, Vector3(3.5, 0.4, 0.5), Vector3(0, 3.3, GATE_Z), stone, false)
	Build.text3d(geo, "NÃO DESÇA", Vector3(0, 3.3, GATE_Z + 0.26), 0.0, 40, Color("c9c2b0"))
	# Duas folhas de ferro.
	_gate_l = Build.door(geo, Vector3(-0.65, 0, GATE_Z), 0.0, iron, 1.3, 3.0)
	_gate_r = Build.door(geo, Vector3(0.65, 0, GATE_Z), 180.0, iron, 1.3, 3.0)
	_blood(Vector3(-0.75, 2.1, GATE_Z + 0.08), Vector3(0, 0, 8), 0.0011)
	_blood(Vector3(0.55, 0.9, GATE_Z + 0.08), Vector3(0, 0, -15), 0.0008)

	# Correntes cruzadas e os quatro cadeados.
	_chains = Node3D.new()
	geo.add_child(_chains)
	for rz in [34.0, -34.0]:
		var c := Build.box(_chains, Vector3(3.0, 0.06, 0.05), Vector3(0, 1.55, GATE_Z + 0.14), chain_mat, false)
		c.rotation_degrees.z = rz
	Build.box(_chains, Vector3(2.6, 0.06, 0.05), Vector3(0, LOCK_Y + 0.22, GATE_Z + 0.15), chain_mat, false)
	for n in range(1, 5):
		var lock := Node3D.new()
		lock.position = Vector3(LOCK_X[n], LOCK_Y, GATE_Z + 0.2)
		geo.add_child(lock)
		var spr := Build.flat_sprite(lock, "res://assets/legacy/padlock.png", Vector3.ZERO, Vector3.ZERO, 0.00082)
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Etiqueta com o número romano pendurada no cadeado.
		Build.box(lock, Vector3(0.2, 0.14, 0.01), Vector3(0, -0.33, 0.0), Build.color_mat(Color("c8bba0")), false)
		var lbl := Build.text3d(lock, ROMAN[n], Vector3(0, -0.33, 0.012), 0.0, 44, Color("8a1016"), UiTheme.FONT_SERIF, 0.004)
		lbl.shaded = false
		_locks[n] = lock
		_lock_its[n] = interact(Vector3(LOCK_X[n], LOCK_Y, -11.3), "Cadeado %s" % ROMAN[n], _try_lock.bind(n), "any", 0.42, true, 0.75)

	# Rodas nas laterais, ligadas às trancas por barras.
	for side in ["L", "R"]:
		var x := -WHEEL_X if side == "L" else WHEEL_X
		Build.box(geo, Vector3(0.36, 0.36, 0.12), Vector3(x, 1.45, GATE_Z + 0.2), dark, false)
		Build.box(geo, Vector3(absf(x) - 1.4, 0.08, 0.08), Vector3(signf(x) * (1.4 + (absf(x) - 1.4) / 2.0), 1.45, GATE_Z + 0.2), iron, false)
		var root := Node3D.new()
		root.position = Vector3(x, 1.45, GATE_Z + 0.32)
		geo.add_child(root)
		var spin := Node3D.new()
		root.add_child(spin)
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.44
		tm.outer_radius = 0.52
		rim.mesh = tm
		rim.material_override = iron
		rim.rotation_degrees.x = 90
		spin.add_child(rim)
		for k in 4:
			var sp := Build.box(spin, Vector3(0.9, 0.06, 0.06), Vector3.ZERO, iron, false)
			sp.rotation_degrees.z = k * 45.0
		Build.sphere(spin, 0.09, Vector3.ZERO, dark)
		for k in 6:
			var ang := k * TAU / 6.0
			var h := Build.cylinder(spin, 0.03, 0.2, Vector3(cos(ang) * 0.48, sin(ang) * 0.48, 0.1), Build.color_mat(Color("3a2a1c")), false, 6)
			h.rotation_degrees.x = 90
		var it := interact(Vector3(x, 1.0, WHEEL_STAND_Z), "Girar a roda", _wheel.bind(side), "any", 0.9, true, 1.1)
		_wheels[side] = {"x": x, "spin": spin, "it": it, "holder": ""}
	_anchors["gate"] = _chains

	zone(Vector3(0, 1, -9.8), Vector3(7, 2, 1.2), _on_gate_near)


func _build_room_doors() -> void:
	var door_mat := Build.mat("planks_dark", Color(0.95, 0.85, 0.75), 1.0)
	var list := [[-7.0, -8.25, 1], [-7.0, -0.75, 2], [7.0, -8.25, 3], [7.0, -0.75, 4]]
	for d in list:
		var x: float = d[0]
		var z: float = d[1]
		var n: int = d[2]
		var side := signf(x)
		var door := Build.door(geo, Vector3(x, 0, z), -side * 90.0, door_mat, 1.2, 2.4)
		_room_doors[n] = door
		_room_its[n] = interact(Vector3(x - side * 0.75, 1.0, z), "Abrir: %s (%s)" % [ROOMS[n], ROMAN[n]], _open_room.bind(n), "any", 1.1, true, 1.6)
		# Placa com o número acima da porta, do lado do saguão.
		Build.box(geo, Vector3(0.04, 0.36, 0.5), Vector3(x - side * 0.17, 2.85, z), Build.color_mat(Color("6b5424"), 0.0, 0.4), false)
		var l := Build.text3d(geo, ROMAN[n], Vector3(x - side * 0.2, 2.85, z), -side * 90.0, 60, Color("e8dcc0"), UiTheme.FONT_SERIF, 0.005)
		l.shaded = false
	# Primeira fala ao entrar em cada cômodo.
	zone(Vector3(-8.6, 1, -8.25), Vector3(1.2, 2, 2.4), _enter_room.bind(1))
	zone(Vector3(-8.6, 1, -0.75), Vector3(1.2, 2, 2.4), _enter_room.bind(2))
	zone(Vector3(8.6, 1, -8.25), Vector3(1.2, 2, 2.4), _enter_room.bind(3))
	zone(Vector3(8.6, 1, -0.75), Vector3(1.2, 2, 2.4), _enter_room.bind(4))


func _build_bedroom() -> void:
	var wood := Build.mat("planks_dark", Color(0.85, 0.75, 0.65), 1.0)
	var cloth := Build.mat("bed_cloth", Color(0.8, 0.8, 0.85), 1.0)
	# Tapete.
	Build.box(geo, Vector3(4.0, 0.02, 2.8), Vector3(-11.8, 0.011, -7.8), Build.mat("carpet_red", Color(0.7, 0.6, 0.65), 1.2), false)
	# Cama de criança com o travesseiro.
	Build.box(geo, Vector3(1.5, 0.42, 2.2), Vector3(-14.5, 0.21, -10.85), wood, true)
	Build.box(geo, Vector3(1.6, 1.1, 0.12), Vector3(-14.5, 0.55, -11.9), wood, false)
	Build.box(geo, Vector3(1.4, 0.14, 2.05), Vector3(-14.5, 0.49, -10.8), cloth, false)
	Build.box(geo, Vector3(1.44, 0.1, 1.3), Vector3(-14.5, 0.58, -10.35), Build.color_mat(Color("4a2a34")), false)
	Build.box(geo, Vector3(0.9, 0.14, 0.38), Vector3(-14.5, 0.62, -11.5), Build.color_mat(Color("d8d4cc")), false)
	Build.flat_sprite(geo, "icon_note", Vector3(-14.2, 0.56, -11.3), Vector3(-90, 15, 0), 0.02)
	doc(Vector3(-13.6, 0.7, -11.2), {
		"id": "ch7_travesseiro",
		"title": "Bilhete sob o travesseiro",
		"style": "hand",
		"body": "Eles me destruíram sem Dó\nO Sol já não nasce como antes\nNão quero mais voltar Lá\nEles apenas Fa-zem chacota de mim",
	}, "Olhar sob o travesseiro", "any", 1.1)
	# Criado-mudo com vela.
	Build.box(geo, Vector3(0.5, 0.6, 0.5), Vector3(-13.2, 0.3, -11.6), wood, true)
	_room_lights[1].append(_light_of(Build.candle(geo, Vector3(-13.2, 0.6, -11.6), 0.8, 4.5)))
	# Escrito na parede.
	var txt := Build.text3d(geo, "VLOHQFLR", Vector3(-11.2, 1.75, -11.83), 0.0, 110, Color("9a1016"), UiTheme.FONT_HAND, 0.006)
	txt.shaded = false
	for i in 9:
		var dx := -12.4 + i * 0.29 + rng.randf_range(-0.08, 0.08)
		var drip := rng.randf_range(0.2, 0.7)
		Build.box(geo, Vector3(0.03, drip, 0.01), Vector3(dx, 1.5 - drip / 2.0, -11.84), Build.color_mat(Color("6a0a0e")), false)
	doc(Vector3(-11.2, 1.0, -11.2), {
		"id": "ch7_parede",
		"title": "Escrito na parede do quarto",
		"style": "stone",
		"body": "[center][color=#c0242c][font_size=86]VLOHQFLR[/font_size][/color]\n\nAs letras ainda escorrem.[/center]",
	}, "Examinar o escrito na parede", "any", 1.2)
	# Armário (chave I).
	Build.box(geo, Vector3(1.5, 2.4, 0.7), Vector3(-8.7, 1.2, -11.5), wood, true)
	_wardrobe_door = Node3D.new()
	_wardrobe_door.position = Vector3(-9.45, 0, -11.13)
	geo.add_child(_wardrobe_door)
	Build.box(_wardrobe_door, Vector3(0.74, 2.2, 0.04), Vector3(0.37, 1.2, 0), Build.mat("planks_dark", Color(1, 0.9, 0.8), 0.8), false)
	Build.box(geo, Vector3(0.74, 2.2, 0.04), Vector3(-8.33, 1.2, -11.13), Build.mat("planks_dark", Color(1, 0.9, 0.8), 0.8), false)
	Build.box(geo, Vector3(0.3, 0.2, 0.06), Vector3(-8.7, 1.25, -11.1), Build.color_mat(Color("8a7a50"), 0.0, 0.3), false)
	_wardrobe_it = interact(Vector3(-8.7, 1.0, -10.7), "Abrir o armário", _wardrobe, "any", 1.1)
	# Janela com luar.
	Build.box(geo, Vector3(0.06, 1.3, 1.1), Vector3(-16.84, 1.9, -8.2), Build.color_mat(Color("6d8fd0"), 0.6), false)
	Build.box(geo, Vector3(0.1, 0.06, 1.1), Vector3(-16.8, 1.9, -8.2), wood, false)
	Build.box(geo, Vector3(0.1, 1.3, 0.06), Vector3(-16.8, 1.9, -8.2), wood, false)
	Build.box(geo, Vector3(0.14, 1.5, 1.4), Vector3(-16.9, 1.9, -8.2), Build.mat("curtain", Color(0.6, 0.5, 0.55), 1.0), false)
	Build.spot(geo, Vector3(-16.4, 2.6, -8.2), Vector3(-13.5, 0, -8.0), Color("7f9ee0"), 2.4, 8.0, 30.0, false)
	var wa := Node3D.new()
	wa.position = Vector3(-16.5, 2, -8.2)
	geo.add_child(wa)
	_anchors["window"] = wa
	# Brinquedos, sangue e teias.
	Build.sphere(geo, 0.14, Vector3(-11.0, 0.14, -6.4), Build.color_mat(Color("7a2a2a")))
	Build.box(geo, Vector3(0.3, 0.3, 0.3), Vector3(-14.6, 0.15, -5.2), Build.mat("wood_wall", Color(0.9, 0.8, 0.6), 0.5), true, 25.0)
	_blood(Vector3(-13.0, 0.025, -9.3), Vector3(-90, 40, 0), 0.0011)
	Build.billboard(geo, "cobweb", Vector3(-16.5, 2.9, -11.6), 0.04, 1, 0, Color(0.8, 0.8, 0.85))
	_room_lights[1].append(Build.omni(geo, Vector3(-11.5, 2.6, -7.5), Color("8a9cc8"), 0.5, 7.0))
	_build_photo()


func _build_kitchen() -> void:
	var wood := Build.mat("planks_dark", Color(0.85, 0.75, 0.65), 1.0)
	var metal := Build.mat("metal", Color(0.8, 0.8, 0.8), 1.0)
	# Geladeira com o bilhete de César.
	Build.box(geo, Vector3(0.8, 1.9, 0.9), Vector3(-16.4, 0.95, -3.3), Build.color_mat(Color("bfbcae"), 0.0, 0.4), true)
	Build.box(geo, Vector3(0.04, 0.5, 0.05), Vector3(-15.98, 1.2, -2.95), metal, false)
	Build.box(geo, Vector3(0.01, 0.46, 0.5), Vector3(-15.99, 1.5, -3.4), Build.color_mat(Color("d8cfb0")), false)
	var ce := Build.text3d(geo, "CÉSAR DISSE:\n+3", Vector3(-15.98, 1.52, -3.4), 90.0, 26, Color("2b2119"), UiTheme.FONT_TYPED, 0.004)
	ce.shaded = true
	doc(Vector3(-15.5, 1.0, -3.3), {
		"id": "ch7_geladeira",
		"title": "Bilhete na geladeira",
		"style": "paper",
		"body": "[center][font_size=46]CÉSAR DISSE: +3[/font_size]\n\nA B C D E F G H I J K L M\nD E F G H I J K L M N O P\n\nN O P Q R S T U V W X Y Z\nQ R S T U V W X Y Z A B C[/center]",
	}, "Ler o bilhete da geladeira", "any", 1.1)
	# Bancada, fogão e pia.
	Build.box(geo, Vector3(0.8, 0.95, 2.4), Vector3(-16.4, 0.475, -1.0), Build.mat("tile_kitchen", Color(0.8, 0.75, 0.7), 0.6), true)
	Build.box(geo, Vector3(0.7, 0.04, 0.7), Vector3(-16.4, 0.97, -1.6), metal, false)
	for pz in [-0.35, 0.1]:
		Build.cylinder(geo, 0.16, 0.2, Vector3(-16.4, 1.07, pz), metal, false, 10)
	# Despensa (chave II).
	Build.box(geo, Vector3(0.8, 2.3, 1.2), Vector3(-16.4, 1.15, 1.9), wood, true)
	_pantry_door = Node3D.new()
	_pantry_door.position = Vector3(-15.98, 0, 1.32)
	geo.add_child(_pantry_door)
	Build.box(_pantry_door, Vector3(0.04, 2.1, 1.12), Vector3(0, 1.15, 0.58), Build.mat("planks_dark", Color(1, 0.9, 0.8), 0.8), false)
	Build.box(geo, Vector3(0.06, 0.2, 0.14), Vector3(-15.93, 1.2, 1.9), Build.color_mat(Color("8a7a50"), 0.0, 0.3), false)
	_pantry_it = interact(Vector3(-15.4, 1.0, 1.9), "Abrir a despensa", _pantry, "any", 1.1)
	# Mesa com o bilhete da mãe.
	Build.box(geo, Vector3(1.6, 0.08, 1.0), Vector3(-12.0, 0.8, -1.0), wood, false)
	for lx in [-0.7, 0.7]:
		for lz in [-0.4, 0.4]:
			Build.box(geo, Vector3(0.07, 0.8, 0.07), Vector3(-12.0 + lx, 0.4, -1.0 + lz), wood, false)
	Build.blocker(geo, Vector3(1.6, 1, 1.0), Vector3(-12.0, 0.5, -1.0))
	for cx in [-12.5, -11.4]:
		Build.box(geo, Vector3(0.45, 0.45, 0.45), Vector3(cx, 0.225, -1.75), wood, false)
		Build.box(geo, Vector3(0.45, 0.6, 0.05), Vector3(cx, 0.75, -1.97), wood, false)
	Build.box(geo, Vector3(0.3, 0.01, 0.22), Vector3(-11.7, 0.845, -0.9), Build.color_mat(Color("d8cfb0")), false)
	_room_lights[2].append(_light_of(Build.candle(geo, Vector3(-12.4, 0.84, -1.1), 0.8, 4.5)))
	doc(Vector3(-11.7, 0.9, -0.9), {
		"id": "ch7_mamae",
		"title": "Bilhete na mesa da cozinha",
		"style": "hand",
		"body": "Mamãe só contava os dardos no vermelho, e somava tudo.",
	}, "Ler o bilhete na mesa", "any", 1.2)
	# Alvo de dardos na parede do saguão (lado da cozinha), com sangue em volta.
	var board := Node3D.new()
	board.position = Vector3(-7.22, 1.7, 1.4)
	geo.add_child(board)
	var rings := [[0.36, Color("14100c")], [0.31, Color("17191c")], [0.25, Color("8e1b1f")], [0.19, Color("17191c")], [0.12, Color("8e1b1f")], [0.05, Color("1f6b2e")], [0.025, Color("8e1b1f")]]
	for i in rings.size():
		var r: Array = rings[i]
		var disc := Build.cylinder(board, r[0], 0.04, Vector3(-0.02 * i, 0, 0), Build.color_mat(r[1]), false, 20)
		disc.rotation_degrees.z = 90
	# Setores alternados (fatias finas sobre os anéis).
	for k in 10:
		var sec := Build.box(board, Vector3(0.012, 0.62, 0.05), Vector3(-0.16, 0, 0), Build.color_mat(Color("8e1b1f") if k % 2 == 0 else Color("17191c")), false)
		sec.rotation_degrees.x = k * 18.0
	for k in DARTS.size():
		var a := k * 1.3 + 0.4
		var dp := Vector3(-0.2, sin(a) * 0.17, cos(a) * 0.17)
		var dart := Build.box(board, Vector3(0.22, 0.015, 0.015), dp + Vector3(-0.11, 0.02, 0), Build.color_mat(Color("c9c2b4")), false)
		dart.rotation_degrees.z = -12
		Build.box(board, Vector3(0.04, 0.06, 0.005), dp + Vector3(-0.22, 0.04, 0), Build.color_mat(Color("3a6fb0")), false)
	_blood(Vector3(-7.21, 1.35, 2.05), Vector3(0, -90, 10), 0.0009)
	_blood(Vector3(-7.21, 2.05, 0.85), Vector3(0, -90, -30), 0.0006)
	_blood(Vector3(-7.9, 0.025, 1.6), Vector3(-90, 0, 0), 0.0012)
	interact(Vector3(-7.9, 1.2, 1.4), "Olhar o alvo de dardos", _dartboard, "any", 1.0, true, 1.1)
	# Lâmpada nua sobre a mesa.
	Build.box(geo, Vector3(0.02, 0.8, 0.02), Vector3(-12.0, 3.1, -1.0), Build.color_mat(Color("111111")), false)
	Build.sphere(geo, 0.08, Vector3(-12.0, 2.65, -1.0), Build.color_mat(Color("ffd9a0"), 2.0))
	_room_lights[2].append(Build.omni(geo, Vector3(-12.0, 2.5, -1.0), Color("ffcf8a"), 0.9, 7.0, false, true))
	Build.billboard(geo, "cobweb", Vector3(-16.5, 2.9, 2.5), 0.04, 1, 0, Color(0.8, 0.8, 0.85))


func _build_office() -> void:
	var dark_wood := Build.color_mat(Color("1a120d"), 0.0, 0.35)
	var wood := Build.mat("planks_dark", Color(0.85, 0.75, 0.65), 1.0)
	# Piano de armário.
	Build.box(geo, Vector3(1.7, 1.3, 0.6), Vector3(12.5, 0.65, -11.55), dark_wood, true)
	Build.box(geo, Vector3(1.6, 0.1, 0.34), Vector3(12.5, 0.75, -11.12), dark_wood, false)
	Build.box(geo, Vector3(1.44, 0.04, 0.22), Vector3(12.5, 0.81, -11.08), Build.color_mat(Color("dcd6c8"), 0.0, 0.3), false)
	for i in 10:
		if i % 7 == 2 or i % 7 == 6:
			continue
		Build.box(geo, Vector3(0.06, 0.03, 0.12), Vector3(11.86 + i * 0.145, 0.84, -11.13), Build.color_mat(Color("0d0b0a")), false)
	Build.box(geo, Vector3(0.9, 0.45, 0.4), Vector3(12.5, 0.225, -10.45), dark_wood, false)
	Build.box(geo, Vector3(0.5, 0.4, 0.02), Vector3(12.5, 1.1, -11.24), Build.color_mat(Color("d8cfb0")), false)
	for cx in [11.9, 13.1]:
		_room_lights[3].append(_light_of(Build.candle(geo, Vector3(cx, 1.3, -11.55), 0.6, 4.0)))
	_blood(Vector3(12.9, 0.84, -11.08), Vector3(-90, 0, 0), 0.0003)
	_piano_it = interact(Vector3(12.5, 1.0, -10.4), "Tocar o piano", _piano, "any", 1.1)
	# Retrato do pai acima do piano.
	_painting(Vector3(12.5, 2.55, -11.8), 0.0, Vector2(1.0, 1.2), Color("1c1612"), "portrait")
	# Mesa com a carta.
	Build.box(geo, Vector3(1.8, 0.08, 0.9), Vector3(14.8, 0.8, -7.4), wood, false)
	Build.box(geo, Vector3(1.8, 0.76, 0.06), Vector3(14.8, 0.38, -7.8), wood, false)
	for lx in [-0.85, 0.85]:
		Build.box(geo, Vector3(0.08, 0.8, 0.9), Vector3(14.8 + lx, 0.4, -7.4), wood, false)
	Build.blocker(geo, Vector3(1.8, 1, 0.9), Vector3(14.8, 0.5, -7.4))
	Build.box(geo, Vector3(0.5, 0.9, 0.5), Vector3(14.8, 0.45, -8.3), wood, false)
	Build.box(geo, Vector3(0.36, 0.01, 0.26), Vector3(14.6, 0.845, -7.3), Build.color_mat(Color("d8cfb0")), false)
	Build.box(geo, Vector3(0.3, 0.01, 0.22), Vector3(15.1, 0.846, -7.45), Build.color_mat(Color("c8bea0")), false, 18.0)
	Build.candle(geo, Vector3(15.5, 0.84, -7.6), 0.8, 4.5)
	doc(Vector3(14.6, 0.9, -7.3), DOC_PAI, "Ler a carta sobre a mesa", "any", 1.2)
	# Estantes.
	for z in [-11.0, -9.4]:
		Build.box(geo, Vector3(0.5, 2.6, 1.5), Vector3(16.6, 1.3, z), wood, true)
		for shelf in 4:
			var y := 0.35 + shelf * 0.6
			var zz: float = z - 0.6
			while zz < float(z) + 0.6:
				var w := rng.randf_range(0.06, 0.12)
				var hh := rng.randf_range(0.3, 0.45)
				var col: Color = [Color("5a1a1e"), Color("1f2d45"), Color("2f4a38"), Color("4a3d30"), Color("6a5a3a")][rng.randi_range(0, 4)]
				Build.box(geo, Vector3(0.05, hh, w), Vector3(16.33, y + hh / 2.0, zz + w / 2.0), Build.color_mat(col), false)
				zz += w + 0.01
	Build.box(geo, Vector3(1.4, 2.4, 0.5), Vector3(8.2, 1.2, -11.6), wood, true)
	_room_lights[3].append(Build.omni(geo, Vector3(12.0, 2.6, -7.5), Color("c9a878"), 0.45, 7.0))
	Build.billboard(geo, "cobweb", Vector3(16.5, 2.9, -11.6), 0.04, 1, 0, Color(0.8, 0.8, 0.85))


func _build_bathroom() -> void:
	var porcelain := Build.color_mat(Color("d8dcd8"), 0.0, 0.3)
	# Banheira com água escura.
	var tub := Node3D.new()
	tub.position = Vector3(15.9, 0, -1.0)
	geo.add_child(tub)
	Build.box(tub, Vector3(1.0, 0.12, 2.2), Vector3(0, 0.06, 0), porcelain, false)
	Build.box(tub, Vector3(0.1, 0.6, 2.2), Vector3(-0.45, 0.3, 0), porcelain, false)
	Build.box(tub, Vector3(0.1, 0.6, 2.2), Vector3(0.45, 0.3, 0), porcelain, false)
	Build.box(tub, Vector3(1.0, 0.6, 0.1), Vector3(0, 0.3, -1.05), porcelain, false)
	Build.box(tub, Vector3(1.0, 0.6, 0.1), Vector3(0, 0.3, 1.05), porcelain, false)
	Build.box(tub, Vector3(0.8, 0.02, 2.0), Vector3(0, 0.46, 0), Build.color_mat(Color(0.28, 0.03, 0.04, 0.92), 0.0, 0.05), false)
	Build.blocker(tub, Vector3(1.0, 1.0, 2.2), Vector3(0, 0.5, 0))
	Build.box(tub, Vector3(0.06, 0.5, 0.06), Vector3(0.4, 0.8, -1.0), Build.mat("metal"), false)
	_anchors["tub"] = tub
	_blood(Vector3(15.35, 0.62, -0.4), Vector3(0, -90, 0), 0.0006)
	_blood(Vector3(14.9, 0.025, -1.4), Vector3(-90, 60, 0), 0.0011)
	# Pia e espelho embaçado.
	Build.box(geo, Vector3(0.55, 0.85, 0.7), Vector3(16.55, 0.425, 1.7), porcelain, true)
	Build.box(geo, Vector3(0.08, 1.15, 0.95), Vector3(16.82, 1.8, 1.7), Build.color_mat(Color("3a2a1c")), false)
	Build.box(geo, Vector3(0.03, 1.0, 0.8), Vector3(16.77, 1.8, 1.7), Build.color_mat(Color("9fb2c2"), 0.15, 0.08), false)
	var fogtxt := Build.text3d(geo, "ACORDE", Vector3(16.75, 1.95, 1.7), -90.0, 28, Color(0.35, 0.42, 0.5, 0.8), UiTheme.FONT_HAND, 0.005)
	fogtxt.shaded = true
	interact(Vector3(15.9, 1.0, 1.7), "Olhar o espelho", _mirror, "any", 1.0)
	# Vaso sanitário.
	Build.box(geo, Vector3(0.5, 0.45, 0.6), Vector3(16.45, 0.225, -3.6), porcelain, true)
	Build.box(geo, Vector3(0.2, 0.7, 0.55), Vector3(16.8, 0.6, -3.6), porcelain, false)
	# Armário do banheiro (chave IV).
	Build.box(geo, Vector3(0.6, 2.0, 1.1), Vector3(7.5, 1.0, -3.4), Build.mat("wood_wall", Color(0.9, 0.9, 0.9), 0.8), true)
	_cabinet_door = Node3D.new()
	_cabinet_door.position = Vector3(7.82, 0, -3.92)
	geo.add_child(_cabinet_door)
	Build.box(_cabinet_door, Vector3(0.04, 1.8, 1.02), Vector3(0, 1.0, 0.51), Build.mat("wood_wall", Color(1, 1, 1), 0.8), false)
	Build.box(geo, Vector3(0.02, 0.3, 0.3), Vector3(7.85, 1.5, -3.4), Build.color_mat(Color("9fb2c2"), 0.1, 0.1), false)
	_cabinet_it = interact(Vector3(8.4, 1.0, -3.4), "Abrir o armário", _cabinet, "any", 1.0)
	# Bilhetes.
	Build.flat_sprite(geo, "icon_note", Vector3(10.0, 0.03, 1.8), Vector3(-90, 25, 0), 0.03)
	doc(Vector3(10.0, 0.05, 1.8), {"id": "ch7_banho_1", "title": "Bilhete no chão", "style": "hand",
		"body": "Repetir é a chave para o sucesso"}, "Pegar bilhete", "any", 1.1)
	Build.flat_sprite(geo, "icon_note", Vector3(14.3, 0.03, -2.6), Vector3(-90, -40, 0), 0.03)
	doc(Vector3(14.3, 0.05, -2.6), {"id": "ch7_banho_2", "title": "Bilhete molhado", "style": "paper",
		"body": "Minhas palavras são construídas caractere por caractere"}, "Pegar bilhete molhado", "any", 1.1)
	Build.flat_sprite(geo, "icon_note", Vector3(11.5, 0.63, -4.45), Vector3(-90, 10, 0), 0.03)
	doc(Vector3(11.5, 0.65, -4.2), {"id": "ch7_banho_3", "title": "Bilhete sobre a mureta", "style": "hand",
		"body": "Aquele que mais se repete, ele está certo"}, "Pegar bilhete", "any", 1.1)
	_bath_light = Build.omni(geo, Vector3(12.0, 2.8, -0.5), Color("b8d4e0"), 1.0, 8.0, false, true)
	var fl: Flicker = _bath_light.get_child(0)
	fl.amount = 0.5
	fl.speed = 14.0
	Build.box(geo, Vector3(1.2, 0.06, 0.2), Vector3(12.0, 3.0, -0.5), Build.color_mat(Color("dfefff"), 1.5), false)
	Build.motes(geo, Vector3(12, 1.5, -0.8), Vector3(4, 1.5, 3), 30, Color(0.8, 0.9, 1.0, 0.35), "fog", 0.4)


## Luz de uma vela/tocha montada pelo Build (a OmniLight3D filha).
func _light_of(root: Node3D) -> OmniLight3D:
	for c in root.get_children():
		if c is OmniLight3D:
			return c
	return null


## Foto de A e B crianças na parede oeste do quarto (o quarto de infância de B).
func _build_photo() -> void:
	var root := Node3D.new()
	root.position = Vector3(-16.8, 1.65, -10.3)
	root.rotation_degrees.y = 90.0
	geo.add_child(root)
	Build.box(root, Vector3(0.62, 0.5, 0.04), Vector3.ZERO, Build.color_mat(Color("5a4320"), 0.0, 0.5), false)
	Build.box(root, Vector3(0.52, 0.4, 0.045), Vector3(0, 0, 0.004), Build.color_mat(Color("b59c78")), false)
	Build.box(root, Vector3(0.52, 0.14, 0.047), Vector3(0, -0.13, 0.005), Build.color_mat(Color("6d7a4a")), false)
	var tex := Build.sprite_tex("char_a")
	for k in 2:
		var s := Sprite3D.new()
		s.texture = Build.sprite_tex("char_a" if k == 0 else "char_b")
		if s.texture == null:
			s.texture = tex
		s.hframes = 4
		s.vframes = 5
		s.frame = 0
		s.pixel_size = 0.0068
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		s.modulate = Color(1.0, 0.86, 0.66)
		s.position = Vector3(-0.09 + k * 0.18, -0.02, 0.03)
		root.add_child(s)
	# Um risco de sangue atravessa o vidro.
	var cut := Build.box(root, Vector3(0.5, 0.012, 0.05), Vector3(0.02, 0.05, 0.01), Build.color_mat(Color("6a0a0e")), false)
	cut.rotation_degrees.z = -24.0
	doc(Vector3(-16.1, 1.0, -10.3), {
		"id": "ch7_foto",
		"title": "Foto na parede do quarto",
		"style": "paper",
		"body": "Duas crianças na frente desta casa, de mãos dadas, rindo de alguma coisa fora da foto. Uma está sem os dentes da frente.\n\nAtrás, na letra da mãe de %s:\n\n[center][i]\"%s e %s. Não se soltam por nada.\"[/i][/center]\n\nAlguém passou o dedo sujo de sangue no vidro, bem no meio das duas." % [Game.name_b, Game.name_a, Game.name_b],
	}, "Olhar a foto", "any", 1.1)


## Esconderijos: um em cada cômodo e um no saguão.
func _build_hiding() -> void:
	var wood := Build.mat("planks_dark", Color(0.85, 0.75, 0.65), 1.0)
	var door_m := Build.mat("planks_dark", Color(1, 0.9, 0.8), 0.8)
	var knob := Build.color_mat(Color("8a7a50"), 0.0, 0.3)
	var curtain := Build.mat("curtain", Color(0.55, 0.42, 0.45), 1.0)
	# Saguão: armário de casacos na parede oeste, perto da porta de ferro.
	Build.box(geo, Vector3(0.7, 2.4, 1.3), Vector3(-6.5, 1.2, -10.6), wood, true)
	Build.box(geo, Vector3(0.04, 2.2, 0.6), Vector3(-6.13, 1.15, -10.92), door_m, false)
	Build.box(geo, Vector3(0.04, 2.2, 0.6), Vector3(-6.13, 1.15, -10.28), door_m, false)
	Build.box(geo, Vector3(0.05, 0.2, 0.06), Vector3(-6.1, 1.2, -10.6), knob, false)
	hide_spot(Vector3(-5.8, 0, -10.6), "Esconder-se no armário de casacos")
	# Quarto: o guarda-roupa de criança de B, na parede oeste.
	Build.box(geo, Vector3(0.7, 2.2, 1.4), Vector3(-16.45, 1.1, -6.0), wood, true)
	Build.box(geo, Vector3(0.04, 2.0, 0.66), Vector3(-16.08, 1.1, -6.34), door_m, false)
	Build.box(geo, Vector3(0.04, 2.0, 0.66), Vector3(-16.08, 1.1, -5.66), door_m, false)
	Build.box(geo, Vector3(0.05, 0.18, 0.06), Vector3(-16.05, 1.15, -6.0), knob, false)
	hide_spot(Vector3(-15.6, 0, -6.0), "Esconder-se no guarda-roupa")
	# Cozinha: debaixo da mesa (lado oeste, longe do bilhete).
	hide_spot(Vector3(-13.2, 0, -1.0), "Esconder-se debaixo da mesa")
	# Escritório: cortina pesada da janela leste.
	Build.box(geo, Vector3(0.06, 1.4, 1.0), Vector3(16.84, 1.9, -6.0), Build.color_mat(Color("6d8fd0"), 0.5), false)
	Build.box(geo, Vector3(0.1, 0.06, 1.8), Vector3(16.7, 3.05, -6.0), Build.color_mat(Color("2a1c12"), 0.0, 0.5), false)
	for cz in [-6.45, -5.55]:
		Build.box(geo, Vector3(0.16, 3.0, 0.8), Vector3(16.68, 1.5, cz), curtain, false)
	hide_spot(Vector3(16.25, 0, -6.0), "Esconder-se atrás da cortina")
	# Banheiro: cortina da banheira.
	Build.box(geo, Vector3(0.04, 0.04, 2.2), Vector3(15.4, 2.1, -1.0), Build.mat("metal"), false)
	# Cortina puxada para o pé da banheira.
	for k in 3:
		Build.box(geo, Vector3(0.07, 1.6, 0.14), Vector3(15.4 + (k % 2) * 0.05, 1.28, -0.08 + k * 0.1), Build.mat("curtain", Color(0.72, 0.78, 0.8), 1.0), false)
	hide_spot(Vector3(15.0, 0, -0.35), "Esconder-se atrás da cortina da banheira")


## Luzes que apagam quando alguém erra um enigma (a do cômodo do erro primeiro).
func _build_dread() -> void:
	_room_lights[4].append(_bath_light)
	_room_lights[4].append(Build.omni(geo, Vector3(16.2, 2.2, 1.7), Color("9fb8c8"), 0.45, 4.0))
	for n in [1, 2, 3, 4, 0]:
		for l in _room_lights[n]:
			if l:
				dread_light(l, str(n))


## Põe as luzes do cômodo `n` na frente da fila de luzes que o erro apaga.
func _dread_first(n: int) -> void:
	dread_focus(str(n))


func _build_pit() -> void:
	var stone := Build.mat("dungeon_stone", Color(0.8, 0.75, 0.75), 1.5)
	Build.stairs(geo, Vector3(0, -3.2, -17.2), Vector3(0, 0, -12.0), 2.6, 10, stone)
	Build.ground(geo, Rect2(-1.5, -20, 3, 2.9), -3.2, stone, "stone")
	for x in [-1.5, 1.5]:
		Build.box(geo, Vector3(0.3, 6.4, 8.0), Vector3(x, -0.1, -16.1), stone, true)
	Build.box(geo, Vector3(3.3, 6.4, 0.3), Vector3(0, -0.1, -20.0), stone, true)
	_pit_light = Build.omni(geo, Vector3(0, -2.2, -17.5), Color("c0303a"), 0.0, 9.0, false, true)
	_anchors["pit"] = _pit_light
	exit_zone(Vector3(0, -0.6, -14.2), Vector3(2.6, 3.0, 2.2))


# --- Fluxo -------------------------------------------------------------------------

func _begin() -> void:
	zone(Vector3(0, 1, -5.7), Vector3(2.6, 2.4, 0.8), _on_hall_enter)
	if _skip_intro:
		_update_objective()
		return
	await say([
		"Vocês se encontram novamente. Se separar pode ser perigoso.",
		"b: %s. A sua escada também descia para cá?" % Game.name_a,
		"a: Descia. E a porta lá de cima bateu atrás de mim.",
		"b: ...Eu conheço esse lustre. Esse tapete. Esse relógio.",
		"a: Conhece de onde?",
		"b: É a casa da minha família. Eu cresci aqui.",
		"b: Só que aquela porta de ferro nunca existiu. Nem as correntes.",
		"a: Fica perto de mim.",
	])
	objective("Desçam a escadaria até o saguão.")
	hints([
		"Cada cadeado da porta ao norte tem um número romano. Cada cômodo também: Quarto (I), Cozinha (II), Escritório (III), Banheiro (IV).",
		"As pistas de um cômodo às vezes estão em outro. Leiam tudo, anotem num papel e contem um ao outro.",
		"A chave fica com quem a encontrou. Só ela abre o cadeado do mesmo número.",
	])


func _on_hall_enter(_ch: Character) -> void:
	Audio.sfx("whisper_saia", -12.0)
	_update_objective()


func _on_gate_near(ch: Character) -> void:
	if _gate_open:
		return
	await say([
		ch.who + ": Quatro cadeados. I, II, III e IV.",
		ch.who + ": E duas rodas, uma de cada lado da porta. Longe demais uma da outra para uma pessoa só.",
	])


func _update_objective() -> void:
	if _gate_open:
		return
	if _locks_open >= 4:
		objective("Girem as duas rodas ao mesmo tempo: um segura, o outro gira.")
		return
	var keys := 0
	for n in range(1, 5):
		if str(Game.get_flag("ch7_key_%d" % n, "")) != "":
			keys += 1
	objective("Achem as chaves nos quatro cômodos e abram os cadeados. Chaves %d/4 · Cadeados %d/4" % [keys, _locks_open])


func _enter_room(ch: Character, n: int) -> void:
	var nb := Game.name_b
	var lines_b := {
		1: ["b: O meu quarto. De quando eu era criança.", "b: Quem escreveu na minha parede?"],
		2: ["b: A cozinha da minha mãe. Ela contava tudo nesta casa. Até os dardos."],
		3: ["b: O piano do meu pai. Todas as noites, as mesmas notas.", "b: O retrato... não era assim. Ele tinha olhos."],
		4: ["b: A banheira está cheia. Ninguém enche essa banheira há anos.", "b: E a água está vermelha."],
	}
	var lines_a := {
		1: ["a: O quarto de %s. Igual a quando a gente brincava aqui." % nb, "a: Só que alguém escreveu na parede. Em vermelho."],
		2: ["a: A cozinha da mãe de %s. Cheiro de ferrugem." % nb, "a: E de alguma coisa podre na despensa."],
		3: ["a: O escritório do pai de %s. O retrato em cima do piano não tem olhos." % nb],
		4: ["a: O espelho está todo embaçado. A água da banheira está fria.", "a: Fria como o rio."],
	}
	await say(lines_b[n] if ch.who == "b" else lines_a[n])


func _open_room(_ch: Character, n: int) -> void:
	var door: Door = _room_doors[n]
	if door.is_open:
		return
	(_room_its[n] as Interactable).disable()
	door.open(100.0, 1.3)


# --- Cômodos -----------------------------------------------------------------------

func _wardrobe(ch: Character) -> void:
	var lock := CodeLock.new("Armário do quarto", ["SILENCIO"],
		"Um cadeado de letras prende as portas do armário. Oito letras.", [
			"As letras da parede do quarto parecem não formar nada. Na geladeira da cozinha, alguém fala de um tal César.",
			"Cifra de César: cada letra andou 3 casas para frente no alfabeto. Volte 3 casas: V vira S, L vira I.",
			"VLOHQFLR voltando 3 casas: SILENCIO.",
		])
	lock.max_len = 8
	lock.placeholder = "8 letras"
	_dread_first(1)
	if await puzzle(lock):
		_wardrobe_it.disable()
		_swing(_wardrobe_door, "rotation_degrees:y", 110.0)
		_key_fx(Vector3(-8.7, 1.4, -10.9))
		var line := "As minhas roupas de criança... e uma chave com o número I." if ch.who == "b" else "Roupas de criança de %s. E, no meio delas, uma chave com o número I." % Game.name_b
		await _give_key(ch, 1, line)


func _pantry(ch: Character) -> void:
	var lock := CodeLock.new("Despensa", ["42"],
		"A porta da despensa tem um cadeado de números.", [
			"O alvo de dardos da cozinha tem setores vermelhos e pretos.",
			"\"Mamãe só contava os dardos no vermelho\": 17, 6 e 19. Os do preto (20 e 3) não contam.",
			"17 + 6 + 19 = 42.",
		])
	lock.keypad = "0123456789"
	lock.max_len = 3
	lock.placeholder = "número"
	_dread_first(2)
	if await puzzle(lock):
		_pantry_it.disable()
		_swing(_pantry_door, "rotation_degrees:y", -105.0)
		Audio.sfx("drip", -6.0)
		_key_fx(Vector3(-15.6, 1.4, 1.9))
		await _give_key(ch, 2, "Potes vazios, cheiro de mofo... e uma chave com o número II.")


func _dartboard(_ch: Character) -> void:
	Audio.sfx("dart_thud", -6.0)
	await Ui.open_panel(DartboardView.new(DARTS))


func _piano(ch: Character) -> void:
	var p := PianoPanel.new("O piano do escritório", PIANO_SEQ,
		"As teclas estão amareladas. Algumas estão manchadas de vermelho.", [
			"Na carta do pai, cada letra é uma nota: C D E F G A B = DÓ RÉ MI FÁ SOL LÁ SI.",
			"O bilhete sob o travesseiro do quarto tem palavras com maiúscula fora do lugar: Dó, Sol, Lá, Fa.",
			"Toque C, G, A, F.",
		])
	_dread_first(3)
	if await puzzle(p):
		_piano_it.disable()
		Audio.sfx("key_pickup", -8.0)
		_key_fx(Vector3(12.5, 1.3, -11.0))
		await _give_key(ch, 3, "Alguma coisa caiu dentro do piano. Uma chave com o número III.")


func _mirror(ch: Character) -> void:
	Audio.sfx("glass_squeak", -8.0)
	await Ui.open_panel(MirrorView.new(MIRROR_WORDS))
	if not Game.get_flag("ch7_scare"):
		Game.set_flag("ch7_scare")
		await _scare(ch)


func _cabinet(ch: Character) -> void:
	var lock := CodeLock.new("Armário do banheiro", ["ACORDE"],
		"Seis letras riscadas na porta do armário, e um cadeado de letras.", [
			"O espelho embaçado escreve palavras, uma letra de cada vez. Algumas se repetem.",
			"\"Aquele que mais se repete, ele está certo.\" Contem quantas vezes cada palavra aparece.",
			"ACORDE aparece sete vezes: ACORDE.",
		])
	lock.max_len = 6
	lock.placeholder = "6 letras"
	_dread_first(4)
	if await puzzle(lock):
		_cabinet_it.disable()
		_swing(_cabinet_door, "rotation_degrees:y", 100.0)
		_key_fx(Vector3(8.0, 1.4, -3.4))
		await _give_key(ch, 4, "Remédios vencidos. Atrás deles, uma chave com o número IV.")


func _swing(n: Node3D, prop: String, to: float) -> void:
	Audio.sfx_at("door_open", n, -6.0)
	create_tween().tween_property(n, prop, to, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _key_fx(pos: Vector3) -> void:
	var s := Build.billboard(geo, "icon_key", pos, 0.03, 1, 0, Color(1.4, 1.25, 0.9), false)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.transparent = true
	var t := create_tween().set_parallel()
	t.tween_property(s, "position:y", pos.y + 0.8, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(s, "modulate:a", 0.0, 1.4).set_delay(0.4)
	t.chain().tween_callback(s.queue_free)


func _give_key(ch: Character, n: int, line: String) -> void:
	Game.set_flag("ch7_key_%d" % n, ch.who)
	Audio.sfx("key_pickup", -2.0)
	Game.add_doc(ch.who, {
		"id": "ch7_chave_%d" % n,
		"title": "Chave %s" % ROMAN[n],
		"style": "paper",
		"body": "Uma chave de ferro com o número %s gravado no cabo.\n\nAbre o cadeado %s da porta do subterrâneo." % [ROMAN[n], ROMAN[n]],
	})
	Ui.toast("%s pegou a chave %s." % [Game.char_name(ch.who), ROMAN[n]])
	_update_objective()
	await say([ch.who + ": " + line])
	if not _patrol_started:
		await _wake_forgotten(ch)


## Susto (uma vez), depois do espelho: a voz que imita B pede para A não acordar e,
## por um instante, o Esquecido aparece na porta do banheiro.
func _scare(ch: Character) -> void:
	Game.lock_input()
	var m := Build.billboard(geo, "forgotten", Vector3(8.1, 0, -0.75), 0.029, 4, 0, Color(0.6, 0.58, 0.66))
	m.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.offset = Vector2(0, 40)
	m.visible = false
	Audio.sfx("heartbeat", -8.0)
	Audio.sfx("glass_squeak", -6.0, 0.7)
	await get_tree().create_timer(0.6).timeout
	var fake: Array = [
		"O vapor do espelho se mexe sozinho. Uma voz sai lá de dentro.",
		"x: %s. Não precisa acordar." % Game.name_a,
		"x: Fica aqui comigo. Dorme mais um pouco. Lá fora dói.",
	]
	if ch.who == "a":
		fake.append("a: %s? De onde você está falando?" % Game.name_b)
	else:
		fake.append("b: ...essa é a minha voz. Eu não disse isso.")
		fake.append("b: Eu nunca pediria isso a %s." % Game.name_a)
	await say(fake)
	_bath_light.visible = false
	Audio.sfx("light_out", -8.0)
	await get_tree().create_timer(0.15).timeout
	_bath_light.visible = true
	m.visible = true
	Audio.sfx("dread_sting", -4.0)
	Audio.sfx("breath", -4.0)
	cam.shake(0.15)
	await get_tree().create_timer(0.6).timeout
	_bath_light.visible = false
	await get_tree().create_timer(0.12).timeout
	m.queue_free()
	_bath_light.visible = true
	Game.unlock_input()
	await say([
		ch.who + ": ...tinha alguém na porta. Com a mão no rosto.",
		ch.who + ": Não. Não tem ninguém. Foco.",
	])
	# A voz falsa falou com A: B desmente quando os dois se encontrarem.
	_fake_pending = ch.who == "a"


## B de verdade nega ter falado pelo espelho (quando A e B ficam perto de novo).
func _deny_fake() -> void:
	_fake_pending = false
	await say([
		"a: %s. Você falou comigo pelo espelho do banheiro?" % Game.name_b,
		"b: Espelho? Eu não falei nada. Nem passei perto do banheiro.",
		"a: Era a sua voz. Pedindo para eu não acordar.",
		"b: Então não era eu. Eu nunca te pediria isso. Nunca.",
	])


# --- Porta do subterrâneo ------------------------------------------------------------

func _try_lock(ch: Character, n: int) -> void:
	if _lock_open[n] or _busy_scene:
		return
	var holder := str(Game.get_flag("ch7_key_%d" % n, ""))
	var lock: Node3D = _locks[n]
	if holder == "":
		Audio.sfx_at("door_locked", lock, -4.0)
		_wobble(lock)
		await say([ch.who + ": O cadeado %s não cede. Preciso da chave %s." % [ROMAN[n], ROMAN[n]]])
		return
	if holder != ch.who:
		_wobble(lock)
		await say([ch.who + ": A chave %s está com %s." % [ROMAN[n], Game.char_name(holder)]])
		return
	_lock_open[n] = true
	_locks_open += 1
	(_lock_its[n] as Interactable).disable()
	Audio.sfx_at("lock_open", lock, 0.0)
	var t := create_tween().set_parallel()
	t.tween_property(lock, "position:y", 0.06, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(lock, "position:z", -11.35, 0.5)
	t.tween_property(lock, "rotation_degrees:x", -88.0, 0.5)
	_update_objective()
	# Ponto seguro: diante da porta de ferro (a patrulha recomeça longe daqui).
	set_checkpoint(Vector3(-1.3, 0, -10.3), Vector3(1.3, 0, -10.3))
	if _locks_open == 1:
		bleed(["Leito %d teve uma parada às três. Conseguimos reverter." % Game.number_b])
	if _locks_open < 4:
		Ui.toast("Cadeado %s aberto. (%d/4)" % [ROMAN[n], _locks_open])
		return
	_busy_scene = true
	await t.finished
	await _stop_patrol()
	await get_tree().create_timer(0.4).timeout
	Audio.sfx("chain_rattle", -2.0)
	var tc := create_tween().set_parallel()
	tc.tween_property(_chains, "position:y", -1.45, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tc.tween_property(_chains, "position:z", 0.5, 0.6)
	cam.shake(0.25)
	await tc.finished
	_busy_scene = false
	var chain_lines := [
		ch.who + ": As correntes caíram. Mas a porta continua presa.",
		ch.who + ": As rodas dos lados... devem puxar as trancas. Mas estão longe demais uma da outra.",
	]
	if _patrol_started:
		chain_lines.append("b: E os passos pararam. Aquilo sumiu.")
		chain_lines.append("a: Ou está esperando alguém ficar parado.")
	await say(chain_lines)
	_update_objective()
	hints([
		"As duas rodas precisam girar ao mesmo tempo. Uma pessoa só não alcança as duas.",
		"Um de vocês segura uma roda enquanto o outro gira a outra. Não demorem: quem fica parado na roda sem ninguém por perto é caçado.",
		"Interaja com uma roda para segurá-la, troque de personagem e gire a roda do outro lado.",
	])
	# Quem segura uma roda sozinho, esperando, é caçado.
	lonely_watch(_wheel_victim, 30.0, _wheel_caught)


func _wobble(n: Node3D) -> void:
	var t := create_tween()
	t.tween_property(n, "rotation:z", 0.14, 0.05)
	t.tween_property(n, "rotation:z", -0.1, 0.06)
	t.tween_property(n, "rotation:z", 0.0, 0.05)


func _wheel(ch: Character, side: String) -> void:
	if _gate_open or _busy_scene:
		return
	var w: Dictionary = _wheels[side]
	var spin: Node3D = w["spin"]
	if _locks_open < 4:
		Audio.sfx_at("chain_rattle", spin, -6.0)
		_wobble(spin)
		await say([ch.who + ": A roda nem se mexe. As correntes dos cadeados travam tudo."])
		return
	if w["holder"] == ch.who:
		_release(side)
		Ui.toast("%s soltou a roda." % Game.char_name(ch.who))
		return
	if w["holder"] != "":
		await say([ch.who + ": %s já está segurando esta. A outra roda fica do outro lado da porta." % Game.char_name(w["holder"])])
		return
	var other_side := "R" if side == "L" else "L"
	var partner := party.other(ch)
	if _wheels[other_side]["holder"] == partner.who:
		await _turn_both(ch, side)
		return
	# Sozinho: tenta girar e a roda volta. Fica segurando.
	_busy_scene = true
	await ch.walk_to(Vector3(w["x"], 0, WHEEL_STAND_Z))
	ch.face("up")
	Audio.sfx_at("wheel_click", spin, -2.0)
	var t := create_tween()
	t.tween_property(spin, "rotation:z", -0.9, 0.55).set_trans(Tween.TRANS_SINE)
	t.tween_property(spin, "rotation:z", 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await t.finished
	Audio.sfx_at("stone_grind", spin, -12.0)
	await say([ch.who + ": A roda volta sozinha. Precisa de alguém do outro lado."])
	w["holder"] = ch.who
	(w["it"] as Interactable).prompt = "Soltar a roda"
	_busy_scene = false
	Ui.toast("%s segura a roda. [%s] troca para %s." % [Game.char_name(ch.who), Ui.key_label("switch"), Game.char_name(partner.who)])


func _release(side: String) -> void:
	var w: Dictionary = _wheels[side]
	w["holder"] = ""
	(w["it"] as Interactable).prompt = "Girar a roda"


func _physics_process(delta: float) -> void:
	super(delta)
	if party == null or _finishing:
		return
	_watch_patrol()
	if _gate_open or _busy_scene:
		return
	for side in _wheels:
		var w: Dictionary = _wheels[side]
		if w["holder"] == "":
			continue
		var c := party.get_char(w["holder"])
		var d := Vector2(c.global_position.x - float(w["x"]), c.global_position.z - WHEEL_STAND_Z).length()
		if d > 0.9:
			_release(side)
			Ui.toast("%s soltou a roda." % Game.char_name(c.who))


## Quem segura uma roda enquanto a outra está livre (fica parado, esperando).
func _wheel_victim() -> Variant:
	if _gate_open or _busy_scene:
		return null
	var held := []
	for side in _wheels:
		if _wheels[side]["holder"] != "":
			held.append(_wheels[side]["holder"])
	if held.size() == 1:
		return party.get_char(held[0])
	return null


## O Esquecido alcançou quem segurava a roda: a roda escapa e a vítima recua.
func _wheel_caught(ch: Character) -> void:
	for side in _wheels:
		if _wheels[side]["holder"] == ch.who:
			_release(side)
			var spin: Node3D = _wheels[side]["spin"]
			create_tween().tween_property(spin, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE)
	ch.teleport(ch.global_position + Vector3(0, 0, 1.4))


func _turn_both(ch: Character, side: String) -> void:
	_gate_open = true
	_busy_scene = true
	Game.lock_input()
	stop_lonely_watch()
	_patrol_on = false
	if stalker and stalker.is_active():
		stalker.vanish(0.4)
	await ch.walk_to(Vector3(_wheels[side]["x"], 0, WHEEL_STAND_Z))
	ch.face("up")
	for s in _wheels:
		(_wheels[s]["it"] as Interactable).disable()
	await cam.look_at_point(Vector3(0, 1.4, -10.5), 1.0)
	await say(["a: No três. Um... dois... três!"])
	Audio.sfx("stone_grind", -2.0)
	var t := create_tween().set_parallel()
	t.tween_property(_wheels["L"]["spin"], "rotation:z", TAU * 1.5, 2.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(_wheels["R"]["spin"], "rotation:z", -TAU * 1.5, 2.6).set_trans(Tween.TRANS_SINE)
	for k in 6:
		get_tree().create_timer(k * 0.42).timeout.connect(func(): Audio.sfx("wheel_click", -4.0, 0.8 + k * 0.06))
	cam.shake(0.3)
	await t.finished
	Audio.sfx("gate_open", 0.0)
	_gate_l.open(100.0, 2.4)
	_gate_r.open(-100.0, 2.4)
	var fl: Flicker = _pit_light.get_child(0)
	create_tween().tween_property(fl, "base", 1.6, 2.5)
	Audio.sfx("wind_gust", -4.0)
	cam.shake(0.4)
	await get_tree().create_timer(2.6).timeout
	Audio.sfx_at("whisper_saia", _pit_light, -2.0, 30.0)
	for s in _wheels:
		_wheels[s]["holder"] = ""
	cam.target = party.active
	Game.unlock_input()
	_busy_scene = false
	await say([
		"b: Abriu. Tem uma escada descendo.",
		"a: Está gelado lá embaixo. E tem uma luz vermelha no fundo.",
		"?: ...SAIA!",
		"a: Essa voz... é a sua, %s." % Game.name_b,
		"b: Eu sei. Eu não lembro de ter gritado isso. Nunca.",
		"b: Vem. A gente desce lado a lado.",
	])
	objective("Desçam ao subterrâneo, lado a lado.")
	hints([
		"A escada do subterrâneo fica atrás da porta de ferro, ao norte.",
		"Ninguém desce só: %s e %s precisam chegar à escada." % [Game.name_a, Game.name_b],
		"Leve %s e %s até a escada atrás da porta." % [Game.name_a, Game.name_b],
	])


# --- O Esquecido -------------------------------------------------------------------

## Primeira chave: todas as portas se abrem e o Esquecido começa a andar pela casa.
func _wake_forgotten(_ch: Character) -> void:
	_patrol_started = true
	Game.lock_input()
	var s := spawn_stalker()
	s.sight = 7.0
	set_checkpoint(LANDING_A, LANDING_B)
	# O lustre apaga; as quatro portas batem abertas de uma vez.
	_lustre_light.visible = false
	Audio.sfx("light_out", -2.0)
	Audio.sfx("chain_rattle", -2.0)
	await get_tree().create_timer(0.5).timeout
	for n in _room_doors:
		(_room_its[n] as Interactable).disable()
		var door: Door = _room_doors[n]
		if not door.is_open:
			door.open(100.0, 0.35)
	cam.shake(0.5)
	s.appear(Vector3(0, 0, -10.6), 0.0)
	await get_tree().create_timer(0.7).timeout
	_lustre_light.visible = true
	Audio.sfx("dread_sting", -2.0)
	await cam.look_at_point(Vector3(0, 1.4, -10.2), 1.0)
	await say([
		"Todas as portas da casa se abrem ao mesmo tempo.",
		"Diante da porta de ferro, alguém. Alto. Encharcado. A mão cobrindo o rosto.",
		"b: Esse moletom... é igual ao seu, %s." % Game.name_a,
		"a: Está andando. Está vindo para dentro da casa.",
		"b: Esconde. Armário, cortina, debaixo da mesa. Qualquer lugar.",
		"a: E se aquilo achar a gente?",
		"b: Corre.",
	])
	cam.target = party.active
	# Ninguém é pego de graça: se alguém está perto da porta, aquilo recomeça longe.
	var near := false
	for c in [party.a, party.b]:
		if c.global_position.distance_to(s.global_position) < 8.0:
			near = true
	if near:
		await s.vanish(0.5)
		s.patrol(PATROL, _far_index([party.a.global_position, party.b.global_position]))
	else:
		s.patrol(PATROL, 0)
	_patrol_on = true
	Game.unlock_input()
	Ui.toast("Aquilo patrulha a casa. Escondam-se (%s) quando passar." % Ui.key_label("interact"), UiTheme.BLOOD)
	hints([
		"Aquilo anda pelo saguão e entra nos cômodos. Só enxerga para a frente, paredes bloqueiam a visão e, correndo, dá para fugir.",
		"Cada cômodo tem um esconderijo: o guarda-roupa do quarto, debaixo da mesa da cozinha, a cortina do escritório, a cortina da banheira. No saguão, o armário de casacos perto da porta de ferro.",
		"Esconda também quem não está jogando: parado no caminho, é alcançado. Cada chave abre o cadeado do mesmo número, e só quem a pegou pode usá-la.",
	])


## Ponto da rota mais longe de todos os pontos dados.
func _far_index(points: Array) -> int:
	var best := 0
	var best_d := -1.0
	for i in PATROL.size():
		var d := INF
		for p in points:
			d = minf(d, Vector2(PATROL[i].x - p.x, PATROL[i].z - p.z).length())
		if d > best_d:
			best_d = d
			best = i
	return best


func _stop_patrol() -> void:
	_patrol_on = false
	if stalker == null or not stalker.is_active():
		return
	Audio.sfx("whisper_many", -8.0)
	await stalker.vanish(1.2)


## Depois de alguém ser pego: a patrulha recomeça no ponto mais longe do ponto seguro.
func _caught(_ch: Character) -> void:
	if stalker == null:
		return
	if not _patrol_on:
		stalker.vanish(0.0)
		return
	var i := _far_index([checkpoint_a, checkpoint_b])
	stalker.global_position = PATROL[i]
	stalker.patrol(PATROL, (i + 1) % PATROL.size())


## Avisa quando aquilo enxerga quem está parado (o personagem que não está sendo
## jogado) e faz B desmentir a voz do espelho.
func _watch_patrol() -> void:
	if not Game.can_control() or _catching:
		return
	if _fake_pending and party.a.global_position.distance_to(party.b.global_position) < 2.6:
		_deny_fake()
		return
	if not _patrol_on or stalker == null:
		return
	if stalker.state == Stalker.CHASE and stalker.target != null and stalker.target != party.active:
		if not _chase_warned:
			_chase_warned = true
			Ui.toast("Aquilo viu %s! [%s] troca e foge." % [Game.char_name(stalker.target.who), Ui.key_label("switch")], UiTheme.BLOOD)
	elif stalker.state != Stalker.CHASE:
		_chase_warned = false


# --- Sons de ambiente --------------------------------------------------------------

func _process(delta: float) -> void:
	if not Ui.in_level:
		return
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = 1.0
		Audio.sfx_at("clock_tick", _anchors["clock"], -18.0, 9.0)
	_amb_t -= delta
	if _amb_t <= 0.0:
		_amb_t = rng.randf_range(9.0, 17.0)
		var pick := rng.randi_range(0, 4)
		match pick:
			0:
				Audio.sfx_at("drip", _anchors["tub"], -2.0, 14.0)
			1:
				Audio.sfx_at("wind_gust", _anchors["window"], -8.0, 20.0)
			2:
				Audio.sfx_at("chain_rattle", _anchors["gate"], -14.0, 20.0)
			3:
				Audio.sfx_at("monster_growl", _anchors["pit"], -20.0, 25.0)
			_:
				Audio.sfx("breath", -22.0)


# --- Depuração (tools/shot.sh --call=...) ----------------------------------------------

func _debug_skip() -> void:
	_skip_intro = true


func _debug_doors() -> void:
	_skip_intro = true
	for n in _room_doors:
		(_room_doors[n] as Door).open(100.0, 0.05)


func _debug_gate() -> void:
	_skip_intro = true
	for n in range(1, 5):
		Game.set_flag("ch7_key_%d" % n, "a")
	_locks_open = 4
	for n in range(1, 5):
		_lock_open[n] = true
		(_locks[n] as Node3D).position = Vector3(LOCK_X[n], 0.06, -11.35)
		(_locks[n] as Node3D).rotation_degrees.x = -88.0
	_chains.position = Vector3(0, -1.45, 0.5)
	_gate_open = true
	_gate_l.open(100.0, 0.05)
	_gate_r.open(-100.0, 0.05)
	_pit_light.light_energy = 1.6
	(_pit_light.get_child(0) as Flicker).base = 1.6


func _debug_doc_pai() -> void:
	_skip_intro = true
	Ui.read_doc("a", DOC_PAI)


func _debug_mirror() -> void:
	_skip_intro = true
	Ui.open_panel(MirrorView.new(MIRROR_WORDS))


## Portas abertas e o Esquecido já patrulhando (sem a cena da primeira chave).
func _debug_patrol() -> void:
	_skip_intro = true
	for n in _room_doors:
		(_room_doors[n] as Door).open(100.0, 0.05)
		(_room_its[n] as Interactable).disable()
	var s := spawn_stalker()
	s.sight = 7.0
	_patrol_started = true
	_patrol_on = true
	s.patrol(PATROL, 0)


## O Esquecido entrando no quarto, com A no saguão (captura de tela).
func _debug_patrol_shot() -> void:
	_debug_patrol()
	stalker.hunting = false
	stalker.walk_speed = 0.3
	stalker.global_position = Vector3(-3.6, 0, -8.3)
	stalker.patrol(PATROL, 1)
	party.a.teleport(Vector3(0.6, 0, -6.4))
	cam.snap()


## Confere a rota: roda uma volta inteira sem perseguir ninguém e diz que pontos alcançou.
func _debug_patrol_check() -> void:
	_debug_patrol()
	party.a.teleport(LANDING_A)
	party.b.teleport(LANDING_B)
	stalker.hunting = false
	var best := []
	for p in PATROL:
		best.append(INF)
	var t := 0.0
	var moved := 0.0
	var last := stalker.global_position
	while t < 95.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		if Game.can_control():
			t += dt
		var p := stalker.global_position
		moved += Vector2(p.x - last.x, p.z - last.z).length()
		last = p
		for i in PATROL.size():
			best[i] = minf(best[i], Vector2(p.x - PATROL[i].x, p.z - PATROL[i].z).length())
	var missed := []
	for i in PATROL.size():
		if best[i] > 0.5:
			missed.append("%d(%.2f)" % [i, best[i]])
	print("PATROL_CHECK andou %.1f m em %.0f s; y=%.2f; pontos não alcançados: %s" % [moved, t, stalker.global_position.y, str(missed)])


func _debug_memory() -> void:
	_skip_intro = true
	party.activate("a", true)
	party.a.teleport(Vector3(14.9, 0, -1.9))
	cam.snap()

