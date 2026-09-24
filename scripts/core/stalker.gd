class_name Stalker
extends CharacterBody3D
## O Esquecido: figura alta, com a roupa de A e a mão de sangue no rosto.
## Estados:
##   HIDDEN  fora de cena
##   STAND   parado, olhando (aparições roteirizadas)
##   PATROL  anda pelos pontos de `path` em loop e persegue quem enxergar
##   CHASE   persegue `target` enquanto o vê; perde o rastro se o alvo se esconder
##   STALK   anda devagar até `target`, sem precisar enxergar (quem ficou sozinho)
## Quem é alcançado dispara `caught(ch)`; a fase decide o que acontece.

signal caught(ch: Character)

enum { HIDDEN, STAND, PATROL, CHASE, STALK, SEARCH }

const FRAME_STAND := 0
const FRAME_REVEAL := 3

var party: Party
var sprite: Sprite3D
var state := HIDDEN
var path: Array = []
var walk_speed := 1.5
var chase_speed := 3.5  # entre andar (3.0) e correr (5.2): correndo dá para fugir
var stalk_speed := 0.9
var sight := 7.5
var catch_radius := 0.8
var target: Character
var hunting := true  # em PATROL, persegue quem enxergar

var _path_i := 0
var _lost_t := 0.0
var _last_seen := Vector3.ZERO
var _step_t := 0.0
var _walk_frame := 1
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _catch_cool := 0.0
var _gravity := 18.0
var _fade: Tween


func setup(p_party: Party) -> void:
	party = p_party
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 2.0
	cs.shape = cap
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	sprite = Build.billboard(self, "forgotten", Vector3.ZERO, 0.029, 4, FRAME_STAND, Color(0.85, 0.82, 0.9))
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.offset = Vector2(0, 40)
	var shadow := Build.blob_shadow(self, 0.5)
	shadow.modulate = Color(0, 0, 0, 0.9)
	visible = false


# --- Controle roteirizado -------------------------------------------------------------

## Surge em `pos` (com um estalo de luz opcional).
func appear(pos: Vector3, fade := 0.4) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	visible = true
	sprite.frame = FRAME_STAND
	_tween_alpha(1.0, fade)
	state = STAND


func vanish(fade := 0.6) -> void:
	if not visible:
		state = HIDDEN
		return
	state = HIDDEN
	target = null
	_tween_alpha(0.0, fade)
	await get_tree().create_timer(fade + 0.05, false).timeout
	if state == HIDDEN:
		visible = false


func stand() -> void:
	state = STAND
	velocity = Vector3.ZERO
	sprite.frame = FRAME_STAND


## Mostra o rosto (a mão abaixa).
func reveal() -> void:
	sprite.frame = FRAME_REVEAL


func patrol(points: Array, start_index := 0) -> void:
	path = points
	_path_i = clampi(start_index, 0, maxi(points.size() - 1, 0))
	if not visible:
		appear(points[_path_i])
	state = PATROL


func chase(ch: Character) -> void:
	target = ch
	_lost_t = 0.0
	state = CHASE
	Audio.sfx("dread_sting", -8.0)


func stalk(ch: Character, speed := 0.9) -> void:
	target = ch
	stalk_speed = speed
	state = STALK


## Anda até `pos` e para (cena roteirizada).
func walk_to(pos: Vector3, speed := 1.5) -> void:
	state = STAND
	var start := global_position
	var flat := Vector3(pos.x, start.y, pos.z)
	var t := create_tween()
	var dist := start.distance_to(flat)
	t.tween_method(func(p: Vector3):
		global_position = p
		_animate_walk(get_physics_process_delta_time()), start, flat, max(dist / speed, 0.05))
	await t.finished
	sprite.frame = FRAME_STAND


func is_active() -> bool:
	return state != HIDDEN and visible


