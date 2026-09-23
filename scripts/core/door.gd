class_name Door
extends Node3D
## Porta com dobradiça à esquerda. `open()` gira e libera a passagem.

signal opened

var locked := true
var is_open := false
var _pivot: Node3D
var _body: StaticBody3D
var _width := 1.2


func setup(material: Material, width := 1.2, height := 2.4) -> void:
	_width = width
	_pivot = Node3D.new()
	_pivot.position = Vector3(-width / 2.0, 0, 0)
	add_child(_pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, 0.12)
	mi.mesh = bm
	mi.material_override = material
	mi.position = Vector3(width / 2.0, height / 2.0, 0)
	_pivot.add_child(mi)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	knob.mesh = sm
	knob.material_override = Build.color_mat(Color("b39650"), 0.0, 0.3)
	knob.position = Vector3(width - 0.15, 1.1, 0.1)
	_pivot.add_child(knob)
	_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.3)
	cs.shape = shape
	cs.position = Vector3(width / 2.0, height / 2.0, 0)
	_body.add_child(cs)
	_pivot.add_child(_body)
	# Batente.
	var frame_mat := Build.color_mat(Color("22180f"))
	Build.box(self, Vector3(0.12, height + 0.1, 0.25), Vector3(-width / 2.0 - 0.06, height / 2.0, 0), frame_mat, false)
	Build.box(self, Vector3(0.12, height + 0.1, 0.25), Vector3(width / 2.0 + 0.06, height / 2.0, 0), frame_mat, false)
	Build.box(self, Vector3(width + 0.24, 0.12, 0.25), Vector3(0, height + 0.06, 0), frame_mat, false)


func open(angle := -100.0, time := 1.4) -> void:
	if is_open:
		return
	is_open = true
	locked = false
	Audio.sfx_at("door_open", self, 0.0)
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	for c in _body.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	var t := create_tween()
	t.tween_property(_pivot, "rotation_degrees:y", angle, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	opened.emit()


func rattle() -> void:
	Audio.sfx_at("door_locked", self, 0.0)
	var t := create_tween()
	t.tween_property(_pivot, "rotation_degrees:y", -2.0, 0.05)
	t.tween_property(_pivot, "rotation_degrees:y", 1.0, 0.05)
	t.tween_property(_pivot, "rotation_degrees:y", 0.0, 0.05)
