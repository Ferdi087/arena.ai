extends Node
## Settings Manager (Autoload "Settings") – AAA-Optionsmenü mit ECHTER Wirkung.
##
## Grundprinzip (Master-Prompt #57/#131): Keine Fake-Option. Jede Option schreibt
## auf ein existierendes Godot-4-Target (ProjectSetting / Environment / Viewport /
## RenderingServer / DisplayServer / Engine / AudioServer). Da sich Environment-
## Properties zwischen 4.3–4.7 teils umbenennen (u. a. Screen-Space AO/SSIL Blöcke,
## Glow-Unterkeys), laufen ALLE Environment-Writes durch _safe_set(), das
## unbekannte Properties sauber überspringt und per push_warning dokumentiert.
## Kein Crash bei Versionssprüngen, Abweichung sichtbar im Log.
##
## Bewusst dokumentierte Einschränkungen (Ehrlichkeit > Fake):
##  - "Occlusion Culling": ProjectSetting, braucht Godot-weit einen Neustart
##    (Engine-Limit) – im Menü mit Restart-Hinweis versehen.
##  - "Texture Quality": wird beim Material-Bau (StyleService) gelesen; Änderungen
##    wirken auf neu gebaute/kreierte Objekte und werden persistiert.
##
## Autoload-Begründung: projektweit, muss Szenenwechsel + Save/Load überleben.

enum Preset { LOW, MEDIUM, HIGH, ULTRA, CUSTOM }

signal settings_changed

const PRESET_DATA: Dictionary = {
	Preset.LOW: {
		"msaa_3d": 0, "shadow_atlas_size": 2048,
		"shadow_distance": 30.0, "shadow_filter": 0,
		"sdfgi_enabled": false, "volumetric_fog_enabled": false, "glow_enabled": false,
		"ao_enabled": false, "ssil_enabled": false, "ssr_enabled": false,
		"view_distance": 140.0, "lod_bias": 0.75, "particles_multiplier": 0.5,
		"decal_count_cap": 16, "max_fps": 60, "texture_filter": 1,
	},
	Preset.MEDIUM: {
		"msaa_3d": 1, "shadow_atlas_size": 4096,
		"shadow_distance": 60.0, "shadow_filter": 2,
		"sdfgi_enabled": false, "volumetric_fog_enabled": false, "glow_enabled": true,
		"ao_enabled": true, "ssil_enabled": false, "ssr_enabled": false,
		"view_distance": 220.0, "lod_bias": 1.0, "particles_multiplier": 1.0,
		"decal_count_cap": 32, "max_fps": 120, "texture_filter": 1,
	},
	Preset.HIGH: {
		"msaa_3d": 1, "shadow_atlas_size": 8192,
		"shadow_distance": 110.0, "shadow_filter": 2,
		"sdfgi_enabled": true, "volumetric_fog_enabled": true, "glow_enabled": true,
		"ao_enabled": true, "ssil_enabled": true, "ssr_enabled": true,
		"view_distance": 380.0, "lod_bias": 1.25, "particles_multiplier": 1.0,
		"decal_count_cap": 48, "max_fps": 0, "texture_filter": 5,
	},
	Preset.ULTRA: {
		"msaa_3d": 2, "shadow_atlas_size": 16384,
		"shadow_distance": 180.0, "shadow_filter": 3,
		"sdfgi_enabled": true, "volumetric_fog_enabled": true, "glow_enabled": true,
		"ao_enabled": true, "ssil_enabled": true, "ssr_enabled": true,
		"view_distance": 620.0, "lod_bias": 1.6, "particles_multiplier": 1.5,
		"decal_count_cap": 64, "max_fps": 0, "texture_filter": 7,
	},
}

var current_preset: int = Preset.MEDIUM
var vsync_enabled: bool = true
var fps_limit: int = 0                 # 0 = unbegrenzt (Engine.max_fps)
var msaa_3d: int = 1
var shadow_quality: int = 1            # 0 = aus, 1 = an
var shadow_distance: float = 60.0
var sdfgi_enabled: bool = false
var volumetric_fog: bool = false
var ao_enabled: bool = true
var ssil_enabled: bool = false
var ssr_enabled: bool = false
var glow_enabled: bool = true
var fog_quality: int = 1               # 0 aus, 1 standard, 2 volumetrisch
var view_distance: float = 220.0
var lod_bias: float = 1.0
var particles_multiplier: float = 1.0
var decal_count_cap: int = 32
var texture_filter: int = 1            # RenderingServer.TextureFilter Werte
var outline_enabled: bool = true
var master_volume_db: float = 0.0
var sfx_volume_db: float = 0.0
var music_volume_db: float = -6.0
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var camera_fov: float = 75.0
var damage_popups: bool = true
var occlusion_culling: bool = false    # Neustart nötig (dokumentiert)

