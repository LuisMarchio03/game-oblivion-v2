extends Node
## Reproduz a travessia da ponte do Cap. 1 (antes e depois de abrir).

var lvl


func _ready() -> void:
	lvl = load("res://scenes/levels/ch01.tscn").instantiate()
	lvl.show_card = false
	add_child(lvl)
	await get_tree().create_timer(0.5).timeout
	for i in 60:
		if not Ui.is_dialog_busy():
			break
		Ui.advance_pressed.emit()
		await get_tree().create_timer(0.1).timeout
	Game.reset_input_lock()
	var a = lvl.party.a
	print("antes de abrir:")
	a.teleport(Vector3(-3.0, 0.1, -4.0))
	await _walk("move_right", 2.0, a)
	for k in ["verde", "vermelha", "azul"]:
		lvl._pull(a, k)
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(6.0).timeout
	for i in 60:
		if not Ui.is_dialog_busy():
			break
		Ui.advance_pressed.emit()
		await get_tree().create_timer(0.1).timeout
	Game.reset_input_lock()
	print("ponte y=", lvl._bridge.global_position.y, " body y=", lvl._bridge._body.global_position.y)
	print("depois de abrir:")
	a.teleport(Vector3(-3.0, 0.1, -4.0))
	await _walk("move_right", 3.0, a)
	get_tree().quit()


func _walk(action: String, secs: float, a) -> void:
	Input.action_press(action)
	var t := 0.0
	while t < secs:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		print("  pos=", a.global_position.snapped(Vector3.ONE * 0.01))
	Input.action_release(action)
