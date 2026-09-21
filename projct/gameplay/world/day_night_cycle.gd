extends Node
class_name DayNightCycle
## 24h-Zyklus mit echter Auswirkung: Licht, Schatten, Laternen, Himmelsfarbe,
## Verkehrsdichte, Auftragsmodifikatoren (#25). Ein Zyklus = 12 Minuten Default.

@export var cycle_minutes: float = 12.0
@export var manual_hour: float = -1.0

var hour: float = 8.0
var sun: DirectionalLight3D = null
var street_lights: Array[OmniLight3D] = []
var _flicker_t: float = 0.0
var _env: Environment = null

signal hour_ticked(h: float)

func _ready() -> void:
	add_to_group("daynight")
	var world := get_parent().get_parent()
	if world != null and world is WorldRoot:
		_env = (world as WorldRoot).world_env.environment

func _process(delta: float) -> void:
	if manual_hour >= 0.0:
		hour = manual_hour
	else:
		hour = fmod(hour + delta * (24.0 / (cycle_minutes * 60.0)), 24.0)
	_apply()
	if _flicker_t > 0.0:
		_flicker_t = maxf(0.0, _flicker_t - delta)
	hour_ticked.emit(hour)

func set_hour(h: float) -> void:
	manual_hour = h
	hour = clampf(h, 0.0, 24.0)
	_apply()

func debug_set_hour(h: float) -> void:
	manual_hour = h

func debug_free_time() -> void:
	manual_hour = -1.0

func flicker(duration: float) -> void:
	_flicker_t = duration

func is_night() -> bool:
	return hour < 6.0 or hour > 20.5

func _apply() -> void:
	var t := hour / 24.0
	var sun_angle := (t - 0.25) * TAU # 6h=0 (Osten), 12h=oben
	if sun != null:
		sun.rotation_degrees = Vector3(-absf(sin(sun_angle)) * 0.0 - (90.0 - rad_to_deg(maxf(sin(sun_angle), 0.05))), rad_to_deg(sun_angle) * 0.5, 0.0)
		var elevation := sin(sun_angle)
		sun.light_energy = clampf(elevation, 0.0, 1.0) * 1.15 + 0.04
		var warm := 1.0 - clampf(absf(elevation), 0.0, 1.0)
		sun.light_color = Color(1.0, lerpf(1.0, 0.55, warm), lerpf(1.0, 0.35, warm))
	var night := 1.0 - clampf(sin(sun_angle) * 2.4, 0.0, 1.0)
	for lamp in street_lights:
		if is_instance_valid(lamp):
			var target_energy := 1.7 * night
			if _flicker_t > 0.0:
				target_energy *= randf_range(0.05, 1.0)
			lamp.light_energy = target_energy
	if _env != null:
		var day_sky := Color(0.42, 0.6, 0.85)
		var night_sky := Color(0.05, 0.06, 0.11)
		var dusk := Color(0.85, 0.45, 0.25)
		var mix_t := clampf(sin(sun_angle) * 2.0, 0.0, 1.0)
		var sky_col := night_sky.lerp(day_sky, mix_t)
		if mix_t > 0.02 and mix_t < 0.45:
			sky_col = sky_col.lerp(dusk, 1.0 - mix_t / 0.45)
		_env.ambient_light_energy = lerpf(0.12, 0.55, mix_t)
		if _env.background_mode == Environment.BG_SKY and _env.background_sky != null:
			var pm := _env.background_sky.sky_material as ProceduralSkyMaterial
			if pm != null:
				pm.sky_top_color = sky_col
				pm.sky_horizon_color = sky_col.lightened(0.18)
		_env.fog_light_color = sky_col.darkened(0.08)
