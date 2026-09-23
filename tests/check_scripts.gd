extends Node
## Carrega todos os scripts e cenas para achar erros de parse/compilação.
## Uso: godot --headless --path . res://tests/check_scripts.tscn

var _fail := 0


func _ready() -> void:
	_scan("res://scripts")
	_scan("res://scenes")
	print("CHECK: %d falha(s)" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var p := dir + "/" + f
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			var r = load(p)
			if r == null or (r is GDScript and not r.can_instantiate()):
				print("FALHA: ", p)
				_fail += 1
	for sub in d.get_directories():
		_scan(dir + "/" + sub)
