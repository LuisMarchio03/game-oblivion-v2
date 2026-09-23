class_name Interactable
extends Node3D
## Ponto de interação. O personagem ativo mais próximo (dentro de `radius`)
## vê o aviso e, ao apertar Interagir, dispara `action(ch)`.

signal interacted(ch: Character)

var prompt := "Examinar"
var who := "any"  # "any", "a" ou "b"
var radius := 1.4
var enabled := true
var one_shot := false
var action: Callable
var marker: Sprite3D
var deny_text := ""  # fala quando o personagem errado tenta


func _ready() -> void:
	add_to_group("interactable")


func setup_marker(height := 1.6) -> void:
	marker = Build.billboard(self, "glow", Vector3(0, height, 0), 0.004, 1, 0, Color(0.6, 0.8, 1.0, 0.9), false)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	marker.transparent = true
	var t := create_tween().set_loops()
	t.tween_property(marker, "modulate:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(marker, "modulate:a", 0.9, 0.9).set_trans(Tween.TRANS_SINE)


func can_use(ch: Character) -> bool:
	if not enabled or not is_visible_in_tree():
		return false
	return who == "any" or who == ch.who or deny_text != ""


func trigger(ch: Character) -> void:
	if who != "any" and who != ch.who:
		if deny_text != "":
			Ui.say([ch.who + ": " + deny_text])
		return
	if one_shot:
		disable()
	interacted.emit(ch)
	if action.is_valid():
		action.call(ch)


func disable() -> void:
	enabled = false
	if marker:
		marker.visible = false


func enable() -> void:
	enabled = true
	if marker:
		marker.visible = true
