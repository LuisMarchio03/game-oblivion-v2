extends Node
## Confere o Esquecido numa fase real: patrulha anda, enxerga, persegue, alcança;
## esconder-se despista; quem fica sozinho é alcançado.
## Uso: godot --headless --path . res://tests/stalker_test.tscn

var _fail := 0


func _ready() -> void:
	var lvl: LevelBase = load("res://scenes/levels/ch01.tscn").instantiate()
	lvl.show_card = false
	add_child(lvl)
	await get_tree().create_timer(2.0).timeout
	Ui.close_all_panels()
	Game.reset_input_lock()
	# Esvazia falas pendentes.
	while Ui.is_dialog_busy():
		Ui.advance_pressed.emit()
		await get_tree().process_frame
	Game.reset_input_lock()
	var a := lvl.party.a
	var b := lvl.party.b
	var s := lvl.spawn_stalker()
	var caught := [null]
	s.caught.connect(func(ch): caught[0] = ch)
	# 1) Patrulha: anda entre dois pontos.
	a.teleport(Vector3(-12, 0.1, 5))
	s.patrol([Vector3(8, 0, -14), Vector3(8, 0, -4)])
	var p0 := s.global_position
	await get_tree().create_timer(1.5).timeout
	_ok(s.global_position.distance_to(p0) > 0.8, "patrulha anda (%.2f m)" % s.global_position.distance_to(p0))
	# 2) Enxerga e persegue quem está na frente.
	a.teleport(s.global_position + Vector3(0, 0, 3.0))
	await get_tree().create_timer(0.3).timeout
	print("   dbg: s=", s.global_position, " a=", a.global_position, " vel=", s.velocity, " see=", s._can_see(a), " cone=", s._can_see(a, true), " ctl=", Game.can_control())
	_ok(s.state == Stalker.CHASE, "persegue quem vê (estado %d)" % s.state)
	await get_tree().create_timer(2.5).timeout
	_ok(caught[0] == a, "alcança")
	await get_tree().create_timer(3.0).timeout
	await _flush()
	# 3) Esconder-se despista.
	caught[0] = null
	s.patrol([Vector3(8, 0, -14), Vector3(8, 0, -4)])
	s.global_position = Vector3(8, 0.1, -12)
	a.teleport(Vector3(8, 0.1, -9))
	await get_tree().create_timer(0.3).timeout
	a.hide_in(a.global_position)
	await get_tree().create_timer(2.5).timeout
	_ok(caught[0] == null and s.state != Stalker.CHASE, "escondido não é pego (estado %d)" % s.state)
	a.leave_hiding()
	s.vanish(0.0)
	await _flush()
	# 4) Quem fica sozinho: A parado longe de B.
	a.teleport(Vector3(-8, 0.1, 2))
	b.teleport(Vector3(8, 0.1, -12))
	var hits := [0]
	lvl.lonely_watch(func(): return a, 6.0, func(ch): hits[0] += 1)
	await get_tree().create_timer(9.0).timeout
	_ok(hits[0] >= 1, "sozinho é alcançado (%d)" % hits[0])
	lvl.stop_lonely_watch()
	while Ui.is_dialog_busy():
		Ui.advance_pressed.emit()
		await get_tree().process_frame
	# 5) Erro em enigma apaga luz.
	var l := Build.omni(lvl.geo, Vector3(0, 2, 0), Color.WHITE, 1.0)
	lvl.dread_light(l)
	Game.puzzle_failed.emit()
	await get_tree().create_timer(1.0).timeout
	_ok(l.light_energy < 0.05, "erro apaga luz")
	print("STALKER: %d falha(s)" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _flush() -> void:
	for i in 600:
		if Ui.is_dialog_busy():
			Ui.advance_pressed.emit()
		elif Game.can_control():
			return
		await get_tree().process_frame


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("ok   ", label)
	else:
		_fail += 1
		print("FALHA ", label)
