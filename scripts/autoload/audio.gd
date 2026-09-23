extends Node
## Áudio: barramentos Music/SFX, efeitos com cache e duas camadas em loop
## (música e ambiente) com crossfade. Arquivo ausente é ignorado em silêncio.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 12

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _layers := {}  # "music"/"ambience" -> {player, name}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for layer in ["music", "ambience"]:
		_layers[layer] = {"player": null, "name": ""}
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	_set_bus("Master", s["master"])
	_set_bus("Music", s["music"])
	_set_bus("SFX", s["sfx"])


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _load(path_no_ext: String) -> AudioStream:
	if _cache.has(path_no_ext):
		return _cache[path_no_ext]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(path_no_ext + ext):
			stream = load(path_no_ext + ext)
			break
	_cache[path_no_ext] = stream
	return stream


func has_sfx(sfx_name: String) -> bool:
	return _load(SFX_DIR + sfx_name) != null


## Toca um efeito. Retorna o player usado (ou null se o arquivo não existe).
func sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var stream := _load(SFX_DIR + sfx_name)
	if stream == null:
		return null
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	return p


## Efeito com variação: escolhe entre nome_1..nome_n e varia o tom.
func sfx_var(base: String, count: int, volume_db := 0.0) -> void:
	sfx("%s_%d" % [base, randi_range(1, count)], volume_db, randf_range(0.92, 1.08))


## Efeito posicional preso a um nó 3D.
func sfx_at(sfx_name: String, node: Node3D, volume_db := 0.0, max_distance := 30.0) -> void:
	var stream := _load(SFX_DIR + sfx_name)
	if stream == null or node == null or not node.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 6.0
	node.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func music(track: String, fade := 2.0, volume_db := 0.0) -> void:
	_play_layer("music", track, fade, volume_db)


func ambience(track: String, fade := 2.0, volume_db := 0.0) -> void:
	_play_layer("ambience", track, fade, volume_db)


func stop_music(fade := 2.0) -> void:
	_play_layer("music", "", fade, 0.0)


func stop_ambience(fade := 2.0) -> void:
	_play_layer("ambience", "", fade, 0.0)


func stop_all(fade := 1.5) -> void:
	stop_music(fade)
	stop_ambience(fade)


func _play_layer(layer: String, track: String, fade: float, volume_db: float) -> void:
	var info: Dictionary = _layers[layer]
	if info["name"] == track and info["player"] != null:
		return
	var old: AudioStreamPlayer = info["player"]
	if old != null:
		var t := create_tween()
		t.tween_property(old, "volume_db", -60.0, max(fade, 0.05))
		t.tween_callback(old.queue_free)
	info["player"] = null
	info["name"] = track
	if track == "":
		return
	var stream := _load(MUSIC_DIR + track)
	if stream == null:
		return
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.stream = stream
	p.volume_db = -60.0
	add_child(p)
	p.play()
	create_tween().tween_property(p, "volume_db", volume_db, max(fade, 0.05))
	info["player"] = p
