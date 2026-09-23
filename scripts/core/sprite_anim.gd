class_name SpriteAnim
extends Node
## Anima os quadros horizontais do Sprite3D pai em loop.

var frames := 4
var fps := 8.0
var _t := randf()


func _process(delta: float) -> void:
	var s := get_parent() as Sprite3D
	if s == null:
		return
	_t += delta * fps
	s.frame = int(_t) % max(frames, 1)
