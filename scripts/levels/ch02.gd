extends LevelBase
## Capítulo 2 — O Cemitério.
## B acorda dentro do cemitério murado; A está na porta da capela.
## Seis lápides (I–VI), espalhadas fora de ordem, formam o acróstico LEMBRE.
## A abre o cadeado de seis rodas; o portão do cemitério destrava junto e os
## dois entram na capela.

const ANSWER := "LEMBRE"
const DOOR_POS := Vector3(-7, 0, -9)
const GATE_X := 1.0
const GATE_Z := -3.0
const CEM := Rect2(1.0, -11.8, 12.8, 17.6)  # cemitério murado (x, z, largura, fundo)

## Numeral, verso, posição (x, z), rotação y, inclinação.
const STONES := [
	["IV", "Busque o nome que se perdeu", Vector2(3.6, -8.6), 6.0, -3.0],
	["I", "Luz nenhuma alcança este chão", Vector2(10.6, -4.2), -8.0, 2.0],
	["VI", "Ecoam pelo vale vazio", Vector2(4.4, -1.4), 4.0, 4.0],
	["II", "Esquecemos o caminho de volta", Vector2(8.2, -9.2), -3.0, -2.0],
	["V", "Rastros de quem já partiu", Vector2(11.4, 1.6), 10.0, -4.0],
	["III", "Mas a memória não morreu", Vector2(6.6, 2.4), -6.0, 3.0],
]

var _door: Door
var _lock_it: Interactable
var _padlock: Node3D
var _gate_leaves: Array[Node3D] = []
var _gate_block: StaticBody3D
var _gate_its: Array[Interactable] = []
var _solved := false
var _bars: Array[Transform3D] = []
var _spikes: Array[Transform3D] = []
var _crows: Array[Node3D] = []


func _init() -> void:
	chapter_index = 1
	preset = "cemetery"
	ambience = "amb_forest"
	spawn_a = Vector3(-7, 0, -3.5)
	spawn_b = Vector3(8.8, 0, 0.4)
	start_who = "b"
	cam_bounds = Rect2(-9.5, -8.5, 20, 12)


func _build() -> void:
	var grass := Build.mat("grass", Color(0.72, 0.78, 0.8))
	var dirt := Build.mat("dirt_dark")
	# Chão geral e terra do cemitério.
	Build.ground(geo, Rect2(-24, -26, 48, 40), 0.0, grass, "grass")
	Build.box(geo, Vector3(CEM.size.x - 0.4, 0.02, CEM.size.y - 0.4), Vector3(CEM.get_center().x, 0.01, CEM.get_center().y), dirt, false)
	# Trilha de pedra até a capela e trilha que liga o portão.
	var path := Build.mat("cobble", Color(0.8, 0.82, 0.86))
	Build.box(geo, Vector3(2.4, 0.03, 8.0), Vector3(DOOR_POS.x, 0.015, -4.6), path, false)
	Build.box(geo, Vector3(7.2, 0.03, 1.8), Vector3(-2.6, 0.016, GATE_Z), path, false)
	Build.box(geo, Vector3(3.2, 0.05, 1.0), Vector3(DOOR_POS.x, 0.025, DOOR_POS.z + 0.55), Build.mat("stone_path"), false)

	_build_chapel()
	_build_walls()
	_build_gate()
	_build_graves()
	_build_courtyard()
	_build_nature()
	_finish_multimeshes()

	# Limites do mapa.
	Build.blocker(geo, Vector3(40, 4, 1), Vector3(0, 2, 7.2))
	Build.blocker(geo, Vector3(1, 4, 30), Vector3(-14.5, 2, -6))
	Build.blocker(geo, Vector3(1, 4, 30), Vector3(15, 2, -6))
	# Entre a capela e o muro do cemitério.
	Build.blocker(geo, Vector3(3.4, 4, 1), Vector3(-0.5, 2, -9.2))
	Build.blocker(geo, Vector3(3, 4, 1), Vector3(-13.3, 2, -9.2))

	# Saída: dentro da capela, logo depois da porta.
	exit_zone(Vector3(DOOR_POS.x, 1, DOOR_POS.z - 1.6), Vector3(4, 2, 2.4), true, "Não entro sem %s.")


# --- Capela (fachada) -----------------------------------------------------------------

