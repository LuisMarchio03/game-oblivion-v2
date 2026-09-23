extends Node
## Confere que os textos e códigos dos enigmas levam às respostas do DESIGN.
## Uso: godot --headless --path . res://tests/test_answers.tscn

var _fail := 0


func _ready() -> void:
	var ch6 = load("res://scripts/levels/ch06.gd")
	_eq(_decode(ch6, ch6.LETTER, [40, 34, 49, 32]), "NOME", "sótão: carta + placa de B")
	_eq(_decode(ch6, ch6.SONG, [4, 21, 14, 22]), "MEDO", "sótão: canção + placa de A")
	_eq(ch6.letter_at("DONT LEAVE ME", 4), "T", "sótão: exemplo do quadro")
	_eq(_caesar("SILENCIO", 3), "VLOHQFLR", "quarto: César +3")
	var red := 0
	for n in [20, 17, 6, 3, 19]:
		if DartboardView.is_red(n):
			red += n
	_eq(str(red), "42", "cozinha: soma dos dardos no vermelho")
	_eq(_morse(". ... --.- ..- . -.-. .-"), "ESQUECA", "portão: morse")
	_eq(Game.normalize("Esqueça!"), "ESQUECA", "normalização")
	_eq(str(Game.matches("#b19cd9", ["B19CD9"])), "true", "hex com #")
	_eq("%02X%02X%02X" % [177, 156, 217], "B19CD9", "lilás em hex")
	print("TESTES: %d falha(s)" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _decode(script, lines: Array, code: Array) -> String:
	var out := ""
	for i in code.size():
		out += script.letter_at(lines[i], code[i])
	return out


func _caesar(s: String, k: int) -> String:
	var out := ""
	for c in s:
		out += char((c.unicode_at(0) - 65 + k) % 26 + 65)
	return out


func _morse(s: String) -> String:
	var table := {".-": "A", "-...": "B", "-.-.": "C", "-..": "D", ".": "E", "..-.": "F", "--.": "G", "....": "H", "..": "I", ".---": "J", "-.-": "K", ".-..": "L", "--": "M", "-.": "N", "---": "O", ".--.": "P", "--.-": "Q", ".-.": "R", "...": "S", "-": "T", "..-": "U", "...-": "V", ".--": "W", "-..-": "X", "-.--": "Y", "--..": "Z"}
	var out := ""
	for tok in s.split(" "):
		out += table.get(tok, "?")
	return out


func _eq(got: String, want: String, label: String) -> void:
	if got == want:
		print("ok   ", label)
	else:
		_fail += 1
		print("FALHA ", label, ": ", got, " != ", want)