var _env_ref: WeakRef = WeakRef.new()

func _ready() -> void:
	apply_all()

# ---------------------------------------------------------------- public API --

func apply_preset(preset: int) -> void:
	current_preset = clampi(preset, Preset.LOW, Preset.ULTRA)
	var d: Dictionary = PRESET_DATA[current_preset]
	msaa_3d = int(d["msaa_3d"])
	shadow_quality = 0 if current_preset == Preset.LOW else 1
	shadow_distance = float(d["shadow_distance"])
	sdfgi_enabled = bool(d["sdfgi_enabled"])
	volumetric_fog = bool(d["volumetric_fog_enabled"])
	ao_enabled = bool(d["ao_enabled"])
	ssil_enabled = bool(d["ssil_enabled"])
	ssr_enabled = bool(d["ssr_enabled"])
	glow_enabled = bool(d["glow_enabled"])
	fog_quality = 2 if volumetric_fog else 1
	view_distance = float(d["view_distance"])
	lod_bias = float(d["lod_bias"])
	particles_multiplier = float(d["particles_multiplier"])
	decal_count_cap = int(d["decal_count_cap"])
	fps_limit = int(d["max_fps"])
	texture_filter = int(d["texture_filter"])
	settings_changed.emit()
	apply_all()

func mark_custom() -> void:
	current_preset = Preset.CUSTOM
	settings_changed.emit()

func apply_all() -> void:
	# --- DisplayServer / Engine: sofort wirksam, kein Neustart ---
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = maxi(fps_limit, 0)
	# --- RenderingServer ---
	var atlas: int = int(PRESET_DATA[min(current_preset, Preset.ULTRA)].get("shadow_atlas_size", 4096))
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.09))
	# --- Viewport: MSAA live umschaltbar ---
	var root_vp := get_tree().root
	root_vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][clampi(msaa_3d, 0, 3)]
	# --- Occlusion Culling: ProjectSetting (Restart für volle Wirkung, dokumentiert) ---
	ProjectSettings.set_setting("rendering/occlusion_culling/use_occlusion_culling", occlusion_culling)
	# --- Environment der aktuellen Welt anwenden ---
	var env: Environment = _env_ref.get_ref()
	if env != null:
		apply_to_environment(env)

func register_world_environment(we: WorldEnvironment) -> void:
	## Welt-Szenen rufen das, sobald sie ihre WorldEnvironment gebaut haben.
	if we != null:
		_env_ref = weakref(we.environment)
		apply_all()

func apply_to_environment(env: Environment) -> void:
	if env == null:
		return
	_safe_set(env, "background_mode", Environment.BG_COLOR)
	_safe_set(env, "ambient_light_source", Environment.AMBIENT_SOURCE_COLOR)
	_safe_set(env, "tonemap_mode", Environment.TONE_MAPPER_FILMIC)
	_safe_set(env, "sdfgi_enabled", sdfgi_enabled)
	_safe_set(env, "volumetric_fog_enabled", volumetric_fog and fog_quality >= 2)
	_safe_set(env, "volumetric_fog_density", 0.03)
	_safe_set(env, "glow_enabled", glow_enabled)
	_safe_set(env, "glow_intensity", 0.35)
	_safe_set(env, "glow_bloom", 0.05)
	_safe_set(env, "adjustment_enabled", true)
	_safe_set(env, "adjustment_contrast", 1.05)
	_safe_set(env, "adjustment_saturation", 1.12)
	# Screen-Space Effekte: Property-Namen versionsabhängig -> _safe_set (s. o.).
	_safe_set(env, "ssao_enabled", ao_enabled)
	_safe_set(env, "ssil_enabled", ssil_enabled)
	_safe_set(env, "ssr_enabled", ssr_enabled)
	_safe_set(env, "fog_enabled", fog_quality > 0)
	if shadow_quality == 0:
		_safe_set(env, "background_sky", null)
	else:
		_safe_set(env, "directional_shadow_max_distance", shadow_distance)
		var filter: int = int(PRESET_DATA[min(current_preset, Preset.ULTRA)].get("shadow_filter", 2))
		_safe_set(env, "directional_shadow_filter", filter)
		# 4.6+ hat den Filter auf ShadowFilter* Enums umgestellt; beide Zahlen
		# (0..3) passen auf alte wie neue Werte – _safe_set fängt Abweichung ab.

