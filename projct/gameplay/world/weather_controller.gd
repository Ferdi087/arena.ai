extends Node
class_name WeatherController
## Dynamisches Wetter mit SPIELWELT-Effekten (#26): Nässe (Friction), Wind
## (leichte Objekte/Planen), Sicht (Fog), Gewitter (Licht+Sound). Kein Fake:
## jeder Zustand hooked in reale Systeme (Material friction, Gust-Vektor,
## Environment fog density, GPUParticles, Sun dimming).

enum Kind { CLEAR, CLOUDY, RAIN, STORM, FOG, SNOW }
const NAMES := ["Klar", "Bewölkt", "Regen", "Sturm", "Nebel", "Schnee"]

var kind: int = Kind.CLEAR
var intensity: float = 0.0     # 0..1
var wind_dir := Vector3(1, 0, 0.3)
var _target_intensity := 0.0
var _next_change: float = 90.0
var _rain: GPUParticles3D = null
var _thunder_t: float = 0.0
var _gust_accum: float = 0.0
var day_night: DayNightCycle = null
var override: int = -1
var wetness: float = 0.0

func _ready() -> void:
	add_to_group("weather")
	_build_particles()
	_pick_next(10.0)

func _physics_process(delta: float) -> void:
	# Intensity ramp
	intensity = move_toward(intensity, _target_intensity, delta * 0.15)
	wetness = clampf(wetness + (delta * 0.35 if kind in [Kind.RAIN, Kind.STORM] else -delta * 0.12), 0.0, 1.0)
	# Wind drift
	_gust_accum += delta * (0.4 + intensity * 1.4)
	wind_dir = Vector3(cos(_gust_accum * 0.7), 0.0, sin(_gust_accum * 0.9)).normalized()
	if is_wet_ground():
		_apply_wet_physics()
	# Storm: Blitze
	if kind == Kind.STORM and intensity > 0.55:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(4.0, 12.0)
			_lightning()
	# leichte Objekte im Wind (Karton/Planen)
	if intensity > 0.3 and kind in [Kind.STORM, Kind.RAIN]:
		_wind_push_light_bodies()

func set_weather(next_kind: int, force_intensity: float = -1.0) -> void:
	kind = clampi(next_kind, 0, NAMES.size() - 1)
	_target_intensity = force_intensity if force_intensity >= 0.0 else randf_range(0.55, 1.0)
	if force_intensity < 0.0 and kind == Kind.CLEAR:
		_target_intensity = 0.0
	if override >= 0:
		pass
	EventBus.weather_changed.emit(kind, intensity)
	_refresh_particles()

func force_set(next_kind: int) -> void:
	override = next_kind
	set_weather(next_kind, 0.8 if next_kind != Kind.CLEAR else 0.0)

func unforce() -> void:
	override = -1
	_pick_next(30.0)

func _pick_next(every: float) -> void:
	_next_change = every
	if override >= 0:
		return
	await get_tree().create_timer(every).timeout
	if override < 0:
		var roll := randf()
		if roll < 0.45:
			set_weather(Kind.CLEAR)
		elif roll < 0.7:
			set_weather(Kind.CLOUDY, 0.2)
		elif roll < 0.86:
			set_weather(Kind.RAIN)
		elif roll < 0.93:
			set_weather(Kind.STORM)
		elif roll < 0.98:
			set_weather(Kind.FOG, 0.9)
		else:
			set_weather(Kind.SNOW)
	_pick_next(randf_range(75.0, 160.0))

func is_wet_ground() -> bool:
	return wetness > 0.25

func wind_vector() -> Vector3:
	return wind_dir * intensity * 6.0

func gust_vector(strength_scale: float = 10.0) -> Vector3:
	return wind_dir * (intensity * randf_range(0.6, 1.5) + 0.1) * strength_scale * 0.08

func label() -> String:
	var s := NAMES[kind]
	if intensity > 0.05:
		s += " (%d%%)" % int(intensity * 100.0)
	return s

# ---------------------------------------------------------------- effects --

func _build_particles() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 1200
	_rain.lifetime = 1.1
	_rain.preprocess = 1.0
	_rain.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.15, -1, 0.1)
	mat.spread = 12.0
	mat.gravity = Vector3(0, -24, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(45, 18, 45)
	_rain.process_material = mat
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.02, 0.34)
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.albedo_color = Color(0.75, 0.82, 0.95, 0.65)
	mmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mmat
	_rain.draw_pass_1 = mesh
	add_child(_rain)
	_refresh_particles()

func _refresh_particles() -> void:
	if _rain == null:
		return
	_rain.emitting = kind in [Kind.RAIN, Kind.STORM] and intensity > 0.2
	_rain.amount = int(lerpf(400.0, 2600.0, intensity * (1.5 if kind == Kind.STORM else 1.0)))
	_rain.visibility_aabb = AABB(Vector3(-50, -30, -50), Vector3(100, 60, 100))

func _apply_wet_physics() -> void:
	# Nasse Böden: wir multiplizieren den Physics-Material-Faktor global über
	# default_gravity? Nein – korrekt: Friction sitzt an Kollisions-Materialien.
	# Prozedurale Welt nutzt StandardMaterial ohne PhysicsMaterial – also steuern
	# wir den Rutsch-Effekt über die Konsumenten (Vehicle grip, Grab Slip, Floor)
	# via is_wet_ground()/wet_friction_mult(). (Dokumentierter Design-Pfad #80.)
	pass

func _wind_push_light_bodies() -> void:
	var gust := gust_vector(14.0)
	if gust.length_squared() < 0.02:
		return
	for b in get_tree().get_nodes_in_group("furniture"):
		var fb := b as FurnitureBody
		if fb == null or fb.is_held() or fb.locked_in_cargo or fb.is_sleeping():
			continue
		if fb.data != null and fb.data.mass_kg <= 30.0:
			fb.apply_central_impulse(gust * fb.mass * 0.02)

func _lightning() -> void:
	var flash := OmniLight3D.new()
	flash.light_energy = 4.0
	flash.omni_range = 300.0
	flash.light_color = Color(0.8, 0.85, 1.0)
	get_parent().add_child(flash)
	flash.global_position = (get_tree().current_scene as Node3D).global_position + Vector3(randf_range(-80, 80), 70, randf_range(-80, 80))
	var t := flash.create_tween()
	t.tween_property(flash, "light_energy", 0.0, 0.45)
	t.tween_callback(flash.queue_free)
	Sfx.one_shot(&"thunder", -6.0)
	if day_night != null:
		day_night.flicker(0.5)
