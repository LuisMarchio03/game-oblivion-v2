class_name Mover
extends Node3D
## Bloco que desliza entre posição fechada e aberta (grade, ponte, parede).

signal moved(is_open: bool)

var open_offset := Vector3(0, 3, 0)
var is_open := false
var sound := "stone_grind"
var time := 1.6
var _mesh: MeshInstance3D
var _body: AnimatableBody3D
var _closed_pos: Vector3
var _tween: Tween


func setup(size: Vector3, offset: Vector3, material: Material) -> void:
	open_offset = offset
	_closed_pos = position
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_mesh.material_override = material
	add_child(_mesh)
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	_body.add_child(cs)
	add_child(_body)


func set_open(value: bool, instant := false) -> void:
	if value == is_open and not instant:
		return
	is_open = value
	var target := _closed_pos + (open_offset if value else Vector3.ZERO)
	if _tween:
		_tween.kill()
	if instant:
		position = target
	else:
		if sound != "":
			Audio.sfx_at(sound, self, 0.0)
		_tween = create_tween()
		_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_tween.tween_property(self, "position", target, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	moved.emit(value)


func open() -> void:
	set_open(true)


func close() -> void:
	set_open(false)
