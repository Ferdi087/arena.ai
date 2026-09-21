extends Node
## Scene Manager (Autoload "Scenes") – asynchroner Szenenwechsel mit Fade.
##
## Responsibility: Laden/Fade/Instanziierung großer Welt-Szenen. Nutzt
## ResourceLoader.load_threaded_request, damit große Stadt-/HQ-Szenen das
## Haupt-Backend beim Import nicht blockieren. Spielt Übergabe-Daten in
## Signale, nicht in Globals.
##
## Autoload-Begründung: Fade-Layer + Ladevorgang müssen den Szenenwechsel
## selbst überleben -> eigener CanvasLayer.

const FADE_TIME := 0.35

signal scene_loading_progress(fraction: float)
signal scene_loaded(scene_path: String)

var _canvas: CanvasLayer
var _fade: ColorRect
var _pending_callback: Callable = Callable()
var _loading: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_fade)

func change_scene(path: String, on_loaded: Callable = Callable(), _unused: bool = false) -> void:
	if _loading:
		push_warning("Scenes: change_scene während Ladevorgang ignoriert: %s" % path)
		return
	_loading = true
	_pending_callback = on_loaded
	_fade_to(1.0)
	var err := ResourceLoader.load_threaded_request(path, "PackedScene")
	if err != OK:
		push_warning("Scenes: threaded request nicht verfügbar (%d) – synchroner Fallback" % err)
		await _swap_to(path)
		return
	await _poll_load(path)

func reload_current_scene(on_loaded: Callable = Callable()) -> void:
	var path := get_tree().current_scene.scene_file_path
	if path.is_empty():
		return
	_pending_callback = on_loaded
	await change_scene(path)

func _poll_load(path: String) -> void:
	var max_seconds := 30.0
	var started := Time.get_ticks_msec()
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Scenes: Laden fehlgeschlagen: %s (Godot öffnet Notbehelf-Szene)" % path)
			await _swap_to("res://scenes/arenas/error_fallback.tscn")
			return
		var progress: Array = []
		ResourceLoader.load_threaded_get_status(path, progress)
		if progress.size() > 0:
			scene_loading_progress.emit(float(progress[0]))
		await get_tree().process_frame
		if (Time.get_ticks_msec() - started) / 1000.0 > max_seconds:
			push_error("Scenes: Timeout beim Laden von %s" % path)
			await _swap_to("res://scenes/arenas/error_fallback.tscn")
			return
	await _swap_to(path)

func _swap_to(path: String) -> void:
	var packed: PackedScene = ResourceLoader.load_threaded_get(path) \
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED \
		else load(path)
	var next_scene := packed.instantiate()
	var old := get_tree().current_scene
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	if old != null:
		old.queue_free()
	await get_tree().process_frame
	_fade_to(0.0)
	_loading = false
	if _pending_callback.is_valid():
		var cb := _pending_callback
		_pending_callback = Callable()
		cb.call()
	scene_loaded.emit(path)

func _fade_to(target_alpha: float) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if target_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", target_alpha, FADE_TIME)
	await tween.finished
