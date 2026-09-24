extends Node
## Estado global: nomes, capítulo atual, diário e bloco de notas por personagem,
## flags de enigmas, save e opções.

signal journal_changed
signal objective_changed(text: String)
signal settings_changed
signal puzzle_failed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"

const CHAPTERS := [
	{"id": "ch01", "title": "A Clareira"},
	{"id": "ch02", "title": "O Cemitério"},
	{"id": "ch03", "title": "A Capela"},
	{"id": "ch04", "title": "Dois Caminhos"},
	{"id": "ch05", "title": "A Casa"},
	{"id": "ch06", "title": "O Sótão"},
	{"id": "ch07", "title": "O Saguão"},
	{"id": "ch08", "title": "Ascendência"},
	{"id": "ch09", "title": "Quatro e Quinze"},
]

var name_a := "Ana"
var name_b := "Leo"
var number_a := 17
var number_b := 29
var chapter := 0
var flags := {}
var journal := {"a": [], "b": []}
var notepad := {"a": "", "b": ""}
var objective := ""
var chapter_hints: Array = []
var hints_shown := 0
var play_time := 0.0
## Lembranças da noite do acidente achadas (ids), uma escondida em cada capítulo de 1 a 8.
var memories: Array = []
## Final escolhido no capítulo 9: "forget", "remember" ou "hope" (lembrou com as 8 lembranças).
var ending := ""

const MEMORY_TOTAL := 8

var settings := {
	"master": 0.8,
	"music": 0.7,
	"sfx": 0.8,
	"fullscreen": false,
	"text_speed": 1.0,
	"quality": 1,
	"brightness": 1.0,
}

var _input_lock := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


# --- Controle -----------------------------------------------------------------

func lock_input() -> void:
	_input_lock += 1


func unlock_input() -> void:
	_input_lock = max(0, _input_lock - 1)


func can_control() -> bool:
	return _input_lock == 0 and not get_tree().paused


func reset_input_lock() -> void:
	_input_lock = 0


# --- Nomes --------------------------------------------------------------------

func char_name(who: String) -> String:
	return name_a if who == "a" else name_b


func char_number(who: String) -> int:
	return number_a if who == "a" else number_b


# --- Diário -------------------------------------------------------------------

## Adiciona um documento ao diário do personagem. `doc` é um Dictionary com
## id, title, body e, opcionalmente, style e image. Retorna true se era novo.
func add_doc(who: String, doc: Dictionary) -> bool:
	for d in journal[who]:
		if d.get("id") == doc.get("id"):
			return false
	journal[who].append(doc.duplicate(true))
	journal_changed.emit()
	return true


func has_doc(who: String, id: String) -> bool:
	for d in journal[who]:
		if d.get("id") == id:
			return true
	return false


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func set_chapter_hints(hints: Array) -> void:
	chapter_hints = hints
	hints_shown = 0


func next_hint() -> String:
	if chapter_hints.is_empty():
		return ""
	hints_shown = min(hints_shown + 1, chapter_hints.size())
	return chapter_hints[hints_shown - 1]


# --- Lembranças ------------------------------------------------------------------

## Guarda uma lembrança. Retorna true se era nova.
func add_memory(id: String) -> bool:
	if memories.has(id):
		return false
	memories.append(id)
	save_game()
	return true


func has_memory(id: String) -> bool:
	return memories.has(id)


func all_memories() -> bool:
	return memories.size() >= MEMORY_TOTAL


# --- Flags --------------------------------------------------------------------

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


# --- Fluxo de jogo --------------------------------------------------------------

func new_game(a: String, b: String) -> void:
	name_a = a.strip_edges() if a.strip_edges() != "" else "Ana"
	name_b = b.strip_edges() if b.strip_edges() != "" else "Leo"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	number_a = rng.randi_range(10, 99)
	number_b = rng.randi_range(10, 99)
	while number_b == number_a:
		number_b = rng.randi_range(10, 99)
	chapter = 0
	flags = {}
	journal = {"a": [], "b": []}
	notepad = {"a": "", "b": ""}
	objective = ""
	play_time = 0.0
	memories = []
	ending = ""


