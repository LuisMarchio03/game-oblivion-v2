extends LevelBase
## Capítulo 3 — A Capela. Cheira a álcool e remédio, como um corredor de hospital.
## 1) Grade levadiça: só sobe enquanto alguém pisa na placa. Um segura, o outro
##    passa e, do outro lado, puxa a alavanca que trava a grade aberta.
##    Quem fica na placa, longe do parceiro, é caçado (`lonely_watch`, ~30 s): sussurros,
##    o Esquecido surge atrás e, se alcança, empurra a vítima para fora da placa e a
##    grade cai (a menos que já esteja travada).
## 2) Confessionário: relógio de bolso parado em 3:15 e o bilhete "atrasou uma hora".
##    B reconhece o relógio: era do avô de B. Quando A chega perto, a voz falsa de B sai
##    do confessionário pedindo para não acertar o relógio; depois, B nega ter falado.
## 3) Console do relógio da torre no altar: 4:15 (errar apaga as velas do altar). Voz do
##    hospital com a hora do acidente. O altar se abre, o espelho mostra a mão de sangue,
##    os números e, por um instante, três figuras no reflexo. Saída pelos fundos.
## Lembrança m3 ("Os comprimidos"): atrás da estátua no canto noroeste, junto de um frasco caído.

const NAVE := Rect2(-8, -16, 16, 25)
const GRADE_Z := 0.0
const GRADE_W := 3.0
const ALTAR := Vector3(0, 0, -13.0)
const MIRROR := Vector3(0, 2.35, -15.72)
const BACK_DOOR := Vector3(5.5, 0, -16)
const BLOOD := Color("9a0f16")
const PLATE := Vector3(-3.4, 0, 2.2)
const MEMORY := Vector3(-6.3, 0, -15.1)
const WATCH_DOC := {
	"id": "ch3_relogio",
	"title": "Relógio de bolso",
	"body": "[center]Prata escurecida. O vidro está rachado.\nOs ponteiros não se mexem.\n\n[font_size=96]3:15[/font_size][/center]",
	"style": "sign",
}

var _grade: Mover
var _plate: PressurePlate
var _lever: Lever
var _lever_it: Interactable
var _console_it: Interactable
var _back_door: Door
var _back_it: Interactable
var _altar_l: Mover
var _altar_r: Mover
var _altar_light: OmniLight3D
var _mirror_light: OmniLight3D
var _hand: Decal
var _numbers: Label3D
var _locked := false
var _solved := false
var _bars: Array[Transform3D] = []
var _spikes: Array[Transform3D] = []
var _fake_done := false
var _watch_a := false
var _watch_b := false
var _refl_a: Sprite3D
var _refl_b: Sprite3D
var _refl_third: Sprite3D


func _init() -> void:
	chapter_index = 2
	preset = "chapel"
	ambience = "amb_house"
	spawn_a = Vector3(-1.3, 0, 6.2)
	spawn_b = Vector3(1.3, 0, 6.2)
	cam_bounds = Rect2(-3, -13, 6, 20)


func _build() -> void:
	var floor_mat := Build.mat("stone_path", Color(0.72, 0.72, 0.78), 2.0)
	var wall_mat := Build.mat("stone_wall", Color(0.72, 0.72, 0.8), 2.0)
	var ceil := Build.mat("ceiling_wood")
	var back_at := BACK_DOOR.x - NAVE.position.x
	Build.room(geo, NAVE, 0.0, 5.0, floor_mat, wall_mat, [{"side": "n", "at": back_at, "width": 1.4}], ceil, "stone", false)
	# Tapete vermelho no corredor central.
	Build.box(geo, Vector3(1.6, 0.02, 22.0), Vector3(0, 0.01, -3.2), Build.mat("carpet_red", Color(0.8, 0.75, 0.75), 1.0), false)
	# Limites (a parede sul é baixa, só para a câmera enxergar).
	Build.blocker(geo, Vector3(18, 4, 1), Vector3(0, 2, NAVE.end.y + 0.3))
	# Pilastras nas paredes laterais.
	var pil := Build.mat("stone_wall", Color(0.62, 0.62, 0.7), 1.5)
	for z in [4.0, -1.5, -5.8, -10.2, -14.6]:
		for x in [NAVE.position.x + 0.3, NAVE.end.x - 0.3]:
			Build.box(geo, Vector3(0.6, 5.0, 0.7), Vector3(x, 2.5, z), pil, true)

	_build_grade()
	_build_pews()
	_build_confessional()
	_build_altar()
	_build_windows()
	_build_decor()
	_finish_multimeshes()

	# Porta dos fundos (sacristia) e o corredor escuro atrás dela.
	Build.ground(geo, Rect2(BACK_DOOR.x - 1.6, -20, 3.2, 4.0), 0.0, Build.mat("planks_dark", Color(0.5, 0.5, 0.55)), "wood")
	Build.box(geo, Vector3(0.3, 4, 4), Vector3(BACK_DOOR.x - 1.7, 2, -18), wall_mat, true)
	Build.box(geo, Vector3(0.3, 4, 4), Vector3(BACK_DOOR.x + 1.7, 2, -18), wall_mat, true)
	Build.box(geo, Vector3(3.6, 4, 0.3), Vector3(BACK_DOOR.x, 2, -20), wall_mat, true)
	_back_door = Build.door(geo, BACK_DOOR, 0.0, Build.mat("planks_dark", Color(0.85, 0.8, 0.75), 1.0))
	_back_it = interact(BACK_DOOR + Vector3(0, 0.5, 0.9), "Abrir a porta dos fundos", func(ch: Character):
		_back_door.rattle()
		await say([ch.who + ": Trancada. O trinco está preso a uma haste de ferro que desce até o altar."]), "any", 1.2, true, 2.0)
	exit_zone(Vector3(BACK_DOOR.x, 1, -17.2), Vector3(3, 2, 2.6), true, "Não saio sem %s.")


