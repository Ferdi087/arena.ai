extends RefCounted
class_name WeatherAccess
## Globaler, zentral gekapselter Zugriff auf Wetter/Welt-Effekte – damit
## Systeme (Schal, Laubbläser, Rutschigkeit) NICHT gegen die Szenenstruktur
## gekoppelt sind. Fallback: windstill + trocken (#102: kein Crash ohne Welt).

static var _cache: Node = null

static func weather_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if _cache != null and is_instance_valid(_cache):
		return _cache
	_cache = tree.get_first_node_in_group("weather")
	return _cache

static func reset_cache() -> void:
	_cache = null

static func wind_at(_pos: Vector3) -> Vector3:
	var w := weather_node()
	if w == null:
		return Vector3.ZERO
	return w.call("wind_vector")

static func is_wet() -> bool:
	var w := weather_node()
	if w == null:
		return false
	return bool(w.call("is_wet_ground"))

static func wet_friction_mult(material: MaterialDef) -> float:
	if material == null:
		return 1.0
	return material.friction_wet_multiplier if is_wet() else 1.0

static func friction_at(pos: Vector3, dry_value: float) -> float:
	# Für Reifen/Floor-Materialien: trockener Wert * Nässe-Faktor.
	if is_wet():
		return dry_value * 0.62
	return dry_value

static func time_of_day() -> float:
	var w := weather_node()
	if w == null:
		return 12.0
	return float(w.call("hour"))

static func gust(strength_scale: float = 10.0) -> Vector3:
	var w := weather_node()
	if w == null or not w.has_method("gust_vector"):
		return Vector3.ZERO
	return w.call("gust_vector", strength_scale)

static func is_night() -> bool:
	var t := time_of_day()
	return t < 6.0 or t > 20.5
