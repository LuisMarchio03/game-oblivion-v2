class_name RulesPanel
extends ModalPanel
## Regras (adaptadas da tela original).


func _init() -> void:
	title = ""
	panel_size = Vector2(1300, 780)
	closable = false


func _build(c: VBoxContainer) -> void:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.add_theme_font_override("normal_font", UiTheme.font(UiTheme.FONT_SERIF))
	rt.add_theme_font_override("bold_font", UiTheme.font(UiTheme.FONT_SERIF))
	rt.add_theme_font_size_override("normal_font_size", 40)
	rt.add_theme_font_size_override("bold_font_size", 40)
	rt.text = """- Use fones para melhor imersão.

- Jogue em tela cheia.

- O papel e a caneta são seus amigos. O que um de vocês lê ou anota, o outro não vê. Cada um tem o próprio diário ([b]%s[/b]).

- [b]%s[/b] troca entre os dois. Algumas portas só se abrem com os dois juntos.

- Travou? O diário tem dicas.""" % [Ui.key_label("journal"), Ui.key_label("switch")]
	c.add_child(rt)
	var luck := UiTheme.label("BOA SORTE!  (vai precisar)", 40, UiTheme.INK, UiTheme.FONT_LOGO)
	luck.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(luck)
	add_footer_button("Entendi", func(): close(true))
