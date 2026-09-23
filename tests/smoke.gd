extends Node
## Carrega cada capítulo por alguns segundos (headless) para pegar erros de execução.
## Uso: godot --headless --path . res://tests/smoke.tscn [-- --only=ch06]


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.split("=")[1]
	var scenes := ["res://scenes/main.tscn"]
	for c in Game.CHAPTERS:
		scenes.append("res://scenes/levels/%s.tscn" % c["id"])
	scenes.append("res://scenes/ui/ending.tscn")
	for path in scenes:
		if only != "" and not path.contains(only):
			continue
		print("== ", path)
		var inst: Node = load(path).instantiate()
		if inst is LevelBase:
			inst.show_card = false
		add_child(inst)
		await get_tree().create_timer(2.5).timeout
		if inst is LevelBase:
			var lvl: LevelBase = inst
			print("   interativos: ", get_tree().get_nodes_in_group("interactable").size(), "  A=", lvl.party.a.global_position, " B=", lvl.party.b.global_position)
			# Os dois devem estar apoiados no chão depois de cair.
			for ch in [lvl.party.a, lvl.party.b]:
				if ch.visible and ch.global_position.y < -2.0:
					print("   ERRO: personagem caiu do mapa: ", ch.who)
		Ui.close_all_panels()
		inst.queue_free()
		await get_tree().process_frame
		Game.reset_input_lock()
		get_tree().paused = false
	print("SMOKE: fim")
	get_tree().quit()
