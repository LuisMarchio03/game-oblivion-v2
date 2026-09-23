class_name Build
## Construtor de geometria das fases: caixas texturizadas com UV triplanar
## em coordenadas de mundo (sem costura), sprites billboard, luzes, textos
## talhados e peças móveis (portas, grades, alavancas).

const TEX_DIR := "res://assets/textures/"
const SPR_DIR := "res://assets/sprites/"

static var _mats := {}
static var _tex := {}
static var _blob: Texture2D


# --- Materiais --------------------------------------------------------------------

static func tex(tex_name: String) -> Texture2D:
	if _tex.has(tex_name):
		return _tex[tex_name]
	var path := tex_name if tex_name.begins_with("res://") else TEX_DIR + tex_name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex[tex_name] = t
	return t


static func sprite_tex(sprite_name: String) -> Texture2D:
	return tex(SPR_DIR + sprite_name + ".png")


## Material com textura pixel (filtro nearest) aplicada em triplanar de mundo.
## `tile` = tamanho em metros de uma repetição da textura.
static func mat(tex_name: String, tint := Color.WHITE, tile := 2.0, rough := 0.9) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [tex_name, tint.to_html(), tile, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var t := tex(tex_name)
	if t:
		m.albedo_texture = t
		m.albedo_color = tint
	else:
		m.albedo_color = _fallback_color(tex_name) * tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	m.roughness = rough
	_mats[key] = m
	return m


static func color_mat(c: Color, emission := 0.0, rough := 0.85) -> StandardMaterial3D:
	var key := "color|%s|%s|%s" % [c.to_html(), emission, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func _fallback_color(tex_name: String) -> Color:
	var table := {
		"grass": Color("2f4a38"), "dirt": Color("4a3d30"), "forest_floor": Color("3a3a2c"),
		"stone_path": Color("5a5d62"), "cobble": Color("55585e"), "brick": Color("5e4038"),
		"stone_wall": Color("5d6068"), "wood_floor": Color("5a4330"), "wood_wall": Color("4d3a2b"),
		"planks_dark": Color("33271f"), "wallpaper_stripes": Color("1f2d45"), "wallpaper_damask": Color("2c2438"),
		"tile_checker": Color("6a6a6a"), "tile_bath": Color("b8bec6"), "tile_kitchen": Color("8a8070"),
		"roof": Color("2e2a2c"), "bark": Color("3b2e24"), "metal": Color("34383e"), "rust_metal": Color("5a3b2a"),
		"carpet_red": Color("5a1a1e"), "bed_cloth": Color("7a7f8a"), "marble_white": Color("e8ecef"),
		"plaster": Color("8f8a82"), "water": Color("12303d"), "gravestone": Color("6c7075"),
		"dungeon_stone": Color("3d4440"), "dirt_dark": Color("2d261f"), "ceiling_wood": Color("3a2c22"),
		"curtain": Color("4a1418"),
	}
	return table.get(tex_name, Color(0.5, 0.5, 0.5))


# --- Geometria ----------------------------------------------------------------------

static func _body(parent: Node3D, shape: Shape3D, xf: Transform3D, surface := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xf
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	if surface != "":
		body.set_meta("surface", surface)
	parent.add_child(body)
	return body


## Caixa sólida. `rot_y` em graus. Devolve o MeshInstance3D (o corpo físico é
## irmão dele e fica em `mesh.get_meta("body")`).
static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, collide := true, rot_y := 0.0, surface := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees.y = rot_y
	parent.add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var body := _body(parent, shape, mi.transform, surface)
		mi.set_meta("body", body)
	return mi


## Piso: caixa fina com o topo em `top_y`.
static func ground(parent: Node3D, rect: Rect2, top_y: float, material: Material, surface := "grass", thickness := 0.5) -> MeshInstance3D:
	var size := Vector3(rect.size.x, thickness, rect.size.y)
	var pos := Vector3(rect.position.x + rect.size.x / 2.0, top_y - thickness / 2.0, rect.position.y + rect.size.y / 2.0)
	return box(parent, size, pos, material, true, 0.0, surface)


## Parede reta de `a` até `b` (no plano XZ, base em y).
static func wall(parent: Node3D, a: Vector3, b: Vector3, height: float, thickness: float, material: Material, collide := true) -> MeshInstance3D:
	var d := b - a
	d.y = 0
	var length := d.length()
	var mid := (a + b) / 2.0
	var ang := rad_to_deg(atan2(-d.z, d.x))
	return box(parent, Vector3(length, height, thickness), Vector3(mid.x, a.y + height / 2.0, mid.z), material, collide, ang)


## Sala retangular: piso, paredes (com vãos) e teto opcional.
## `gaps` = lista de {side: "n"/"s"/"e"/"w", at: posição ao longo da parede (m), width}
static func room(parent: Node3D, rect: Rect2, floor_y: float, height: float, floor_mat: Material, wall_mat: Material, gaps: Array = [], ceiling_mat: Material = null, surface := "wood", walls_south := true) -> void:
	ground(parent, rect, floor_y, floor_mat, surface)
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var t := 0.3
	var sides := {
		"n": [Vector3(x0, floor_y, z0), Vector3(x1, floor_y, z0)],
		"s": [Vector3(x0, floor_y, z1), Vector3(x1, floor_y, z1)],
		"w": [Vector3(x0, floor_y, z0), Vector3(x0, floor_y, z1)],
		"e": [Vector3(x1, floor_y, z0), Vector3(x1, floor_y, z1)],
	}
	for side in sides.keys():
		if side == "s" and not walls_south:
			# Parede sul baixa, para a câmera enxergar dentro (estilo diorama).
			var a0: Vector3 = sides[side][0]
			var b0: Vector3 = sides[side][1]
			_wall_with_gaps(parent, a0, b0, 0.6, t, wall_mat, _gaps_for(gaps, side))
			continue
		var a: Vector3 = sides[side][0]
		var b: Vector3 = sides[side][1]
		_wall_with_gaps(parent, a, b, height, t, wall_mat, _gaps_for(gaps, side))
	if ceiling_mat:
		var c := box(parent, Vector3(rect.size.x, 0.2, rect.size.y), Vector3(rect.get_center().x, floor_y + height + 0.1, rect.get_center().y), ceiling_mat, false)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


static func _gaps_for(gaps: Array, side: String) -> Array:
	var out := []
	for g in gaps:
		if g["side"] == side:
			out.append(g)
	return out


static func _wall_with_gaps(parent: Node3D, a: Vector3, b: Vector3, height: float, t: float, material: Material, gaps: Array) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var cuts := []
	for g in gaps:
		var at: float = g["at"]
		var w: float = g["width"]
		cuts.append([at - w / 2.0, at + w / 2.0, g.get("lintel", true)])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var cur := 0.0
	for c in cuts:
		if c[0] > cur + 0.01:
			wall(parent, a + dir * cur, a + dir * c[0], height, t, material)
		# Verga acima do vão.
		if c[2] and height > 2.6:
			var la: Vector3 = a + dir * float(c[0])
			var lb: Vector3 = a + dir * float(c[1])
			la.y += 2.5
			lb.y += 2.5
			wall(parent, la, lb, height - 2.5, t, material, false)
		cur = c[1]
	if cur < length - 0.01:
		wall(parent, a + dir * cur, b, height, t, material)


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, collide := true, sides := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_body(parent, shape, mi.transform)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## Escada reta de `from` (base do primeiro degrau) até `to` (topo), com rampa
## invisível de colisão para o personagem subir liso.
static func stairs(parent: Node3D, from: Vector3, to: Vector3, width: float, steps: int, material: Material) -> void:
	var d := to - from
	var horiz := Vector3(d.x, 0, d.z)
	var run := horiz.length()
	var dir := horiz.normalized()
	var ang := rad_to_deg(atan2(-dir.z, dir.x))
	var step_run := run / steps
	var step_h := d.y / steps
	for i in steps:
		var h := step_h * (i + 1)
		var center := from + dir * (step_run * (i + 0.5))
		center.y = from.y + h / 2.0
		box(parent, Vector3(step_run, h, width), center, material, false, ang)
	# Rampa de colisão.
	var ramp_len := sqrt(run * run + d.y * d.y)
	var mid := (from + to) / 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(ramp_len, 0.1, width)
	var xf := Transform3D.IDENTITY
	xf = xf.rotated(Vector3(0, 0, 1), atan2(d.y, run))
	xf = xf.rotated(Vector3.UP, deg_to_rad(ang))
	xf.origin = mid + Vector3(0, -0.02, 0)
	_body(parent, shape, xf, "wood")


## Bloqueio invisível.
static func blocker(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return _body(parent, shape, Transform3D(Basis.IDENTITY, pos))


static func water(parent: Node3D, rect: Rect2, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = rect.size
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/water.gdshader")
	mi.material_override = sm
	mi.position = Vector3(rect.get_center().x, y, rect.get_center().y)
	parent.add_child(mi)
	return mi


# --- Sprites ------------------------------------------------------------------------

## Sprite billboard (gira só no eixo Y), com a base no chão em `pos`.
static func billboard(parent: Node3D, sprite_name: String, pos: Vector3, pixel := 0.035, hframes := 1, frame := 0, tint := Color.WHITE, shaded := true) -> Sprite3D:
	var s := Sprite3D.new()
	var t := sprite_tex(sprite_name)
	if t == null:
		t = _placeholder(sprite_name)
	s.texture = t
	s.hframes = hframes
	s.frame = frame
	s.pixel_size = pixel
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = shaded
	s.double_sided = true
	s.modulate = tint
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var h := t.get_height()
	s.offset = Vector2(0, h / 2.0)
	s.position = pos
	parent.add_child(s)
	return s


## Sprite deitado/fixo (sem billboard), útil para decalques em paredes e no chão.
static func flat_sprite(parent: Node3D, sprite_name: String, pos: Vector3, rot_deg: Vector3, pixel := 0.03, tint := Color.WHITE) -> Sprite3D:
	var s := Sprite3D.new()
	var t := sprite_tex(sprite_name) if not sprite_name.begins_with("res://") else tex(sprite_name)
	if t == null:
		t = _placeholder(sprite_name)
	s.texture = t
	s.pixel_size = pixel
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.modulate = tint
	s.position = pos
	s.rotation_degrees = rot_deg
	parent.add_child(s)
	return s


static func _placeholder(sprite_name: String) -> Texture2D:
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.35, 0.4, 1.0))
	var h := hash(sprite_name)
	img.fill_rect(Rect2i(2, 2, 12, 12), Color.from_hsv((h % 360) / 360.0, 0.4, 0.7))
	return ImageTexture.create_from_image(img)


## Espalha sprites aleatórios num retângulo, evitando `avoid` (lista de Rect2).
static func scatter(parent: Node3D, names: Array, rect: Rect2, count: int, y: float, rng: RandomNumberGenerator, avoid: Array = [], pixel := 0.035, tint := Color.WHITE) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		var bad := false
		for r in avoid:
			if (r as Rect2).has_point(p):
				bad = true
				break
		if bad:
			continue
		var n: String = names[rng.randi_range(0, names.size() - 1)]
		var hf := 3 if n == "grass" else 1
		var s := billboard(parent, n, Vector3(p.x, y, p.y), pixel * rng.randf_range(0.85, 1.2), hf, rng.randi_range(0, hf - 1), tint)
		s.flip_h = rng.randf() < 0.5
		placed += 1


## Árvore: sprite + tronco invisível de colisão.
static func tree(parent: Node3D, sprite_name: String, pos: Vector3, scale := 1.0, collide := true, tint := Color.WHITE) -> Sprite3D:
	var s := billboard(parent, sprite_name, pos, 0.06 * scale, 1, 0, tint)
	if collide:
		blocker(parent, Vector3(0.6, 3, 0.6), pos + Vector3(0, 1.5, 0))
	return s


# --- Luz e efeitos --------------------------------------------------------------------

static func omni(parent: Node3D, pos: Vector3, color: Color, energy := 1.5, radius := 6.0, shadows := false, flicker := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 0.6
	parent.add_child(l)
	if flicker:
		var f := Flicker.new()
		f.base = energy
		l.add_child(f)
	return l


static func spot(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy := 3.0, radius := 12.0, angle := 30.0, shadows := true) -> SpotLight3D:
	var l := SpotLight3D.new()
	parent.add_child(l)
	l.position = pos
	l.look_at_from_position(pos, target, Vector3.UP if abs((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = radius
	l.spot_angle = angle
	l.shadow_enabled = shadows
	return l


## Vela: chama animada + luz quente tremulante.
static func candle(parent: Node3D, pos: Vector3, energy := 0.9, radius := 4.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	cylinder(root, 0.05, 0.25, Vector3(0, 0.125, 0), color_mat(Color("d8d0bc")), false, 8)
	var fl := billboard(root, "flame", Vector3(0, 0.25, 0), 0.012, 4, 0, Color(1.4, 1.2, 0.9), false)
	var anim := SpriteAnim.new()
	anim.frames = 4
	anim.fps = 10
	fl.add_child(anim)
	omni(root, Vector3(0, 0.5, 0), Color("ffb870"), energy, radius, false, true)
	return root


static func torch(parent: Node3D, pos: Vector3, energy := 1.6, radius := 7.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	box(root, Vector3(0.08, 0.5, 0.08), Vector3(0, 0, 0), color_mat(Color("3a2a1c")), false)
	var fl := billboard(root, "torch", Vector3(0, 0.22, 0), 0.02, 4, 0, Color(1.5, 1.3, 1.0), false)
	var anim := SpriteAnim.new()
	anim.frames = 4
	anim.fps = 9
	fl.add_child(anim)
	omni(root, Vector3(0, 0.6, 0.2), Color("ff9a4a"), energy, radius, true, true)
	return root


static func blob_texture() -> Texture2D:
	if _blob:
		return _blob
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.75))
	g.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_blob = gt
	return gt


## Sombra redonda projetada no chão.
static func blob_shadow(parent: Node3D, radius := 0.45) -> Decal:
	var d := Decal.new()
	d.texture_albedo = blob_texture()
	d.size = Vector3(radius * 2.0, 2.0, radius * 2.0)
	d.position = Vector3(0, 0.5, 0)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	parent.add_child(d)
	return d


## Decalque (ex.: mão de sangue) projetado numa superfície.
static func decal(parent: Node3D, texture_path: String, pos: Vector3, size: Vector3, rot_deg := Vector3.ZERO, tint := Color.WHITE) -> Decal:
	var d := Decal.new()
	var t := tex(texture_path)
	if t == null:
		return d
	d.texture_albedo = t
	d.size = size
	d.position = pos
	d.rotation_degrees = rot_deg
	d.modulate = tint
	parent.add_child(d)
	return d


## Texto 3D (inscrição, placa, parede).
static func text3d(parent: Node3D, text: String, pos: Vector3, rot_y := 0.0, size := 48, color := Color("d9d4c7"), font_path := UiTheme.FONT_SERIF, pixel := 0.006, billboard_mode := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.font(font_path)
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = rot_y
	l.shaded = true
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if billboard_mode:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.shaded = false
	parent.add_child(l)
	return l


## Partículas de poeira/vaga-lumes flutuando numa área.
static func motes(parent: Node3D, center: Vector3, extents: Vector3, amount := 60, color := Color(0.8, 0.9, 1.0, 0.6), sprite_name := "dust", size := 0.05) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.position = center
	p.visibility_aabb = AABB(-extents - Vector3.ONE, extents * 2.0 + Vector3.ONE * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3(0, 0.02, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 3.0
	var alpha := Gradient.new()
	alpha.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	alpha.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var at := GradientTexture1D.new()
	at.gradient = alpha
	pm.color_ramp = at
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	var t := sprite_tex(sprite_name)
	if t:
		m.albedo_texture = t
	qm.material = m
	p.draw_pass_1 = qm
	parent.add_child(p)
	return p


# --- Peças móveis --------------------------------------------------------------------

## Porta com dobradiça. `pos` = centro da base da porta; `rot_y` em graus.
static func door(parent: Node3D, pos: Vector3, rot_y: float, material: Material, width := 1.2, height := 2.4) -> Door:
	var d := Door.new()
	d.position = pos
	d.rotation_degrees.y = rot_y
	parent.add_child(d)
	d.setup(material, width, height)
	return d


## Peça que desliza entre fechada e aberta (grade levadiça, ponte, parede falsa).
static func mover(parent: Node3D, size: Vector3, closed_pos: Vector3, open_offset: Vector3, material: Material, rot_y := 0.0) -> Mover:
	var m := Mover.new()
	m.position = closed_pos
	m.rotation_degrees.y = rot_y
	parent.add_child(m)
	m.setup(size, open_offset, material)
	return m


static func lever(parent: Node3D, pos: Vector3, handle_color: Color, rot_y := 0.0) -> Lever:
	var l := Lever.new()
	l.position = pos
	l.rotation_degrees.y = rot_y
	parent.add_child(l)
	l.setup(handle_color)
	return l
