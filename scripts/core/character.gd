class_name Character
extends CharacterBody3D
## Personagem jogável em sprite (HD-2D). Anda relativo à câmera, anima pelas
## 4 direções, toca passos conforme o piso e interage com o que está perto.

signal arrived

const FRAME_W := 32
const FRAME_H := 48
const WALK := 3.0
const RUN := 5.2
const ROW := {"down": 0, "left": 1, "right": 2, "up": 3, "climb": 4}

var who := "a"
var active := false
var busy := false  # em cena scriptada (escalando, andando sozinho)
var hidden := false  # dentro de um esconderijo: o Esquecido não enxerga
var facing := "down"
var sprite: Sprite3D
var lamp: OmniLight3D
var camera: Camera3D
var _stride := 0.0
var _frame := 0
var _focus: Interactable
var _gravity := 18.0
var _last_step_frame := -1


func setup(p_who: String) -> void:
	who = p_who
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)

	sprite = Sprite3D.new()
	var tex := Build.sprite_tex("char_" + who)
	if tex == null:
		tex = _placeholder_sheet()
	sprite.texture = tex
	sprite.hframes = 4
	sprite.vframes = 5
	sprite.pixel_size = 0.036
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.double_sided = true
	sprite.offset = Vector2(0, FRAME_H / 2.0)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	Build.blob_shadow(self, 0.42)

	lamp = OmniLight3D.new()
	lamp.position = Vector3(0, 1.4, 0.6)
	lamp.light_color = Color("c8d8ff") if who == "a" else Color("ffd9b0")
	lamp.omni_range = 4.5
	lamp.light_energy = 0.35
	lamp.light_volumetric_fog_energy = 0.0
	add_child(lamp)
	_set_frame()


func _placeholder_sheet() -> Texture2D:
	var img := Image.create(FRAME_W * 4, FRAME_H * 5, false, Image.FORMAT_RGBA8)
	var body := Color("8a8f99") if who == "a" else Color("3d5a3a")
	for r in 5:
		for c in 4:
			var o := Vector2i(c * FRAME_W, r * FRAME_H)
			img.fill_rect(Rect2i(o + Vector2i(10, 16), Vector2i(12, 20)), body)
			img.fill_rect(Rect2i(o + Vector2i(11, 4), Vector2i(10, 12)), Color("e6d2c0"))
			img.fill_rect(Rect2i(o + Vector2i(10 + (c % 2) * 2, 36), Vector2i(4, 11)), Color("222"))
			img.fill_rect(Rect2i(o + Vector2i(18 - (c % 2) * 2, 36), Vector2i(4, 11)), Color("222"))
	return ImageTexture.create_from_image(img)


func set_active(on: bool) -> void:
	active = on
	lamp.light_energy = 0.0 if hidden else (0.55 if on else 0.18)
	if on and hidden:
		Ui.show_prompt("Sair do esconderijo")
	if not on:
		velocity = Vector3.ZERO
		_frame = 0
		_set_frame()
		if _focus:
			_focus = null
			Ui.hide_prompt()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	var input := Vector2.ZERO
	if active and not busy and Game.can_control():
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3.ZERO
	if input.length() > 0.05 and camera:
		var fwd := -camera.global_transform.basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var right := camera.global_transform.basis.x
		right.y = 0
		right = right.normalized()
		dir = (right * input.x + fwd * -input.y)
		if dir.length() > 1.0:
			dir = dir.normalized()
		_update_facing(input)
	if not busy:
		var speed := RUN if Input.is_action_pressed("run") else WALK
		var target := dir * speed
		var accel := 14.0 if dir != Vector3.ZERO else 18.0
		velocity.x = move_toward(velocity.x, target.x, accel * delta * speed)
		velocity.z = move_toward(velocity.z, target.z, accel * delta * speed)
		move_and_slide()
	_animate(delta)
	if active and not busy and Game.can_control():
		_update_focus()
	elif _focus and not Game.can_control():
		_focus = null


func _update_facing(v: Vector2) -> void:
	if abs(v.x) > abs(v.y) * 1.1:
		facing = "right" if v.x > 0 else "left"
	elif abs(v.y) > 0.01:
		facing = "down" if v.y > 0 else "up"


func face(dir_name: String) -> void:
	facing = dir_name
	_set_frame()