# --- Grade levadiça, placa e alavanca -------------------------------------------------

func _build_grade() -> void:
	var stone := Build.mat("stone_wall", Color(0.62, 0.62, 0.7), 1.5)
	var iron := Build.color_mat(Color("23262b"), 0.0, 0.35)
	var half := GRADE_W / 2.0
	# Anteparo de ferro (vê-se através dele) dos dois lados da grade.
	_fence(Vector3(NAVE.position.x + 0.15, 0, GRADE_Z), Vector3(-half - 0.35, 0, GRADE_Z))
	_fence(Vector3(half + 0.35, 0, GRADE_Z), Vector3(NAVE.end.x - 0.15, 0, GRADE_Z))
	# Pilares e verga de pedra do vão.
	for x in [-half - 0.2, half + 0.2]:
		Build.box(geo, Vector3(0.45, 3.2, 0.6), Vector3(x, 1.6, GRADE_Z), stone, true)
	Build.box(geo, Vector3(GRADE_W + 0.9, 0.5, 0.6), Vector3(0, 3.35, GRADE_Z), stone, false)
	Build.text3d(geo, "MEMENTO MORI", Vector3(0, 3.35, GRADE_Z + 0.31), 0.0, 44, Color("c9c2b0"))
	# A grade: corpo invisível + barras filhas (sobem juntas).
	_grade = Build.mover(geo, Vector3(GRADE_W, 2.9, 0.14), Vector3(0, 1.45, GRADE_Z), Vector3(0, 2.4, 0), Build.color_mat(Color(0, 0, 0, 0)))
	_grade.time = 0.9
	_grade.sound = "chain_rattle"
	var n := 11
	for i in n:
		var x := -half + 0.1 + (GRADE_W - 0.2) * i / float(n - 1)
		Build.box(_grade, Vector3(0.06, 2.9, 0.06), Vector3(x, 0, 0), iron, false)
		var tip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.0
		cm.height = 0.18
		cm.radial_segments = 4
		tip.mesh = cm
		tip.material_override = iron
		tip.position = Vector3(x, -1.5, 0)
		_grade.add_child(tip)
	for y in [-0.9, 0.2, 1.3]:
		Build.box(_grade, Vector3(GRADE_W - 0.1, 0.08, 0.08), Vector3(0, y, 0), iron, false)
	# Correntes que sobem até o teto.
	for x in [-half + 0.2, half - 0.2]:
		Build.box(geo, Vector3(0.04, 1.4, 0.04), Vector3(x, 4.3, GRADE_Z - 0.1), Build.color_mat(Color("555a60"), 0.0, 0.3), false)

	# Placa de pressão (lado da entrada).
	_plate = plate(PLATE, Vector2(1.2, 1.2))
	_plate.changed.connect(_on_plate)
	Build.box(geo, Vector3(0.05, 0.02, 2.0), Vector3(-2.2, 0.012, 1.2), iron, false, 30.0)
	# Alavanca (lado do altar).
	_lever = Build.lever(geo, Vector3(3.2, 0, -1.5), Color("8a6a2a"))
	_lever_it = interact(Vector3(3.2, 0.5, -2.0), "Puxar a alavanca", _pull_lever, "any", 1.0, true, 1.6)


func _on_plate(pressed: bool) -> void:
	if _locked:
		return
	if pressed:
		_grade.set_open(true)
		if not Game.get_flag("ch3_plate"):
			Game.set_flag("ch3_plate")
			await get_tree().create_timer(0.9).timeout
			await say(["A grade sobe, rangendo, enquanto a placa está afundada."])
	else:
		_close_when_clear()


func _close_when_clear() -> void:
	# Não desce em cima de ninguém.
	while not _locked and not _plate.pressed and _someone_under_grade():
		await get_tree().physics_frame
	if not _locked and not _plate.pressed:
		_grade.set_open(false)


func _someone_under_grade() -> bool:
	for ch in [party.a, party.b]:
		var p: Vector3 = ch.global_position
		if abs(p.x) < GRADE_W / 2.0 + 0.4 and abs(p.z - GRADE_Z) < 0.75:
			return true
	return false


func _pull_lever(ch: Character) -> void:
	if _locked:
		return
	_lock_grade()
	await get_tree().create_timer(0.5).timeout
	await say([
		"Um trinco de ferro estala. A grade fica presa lá em cima.",
		ch.who + ": Travou. Pode sair da placa. Vem para perto.",
	])
	objective("Descubram como abrir o altar.")
	hints([
		"O confessionário, à direita, guarda um relógio de bolso e um bilhete.",
		"O relógio parou em 3:15, mas o dono diz que ele sempre atrasou uma hora.",
		"Acerte o relógio da torre, no console do altar, em 4:15.",
	])


