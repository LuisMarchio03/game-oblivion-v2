class_name OptionsPanel
extends ModalPanel
## Opções: volumes, tela cheia, velocidade do texto, qualidade e brilho.


func _init() -> void:
	title = "OPÇÕES"
	panel_size = Vector2(1000, 720)


func _build(c: VBoxContainer) -> void:
	_slider(c, "Volume geral", "master", 0.0, 1.0, 0.05)
	_slider(c, "Música e ambiente", "music", 0.0, 1.0, 0.05)
	_slider(c, "Efeitos", "sfx", 0.0, 1.0, 0.05)
	_slider(c, "Velocidade do texto", "text_speed", 0.5, 3.0, 0.25)
	_slider(c, "Brilho", "brightness", 0.6, 1.6, 0.05)

	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 16)
	var ql := UiTheme.label("Qualidade gráfica", 34)
	ql.custom_minimum_size = Vector2(380, 0)
	q.add_child(ql)
	var names := ["Baixa", "Alta"]
	var qb := UiTheme.button(names[int(Game.settings["quality"])])
	qb.pressed.connect(func():
		var v := 1 - int(Game.settings["quality"])
		Game.set_setting("quality", v)
		qb.text = names[v])
	q.add_child(qb)
	c.add_child(q)

	var fs := HBoxContainer.new()
	fs.add_theme_constant_override("separation", 16)
	var fl := UiTheme.label("Tela cheia", 34)
	fl.custom_minimum_size = Vector2(380, 0)
	fs.add_child(fl)
	var fb := UiTheme.button("Sim" if Game.settings["fullscreen"] else "Não")
	fb.pressed.connect(func():
		var v: bool = not Game.settings["fullscreen"]
		Game.set_setting("fullscreen", v)
		fb.text = "Sim" if v else "Não")
	fs.add_child(fb)
	c.add_child(fs)


func _slider(c: VBoxContainer, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiTheme.label(text, 34)
	l.custom_minimum_size = Vector2(380, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(440, 40)
	s.focus_mode = Control.FOCUS_ALL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := UiTheme.label("%.2f" % s.value, 30, UiTheme.INK_DIM)
	s.value_changed.connect(func(val):
		v.text = "%.2f" % val
		Game.settings[key] = val
		Game.apply_settings())
	s.drag_ended.connect(func(_c): Game.save_settings())
	row.add_child(s)
	row.add_child(v)
	c.add_child(row)


func close(result: Variant = null) -> void:
	Game.save_settings()
	super.close(result)
