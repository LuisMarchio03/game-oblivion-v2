class_name MirrorView
extends ModalPanel
## Espelho embaçado: palavras aparecem caractere por caractere, espalhadas.

var words: Array = []
var _area: Control
var _labels: Array[Label] = []


func _init(p_words: Array) -> void:
	title = "O espelho"
	words = p_words
	panel_size = Vector2(1300, 880)


func _build(c: VBoxContainer) -> void:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a2430")
	sb.border_color = Color("5b4a36")
	sb.set_border_width_all(14)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(0, 700)
	c.add_child(frame)
	var fog := ColorRect.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/fog_mirror.gdshader")
	fog.material = sm
	frame.add_child(fog)
	_area = Control.new()
	frame.add_child(_area)
	_write.call_deferred()


func _write() -> void:
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := 5
	var rows := int(ceil(words.size() / float(cols)))
	var cell := Vector2(_area.size.x / cols, _area.size.y / maxi(rows, 1))
	for i in words.size():
		var l := UiTheme.label("", 44, Color(0.2, 0.26, 0.33, 0.95), UiTheme.FONT_HAND)
		l.position = Vector2((i % cols) * cell.x + rng.randf_range(10, cell.x * 0.35), (i / cols) * cell.y + rng.randf_range(6, cell.y * 0.4))
		l.rotation = rng.randf_range(-0.15, 0.15)
		_area.add_child(l)
		_labels.append(l)
	var order := range(words.size())
	order.shuffle()
	for i in order:
		if _closed:
			return
		var w: String = words[i]
		for k in w.length():
			if _closed:
				return
			_labels[i].text = w.substr(0, k + 1)
			if k % 2 == 0:
				Audio.sfx("glass_squeak", -20.0, randf_range(0.8, 1.2))
			await get_tree().create_timer(0.03, true, false, true).timeout