func _build_chapel() -> void:
	var stone := Build.mat("stone_wall", Color(0.78, 0.8, 0.86), 2.0)
	var x0 := -12.0
	var x1 := -2.0
	var zf := DOOR_POS.z
	var zb := -21.0
	var h := 5.5
	# Fachada com o vão da porta.
	Build.wall(geo, Vector3(x0, 0, zf), Vector3(DOOR_POS.x - 0.75, 0, zf), h, 0.5, stone)
	Build.wall(geo, Vector3(DOOR_POS.x + 0.75, 0, zf), Vector3(x1, 0, zf), h, 0.5, stone)
	Build.wall(geo, Vector3(DOOR_POS.x - 0.75, 2.55, zf), Vector3(DOOR_POS.x + 0.75, 2.55, zf), h - 2.55, 0.5, stone, false)
	Build.wall(geo, Vector3(x0, 0, zf), Vector3(x0, 0, zb), h, 0.5, stone)
	Build.wall(geo, Vector3(x1, 0, zf), Vector3(x1, 0, zb), h, 0.5, stone)
	Build.wall(geo, Vector3(x0, 0, zb), Vector3(x1, 0, zb), h, 0.5, stone)
	# Interior escuro (visto pela porta aberta).
	Build.box(geo, Vector3(9.4, 0.04, 11.4), Vector3(-7, 0.02, -15), Build.mat("planks_dark", Color(0.4, 0.4, 0.45)), false)
	# Contrafortes.
	for x in [x0 - 0.25, -9.6, -4.4, x1 + 0.25]:
		Build.box(geo, Vector3(0.7, 3.2, 0.9), Vector3(x, 1.6, zf + 0.35), stone, true)
	# Frontão triangular.
	var gable := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(10.6, 3.0, 0.5)
	gable.mesh = pm
	gable.material_override = stone
	gable.position = Vector3(-7, h + 1.5, zf)
	geo.add_child(gable)
	# Telhado de duas águas.
	var roof := Build.mat("roof", Color(0.7, 0.72, 0.8))
	for side in [-1.0, 1.0]:
		var slab := Build.box(geo, Vector3(6.3, 0.25, 12.8), Vector3(-7 + side * 2.65, h + 1.55, (zf + zb) / 2.0), roof, false)
		slab.rotation_degrees.z = -side * 30.0
	# Torre do sino.
	Build.box(geo, Vector3(2.2, 3.4, 2.2), Vector3(-7, h + 3.0 + 1.7, zf - 1.4), stone, false)
	var spire := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 1.7
	cm.height = 2.6
	cm.radial_segments = 4
	spire.mesh = cm
	spire.material_override = roof
	spire.rotation_degrees.y = 45
	spire.position = Vector3(-7, h + 6.4 + 1.3, zf - 1.4)
	geo.add_child(spire)
	var iron := Build.color_mat(Color("2a2d33"), 0.0, 0.4)
	Build.box(geo, Vector3(0.12, 1.2, 0.12), Vector3(-7, h + 9.3, zf - 1.4), iron, false)
	Build.box(geo, Vector3(0.7, 0.12, 0.12), Vector3(-7, h + 9.5, zf - 1.4), iron, false)
	# Rosácea (vitral redondo) acima da porta.
	var rose := Build.cylinder(geo, 0.62, 0.1, Vector3(-7, 3.55, zf + 0.26), Build.color_mat(Color("3e1d4c"), 0.4), false, 16)
	rose.rotation_degrees.x = 90
	var rose_in := Build.cylinder(geo, 0.3, 0.12, Vector3(-7, 3.55, zf + 0.27), Build.color_mat(Color("7a5c22"), 0.5), false, 12)
	rose_in.rotation_degrees.x = 90
	Build.omni(geo, Vector3(-7, 3.5, zf + 1.2), Color("b47ad0"), 0.25, 3.0)
	# Janelas estreitas (luz fraca de dentro).
	for x in [-10.4, -3.6]:
		Build.box(geo, Vector3(0.5, 1.4, 0.1), Vector3(x, 2.4, zf + 0.26), Build.color_mat(Color("2b4064"), 0.6), false)
	# Porta e cadeado.
	_door = Build.door(geo, DOOR_POS, 0.0, Build.mat("planks_dark", Color(0.9, 0.85, 0.8), 1.0))
	_padlock = Node3D.new()
	_padlock.position = DOOR_POS + Vector3(0.25, 1.05, 0.12)
	geo.add_child(_padlock)
	Build.flat_sprite(_padlock, "res://assets/legacy/padlock.png", Vector3.ZERO, Vector3.ZERO, 0.0008)
	var chain := Build.color_mat(Color("5a5e66"), 0.0, 0.3)
	Build.box(_padlock, Vector3(1.0, 0.05, 0.04), Vector3(-0.25, 0.28, -0.02), chain, false)
	Build.box(_padlock, Vector3(0.9, 0.05, 0.04), Vector3(-0.25, 0.28, -0.02), chain, false, 0.0).rotation_degrees.z = 14
	_lock_it = interact(DOOR_POS + Vector3(0, 0.5, 0.9), "Examinar o cadeado", _try_lock, "any", 1.3, true, 1.9)
	doc(DOOR_POS + Vector3(-1.9, 0.5, 0.7), {
		"id": "ch2_placa_capela",
		"title": "Placa de bronze",
		"body": "[center]CAPELA DE SÃO LÁZARO\n\n[i]\"Esta porta só se abre\npara quem não esquece os seus mortos.\"[/i][/center]",
		"style": "stone",
	}, "Ler a placa", "any", 1.0)
	Build.box(geo, Vector3(0.7, 0.5, 0.05), DOOR_POS + Vector3(-1.9, 1.5, 0.27), Build.color_mat(Color("7a5a2e"), 0.0, 0.4), false)
	# Lanternas da porta.
	Build.torch(geo, DOOR_POS + Vector3(-1.15, 1.9, 0.45), 1.3, 6.0)
	Build.torch(geo, DOOR_POS + Vector3(1.15, 1.9, 0.45), 1.3, 6.0)