func _lock_grade() -> void:
	_locked = true
	stop_lonely_watch()
	_lever_it.disable()
	_lever.set_down(true)
	_grade.set_open(true)
	Audio.sfx_at("lock_open", _lever, -2.0)


# --- Bancos ------------------------------------------------------------------------------

func _build_pews() -> void:
	var wood := Build.mat("planks_dark", Color(0.85, 0.75, 0.65), 1.0)
	for z in [-3.6, -5.3, -7.0, -8.7]:
		for cx in [-2.9, 2.9]:
			_pew(Vector3(cx, 0, z), 2.8, wood)
	# Bancos quebrados/tombados na entrada.
	var b := Build.box(geo, Vector3(2.2, 0.1, 0.45), Vector3(4.6, 0.3, 5.6), wood, true, 18.0)
	b.rotation_degrees.z = 12
	_pew(Vector3(-4.9, 0, 4.4), 2.2, wood)


func _pew(pos: Vector3, width: float, wood: Material) -> void:
	Build.box(geo, Vector3(width, 0.08, 0.5), pos + Vector3(0, 0.46, 0), wood, true)
	Build.box(geo, Vector3(width, 0.6, 0.07), pos + Vector3(0, 0.8, 0.26), wood, false)
	for dx in [-width / 2.0 + 0.08, width / 2.0 - 0.08]:
		Build.box(geo, Vector3(0.08, 0.9, 0.55), pos + Vector3(dx, 0.45, 0.02), wood, false)
	Build.blocker(geo, Vector3(width, 1.0, 0.65), pos + Vector3(0, 0.5, 0.05))


# --- Confessionário -------------------------------------------------------------------

func _build_confessional() -> void:
	var wood := Build.mat("wood_wall", Color(0.7, 0.55, 0.45), 1.0)
	var dark := Build.mat("planks_dark", Color(0.7, 0.6, 0.55), 1.0)
	var cx := 6.85
	var cz := -6.8
	# Caixa de madeira encostada na parede leste, aberta para oeste.
	Build.box(geo, Vector3(1.6, 2.7, 0.12), Vector3(cx, 1.35, cz + 1.7), wood, true)
	Build.box(geo, Vector3(1.6, 2.7, 0.12), Vector3(cx, 1.35, cz - 1.7), wood, true)
	Build.box(geo, Vector3(1.6, 2.7, 0.1), Vector3(cx, 1.35, cz), wood, false)
	Build.box(geo, Vector3(0.1, 2.7, 3.5), Vector3(cx + 0.75, 1.35, cz), dark, false)
	Build.box(geo, Vector3(0.2, 0.3, 3.7), Vector3(cx - 0.75, 2.75, cz), wood, false)
	Build.box(geo, Vector3(0.12, 0.5, 0.08), Vector3(cx - 0.86, 3.05, cz), Build.color_mat(Color("c9a560"), 0.2), false)
	Build.box(geo, Vector3(0.12, 0.08, 0.3), Vector3(cx - 0.86, 3.15, cz), Build.color_mat(Color("c9a560"), 0.2), false)
	# Treliça entre as duas cabines.
	var lattice := Build.color_mat(Color("1a120c"))
	for i in 5:
		Build.box(geo, Vector3(0.12, 0.03, 0.03), Vector3(cx - 0.1, 1.2 + i * 0.12, cz), lattice, false)
	# Cortinas: a da cabine norte está puxada de lado.
	var curtain := Build.mat("curtain", Color(0.75, 0.6, 0.6), 1.0)
	Build.box(geo, Vector3(0.05, 2.3, 1.5), Vector3(cx - 0.78, 1.3, cz + 0.85), curtain, false)
	Build.box(geo, Vector3(0.05, 2.3, 0.35), Vector3(cx - 0.78, 1.3, cz - 1.5), curtain, false)
	Build.blocker(geo, Vector3(1.6, 3, 3.5), Vector3(cx + 0.1, 1.5, cz))
	# Genuflexório com o relógio de bolso e o bilhete.
	Build.box(geo, Vector3(0.5, 0.35, 1.0), Vector3(cx - 0.35, 0.18, cz - 0.85), dark, false)
	var watch := Build.cylinder(geo, 0.09, 0.03, Vector3(cx - 0.4, 0.38, cz - 0.7), Build.color_mat(Color("c8c8d0"), 0.15, 0.25), false, 16)
	watch.rotation_degrees.z = 8
	Build.box(geo, Vector3(0.02, 0.01, 0.35), Vector3(cx - 0.4, 0.37, cz - 0.95), Build.color_mat(Color("a0a0a8"), 0.0, 0.3), false, 20.0)
	Build.flat_sprite(geo, "icon_note", Vector3(cx - 0.3, 0.37, cz - 1.1), Vector3(-90, 30, 0), 0.02)
	Build.candle(geo, Vector3(cx - 0.35, 0.36, cz - 1.2), 0.6, 3.5)
	interact(Vector3(cx - 1.35, 0.4, cz - 0.55), "Examinar o relógio de bolso", _examine_watch, "any", 0.9)
	doc(Vector3(cx - 1.35, 0.4, cz - 1.25), {
		"id": "ch3_bilhete",
		"title": "Bilhete dobrado",
		"body": "Meu relógio sempre atrasou uma hora.\n\nFoi a hora em que eu parti.",
		"style": "hand",
	}, "Ler o bilhete", "any", 0.9)
	# Quem chega perto do confessionário (A) ouve a voz que imita B.
	zone(Vector3(cx - 1.7, 1, cz), Vector3(2.6, 2, 4.2), _on_confessional, false)


