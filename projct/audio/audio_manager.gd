extends Node
## Audio Manager (Autoload "Sfx") – poolbasierte 3D-SFX + Material-Mapping (#78).
## Sound-Auswahl: (MaterialDef.impact_sound_set + Masse/Velocity) -> variiert
## Lautstärke/Pitch. Dateien: res://audio/sfx/*.wav (im Repo generiert, s. tools/).
## Fehlende Datei = Warnung EINMAL + Stille, kein Crash (#102).

const POOL_SIZE := 24

var _pool: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _stream_cache: Dictionary[StringName, AudioStream] = {}
var _missing: Dictionary[String, bool] = {}
var _master_ready: bool = false

func _ready() -> void:
	# Busse: Master/Sfx/Music – falls im Projekt nicht angelegt, ignorieren wir
	# (Default "Master" existiert immer).
	for bus in ["Sfx", "Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			_create_bus(bus)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Sfx" if AudioServer.get_bus_index("Sfx") >= 0 else "Master"
		p.max_db_range = 14.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_distance = 60.0
		p.unit_db = 0.0
		add_child(p)
		_pool.append(p)
	_master_ready = true

func _create_bus(bus_name: String) -> void:
	# Autoload darf Busse zur Laufzeit anlegen – persistent speichern wir nicht
	# (Layout ist klein; wer es will: default_bus_layout.tres anlegen).
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	if bus_name == "Music":
		AudioServer.set_bus_volume_db(idx, -6.0)

# ------------------------------------------------------------------- API --

func impact_at(pos: Vector3, sound_set: StringName, strength: float = 1.0, material_hint: MaterialDef = null) -> void:
	var set_name: StringName = sound_set
	if material_hint != null:
		set_name = material_hint.impact_sound_set
	var stream := _load_stream(_variant_key(set_name, strength))
	if stream == null:
		stream = _load_stream(set_name)
	if stream == null:
		return
	var p := _acquire()
	p.stream = stream
	p.global_position = pos
	p.volume_db = lerpf(-14.0, 4.0, clampf(strength, 0.0, 1.5))
	p.pitch_scale = clampf(randf_range(0.9, 1.12) * lerpf(1.2, 0.75, clampf(strength / 1.4, 0.0, 1.0)), 0.6, 1.5)
	p.play()

func ui_click() -> void:
	var s := _load_stream(&"ui_click")
	if s != null:
		var pl := AudioStreamPlayer.new()
		pl.stream = s
		pl.bus = "Sfx" if AudioServer.get_bus_index("Sfx") >= 0 else "Master"
		pl.play()
		pl.finished.connect(pl.queue_free)

func ui_confirm() -> void:
	var s := _load_stream(&"ui_confirm")
	if s != null:
		var pl := AudioStreamPlayer.new()
		pl.stream = s
		pl.bus = "Sfx" if AudioServer.get_bus_index("Sfx") >= 0 else "Master"
		pl.play()
		pl.finished.connect(pl.queue_free)

func play_world(pos: Vector3, key: StringName, volume_db: float = 0.0) -> void:
	var s := _load_stream(key)
	if s == null:
		return
	var p := _acquire()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.play()

func one_shot(key: StringName, volume_db: float = -4.0) -> void:
	var s := _load_stream(key)
	if s == null:
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = s
	pl.volume_db = volume_db
	pl.bus = "Sfx" if AudioServer.get_bus_index("Sfx") >= 0 else "Master"
	add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)

# ---------------------------------------------------------------- internal --

func _variant_key(set_name: StringName, strength: float) -> StringName:
	var bucket := "heavy" if strength > 1.0 else ("soft" if strength < 0.5 else "mid")
	return StringName("%s_%s" % [String(set_name), bucket])

func _load_stream(key: StringName) -> AudioStream:
	if _stream_cache.has(key):
		return _stream_cache[key]
	var candidates := [
		"res://audio/sfx/%s.wav" % String(key),
		"res://audio/sfx/%s.ogg" % String(key),
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			if s != null:
				_stream_cache[key] = s
				return s
	if not _missing.has(String(key)):
		_missing[String(key)] = true
		push_warning("Sfx: Sounddatei fehlt (%s) – Stille statt Crash." % String(key))
	return null

func _acquire() -> AudioStreamPlayer3D:
	var start := _next
	for i in POOL_SIZE:
		var idx := (start + i) % POOL_SIZE
		var p := _pool[idx]
		if not p.playing:
			_next = (idx + 1) % POOL_SIZE
			return p
	# alle belegt: frechen Reuse-Plan (ältester wird gekappt)
	var p2 := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	if p2.playing:
		p2.stop()
	return p2

func stop_all_in_area(pos: Vector3, radius: float) -> void:
	for p in _pool:
		if p.playing and p.global_position.distance_to(pos) < radius:
			p.stop()
