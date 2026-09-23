extends Node
## Captura de tela de uma cena para inspeção visual.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . res://tests/shot.tscn -- \
##   --scene=res://scenes/levels/ch01.tscn --wait=3 --out=/tmp/x.png [--who=b] [--pos=x,y,z]
##   [--view=ox,oy,oz] [--call=metodo] [--panel=nome]

var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	get_window().size = Vector2i(1920, 1080)
	var scene_path: String = args.get("scene", "res://scenes/main.tscn")
	var packed: PackedScene = load(scene_path)
	var inst := packed.instantiate()
	if inst is LevelBase:
		inst.show_card = false
	add_child(inst)
	await get_tree().create_timer(0.3).timeout
	Ui.set_black(false)
	if inst is LevelBase:
		var lvl: LevelBase = inst
		if args.has("who"):
			lvl.party.activate(args["who"], true)
		if args.has("pos"):
			var p: PackedStringArray = args["pos"].split(",")
			lvl.party.active.teleport(Vector3(float(p[0]), float(p[1]), float(p[2])))
			lvl.cam.snap()
		if args.has("view"):
			var v: PackedStringArray = args["view"].split(",")
			lvl.cam.offset = Vector3(float(v[0]), float(v[1]), float(v[2]))
			lvl.cam.snap()
		if args.has("call"):
			for m in args["call"].split(","):
				lvl.call(m)
	if args.has("panel"):
		Ui.open_panel(_make_panel(args["panel"]))
	await get_tree().create_timer(float(args.get("wait", "3"))).timeout
	var img := get_viewport().get_texture().get_image()
	var out: String = args.get("out", "/tmp/shot.png")
	img.save_png(out)
	print("SHOT ", out)
	get_tree().quit()


func _make_panel(kind: String) -> Control:
	match kind:
		"code":
			var c := CodeLock.new("Porta de %s" % Game.name_a, ["B19CD9"], "Uma amostra de cor e um teclado.", ["dica 1", "dica 2"])
			c.keypad = "0123456789ABCDEF"
			c.swatch = Color8(177, 156, 217)
			c.prefix = "#"
			return c
		"wheel":
			return WheelLock.new("Porta da capela", "LEMBRE", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "Seis rodas de letras.", ["x"])
		"clock":
			return ClockLock.new("Relógio da torre", 4, 15, "Os ponteiros estão soltos.", ["x"])
		"piano":
			return PianoPanel.new("O piano", ["C", "G", "A", "F"], "As teclas estão manchadas.", ["x"])
		"dart":
			return DartboardView.new([20, 17, 6, 3, 19])
		"mirror":
			return MirrorView.new(["ACORDE", "FUJA", "MEDO", "ACORDE", "SONO", "NOITE", "ACORDE", "FUJA", "MEDO", "ACORDE"])
		"terminal":
			return TerminalPanel.new("Laboratório", [{"q": "AQUELE QUE TE DOPA", "answers": ["x"]}, {"q": "AQUELE QUE TE INDUZ", "answers": ["x"]}, {"q": "AQUELE QUE TE SEPARA", "answers": ["x"]}, {"q": "AQUELE QUE TE SEDUZ", "answers": ["x"]}])
		"pigpen":
			return NoteView.new({"title": "Bilhete no corpo", "style": "pigpen", "cipher": "NUNCA"})
		"pigpen_key":
			return NoteView.new({"title": "Folha na caixa", "style": "pigpen_key"})
		"stone":
			return NoteView.new({"title": "Pedra pintada", "style": "stone", "circles": [["#b3262e", 60], ["#2e5fb3", 90], ["#2f8f3a", 28]], "body": "[center]Do menor ao maior.[/center]"})
		"hand":
			return NoteView.new({"title": "Sob o travesseiro", "style": "hand", "body": "Eles me destruíram sem Dó\nO Sol já não nasce como antes\nNão quero mais voltar Lá\nEles apenas Fa-zem chacota de mim"})
		"journal":
			Game.add_doc("a", {"id": "t1", "title": "Bilhete amassado", "body": "x"})
			Game.set_chapter_hints(["Primeira dica.", "Segunda."])
			Game.next_hint()
			return JournalPanel.new()
		"names":
			return NameEntry.new()
		"rules":
			return RulesPanel.new()
		"pause":
			return PauseMenu.new()
		"options":
			return OptionsPanel.new()
	return PauseMenu.new()
