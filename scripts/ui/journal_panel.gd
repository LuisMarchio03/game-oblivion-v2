class_name JournalPanel
extends ModalPanel
## Diário: documentos do personagem ativo, bloco de notas do personagem ativo e
## objetivo com dicas progressivas.

var _who := "a"
var _list: ItemList
var _notes: TextEdit
var _hints_box: VBoxContainer


func _init() -> void:
	panel_size = Vector2(1400, 860)


func _build(c: VBoxContainer) -> void:
	_who = Game.get_meta("active_who", "a")
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(tabs)

	# --- Documentos
	var docs := VBoxContainer.new()
	docs.name = "Diário de " + Game.char_name(_who)
	docs.add_theme_constant_override("separation", 12)
	tabs.add_child(docs)
	var other := "b" if _who == "a" else "a"
	var info := UiTheme.label("Só %s pode ler o que está aqui. O que %s encontrou fica com %s." % [Game.char_name(_who), Game.char_name(other), Game.char_name(other)], 26, UiTheme.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	docs.add_child(info)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.focus_mode = Control.FOCUS_ALL
	var entries: Array = Game.journal[_who]
	for d in entries:
		_list.add_item("  " + str(d.get("title", "Documento")))
	if entries.is_empty():
		_list.add_item("  (nada ainda)")
		_list.set_item_disabled(0, true)
	_list.item_activated.connect(_open_doc)
	_list.item_clicked.connect(func(i, _p, _b): _open_doc(i))
	docs.add_child(_list)

	# --- Bloco de notas
	var np := VBoxContainer.new()
	np.name = "Notas de " + Game.char_name(_who)
	tabs.add_child(np)
	var tip := UiTheme.label("Estas notas são só de %s. Para passar algo ao outro, use papel e caneta de verdade." % Game.char_name(_who), 26, UiTheme.INK_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	np.add_child(tip)
	_notes = TextEdit.new()
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.text = Game.notepad[_who]
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_notes.placeholder_text = "Escreva aqui..."
	_notes.add_theme_font_override("font", UiTheme.font(UiTheme.FONT_TYPED))
	_notes.add_theme_font_size_override("font_size", 28)
	np.add_child(_notes)

	# --- Objetivo
	var ob := VBoxContainer.new()
	ob.name = "Objetivo"
	ob.add_theme_constant_override("separation", 16)
	tabs.add_child(ob)
	var ch_i: int = Game.chapter
	ob.add_child(UiTheme.label("Capítulo %d — %s" % [ch_i + 1, Game.CHAPTERS[ch_i]["title"]], 36, UiTheme.INK_DIM))
	var obj := UiTheme.label(Game.objective if Game.objective != "" else "Explore.", 40)
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ob.add_child(obj)
	_hints_box = VBoxContainer.new()
	ob.add_child(_hints_box)
	_refresh_hints()
	if not Game.chapter_hints.is_empty():
		var hb := UiTheme.button("Pedir uma dica", func():
			Game.next_hint()
			_refresh_hints())
		hb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ob.add_child(hb)

	add_footer_button("Menu de pausa", func():
		_save_notes()
		close("pause"))


func _refresh_hints() -> void:
	for ch in _hints_box.get_children():
		ch.queue_free()
	for i in Game.hints_shown:
		var l := UiTheme.label("Dica %d: %s" % [i + 1, Game.chapter_hints[i]], 30, Color("9fc3ee"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hints_box.add_child(l)
	if Game.hints_shown >= Game.chapter_hints.size() and not Game.chapter_hints.is_empty():
		_hints_box.add_child(UiTheme.label("Não há mais dicas.", 26, UiTheme.INK_DIM))


func _open_doc(i: int) -> void:
	var entries: Array = Game.journal[_who]
	if i < 0 or i >= entries.size():
		return
	Audio.sfx("paper", -6.0)
	await Ui.open_panel(NoteView.new(entries[i]))
	_list.grab_focus()


func _save_notes() -> void:
	if _notes and _notes.text != Game.notepad[_who]:
		Game.save_notepad(_who, _notes.text)


func close(result: Variant = null) -> void:
	_save_notes()
	super.close(result)
	if result == "pause":
		Ui.call_deferred("open_panel", PauseMenu.new())