# --- Altar, console e espelho ----------------------------------------------------------

func _build_altar() -> void:
	var marble := Build.mat("marble_white", Color(0.85, 0.85, 0.9), 1.0)
	var cloth := Build.color_mat(Color("e6e0d2"))
	var red := Build.color_mat(Color("6a1418"))
	# Estrado (baixo, só visual) e degrau.
	Build.box(geo, Vector3(7.0, 0.06, 4.6), Vector3(0, 0.03, ALTAR.z - 0.4), Build.mat("marble_white", Color(0.55, 0.55, 0.62), 1.5), false)
	# Vão escondido sob o altar.
	Build.box(geo, Vector3(2.2, 0.02, 0.9), Vector3(ALTAR.x, 0.07, ALTAR.z), Build.color_mat(Color("0a0203")), false)
	_altar_light = Build.omni(geo, ALTAR + Vector3(0, 0.3, 0), Color("ff3a2a"), 0.0, 4.0)
	# Duas metades que se afastam.
	var halves: Array[Mover] = []
	for side in [-1.0, 1.0]:
		var m := Build.mover(geo, Vector3(1.3, 1.05, 1.1), ALTAR + Vector3(side * 0.66, 0.53, 0), Vector3(side * 1.25, 0, 0), marble)
		m.time = 2.4
		Build.box(m, Vector3(1.36, 0.08, 1.2), Vector3(0, 0.56, 0), cloth, false)
		Build.box(m, Vector3(0.5, 0.6, 0.02), Vector3(-side * 0.25, 0.1, 0.61), red, false)
		halves.append(m)
	_altar_l = halves[0]
	_altar_r = halves[1]
	# Console do relógio da torre (latão), sobre a metade esquerda.
	var brass := Build.color_mat(Color("b08a3e"), 0.1, 0.35)
	Build.box(_altar_l, Vector3(0.7, 0.22, 0.45), Vector3(0.25, 0.71, 0.0), brass, false)
	var face := Build.cylinder(_altar_l, 0.3, 0.06, Vector3(0.25, 1.12, 0.05), Build.color_mat(Color("d9ccb0"), 0.25), false, 20)
	face.rotation_degrees.x = 80
	Build.box(_altar_l, Vector3(0.03, 0.2, 0.02), Vector3(0.25, 1.18, 0.1), Build.color_mat(Color("140e0a")), false)
	var hand_m := Build.box(_altar_l, Vector3(0.03, 0.14, 0.02), Vector3(0.3, 1.1, 0.1), Build.color_mat(Color("140e0a")), false)
	hand_m.rotation_degrees.z = -60
	Build.cylinder(_altar_l, 0.36, 0.04, Vector3(0.25, 1.12, 0.02), brass, false, 20).rotation_degrees.x = 80
	_console_it = interact(ALTAR + Vector3(0, 0.5, 1.2), "Mexer no console do relógio", _try_clock, "any", 1.2, true, 1.9)
	# Candelabros altos.
	var iron := Build.color_mat(Color("2a2522"), 0.0, 0.4)
	for x in [-2.3, 2.3]:
		Build.cylinder(geo, 0.05, 1.3, Vector3(x, 0.65, ALTAR.z - 0.2), iron, false, 6)
		Build.cylinder(geo, 0.2, 0.06, Vector3(x, 0.03, ALTAR.z - 0.2), iron, true, 8)
		dread_light(_light_of(Build.candle(geo, Vector3(x, 1.3, ALTAR.z - 0.2), 1.0, 5.0)))
	# Crucifixo alto acima do espelho.
	var wood := Build.mat("planks_dark", Color(0.8, 0.7, 0.6), 1.0)
	Build.box(geo, Vector3(0.14, 1.0, 0.1), Vector3(0, 4.35, -15.78), wood, false)
	Build.box(geo, Vector3(0.6, 0.12, 0.1), Vector3(0, 4.55, -15.78), wood, false)
	# Espelho na parede norte.
	Build.box(geo, Vector3(2.3, 3.1, 0.12), Vector3(MIRROR.x, MIRROR.y, -15.8), Build.mat("planks_dark", Color(0.9, 0.7, 0.45), 0.6), false)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("5d6f82")
	glass.metallic = 0.3
	glass.roughness = 0.4
	glass.emission_enabled = true
	glass.emission = Color("3a4a5c")
	glass.emission_energy_multiplier = 0.5
	Build.box(geo, Vector3(1.9, 2.7, 0.05), Vector3(MIRROR.x, MIRROR.y, -15.73), glass, false)
	# Mão de sangue (decalque, escondido até o fim) e os números.
	_hand = Build.decal(geo, "res://assets/legacy/blood_hand.png", Vector3(MIRROR.x, MIRROR.y - 0.15, -15.5), Vector3(1.25, 0.8, 1.71), Vector3(90, 0, 0), Color(1, 1, 1, 0))
	_hand.visible = false
	_numbers = Build.text3d(geo, "", Vector3(MIRROR.x, MIRROR.y + 0.95, -15.69), 0.0, 84, BLOOD, UiTheme.FONT_HAND)
	_numbers.shaded = false
	_numbers.modulate.a = 0.0
	_mirror_light = Build.omni(geo, Vector3(MIRROR.x, MIRROR.y, -14.6), Color("ff4a3a"), 0.0, 4.0)
	# Reflexo: os dois... e, por um instante, um terceiro atrás deles.
	_refl_third = _mirror_figure("forgotten", 4, 1, 0.0, 1.02, 0.02, -15.697, Color(0.55, 0.5, 0.6))
	_refl_a = _mirror_figure("char_a", 4, 5, -0.45, 1.1, 0.021, -15.686, Color(0.6, 0.68, 0.82))
	_refl_b = _mirror_figure("char_b", 4, 5, 0.45, 1.1, 0.021, -15.686, Color(0.6, 0.68, 0.82))
	Build.omni(geo, Vector3(0, 3.2, -13.0), Color("9fb0d8"), 0.5, 5.0)