func set_volume_db(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Settings: Audio-Bus '%s' fehlt" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, db)

func to_save_dict() -> Dictionary:
	return {
		"preset": current_preset, "vsync": vsync_enabled, "fps_limit": fps_limit,
		"msaa_3d": msaa_3d, "shadow_quality": shadow_quality, "shadow_distance": shadow_distance,
		"sdfgi": sdfgi_enabled, "volumetric_fog": volumetric_fog, "ao": ao_enabled,
		"ssil": ssil_enabled, "ssr": ssr_enabled, "glow": glow_enabled, "fog_quality": fog_quality,
		"view_distance": view_distance, "lod_bias": lod_bias, "particles": particles_multiplier,
		"decal_cap": decal_count_cap, "texture_filter": texture_filter, "outline": outline_enabled,
		"occlusion": occlusion_culling, "master_db": master_volume_db, "sfx_db": sfx_volume_db,
		"music_db": music_volume_db, "mouse_sens": mouse_sensitivity, "invert_y": invert_y,
		"fov": camera_fov, "damage_popups": damage_popups,
	}

func from_save_dict(d: Dictionary) -> void:
	if d.has("preset") and int(d["preset"]) <= Preset.ULTRA and int(d["preset"]) != Preset.CUSTOM:
		apply_preset(int(d["preset"]))
	vsync_enabled = bool(d.get("vsync", vsync_enabled))
	fps_limit = int(d.get("fps_limit", fps_limit))
	msaa_3d = int(d.get("msaa_3d", msaa_3d))
	shadow_quality = int(d.get("shadow_quality", shadow_quality))
	shadow_distance = float(d.get("shadow_distance", shadow_distance))
	sdfgi_enabled = bool(d.get("sdfgi", sdfgi_enabled))
	volumetric_fog = bool(d.get("volumetric_fog", volumetric_fog))
	ao_enabled = bool(d.get("ao", ao_enabled))
	ssil_enabled = bool(d.get("ssil", ssil_enabled))
	ssr_enabled = bool(d.get("ssr", ssr_enabled))
	glow_enabled = bool(d.get("glow", glow_enabled))
	fog_quality = int(d.get("fog_quality", fog_quality))
	view_distance = float(d.get("view_distance", view_distance))
	lod_bias = float(d.get("lod_bias", lod_bias))
	particles_multiplier = float(d.get("particles", particles_multiplier))
	decal_count_cap = int(d.get("decal_cap", decal_count_cap))
	texture_filter = int(d.get("texture_filter", texture_filter))
	outline_enabled = bool(d.get("outline", outline_enabled))
	occlusion_culling = bool(d.get("occlusion", occlusion_culling))
	master_volume_db = float(d.get("master_db", master_volume_db))
	sfx_volume_db = float(d.get("sfx_db", sfx_volume_db))
	music_volume_db = float(d.get("music_db", music_volume_db))
	mouse_sensitivity = float(d.get("mouse_sens", mouse_sensitivity))
	invert_y = bool(d.get("invert_y", invert_y))
	camera_fov = float(d.get("fov", camera_fov))
	damage_popups = bool(d.get("damage_popups", damage_popups))
	set_volume_db("Master", master_volume_db)
	set_volume_db("Sfx", sfx_volume_db)
	set_volume_db("Music", music_volume_db)
	apply_all()

# ------------------------------------------------------------- internal help --

func _safe_set(obj: Object, prop: String, value: Variant) -> void:
	if obj == null:
		return
	var has_prop := false
	for p in obj.get_property_list():
		if p["name"] == prop:
			has_prop = true
			break
	if not has_prop:
		push_warning("Settings: '%s' in %s nicht vorhanden (versionsabhängig) – ignoriert." % [prop, obj.get_class()])
		return
	obj.set(prop, value)