func chapter_scene(index: int) -> String:
	return "res://scenes/levels/%s.tscn" % CHAPTERS[index]["id"]


func start_chapter(index: int) -> void:
	chapter = index
	flags = {}
	chapter_hints = []
	hints_shown = 0
	save_game()
	reset_input_lock()
	get_tree().paused = false
	Ui.change_scene(chapter_scene(index))


func next_chapter() -> void:
	if chapter + 1 >= CHAPTERS.size():
		Ui.change_scene("res://scenes/ui/ending.tscn")
	else:
		start_chapter(chapter + 1)


func go_to_menu() -> void:
	reset_input_lock()
	get_tree().paused = false
	Ui.change_scene("res://scenes/main.tscn")


# --- Save -----------------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": 1,
		"name_a": name_a, "name_b": name_b,
		"number_a": number_a, "number_b": number_b,
		"chapter": chapter,
		"journal": journal,
		"notepad": notepad,
		"play_time": play_time,
		"memories": memories,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	name_a = data.get("name_a", "Ana")
	name_b = data.get("name_b", "Leo")
	number_a = int(data.get("number_a", 17))
	number_b = int(data.get("number_b", 29))
	chapter = clampi(int(data.get("chapter", 0)), 0, CHAPTERS.size() - 1)
	journal = data.get("journal", {"a": [], "b": []})
	if not journal.has("a"):
		journal["a"] = []
	if not journal.has("b"):
		journal["b"] = []
	var np = data.get("notepad", {})
	if typeof(np) == TYPE_STRING:
		# Save antigo: bloco único vai para A.
		np = {"a": np, "b": ""}
	notepad = {"a": str(np.get("a", "")), "b": str(np.get("b", ""))}
	play_time = float(data.get("play_time", 0.0))
	memories = Array(data.get("memories", []))
	ending = ""
	return true


func save_notepad(who: String, text: String) -> void:
	notepad[who] = text
	save_game()


# --- Opções ---------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cfg.get_value("settings", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_volumes()
	settings_changed.emit()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


# --- Texto ----------------------------------------------------------------------

## Normaliza respostas: maiúsculas, sem acento, só letras e dígitos.
static func normalize(text: String) -> String:
	var map := {
		"Á": "A", "À": "A", "Â": "A", "Ã": "A", "Ä": "A",
		"É": "E", "È": "E", "Ê": "E", "Ë": "E",
		"Í": "I", "Ì": "I", "Î": "I", "Ï": "I",
		"Ó": "O", "Ò": "O", "Ô": "O", "Õ": "O", "Ö": "O",
		"Ú": "U", "Ù": "U", "Û": "U", "Ü": "U",
		"Ç": "C", "Ñ": "N",
	}
	var up := text.to_upper()
	var out := ""
	for c in up:
		if map.has(c):
			out += map[c]
		elif (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			out += c
	return out


static func matches(text: String, answers: Array) -> bool:
	var n := normalize(text)
	for a in answers:
		if n == normalize(str(a)):
			return true
	return false


# --- Input ----------------------------------------------------------------------

func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]], [JOY_BUTTON_DPAD_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]], [JOY_BUTTON_DPAD_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]], [JOY_BUTTON_DPAD_UP])
	_bind("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]], [JOY_BUTTON_DPAD_DOWN])
	_bind("run", [KEY_SHIFT], [], [], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("interact", [KEY_E, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER], [], [], [JOY_BUTTON_A])
	_bind("switch", [KEY_TAB], [], [], [JOY_BUTTON_Y])
	_bind("journal", [KEY_J], [], [], [JOY_BUTTON_BACK])
	_bind("pause", [KEY_ESCAPE], [], [], [JOY_BUTTON_START])
	_bind("cancel", [KEY_ESCAPE, KEY_BACKSPACE], [], [], [JOY_BUTTON_B])


func _bind(action: String, keys: Array, _mouse: Array, axes: Array, buttons: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for ax in axes:
		var j := InputEventJoypadMotion.new()
		j.axis = ax[0]
		j.axis_value = ax[1]
		InputMap.action_add_event(action, j)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