func _try_clock(ch: Character) -> void:
	if _solved:
		return
	var clock := ClockLock.new("Relógio da torre", 4, 15,
		"Um console de latão preso ao altar. Os ponteiros comandam o relógio da torre.",
		[
			"O relógio de bolso do confessionário parou em 3:15.",
			"O bilhete diz que o relógio sempre atrasou uma hora. A hora certa é uma hora depois.",
			"Acerte o relógio da torre em 4:15.",
		])
	if await puzzle(clock):
		_reveal()
	elif not Game.get_flag("ch3_clock_tried"):
		Game.set_flag("ch3_clock_tried")
		await say([ch.who + ": Que hora eu marco? Alguém deixou uma pista por aqui."])


func _reveal() -> void:
	_solved = true
	_console_it.disable()
	Game.lock_input()
	if not _locked:
		_lock_grade()
	# O hospital vaza: a mesma hora.
	bleed(["Horário do acidente, segundo a perícia: quatro e quinze."])
	# O altar se abre.
	await get_tree().create_timer(0.6).timeout
	await cam.look_at_point(ALTAR + Vector3(0, 0.6, 0), 1.2)
	_altar_l.open()
	_altar_r.open()
	cam.shake(0.35)
	create_tween().tween_property(_altar_light, "light_energy", 1.6, 2.0)
	await get_tree().create_timer(2.4).timeout
	# O espelho: a mão de sangue e os números.
	cam.set_view(Vector3(0, 2.2, 7.5), 34.0, 1.8)
	await cam.look_at_point(Vector3(MIRROR.x, MIRROR.y + 0.1, MIRROR.z), 1.8)
	Audio.sfx("heartbeat", -2.0)
	await get_tree().create_timer(1.0).timeout
	_hand.visible = true
	Audio.sfx("glass_squeak", -4.0)
	Ui.flash(Color(0.5, 0.0, 0.02), 0.5)
	var t := create_tween().set_parallel()
	t.tween_property(_hand, "modulate:a", 1.0, 1.2)
	t.tween_property(_mirror_light, "light_energy", 1.2, 1.2)
	await t.finished
	Audio.sfx("whisper_saia", -8.0)
	_numbers.text = "%d   %d" % [Game.number_a, Game.number_b]
	create_tween().tween_property(_numbers, "modulate:a", 1.0, 2.0)
	await get_tree().create_timer(2.2).timeout
	await _show_reflection()
	await Ui.fade_out(1.2)
	await Ui.narrate(["Vocês sentem uma estranha afinidade com os números %d e %d." % [Game.number_a, Game.number_b]], UiTheme.INK, 44)
	cam.set_view(Vector3(0, 7.2, 8.6), 34.0, 0.1)
	cam.target = party.active
	await Ui.fade_in(1.2)
	# A porta dos fundos destrava.
	_back_it.disable()
	_back_door.open(100.0, 1.6)
	Game.unlock_input()
	await say([
		"a: %d. Eu conheço esse número. Não sei de onde." % Game.number_a,
		"b: O meu é %d. Parece que estava escrito em mim." % Game.number_b,
		"b: %s... no espelho. Tinha mais alguém atrás da gente." % Game.name_a,
		"a: Eu vi. Não olha de novo.",
		"b: Ouviu isso? A porta dos fundos se abriu.",
		"a: Vamos. Não quero ficar mais nem um minuto aqui.",
	])
	objective("Saiam juntos pela porta dos fundos.")
	hints([
		"A porta dos fundos fica à direita do espelho.",
		"Os dois precisam passar pela porta.",
		"Leve %s e %s até a porta aberta atrás do altar." % [Game.name_a, Game.name_b],
	])


# --- Vitrais -------------------------------------------------------------------------------

