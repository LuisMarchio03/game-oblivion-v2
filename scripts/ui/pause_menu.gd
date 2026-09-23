class_name PauseMenu
extends ModalPanel
## Menu de pausa.


func _init() -> void:
	title = "PAUSA"
	panel_size = Vector2(620, 560)


func _build(c: VBoxContainer) -> void:
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(UiTheme.button("Continuar", func(): close(null)))
	c.add_child(UiTheme.button("Diário", func():
		close(null)
		Ui.call_deferred("open_panel", JournalPanel.new())))
	c.add_child(UiTheme.button("Opções", func(): await Ui.open_panel(OptionsPanel.new())))
	c.add_child(UiTheme.button("Reiniciar capítulo", func():
		close(null)
		Game.start_chapter(Game.chapter)))
	c.add_child(UiTheme.button("Menu principal", func():
		close(null)
		Game.go_to_menu()))
	closable = true


func _ready() -> void:
	super._ready()
	# Sem botão "Fechar" duplicado: "Continuar" já fecha.
	for b in _footer.get_children():
		b.queue_free()
