class_name Flicker
extends Node
## Faz a luz pai tremular (vela, tocha).

var base := 1.0
var amount := 0.25
var speed := 9.0
var _t := 0.0
var _seed := randf() * 100.0


func _process(delta: float) -> void:
	var l := get_parent() as Light3D
	if l == null:
		return
	_t += delta * speed
	var n := sin(_t + _seed) * 0.5 + sin(_t * 2.7 + _seed * 1.3) * 0.3 + sin(_t * 6.1) * 0.2
	l.light_energy = base * (1.0 + n * amount)