func _build_windows() -> void:
	var colors := [Color("6e1a20"), Color("1f3d70"), Color("8a6a26"), Color("24553e"), Color("4a2466")]
	var lead := Build.color_mat(Color("0b0b0e"))
	var i := 0
	for side in [-1.0, 1.0]:
		var x: float = NAVE.end.x - 0.17 if side > 0 else NAVE.position.x + 0.17
		for z in [2.2, -3.6, -8.0, -12.4]:
			var c: Color = colors[i % colors.size()]
			var c2: Color = colors[(i + 2) % colors.size()]
			i += 1
			Build.box(geo, Vector3(0.06, 2.0, 1.1), Vector3(x, 3.1, z), lead, false)
			Build.box(geo, Vector3(0.08, 0.9, 0.9), Vector3(x, 2.6, z), Build.color_mat(c, 0.9), false)
			Build.box(geo, Vector3(0.08, 0.8, 0.9), Vector3(x, 3.55, z), Build.color_mat(c2, 0.9), false)
			var arch := Build.cylinder(geo, 0.45, 0.08, Vector3(x, 3.95, z), Build.color_mat(c, 0.9), false, 12)
			arch.rotation_degrees.z = 90
			Build.box(geo, Vector3(0.1, 0.05, 0.95), Vector3(x, 3.12, z), lead, false)
			if z > -10.0 and z < 0.0:
				Build.spot(geo, Vector3(x - side * 0.3, 3.4, z), Vector3(x - side * 3.2, 0, z + 0.6), c.lightened(0.3), 2.2, 7.0, 22.0, false)
	# Vitrais altos na parede norte, ao lado do espelho.
	for x in [-3.4, 3.2]:
		Build.box(geo, Vector3(1.1, 2.1, 0.06), Vector3(x, 3.0, NAVE.position.y + 0.17), lead, false)
		Build.box(geo, Vector3(0.9, 1.0, 0.08), Vector3(x, 2.55, NAVE.position.y + 0.18), Build.color_mat(colors[1], 0.9), false)
		Build.box(geo, Vector3(0.9, 0.85, 0.08), Vector3(x, 3.5, NAVE.position.y + 0.18), Build.color_mat(colors[0], 0.9), false)
		var arch := Build.cylinder(geo, 0.45, 0.08, Vector3(x, 3.95, NAVE.position.y + 0.18), Build.color_mat(colors[2], 0.9), false, 12)
		arch.rotation_degrees.x = 90


# --- Cenário ------------------------------------------------------------------------------

func _build_decor() -> void:
	var stone := Build.mat("stone_wall", Color(0.7, 0.7, 0.78), 1.0)
	# Pia batismal na entrada.
	Build.cylinder(geo, 0.25, 0.8, Vector3(4.2, 0.4, 3.0), stone, true, 10)
	Build.cylinder(geo, 0.6, 0.3, Vector3(4.2, 0.95, 3.0), stone, false, 12)
	Build.cylinder(geo, 0.5, 0.02, Vector3(4.2, 1.1, 3.0), Build.color_mat(Color("1b2a38"), 0.2, 0.1), false, 12)
	# Estante de velas votivas (lado oeste, depois da grade).
	var iron := Build.color_mat(Color("2a2522"), 0.0, 0.4)
	Build.box(geo, Vector3(0.6, 0.9, 1.8), Vector3(-6.9, 0.45, -6.0), iron, true)
	Build.box(geo, Vector3(0.5, 0.5, 1.8), Vector3(-7.1, 1.1, -6.0), iron, false)
	for k in 6:
		var p := Vector3(-6.85 + (k % 2) * -0.25, 0.9 + (k % 2) * 0.4, -6.7 + (k / 2) * 0.6)
		Build.cylinder(geo, 0.04, 0.12, p + Vector3(0, 0.06, 0), Build.color_mat(Color("c43a2a"), 0.3), false, 6)
		var fl := Build.billboard(geo, "flame", p + Vector3(0, 0.12, 0), 0.008, 4, k % 4, Color(1.4, 1.2, 0.9), false)
		var an := SpriteAnim.new()
		an.frames = 4
		an.fps = 9
		fl.add_child(an)
	Build.omni(geo, Vector3(-6.3, 1.4, -6.0), Color("ffab5e"), 1.2, 4.5, false, true)
	# Estátua (manto) no canto oeste do altar.
	Build.box(geo, Vector3(0.9, 0.5, 0.9), Vector3(-6.4, 0.25, -13.6), stone, true)
	Build.cylinder(geo, 0.32, 1.5, Vector3(-6.4, 1.25, -13.6), Build.mat("marble_white", Color(0.7, 0.72, 0.8), 1.0), false, 8)
	Build.sphere(geo, 0.2, Vector3(-6.4, 2.15, -13.6), Build.mat("marble_white", Color(0.7, 0.72, 0.8), 1.0))
	Build.sphere(geo, 0.16, Vector3(-6.4, 2.45, -13.5), Build.color_mat(Color("d9c27a"), 0.6))
	# Lembrança m3: atrás da estátua, um frasco de remédio caído e dois comprimidos.
	var bottle := Build.cylinder(geo, 0.05, 0.14, MEMORY + Vector3(0.35, 0.05, 0.15), Build.color_mat(Color("b86a1e"), 0.05, 0.3), false, 8)
	bottle.rotation_degrees = Vector3(0, 30, 90)
	for k in 2:
		Build.sphere(geo, 0.025, MEMORY + Vector3(0.55 + k * 0.09, 0.025, 0.3 - k * 0.05), Build.color_mat(Color("e8e8e0"), 0.1))
	memory(MEMORY, "m3", "Os comprimidos",
		"A cabeça doía. Tomei dois do meu remédio, o de dormir, porque era o que tinha na bolsa.\n\nDepois o copo. Depois outro.\n\nA bula dizia: não dirija.")
	# Tochas na entrada.
	Build.torch(geo, Vector3(NAVE.position.x + 0.4, 1.9, 6.5), 1.2, 6.0)
	Build.torch(geo, Vector3(NAVE.end.x - 0.4, 1.9, 6.5), 1.2, 6.0)
	# Velas no chão, perto da placa e do espelho.
	Build.candle(geo, Vector3(-4.6, 0, 1.2), 0.6, 3.5)
	dread_light(_light_of(Build.candle(geo, Vector3(-1.4, 0, -15.3), 0.5, 3.0)))
	dread_light(_light_of(Build.candle(geo, Vector3(1.5, 0, -15.3), 0.5, 3.0)))
	Build.candle(geo, Vector3(5.0, 0, -15.3), 0.6, 3.5)
	# Luz de preenchimento (lustres apagados, luar pelas frestas).
	for z in [4.0, -3.0, -8.5]:
		Build.omni(geo, Vector3(0, 3.8, z), Color("c9b69a"), 0.9, 8.5)
	Build.omni(geo, Vector3(-3.4, 1.2, 2.2), Color("9fb0d8"), 0.7, 3.5)
	# Teias e poeira.
	for p in [Vector3(-7.7, 4.2, -15.7), Vector3(7.7, 4.2, -15.7), Vector3(-7.7, 4.0, 8.6), Vector3(7.7, 4.0, 8.6)]:
		Build.flat_sprite(geo, "cobweb", p, Vector3(0, 0, 0), 0.05, Color(0.8, 0.85, 0.95))
	Build.motes(geo, Vector3(0, 2.2, -4), Vector3(7, 1.8, 11), 90, Color(1.0, 0.9, 0.75, 0.6), "dust", 0.04)
	Build.motes(geo, Vector3(0, 0.3, -4), Vector3(7, 0.2, 11), 20, Color(0.5, 0.55, 0.7, 0.1), "fog", 2.6)


