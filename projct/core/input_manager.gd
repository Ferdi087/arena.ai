extends Node
## Input Manager (Autoload "GameInput") – Input-Komfort-Schicht über InputMap.
##
## Responsibility:
##  - Action-Namen zentral definieren (kein KEY_*-Hardcoding im Gameplay, #71)
##  - Device-Erkennung (Maus/Keyboard <-> Controller) für UI-Hinweise
##  - Per-Player-Action-Präfixe für lokales Co-op ("move_forward" / "p2_move_forward")
##  - Puffer (Buffered Input) für griffiges Grab-Feeling
##
## Autoload-Begründung: Device-Zustand + Buffers sind global; InputMap selbst ist
## Engine-global. Kein Gameplay hier.

const ACTIONS := {
	"move": ["move_forward", "move_backward", "move_left", "move_right"],
	"single": ["jump", "sprint", "crouch", "interact", "grab", "grab_release",
		"grab_rotate_ccw", "grab_rotate_cw", "tool_use", "tool_next", "tool_previous",
		"open_map", "open_menu", "open_tools", "cycle_camera",
		"vehicle_accelerate", "vehicle_brake", "vehicle_steer_left", "vehicle_steer_right",
		"vehicle_horn", "exit_vehicle", "build_toggle"],
}

const COOP_PREFIXES := ["", "p2_"]

var using_controller: bool = false
var _press_buffer: Dictionary[StringName, float] = {}
var _buffer_window := 0.18

signal input_device_changed(controller: bool)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_action_pressed_buffered(action: String) -> bool:
	## true, wenn Action in den letzten ~0.18s gedrückt wurde (Input Buffering).
	if Input.is_action_just_pressed(action):
		_press_buffer[StringName(action)] = Time.get_ticks_msec() / 1000.0
		return true
	var t: float = _press_buffer.get(StringName(action), -10.0)
	if Time.get_ticks_msec() / 1000.0 - t <= _buffer_window:
		_press_buffer.erase(StringName(action))
		return true
	return false

func consume_buffer(action: String) -> bool:
	var key := StringName(action)
	if _press_buffer.has(key):
		_press_buffer.erase(key)
		return true
	return false

func movement_vector(player_prefix_index: int = 0) -> Vector2:
	var prefix: String = COOP_PREFIXES[player_prefix_index] if player_prefix_index < COOP_PREFIXES.size() else "p%d_" % (player_prefix_index + 1)
	var v := Vector2.ZERO
	if Input.is_action_pressed(prefix + "move_left"):
		v.x -= 1.0
	if Input.is_action_pressed(prefix + "move_right"):
		v.x += 1.0
	if Input.is_action_pressed(prefix + "move_forward"):
		v.y -= 1.0
	if Input.is_action_pressed(prefix + "move_backward"):
		v.y += 1.0
	return v.normalized() if v.length_squared() > 0.0 else v

func set_ui_focus_sound_enabled(_enabled: bool) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not using_controller:
			using_controller = true
			input_device_changed.emit(true)
	elif event is InputEventMouseMotion or event is InputEventKey:
		if using_controller and (event is InputEventKey):
			using_controller = false
			input_device_changed.emit(false)

func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
