class_name CameraRig
extends Node3D
## Câmera HD-2D: segue o alvo num ângulo fixo, com profundidade de campo
## tilt-shift e limites por fase.

var target: Node3D
var offset := Vector3(0, 7.2, 8.6)
var fov := 34.0
var bounds := Rect2()  # vazio = sem limite
var follow_speed := 4.0
var cam: Camera3D
var _shake := 0.0
var _focus_point := Vector3.ZERO
var _attrs: CameraAttributesPractical


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.3
	cam.far = 120.0
	add_child(cam)
	cam.current = true
	_attrs = CameraAttributesPractical.new()
	cam.attributes = _attrs
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()


func _apply_quality() -> void:
	var high: bool = int(Game.settings["quality"]) >= 1
	_attrs.dof_blur_far_enabled = high
	_attrs.dof_blur_near_enabled = high
	_update_dof()


func _update_dof() -> void:
	var dist := offset.length()
	_attrs.dof_blur_far_distance = dist + 6.0
	_attrs.dof_blur_far_transition = 10.0
	_attrs.dof_blur_near_distance = max(dist - 5.0, 1.0)
	_attrs.dof_blur_near_transition = 3.0
	_attrs.dof_blur_amount = 0.06


func snap() -> void:
	if target:
		_focus_point = _clamp(target.global_position)
	_place()


func _clamp(p: Vector3) -> Vector3:
	if bounds.size == Vector2.ZERO:
		return p
	return Vector3(clamp(p.x, bounds.position.x, bounds.end.x), p.y, clamp(p.z, bounds.position.y, bounds.end.y))


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		var goal := _clamp(target.global_position + Vector3(0, 0.8, 0))
		_focus_point = _focus_point.lerp(goal, 1.0 - exp(-follow_speed * delta))
	_place()
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.3
		cam.v_offset = randf_range(-1, 1) * _shake * 0.3
	else:
		cam.h_offset = 0
		cam.v_offset = 0


func _place() -> void:
	global_position = _focus_point + offset
	cam.fov = fov
	look_at(_focus_point, Vector3.UP)


func shake(amount := 0.6) -> void:
	_shake = max(_shake, amount)


func set_view(new_offset: Vector3, new_fov := -1.0, time := 1.2) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(self, "offset", new_offset, time).set_trans(Tween.TRANS_SINE)
	if new_fov > 0:
		t.tween_property(self, "fov", new_fov, time).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(_update_dof)


func look_at_point(p: Vector3, time := 1.0) -> void:
	# Leva o foco até um ponto (cena), sem alvo.
	target = null
	var t := create_tween()
	t.tween_property(self, "_focus_point", p, time).set_trans(Tween.TRANS_SINE)
	await t.finished