# --- Anteparo de ferro ------------------------------------------------------------------

func _fence(a: Vector3, b: Vector3) -> void:
	var stone := Build.mat("stone_wall", Color(0.62, 0.62, 0.7), 1.0)
	var iron := Build.color_mat(Color("23262b"), 0.0, 0.35)
	var base_h := 0.3
	var top := 2.3
	Build.wall(geo, a, b, base_h, 0.35, stone, false)
	var d := b - a
	var length := d.length()
	var dir := d.normalized()
	var ang := rad_to_deg(atan2(-d.z, d.x))
	var mid := (a + b) / 2.0
	for y in [base_h + 0.2, top - 0.1]:
		Build.box(geo, Vector3(length, 0.05, 0.05), Vector3(mid.x, y, mid.z), iron, false, ang)
	var n := int(length / 0.22)
	for i in n + 1:
		var p := a + dir * (length * i / float(maxi(n, 1)))
		_bars.append(Transform3D(Basis.IDENTITY, Vector3(p.x, (base_h + top) / 2.0, p.z)))
		_spikes.append(Transform3D(Basis.IDENTITY, Vector3(p.x, top + 0.08, p.z)))
	Build.blocker(geo, Vector3(length, 3.0, 0.4), Vector3(mid.x, 1.5, mid.z)).rotation_degrees.y = ang


func _finish_multimeshes() -> void:
	var iron := Build.color_mat(Color("23262b"), 0.0, 0.35)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.04, 2.0, 0.04)
	_multimesh(bar, _bars, iron)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.05
	spike.height = 0.16
	spike.radial_segments = 4
	_multimesh(spike, _spikes, iron)