func _try_lock(ch: Character) -> void:
	if _solved:
		return
	var lock := WheelLock.new("Cadeado da capela", ANSWER, "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
		"Seis rodas de letras enferrujadas. A corrente atravessa a porta.",
		[
			"As seis lápides do cemitério estão numeradas de I a VI, fora de ordem.",
			"Leia os versos na ordem dos numerais e junte a primeira letra de cada um.",
			"L-E-M-B-R-E. A palavra é LEMBRE.",
		])
	if await puzzle(lock):
		_solve(ch)
	elif not Game.get_flag("ch2_lock_tried"):
		Game.set_flag("ch2_lock_tried")
		if ch.who == "a":
			await say(["a: Seis letras. %s, o que está escrito aí dentro?" % Game.name_b])


func _solve(_ch: Character) -> void:
	_solved = true
	_lock_it.disable()
	Game.lock_input()
	Audio.sfx_at("lock_open", _padlock, 0.0)
	var t := create_tween()
	t.tween_property(_padlock, "position:y", 0.08, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	_padlock.visible = false
	await get_tree().create_timer(0.4).timeout
	_door.open(100.0, 1.8)
	await get_tree().create_timer(1.2).timeout
	await cam.look_at_point(Vector3(GATE_X, 0.8, GATE_Z), 1.4)
	_open_gate()
	cam.shake(0.25)
	await get_tree().create_timer(1.8).timeout
	cam.target = party.active
	Game.unlock_input()
	await say([
		"a: Abriu. E ouvi um estalo do lado do cemitério.",
		"b: O portão! Destravou sozinho.",
		"a: Vem até aqui. A gente entra junto.",
	])
	objective("Entrem juntos na capela.")
	hints([
		"O portão do cemitério está aberto.",
		"Leve %s até a porta da capela." % Game.name_b,
		"Entrem os dois pela porta aberta da capela.",
	])


# --- Muro e cerca de ferro ---------------------------------------------------------------

func _build_walls() -> void:
	var x0 := CEM.position.x
	var x1 := CEM.end.x
	var z0 := CEM.position.y
	var z1 := CEM.end.y
	_fence(Vector3(x0, 0, z0), Vector3(x1, 0, z0))
	_fence(Vector3(x1, 0, z0), Vector3(x1, 0, z1))
	_fence(Vector3(x0, 0, z1), Vector3(x1, 0, z1), 0.35)
	_fence(Vector3(x0, 0, z0), Vector3(x0, 0, GATE_Z - 1.25))
	_fence(Vector3(x0, 0, GATE_Z + 1.25), Vector3(x0, 0, z1))
	# Pilares do portão com lanternas.
	var stone := Build.mat("stone_wall", Color(0.75, 0.78, 0.84), 1.5)
	for dz in [-1.45, 1.45]:
		Build.box(geo, Vector3(0.6, 2.6, 0.6), Vector3(x0, 1.3, GATE_Z + dz), stone, true)
		Build.box(geo, Vector3(0.75, 0.15, 0.75), Vector3(x0, 2.67, GATE_Z + dz), stone, false)
	Build.sphere(geo, 0.18, Vector3(x0, 2.95, GATE_Z - 1.45), stone)
	Build.sphere(geo, 0.18, Vector3(x0, 2.95, GATE_Z + 1.45), stone)
	# Arco de ferro com o nome.
	var iron := Build.color_mat(Color("24272c"), 0.0, 0.4)
	Build.box(geo, Vector3(0.08, 0.08, 2.9), Vector3(x0, 2.75, GATE_Z), iron, false)
	for dz in [-0.5, 0.5]:
		var brace := Build.box(geo, Vector3(0.05, 0.05, 1.1), Vector3(x0, 2.92, GATE_Z + dz), iron, false)
		brace.rotation_degrees.x = 16.0 if dz < 0 else -16.0
	Build.omni(geo, Vector3(x0 + 0.6, 2.4, GATE_Z), Color("9fb8e8"), 0.9, 6.0)


## Muro baixo de pedra com grade de ferro por cima. `base_h` menor no lado sul (perto da câmera).
func _fence(a: Vector3, b: Vector3, base_h := 0.55) -> void:
	var stone := Build.mat("stone_wall", Color(0.7, 0.72, 0.78), 1.5)
	var iron := Build.color_mat(Color("24272c"), 0.0, 0.4)
	Build.wall(geo, a, b, base_h, 0.4, stone, false)
	var d := b - a
	var length := d.length()
	var dir := d.normalized()
	var ang := rad_to_deg(atan2(-d.z, d.x))
	var top := base_h + 1.55
	# Corrimãos.
	var mid := (a + b) / 2.0
	Build.box(geo, Vector3(length, 0.05, 0.05), Vector3(mid.x, base_h + 0.25, mid.z), iron, false, ang)
	Build.box(geo, Vector3(length, 0.05, 0.05), Vector3(mid.x, top - 0.15, mid.z), iron, false, ang)
	# Barras e pontas (multimesh).
	var n := int(length / 0.26)
	for i in n + 1:
		var p := a + dir * (length * i / float(maxi(n, 1)))
		_bars.append(Transform3D(Basis.IDENTITY, Vector3(p.x, base_h + 0.775, p.z)))
		_spikes.append(Transform3D(Basis.IDENTITY, Vector3(p.x, top + 0.08, p.z)))
	# Pilares a cada ~4 m.
	var posts := maxi(1, int(round(length / 4.2)))
	for i in posts + 1:
		var p := a + dir * (length * i / float(posts))
		Build.box(geo, Vector3(0.45, top + 0.1, 0.45), Vector3(p.x, (top + 0.1) / 2.0, p.z), stone, false)
		Build.box(geo, Vector3(0.58, 0.12, 0.58), Vector3(p.x, top + 0.16, p.z), stone, false)
	# Colisão.
	Build.blocker(geo, Vector3(length + 0.4, 3.0, 0.5), Vector3(mid.x, 1.5, mid.z)).rotation_degrees.y = ang


func _finish_multimeshes() -> void:
	var iron := Build.color_mat(Color("24272c"), 0.0, 0.4)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.045, 1.55, 0.045)
	_multimesh(bar, _bars, iron)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.05
	spike.height = 0.18
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


