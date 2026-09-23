class_name DartboardView
extends ModalPanel
## Alvo de dardos visto de perto. Setores alternam vermelho e preto; `darts`
## lista os números atingidos.

const ORDER := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

var darts: Array = []
var _board: Control


func _init(p_darts: Array) -> void:
	title = "O alvo da cozinha"
	darts = p_darts
	panel_size = Vector2(1000, 900)


func _build(c: VBoxContainer) -> void:
	_board = Control.new()
	_board.custom_minimum_size = Vector2(0, 700)
	_board.draw.connect(_draw_board)
	c.add_child(_board)


## Setor vermelho = índice ímpar na ordem do alvo.
static func is_red(number: int) -> bool:
	return ORDER.find(number) % 2 == 1


func _draw_board() -> void:
	var ctr := _board.size / 2.0
	var r: float = min(_board.size.x, _board.size.y) * 0.42
	var font := UiTheme.font(UiTheme.FONT_UI)
	_board.draw_circle(ctr, r * 1.18, Color("14100c"))
	var step := TAU / 20.0
	for i in 20:
		var a0 := -PI / 2.0 - step / 2.0 + i * step
		var col := Color("8e1b1f") if i % 2 == 1 else Color("17191c")
		var pts := PackedVector2Array([ctr])
		for k in 9:
			var a := a0 + step * k / 8.0
			pts.append(ctr + Vector2(cos(a), sin(a)) * r)
		_board.draw_colored_polygon(pts, col)
		var am := a0 + step / 2.0
		var lp := ctr + Vector2(cos(am), sin(am)) * r * 1.09
		_board.draw_string(font, lp + Vector2(-16, 10), str(ORDER[i]), HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color("e8e0d0"))
	_board.draw_arc(ctr, r * 0.62, 0, TAU, 64, Color("b0a890"), 2)
	_board.draw_circle(ctr, r * 0.08, Color("1f6b2e"))
	_board.draw_circle(ctr, r * 0.04, Color("8e1b1f"))
	# Manchas de sangue.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 40:
		var p := ctr + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r)) * 1.1
		_board.draw_circle(p, rng.randf_range(2, 9), Color(0.45, 0.02, 0.03, 0.75))
	# Dardos.
	for idx in darts.size():
		var n: int = darts[idx]
		var i := ORDER.find(n)
		var am := -PI / 2.0 + i * step + (rng.randf_range(-0.2, 0.2) * step)
		var dist := r * (0.38 + 0.12 * (idx % 3))
		var tip := ctr + Vector2(cos(am), sin(am)) * dist
		var tail := tip + Vector2(46, -58)
		_board.draw_line(tip, tail, Color("c9c2b4"), 6)
		_board.draw_line(tail, tail + Vector2(18, -8), Color("3a6fb0"), 10)
		_board.draw_line(tail, tail + Vector2(4, -22), Color("3a6fb0"), 10)
		_board.draw_circle(tip, 6, Color("e8e0d0"))