func _multimesh(mesh: Mesh, xfs: Array[Transform3D], material: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	geo.add_child(mmi)


# --- Terror: quem fica na placa, a voz falsa, o relógio do avô, o reflexo -----------------

func _light_of(n: Node) -> Light3D:
	for c in n.get_children():
		if c is Light3D:
			return c
	return null


func _standing_on_plate(ch: Character) -> bool:
	var p := ch.global_position
	return absf(p.x - PLATE.x) < 0.9 and absf(p.z - PLATE.z) < 0.9


## Quem está na placa, longe do parceiro, com a grade ainda solta.
func _plate_victim() -> Variant:
	if _locked or not _plate.pressed:
		return null
	for ch in [party.a, party.b]:
		if _standing_on_plate(ch) and ch.global_position.distance_to(party.other(ch).global_position) > 3.5:
			return ch
	return null


## Alcançou quem segurava a placa: a vítima é jogada para fora e a grade cai.
func _plate_caught(ch: Character) -> void:
	ch.teleport(PLATE + Vector3(0.2, 0.05, 1.9))
	Audio.sfx("chain_rattle", -4.0)


func _on_confessional(ch: Character) -> void:
	if ch.who != "a" or ch != party.active or _fake_done or _solved:
		return
	_fake_done = true
	var b_near := party.a.global_position.distance_to(party.b.global_position) < 4.0
	Audio.sfx("whisper_many", -14.0, 0.8)
	await get_tree().create_timer(0.5).timeout
	await say([
		"x: %s..." % Game.name_a,
		"x: Não mexe no relógio. Deixa ele parado.",
		"x: Aqui dentro a hora não passa. Fica aqui comigo.",
		"x: Não precisa acordar.",
		"a: %s? Você está aí dentro?" % Game.name_b,
		"A cortina não se mexe. A cabine está vazia.",
	])
	# O B de verdade nega: na hora, se estava perto; senão, quando os dois se encontram.
	while not _finishing and (party.a.global_position.distance_to(party.b.global_position) > 3.5 or not Game.can_control()):
		await get_tree().create_timer(0.4, false).timeout
	if _finishing:
		return
	var lines := ["a: Por que você me pediu para não mexer no relógio?", "b: Eu? Eu não falei nada."]
	if b_near:
		lines.append("b: Eu estava do seu lado. Não abri a boca.")
	else:
		lines.append("b: Eu nem estava perto do confessionário.")
	lines.append("a: Era a sua voz. Vinha lá de dentro.")
	lines.append("b: Não era eu, %s. Juro que não era eu." % Game.name_a)
	await say(lines)


func _examine_watch(ch: Character) -> void:
	await Ui.read_doc(ch.who, WATCH_DOC)
	if ch.who == "b" and not _watch_b:
		_watch_b = true
		await say([
			"b: Esse relógio...",
			"b: Era do meu avô. Tem o mesmo amassado na tampa, de quando eu deixei cair.",
			"b: Vivia atrasado. Meu avô nunca quis consertar.",
			"b: O que ele está fazendo aqui?",
		])
	elif ch.who == "a" and not _watch_a:
		_watch_a = true
		await say([
			"a: Eu já vi esse relógio. Na mão de alguém.",
			"a: ...não quero lembrar de quem.",
		])


## Figura no espelho (sprite chapado, sem billboard, virada para a nave).
func _mirror_figure(sprite_name: String, hf: int, vf: int, x: float, y: float, px: float, z: float, tint: Color) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = Build.sprite_tex(sprite_name)
	sp.hframes = hf
	sp.vframes = vf
	sp.frame = 0
	sp.pixel_size = px
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.transparent = true
	sp.shaded = false
	sp.double_sided = false
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if sp.texture:
		sp.offset = Vector2(0, sp.texture.get_height() / float(vf) / 2.0)
	sp.position = Vector3(MIRROR.x + x, y, z)
	sp.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	geo.add_child(sp)
	return sp


func _show_reflection() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_refl_a, "modulate:a", 0.6, 0.9)
	t.tween_property(_refl_b, "modulate:a", 0.6, 0.9)
	await t.finished
	await get_tree().create_timer(0.6).timeout
	# Por um instante, são três.
	_refl_third.modulate.a = 0.95
	Audio.sfx("dread_sting", -2.0)
	Audio.sfx("breath", -8.0)
	Ui.flash(Color(0.35, 0.0, 0.02), 0.3)
	cam.shake(0.3)
	await get_tree().create_timer(0.5).timeout
	_refl_third.modulate.a = 0.0
	var t2 := create_tween().set_parallel()
	t2.tween_property(_refl_a, "modulate:a", 0.0, 1.0)
	t2.tween_property(_refl_b, "modulate:a", 0.0, 1.0)
	await get_tree().create_timer(1.1).timeout


func _begin() -> void:
	objective("Explorem a capela.")
	await say([
		"a: Está mais frio aqui dentro do que lá fora.",
		"b: Tem cheiro de álcool. De remédio. Parece corredor de hospital.",
		"a: Uma grade de ferro fecha a nave. Não dá para levantar.",
		"b: E tem uma placa de metal no chão, perto da parede.",
		"a: Se um de nós pisar, o outro passa. Mas quem fica na placa fica longe de todo mundo.",
		"b: Então ninguém fica muito tempo.",
	])
	objective("Passem pela grade. Não deixem ninguém muito tempo na placa.")
	hints([
		"A grade só sobe enquanto alguém pisa na placa de metal.",
		"Deixe um de vocês na placa, troque de personagem e passe pela grade com o outro. Rápido: quem fica sozinho na placa é caçado.",
		"Do outro lado, puxe a alavanca à direita para travar a grade aberta.",
	])
	lonely_watch(_plate_victim, 30.0, _plate_caught)


# --- Depuração (tools/shot.sh --call=...) ------------------------------------------------

func _debug_lock() -> void:
	_lock_grade()


func _debug_reveal() -> void:
	_solved = true
	_lock_grade()
	_altar_l.set_open(true, true)
	_altar_r.set_open(true, true)
	_altar_light.light_energy = 1.6
	_hand.visible = true
	_hand.modulate.a = 1.0
	_mirror_light.light_energy = 1.2
	_numbers.text = "%d   %d" % [Game.number_a, Game.number_b]
	_numbers.modulate.a = 1.0
	_console_it.disable()
	_back_it.disable()
	_back_door.open(100.0, 0.1)


func _debug_mirror() -> void:
	_debug_reveal()
	cam.target = null
	cam.offset = Vector3(0, 2.2, 7.5)
	cam.set("_focus_point", Vector3(MIRROR.x, MIRROR.y + 0.1, MIRROR.z))


## Quem ficou na placa, com o Esquecido chegando por trás.
func _debug_watch() -> void:
	_grade.set_open(true, true)
	party.activate("a", true)
	party.a.teleport(PLATE + Vector3(0, 0.1, 0))
	party.b.teleport(Vector3(1.0, 0.1, -4.0))
	_get_shade().appear(PLATE + Vector3(0.6, 0, 2.4), 0.0)
	cam.snap()


## O reflexo com as três figuras.
func _debug_mirror3() -> void:
	_debug_mirror()
	_refl_a.modulate.a = 0.6
	_refl_b.modulate.a = 0.6
	_refl_third.modulate.a = 0.95