func _animate(_delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if busy and facing == "climb":
		return
	if hspeed > 0.3:
		_stride += hspeed * _delta
		var step_len := 0.42
		_frame = int(_stride / step_len) % 4
		if (_frame == 1 or _frame == 3) and _frame != _last_step_frame:
			_footstep()
		_last_step_frame = _frame
	else:
		_frame = 0
		_stride = 0.0
		_last_step_frame = -1
	_set_frame()


func _set_frame() -> void:
	if sprite:
		sprite.frame = ROW.get(facing, 0) * 4 + _frame


func _footstep() -> void:
	var surface := "stone"
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.3, 0), global_position + Vector3(0, -0.6, 0), 1)
	var hit := space.intersect_ray(q)
	if hit and hit.collider and hit.collider.has_meta("surface"):
		surface = hit.collider.get_meta("surface")
	var vol := -10.0 if active else -18.0
	match surface:
		"grass", "dirt":
			Audio.sfx_var("step_grass", 3, vol)
		"wood":
			Audio.sfx_var("step_wood", 3, vol)
		_:
			Audio.sfx_var("step_stone", 3, vol)


func _update_focus() -> void:
	var best: Interactable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.can_use(self):
			continue
		var d := it.global_position.distance_to(global_position)
		var flat := Vector2(it.global_position.x - global_position.x, it.global_position.z - global_position.z).length()
		if flat <= it.radius and absf(it.global_position.y - global_position.y) < 2.2 and d < best_d:
			best = it
			best_d = d
	if best != _focus:
		_focus = best
		if best:
			Ui.show_prompt(best.prompt)
		else:
			Ui.hide_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if active and hidden and Game.can_control() and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		leave_hiding()
		return
	if not active or busy or not Game.can_control():
		return
	if event.is_action_pressed("interact") and _focus:
		get_viewport().set_input_as_handled()
		var f := _focus
		_focus = null
		Ui.hide_prompt()
		f.trigger(self)


func clear_focus() -> void:
	_focus = null


# --- Cenas scriptadas ---------------------------------------------------------------

## Anda sozinho até `pos` (no plano). Devolve quando chega.
func walk_to(pos: Vector3, speed := WALK) -> void:
	busy = true
	var start := global_position
	var flat := Vector3(pos.x, start.y, pos.z)
	var dist := start.distance_to(flat)
	var d := (flat - start)
	if d.length() > 0.01:
		var v := Vector2(d.x, d.z).normalized()
		_update_facing(v)
	var t := create_tween()
	t.tween_method(func(p: Vector3):
		var prev := global_position
		global_position = p
		velocity = (p - prev) / max(get_physics_process_delta_time(), 0.001)
		, start, flat, max(dist / speed, 0.05))
	await t.finished
	velocity = Vector3.ZERO
	busy = false
	arrived.emit()


## Escala seguindo pontos (trepadeira, escada de mão).
func climb(points: Array, duration := 3.0) -> void:
	busy = true
	facing = "climb"
	var cs: CollisionShape3D = get_child(0)
	cs.disabled = true
	var t := create_tween()
	var seg := duration / maxi(points.size(), 1)
	for p in points:
		t.tween_property(self, "global_position", p, seg)
	var anim := create_tween().set_loops(int(duration / 0.25))
	anim.tween_callback(func():
		_frame = (_frame + 1) % 4
		sprite.frame = ROW["climb"] * 4 + _frame
		if _frame % 2 == 0:
			Audio.sfx("step_wood_1", -16.0, 0.7))
	anim.tween_interval(0.25)
	await t.finished
	anim.kill()
	cs.disabled = false
	facing = "up"
	_frame = 0
	_set_frame()
	busy = false


## Entra num esconderijo (armário, debaixo da cama): some da vista até sair.
func hide_in(spot: Vector3) -> void:
	if hidden:
		return
	hidden = true
	busy = true
	velocity = Vector3.ZERO
	global_position = Vector3(spot.x, global_position.y, spot.z)
	sprite.visible = false
	lamp.light_energy = 0.0
	Audio.sfx("door_open", -14.0, 1.5)
	Audio.sfx("breath", -16.0)
	Ui.show_prompt("Sair do esconderijo")


func leave_hiding() -> void:
	if not hidden:
		return
	hidden = false
	busy = false
	sprite.visible = true
	lamp.light_energy = 0.55 if active else 0.18
	Audio.sfx("door_open", -14.0, 1.3)
	Ui.hide_prompt()


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
