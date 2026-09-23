class_name CreditsPanel
extends ModalPanel
## Créditos.


func _init() -> void:
	title = "CRÉDITOS"
	panel_size = Vector2(1100, 760)


func _build(c: VBoxContainer) -> void:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.add_theme_font_size_override("normal_font_size", 34)
	rt.text = """[center][b]OBLIVION[/b]

Ideia, roteiro e enigmas originais
[color=#9fc3ee]Luis Marchio[/color]
Sistemas de Informação — 2023

Remake em Godot 4 (HD-2D)
Arte em pixel, áudio e código gerados para esta versão

Fontes: VT323, Special Elite, Caveat, Michroma, IM Fell English (OFL/Apache)

[color=#8193ab]Esteja no controle da sua vida.[/color][/center]"""
	c.add_child(rt)
