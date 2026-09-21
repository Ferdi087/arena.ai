extends Node
class_name SplitScreen
## Lokales Co-op: SubViewportContainer teilt den Screen, pro Spieler ein
## SubViewport mit geteiltem World3D. Die Spieler-Kamera bleibt Hauptcam
## (deaktiviert), ihre TRANSFORM wird via RemoteTransform3D auf die
## SubViewport-Cam gespiegelt -> Rigid-Kollisionsarm funktioniert weiter.

static var _instance: SplitScreen = null

static func attach(player: Player, index: int) -> void:
	var tree := player.get_tree()
	if _instance == null or not is_instance_valid(_instance):
		_instance = SplitScreen.new()
		_instance.name = "SplitScreenLayer"
		tree.root.add_child(_instance)
	_instance.call_deferred("_add_player_deferred", player, index)

static func is_active() -> bool:
	return _instance != null and is_instance_valid(_instance) and _instance._entries.size() >= 2

static func detach_all() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance._teardown()
		_instance.queue_free()
	_instance = null

var _entries: Array[Dictionary] = []
var _root_container: SubViewportContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root_container = SubViewportContainer.new()
	_root_container.name = "SViewportContainer"
	_root_container.stretch = true
	_root_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_container)
	var layer := _root_container.get_parent()
	if layer is CanvasLayer:
		pass
	# In eigener CanvasLayer-Ebene über dem Spiel:
	var cl := get_tree().root.find_child("SplitCanvas", true, false)
	if cl == null:
		cl = CanvasLayer.new()
		cl.name = "SplitCanvas"
		cl.layer = 5
		get_tree().root.add_child(cl)
		cl.add_child(_root_container)
	_root_container.visible = false  # erst zeigen, wenn beide drin sind

func _add_player_deferred(player: Player, index: int) -> void:
	var vp := SubViewport.new()
	vp.name = "PlayerVP_%d" % index
	vp.world_3d = get_tree().root.world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(860, 520)
	vp.msaa_3d = get_tree().root.msaa_3d
	_root_container.add_child(vp)
	var cam := Camera3D.new()
	cam.name = "VPCam"
	cam.fov = Settings.camera_fov
	vp.add_child(cam)
	cam.current = true
	# Transform-Spiegel Player-Kamera -> VPCam
	var rt := RemoteTransform3D.new()
	rt.remote_path = cam.get_path()
	rt.update_position = true
	rt.update_rotation = true
	rt.update_scale = false
	var main_cam := player.get_main_camera()
	if main_cam != null:
		main_cam.add_child(rt)
		main_cam.enabled = false
	_entries.append({"player": player, "index": index, "vp": vp, "cam": cam})
	if _entries.size() >= 2:
		_root_container.visible = true
		EventBus.build_mode_toggled.emit(false) # UI-Neutralität: Build aus im Splitscreen

func _teardown() -> void:
	for e in _entries:
		var vp: SubViewport = e["vp"]
		if is_instance_valid(vp):
			vp.queue_free()
		var p := e["player"] as Player
		if p != null:
			var mc := p.get_main_camera()
			if mc != null:
				mc.enabled = true
	_entries.clear()
	_root_container.visible = false
