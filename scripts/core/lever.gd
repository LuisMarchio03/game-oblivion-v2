class_name Lever
extends Node3D
## Alavanca de parede/chão com cabo colorido.

var down := false
var _arm: Node3D


func setup(handle_color: Color) -> void:
	Build.box(self, Vector3(0.5, 0.3, 0.3), Vector3(0, 0.15, 0), Build.mat("metal", Color(0.8, 0.8, 0.85), 1.0), true)
	_arm = Node3D.new()
	_arm.position = Vector3(0, 0.3, 0)
	_arm.rotation_degrees.x = -35.0
	add_child(_arm)
	Build.box(_arm, Vector3(0.08, 0.9, 0.08), Vector3(0, 0.45, 0), Build.color_mat(Color("3b3e44"), 0.0, 0.4), false)
	Build.sphere(_arm, 0.13, Vector3(0, 0.95, 0), Build.color_mat(handle_color, 0.4, 0.5))


func set_down(value: bool, instant := false) -> void:
	down = value
	var target := 35.0 if value else -35.0
	if instant:
		_arm.rotation_degrees.x = target
		return
	Audio.sfx_at("lever", self, 0.0)
	create_tween().tween_property(_arm, "rotation_degrees:x", target, 0.3).set_trans(Tween.TRANS_BACK)