# --- Portão ----------------------------------------------------------------------------

func _build_gate() -> void:
	# Duas folhas de ferro; fechadas elas ficam alinhadas com o muro (eixo z).
	_gate_leaves.append(_gate_leaf(Vector3(GATE_X, 0, GATE_Z - 1.15), -90.0))
	_gate_leaves.append(_gate_leaf(Vector3(GATE_X, 0, GATE_Z + 1.15), 90.0))
	_gate_block = Build.blocker(geo, Vector3(0.5, 3, 2.4), Vector3(GATE_X, 1.5, GATE_Z))
	# Corrente e cadeado no meio do portão.
	var chain := Build.color_mat(Color("5a5e66"), 0.0, 0.3)
	var lockbox := Build.box(_gate_leaves[0], Vector3(1.0, 0.05, 0.05), Vector3(1.1, 1.1, 0.0), chain, false)
	lockbox.rotation_degrees.z = 8
	Build.box(_gate_leaves[0], Vector3(0.14, 0.18, 0.08), Vector3(1.12, 0.98, 0.0), Build.color_mat(Color("7a6a3e"), 0.0, 0.4), false)
	# Examinar o portão (dos dois lados).
	_gate_its.append(interact(Vector3(GATE_X + 0.8, 0.5, GATE_Z), "Examinar o portão", func(ch: Character):
		if _solved:
			return
		Audio.sfx_at("chain_rattle", _gate_leaves[0], -2.0)
		await say([ch.who + ": Trancado. A corrente segue por um cabo de ferro até a capela."]), "b", 1.2, true, 1.9))
	_gate_its.append(interact(Vector3(GATE_X - 0.8, 0.5, GATE_Z), "Examinar o portão", func(ch: Character):
		if _solved:
			return
		Audio.sfx_at("chain_rattle", _gate_leaves[0], -2.0)
		await say([ch.who + ": Um cabo de ferro liga a tranca do portão à porta da capela."]), "a", 1.2, true, 1.9))