func _tween_alpha(a: float, time: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(sprite, "modulate:a", a, max(time, 0.01))


# --- Laço ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_catch_cool = max(0.0, _catch_cool - delta)
	if state == HIDDEN or party == null:
		return
	if not Game.can_control():
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	match state:
		STAND:
			velocity.x = 0.0
			velocity.z = 0.0
		PATROL:
			_patrol(delta)
			_look_for_prey()
		CHASE:
			_chase(delta)
		STALK:
			if target == null or not target.visible:
				stand()
			else:
				_move_toward(target.global_position, stalk_speed, delta)
				_check_catch(target)
		SEARCH:
			if _move_toward(_last_seen, walk_speed, delta):
				_lost_t += delta
				if _lost_t > 2.0:
					_resume_patrol()
			_look_for_prey()
	move_and_slide()


func _patrol(delta: float) -> void:
	if path.is_empty():
		stand()
		return
	var goal: Vector3 = path[_path_i]
	if _move_toward(goal, walk_speed, delta):
		_path_i = (_path_i + 1) % path.size()
	# Preso numa quina: pula para o próximo ponto.
	if global_position.distance_to(_last_pos) < 0.01 * walk_speed:
		_stuck_t += delta
		if _stuck_t > 1.2:
			_stuck_t = 0.0
			_path_i = (_path_i + 1) % path.size()
	else:
		_stuck_t = 0.0
	_last_pos = global_position


func _chase(delta: float) -> void:
	if target == null or not target.visible:
		_resume_patrol()
		return
	if target.hidden or not _can_see(target):
		_lost_t += delta
		if _lost_t > (1.0 if target.hidden else 3.0):
			_lost_t = 0.0
			state = SEARCH
			return
	else:
		_lost_t = 0.0
		_last_seen = target.global_position
	_move_toward(_last_seen if _lost_t > 0.0 else target.global_position, chase_speed, delta)
	_check_catch(target)


func _resume_patrol() -> void:
	target = null
	_lost_t = 0.0
	if path.is_empty():
		stand()
		return
	# Volta pelo ponto de patrulha mais próximo.
	var best := 0
	var best_d := INF
	for i in path.size():
		var d: float = global_position.distance_to(path[i])
		if d < best_d:
			best_d = d
			best = i
	_path_i = best
	state = PATROL


func _look_for_prey() -> void:
	if not hunting:
		return
	for ch in [party.a, party.b]:
		if ch.visible and not ch.hidden and _can_see(ch, true):
			chase(ch)
			return


## Linha de visão (paredes bloqueiam). Com `cone`, só enxerga para a frente ou bem de perto.
func _can_see(ch: Character, cone := false) -> bool:
	var to := ch.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > sight or ch.hidden:
		return false
	if cone and d > 2.2:
		var fwd := Vector3(velocity.x, 0, velocity.z)
		if fwd.length() > 0.1 and fwd.normalized().dot(to.normalized()) < 0.35:
			return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), ch.global_position + Vector3(0, 1.1, 0), 1)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


## Anda no plano até `goal`. Devolve true ao chegar.
func _move_toward(goal: Vector3, speed: float, delta: float) -> bool:
	var d := goal - global_position
	d.y = 0.0
	if d.length() < 0.25:
		velocity.x = 0.0
		velocity.z = 0.0
		sprite.frame = FRAME_STAND
		return true
	var v := d.normalized() * speed
	velocity.x = v.x
	velocity.z = v.z
	_animate_walk(delta)
	return false


func _animate_walk(delta: float) -> void:
	_step_t += delta
	var period := 0.55 if state != CHASE else 0.32
	if _step_t >= period:
		_step_t = 0.0
		_walk_frame = 2 if _walk_frame == 1 else 1
		sprite.frame = _walk_frame
		Audio.sfx_at("stalker_step", self, -6.0, 18.0)


func _check_catch(ch: Character) -> void:
	if _catch_cool > 0.0 or ch.hidden:
		return
	var d := Vector2(ch.global_position.x - global_position.x, ch.global_position.z - global_position.z).length()
	if d <= catch_radius:
		_catch_cool = 3.0
		stand()
		caught.emit(ch)


## Distância no plano até o personagem ativo (para o medo na tela).
func distance_to_active() -> float:
	if party == null or party.active == null or not is_active():
		return INF
	var p := party.active.global_position
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
