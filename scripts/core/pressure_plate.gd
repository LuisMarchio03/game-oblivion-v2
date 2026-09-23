class_name PressurePlate
extends Area3D
## Placa de pressão: fica ativa enquanto um personagem está em cima.

signal changed(pressed: bool)

var pressed := false
var _plate: MeshInstance3D
var _count := 0


func setup(size := Vector2(1.2, 1.2)) -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 1.0, size.y)
	cs.shape = shape
	cs.position = Vector3(0, 0.5, 0)
	add_child(cs)
	_plate = Build.box(self, Vector3(size.x, 0.08, size.y), Vector3(0, 0.04, 0), Build.mat("metal", Color(0.9, 0.85, 0.7), 1.0), false)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b: Node) -> void:
	if b is Character:
		_count += 1
		_update()


func _on_exit(b: Node) -> void:
	if b is Character:
		_count = max(0, _count - 1)
		_update()


func _update() -> void:
	var now := _count > 0
	if now == pressed:
		return
	pressed = now
	Audio.sfx_at("lever", self, -4.0)
	create_tween().tween_property(_plate, "position:y", -0.02 if pressed else 0.04, 0.15)
	changed.emit(pressed)