func _gate_leaf(hinge: Vector3, rot_y: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hinge
	pivot.rotation_degrees.y = rot_y
	geo.add_child(pivot)
	var iron := Build.color_mat(Color("2a2d33"), 0.0, 0.35)
	var w := 1.15
	for y in [0.15, 1.1, 2.05]:
		Build.box(pivot, Vector3(w, 0.06, 0.06), Vector3(w / 2.0, y, 0), iron, false)
	var n := 8
	for i in n:
		var x := 0.07 + (w - 0.14) * i / float(n - 1)
		Build.box(pivot, Vector3(0.04, 2.2, 0.04), Vector3(x, 1.1, 0), iron, false)
		var tip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.045
		cm.height = 0.16
		cm.radial_segments = 4
		tip.mesh = cm
		tip.material_override = iron
		tip.position = Vector3(x, 2.28, 0)
		pivot.add_child(tip)
	# Voluta central.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.26
	ring.mesh = tm
	ring.material_override = iron
	ring.rotation_degrees.x = 90
	ring.position = Vector3(w / 2.0, 1.58, 0)
	pivot.add_child(ring)
	return pivot


func _open_gate() -> void:
	Audio.sfx_at("gate_open", _gate_leaves[0], 0.0)
	Audio.sfx_at("chain_rattle", _gate_leaves[0], -4.0)
	for it in _gate_its:
		it.disable()
	if is_instance_valid(_gate_block):
		_gate_block.queue_free()
	for i in _gate_leaves.size():
		var leaf := _gate_leaves[i]
		var target := -10.0 if i == 0 else 10.0
		var t := create_tween()
		t.tween_property(leaf, "rotation_degrees:y", target, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- Túmulos ---------------------------------------------------------------------------

func _build_graves() -> void:
	var stone := Build.mat("gravestone", Color(0.85, 0.88, 0.92), 1.0)
	for s in STONES:
		var pos2: Vector2 = s[2]
		_gravestone(s[0], s[1], Vector3(pos2.x, 0, pos2.y), s[3], s[4], stone)
	# Túmulos sem nome (cenário): cruzes, lápides quebradas, cova aberta, mausoléu.
	var crosses := [Vector2(2.6, -5.0), Vector2(12.4, -7.6), Vector2(9.2, -1.2), Vector2(2.8, 3.8), Vector2(12.6, -1.8)]
	for c in crosses:
		_cross(Vector3(c.x, 0, c.y), rng.randf_range(-12, 12), stone)
	var broken := [Vector2(6.0, -5.6), Vector2(9.6, 4.2), Vector2(12.2, -10.4), Vector2(2.4, -10.4)]
	for bpos in broken:
		var bs := Build.box(geo, Vector3(0.7, rng.randf_range(0.35, 0.6), 0.2), Vector3(bpos.x, 0.25, bpos.y), stone, true, rng.randf_range(-20, 20))
		bs.rotation_degrees.z = rng.randf_range(-14, 14)
		Build.box(geo, Vector3(0.5, 0.12, 0.35), Vector3(bpos.x + 0.5, 0.06, bpos.y + 0.3), stone, false, rng.randf_range(0, 90))
	# Covas (montes de terra) na frente de cada lápide numerada.
	var mound := Build.mat("dirt_dark", Color(0.85, 0.8, 0.75), 1.0)
	for s in STONES:
		var p: Vector2 = s[2]
		Build.box(geo, Vector3(0.9, 0.14, 1.7), Vector3(p.x, 0.07, p.y + 1.1), mound, false, s[3])
	# Cova aberta com pá.
	Build.box(geo, Vector3(1.0, 0.03, 2.0), Vector3(9.0, 0.02, -6.6), Build.color_mat(Color("06070a")), false)
	Build.box(geo, Vector3(1.2, 0.45, 1.4), Vector3(10.4, 0.2, -6.6), mound, true)
	Build.blocker(geo, Vector3(1.0, 2, 2.0), Vector3(9.0, 1, -6.6))
	var shovel := Build.box(geo, Vector3(0.05, 1.3, 0.05), Vector3(10.5, 0.75, -6.1), Build.mat("bark"), false)
	shovel.rotation_degrees.z = 18
	var blade := Build.box(geo, Vector3(0.28, 0.35, 0.03), Vector3(10.32, 0.12, -6.1), Build.color_mat(Color("4a4d52"), 0.0, 0.4), false)
	blade.rotation_degrees.z = 18
	# Mausoléu ao fundo.
	var mz := -10.6
	var mx := 6.2
	var ms := Build.mat("stone_wall", Color(0.62, 0.66, 0.74), 1.5)
	Build.box(geo, Vector3(2.8, 2.4, 1.8), Vector3(mx, 1.2, mz), ms, true)
	var mroof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(3.2, 0.9, 2.1)
	mroof.mesh = pm
	mroof.material_override = ms
	mroof.position = Vector3(mx, 2.85, mz)
	geo.add_child(mroof)
	Build.box(geo, Vector3(1.0, 1.7, 0.05), Vector3(mx, 0.85, mz + 0.91), Build.color_mat(Color("05060a")), false)
	for dx in [-1.2, 1.2]:
		Build.cylinder(geo, 0.14, 2.4, Vector3(mx + dx, 1.2, mz + 1.0), ms, false, 8)
	Build.text3d(geo, "IN MEMORIAM", Vector3(mx, 2.05, mz + 0.92), 0.0, 36, Color("aeb5c2"))
	# Velas em alguns túmulos.
	Build.candle(geo, Vector3(6.25, 0.0, 3.2), 0.7, 3.5)
	Build.candle(geo, Vector3(3.9, 0.0, -7.8), 0.6, 3.5)
	Build.candle(geo, Vector3(mx - 0.5, 0.0, mz + 1.2), 0.7, 3.0)
	Build.candle(geo, Vector3(mx + 0.55, 0.0, mz + 1.25), 0.5, 3.0)


func _gravestone(numeral: String, verse: String, pos: Vector3, rot_y: float, tilt: float, material: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, rot_y, tilt)
	geo.add_child(root)
	Build.box(root, Vector3(0.9, 0.95, 0.22), Vector3(0, 0.475, 0), material, false)
	var arch := Build.cylinder(root, 0.45, 0.22, Vector3(0, 0.95, 0), material, false, 16)
	arch.rotation_degrees.x = 90
	Build.box(root, Vector3(1.1, 0.12, 0.4), Vector3(0, 0.06, 0), material, false)
	Build.text3d(root, numeral, Vector3(0, 0.98, 0.115), 0.0, 72, Color("e6e9ee"))
	# Linhas talhadas (ilegíveis de longe).
	var carve := Build.color_mat(Color("3a3e45"))
	for i in 3:
		Build.box(root, Vector3(0.5 - i * 0.08, 0.025, 0.01), Vector3(0, 0.62 - i * 0.12, 0.115), carve, false)
	Build.blocker(geo, Vector3(0.95, 1.6, 0.35), pos + Vector3(0, 0.8, 0)).rotation_degrees.y = rot_y
	doc(pos + Vector3(0, 0.3, 0.7), {
		"id": "ch2_lapide_" + numeral.to_lower(),
		"title": "Lápide " + numeral,
		"body": "[center][font_size=64]%s[/font_size]\n\n[i]\"%s\"[/i][/center]" % [numeral, verse],
		"style": "stone",
	}, "Ler a lápide " + numeral, "any", 1.1)


func _cross(pos: Vector3, rot_y: float, material: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, rot_y, rng.randf_range(-8, 8))
	geo.add_child(root)
	Build.box(root, Vector3(0.14, 1.3, 0.14), Vector3(0, 0.65, 0), material, false)
	Build.box(root, Vector3(0.7, 0.14, 0.14), Vector3(0, 0.95, 0), material, false)
	Build.box(root, Vector3(0.5, 0.2, 0.4), Vector3(0, 0.1, 0), material, false)
	Build.blocker(geo, Vector3(0.4, 1.4, 0.4), pos + Vector3(0, 0.7, 0))


# --- Pátio de A ------------------------------------------------------------------------

func _build_courtyard() -> void:
	var wood := Build.mat("planks_dark", Color(0.8, 0.78, 0.75), 1.0)
	# Banco de madeira.
	Build.box(geo, Vector3(1.8, 0.1, 0.5), Vector3(-10.6, 0.5, -4.8), wood, true, 90)
	Build.box(geo, Vector3(1.8, 0.5, 0.08), Vector3(-10.85, 0.8, -4.8), wood, false, 90)
	for dz in [-0.75, 0.75]:
		Build.box(geo, Vector3(0.4, 0.45, 0.08), Vector3(-10.6, 0.225, -4.8 + dz), wood, false, 90)
	# Poço velho.
	var ws := Build.mat("stone_wall", Color(0.7, 0.72, 0.78), 1.0)
	Build.cylinder(geo, 0.8, 0.8, Vector3(-11.2, 0.4, 1.2), ws, true, 12)
	Build.cylinder(geo, 0.62, 0.02, Vector3(-11.2, 0.81, 1.2), Build.color_mat(Color("05070a")), false, 12)
	for dx in [-0.75, 0.75]:
		Build.box(geo, Vector3(0.1, 1.5, 0.1), Vector3(-11.2 + dx, 1.5, 1.2), Build.mat("bark"), false)
	var beam := Build.box(geo, Vector3(1.7, 0.1, 0.1), Vector3(-11.2, 2.2, 1.2), Build.mat("bark"), false)
	beam.rotation_degrees.y = 0
	Build.box(geo, Vector3(0.3, 0.3, 0.3), Vector3(-11.2, 1.5, 1.2), wood, false)
	# Lampião na trilha.
	Build.box(geo, Vector3(0.12, 2.2, 0.12), Vector3(-4.8, 1.1, -2.2), Build.color_mat(Color("24272c"), 0.0, 0.4), true)
	Build.box(geo, Vector3(0.3, 0.35, 0.3), Vector3(-4.8, 2.35, -2.2), Build.color_mat(Color("e0a860"), 0.7), false)
	Build.omni(geo, Vector3(-4.8, 2.4, -1.9), Color("ffb870"), 0.9, 6.0, false, true)
	# Velas nos degraus da capela.
	Build.candle(geo, DOOR_POS + Vector3(-1.4, 0.0, 0.9), 0.5, 3.0)
	Build.candle(geo, DOOR_POS + Vector3(1.5, 0.0, 1.0), 0.5, 3.0)


# --- Natureza e clima ------------------------------------------------------------------

func _build_nature() -> void:
	var tint := Color(0.78, 0.82, 0.9)
	# Árvores mortas dentro do cemitério.
	for p in [Vector3(12.4, 0, -4.8), Vector3(3.2, 0, -6.4), Vector3(8.4, 0, -11.0), Vector3(12.9, 0, -0.6)]:
		Build.tree(geo, "tree_dead", p, rng.randf_range(0.9, 1.2), true, tint)
	# Árvores no pátio e moldura.
	for p in [Vector3(-12.8, 0, -3.0), Vector3(-2.6, 0, -7.2), Vector3(-13.2, 0, -7.6)]:
		Build.tree(geo, "tree_dead", p, rng.randf_range(1.0, 1.3), true, tint)
	for i in 14:
		var x := -22.0 + i * 3.4 + rng.randf_range(-0.6, 0.6)
		if x > -12.5 and x < -1.5:
			continue
		Build.tree(geo, ["tree_pine", "tree_dead"][i % 2], Vector3(x, 0, -16.5 + rng.randf_range(-1.5, 1.5)), rng.randf_range(1.1, 1.5), false, tint)
	for z in [-12.0, -6.0, 0.0]:
		Build.tree(geo, "tree_pine", Vector3(16.5, 0, z + rng.randf_range(-1, 1)), rng.randf_range(1.1, 1.4), false, tint)
		Build.tree(geo, "tree_pine", Vector3(-16.5, 0, z + rng.randf_range(-1, 1)), rng.randf_range(1.1, 1.4), false, tint)
	# Vegetação rasteira, pálida.
	var avoid_a := [Rect2(-8.4, -9, 2.8, 9), Rect2(-9, GATE_Z - 1, 11, 2)]
	Build.scatter(geo, ["grass", "grass", "fern", "bush"], Rect2(-14, -8.6, 14.6, 15), 70, 0.0, rng, avoid_a, 0.035, tint)
	var avoid_b := []
	for s in STONES:
		var p: Vector2 = s[2]
		avoid_b.append(Rect2(p.x - 0.8, p.y - 0.4, 1.6, 2.6))
	avoid_b.append(Rect2(GATE_X, GATE_Z - 1.5, 2.0, 3.0))
	Build.scatter(geo, ["grass", "grass", "grass", "flower_white"], Rect2(CEM.position.x + 0.4, CEM.position.y + 0.4, CEM.size.x - 0.8, CEM.size.y - 0.8), 60, 0.0, rng, avoid_b, 0.03, Color(0.7, 0.72, 0.75))
	Build.scatter(geo, ["grass", "bush", "fern"], Rect2(-14, -15, 30, 5.6), 40, 0.0, rng, [Rect2(-12.5, -22, 10.6, 13)], 0.035, tint)
	# Corvos no muro e nas árvores.
	for p in [Vector3(CEM.end.x, 2.3, -7.8), Vector3(GATE_X, 3.1, GATE_Z - 1.45), Vector3(8.6, 2.2, CEM.position.y), Vector3(-2.6, 3.3, -6.7)]:
		var crow := Build.billboard(geo, "crow", p, 0.04, 2, 0, Color(0.85, 0.88, 0.95))
		var ca := SpriteAnim.new()
		ca.frames = 2
		ca.fps = rng.randf_range(0.8, 1.6)
		crow.add_child(ca)
		_crows.append(crow)
	var timer := Timer.new()
	timer.wait_time = 9.0
	timer.autostart = true
	timer.timeout.connect(func():
		timer.wait_time = rng.randf_range(7.0, 15.0)
		if not _crows.is_empty():
			Audio.sfx_at("crow_caw", _crows[rng.randi_range(0, _crows.size() - 1)], -6.0))
	geo.add_child(timer)
	# Névoa rasteira e poeira.
	Build.motes(geo, Vector3(7.4, 0.35, -3.0), Vector3(6.2, 0.25, 8.4), 34, Color(0.55, 0.65, 0.82, 0.16), "fog", 2.8)
	Build.motes(geo, Vector3(-7.0, 0.35, -2.0), Vector3(6.5, 0.25, 7.0), 22, Color(0.55, 0.65, 0.82, 0.12), "fog", 2.8)
	Build.motes(geo, Vector3(2, 1.4, -3), Vector3(12, 1.2, 8), 50, Color(0.75, 0.85, 1.0, 0.6), "dust", 0.04)
	# Luar frio sobre o cemitério.
	Build.omni(geo, Vector3(7.5, 3.5, -3.5), Color("7b97d6"), 1.1, 9.0)
	Build.omni(geo, Vector3(7.5, 3.0, 2.5), Color("7b97d6"), 0.8, 7.0)
	Build.omni(geo, Vector3(-8.5, 3.0, 0.5), Color("7b97d6"), 0.7, 7.0)
	# Sussurro ao chegar perto do mausoléu.
	zone(Vector3(6.2, 1, -8.6), Vector3(3, 2, 1.6), func(_ch):
		Audio.sfx("whisper_saia", -10.0))


func _begin() -> void:
	objective("Descubram onde estão.")
	await say([
		"b: ...que frio. Isso é terra de cova.",
		"b: %s? Estou preso num cemitério. O portão está trancado." % Game.name_a,
		"a: Estou do lado de fora, na porta de uma capela. Tem um cadeado com seis rodas de letras.",
		"b: Aqui tem lápides com números romanos. Estão todas fora de ordem.",
		"a: Lê para mim o que está escrito. Eu anoto.",
	])
	objective("Descubram a palavra de seis letras do cadeado da capela.")
	hints([
		"%s está no cemitério: examine as seis lápides numeradas de I a VI." % Game.name_b,
		"Organize os versos na ordem dos numerais e olhe a primeira letra de cada um.",
		"As iniciais formam LEMBRE. Use essa palavra no cadeado da porta da capela.",
	])


# --- Depuração (tools/shot.sh --call=...) ------------------------------------------------

func _debug_open() -> void:
	_solved = true
	_lock_it.disable()
	_padlock.visible = false
	_door.open(100.0, 0.1)
	_open_gate()
