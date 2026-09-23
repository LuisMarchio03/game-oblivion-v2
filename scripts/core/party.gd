class_name Party
extends Node3D
## Os dois personagens e a troca entre eles.

signal switched(who: String)

var a: Character
var b: Character
var active: Character
var switch_enabled := true
var cam: CameraRig


func setup(camera_rig: CameraRig, pos_a: Vector3, pos_b: Vector3) -> void:
	cam = camera_rig
	a = Character.new()
	a.name = "A"
	add_child(a)
	a.setup("a")
	a.global_position = pos_a
	b = Character.new()
	b.name = "B"
	add_child(b)
	b.setup("b")
	b.global_position = pos_b
	a.camera = cam.cam
	b.camera = cam.cam


func get_char(who: String) -> Character:
	return a if who == "a" else b


func other(ch: Character) -> Character:
	return b if ch == a else a


func activate(who: String, instant := false) -> void:
	var ch := get_char(who)
	if active == ch:
		return
	if active:
		active.set_active(false)
	active = ch
	ch.set_active(true)
	cam.target = ch
	if instant:
		cam.snap()
	Game.set_meta("active_who", who)
	Ui.set_active_character(who)
	switched.emit(who)


func switch() -> void:
	if not switch_enabled:
		return
	Audio.sfx("switch_char", -6.0)
	activate("b" if active == a else "a")


## Deixa só um personagem em cena (fase branca).
func solo(who: String) -> void:
	var gone := b if who == "a" else a
	gone.visible = false
	gone.process_mode = Node.PROCESS_MODE_DISABLED
	gone.collision_layer = 0
	switch_enabled = false
	Ui.set_switch_enabled(false)
	activate(who, true)


func set_switch_enabled(on: bool) -> void:
	switch_enabled = on
	Ui.set_switch_enabled(on)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch") and Game.can_control() and switch_enabled and active and not active.busy:
		get_viewport().set_input_as_handled()
		switch()


func both_near(p: Vector3, radius: float) -> bool:
	return _flat(a.global_position, p) <= radius and _flat(b.global_position, p) <= radius


func _flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()
