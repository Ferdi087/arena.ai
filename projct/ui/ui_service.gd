extends Node
## UI Service (Autoload "UI") – Fenster-Manager + HUD-Zugriff.
## Alle Screens werden LAZY in Code gebaut (kein .tscn-Asset-Zwang, aber jede
## Klasse ist 1:1 in eine Scene auslagerbar). Pause-Logik + Fokus-Verwaltung.
## Abhängigkeiten: UI -> Services (Company, Missions, …) – NIEMALS umgekehrt.

enum Overlay { NONE, PAUSE, SETTINGS, SAVE_LOAD, MISSION_BOARD, GARAGE, SHOP_CLOTHES, SHOP_VEHICLE, SHOP_BUILD, HIRE, MAP, CREATOR, COMPANY_SETUP, PALETTE, EXTRAS, CREDITS }

var hud: GameHUD = null
var overlay_stack: Array[Overlay] = []
var _instances: Dictionary = {}
var _root: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = CanvasLayer.new()
	_root.name = "UIRoot"
	_root.layer = 40
	add_child(_root)

func attach_hud() -> void:
	if hud != null and is_instance_valid(hud):
		return
	hud = GameHUD.new()
	hud.name = "HUD"
	_root.add_child(hud)
	hud._refresh_statics()
	GameInput.release_mouse()

func detach_hud() -> void:
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null

func toast(text: String, seconds: float = 2.6) -> void:
	if hud != null and is_instance_valid(hud):
		hud.toast(text, seconds)

func hud_hint(text: String) -> void:
	if hud != null and is_instance_valid(hud):
		hud.hint(text)

func banner(text: String) -> void:
	if hud != null and is_instance_valid(hud):
		hud.banner_text(text)

func mission_started_update() -> void:
	if hud != null and is_instance_valid(hud):
		hud._refresh_objectives()

func mission_finished_update() -> void:
	if hud != null and is_instance_valid(hud):
		hud._refresh_objectives()

func hint_changed(text: String) -> void:
	toast(text, 1.4)

# ---------------------------------------------------------------- Overlays --

func open(overlay: Overlay) -> void:
	if overlay_stack.has(overlay):
		return
	if overlay == Overlay.PAUSE:
		Game.pause_game()
	var node := _get_or_build(overlay)
	if node == null:
		return
	overlay_stack.append(overlay)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.add_child(node)
	node.focus_mode = Control.FOCUS_ALL
	node.grab_focus.call_deferred() if node is Control else null

func _get_or_build(overlay: Overlay) -> Control:
	if _instances.has(overlay):
		var cached := _instances[overlay] as Control
		if is_instance_valid(cached):
			return cached
	var node: Control = null
	match overlay:
		Overlay.PAUSE:
			node = PauseScreen.new()
		Overlay.SETTINGS:
			node = SettingsScreen.new()
		Overlay.SAVE_LOAD:
			node = SaveLoadScreen.new()
		Overlay.MISSION_BOARD:
			node = MissionBoardScreen.new()
		Overlay.GARAGE:
			node = GarageScreen.new()
		Overlay.SHOP_CLOTHES:
			node = ClothesShopScreen.new()
		Overlay.SHOP_VEHICLE:
			node = VehicleShopScreen.new()
		Overlay.SHOP_BUILD:
			node = BuildShopScreen.new()
		Overlay.HIRE:
			node = HireScreen.new()
		Overlay.MAP:
			node = MapScreen.new()
		Overlay.PALETTE:
			node = PaintPaletteScreen.new()
		Overlay.EXTRAS:
			node = ExtrasScreen.new()
		Overlay.CREDITS:
			node = CreditsScreen.new()
		_:
			return null
	_instances[overlay] = node
	return node

func close(overlay: Overlay) -> void:
	overlay_stack.erase(overlay)
	var node := _instances.get(overlay) as Control
	if node != null and is_instance_valid(node):
		node.queue_free()
		_instances.erase(overlay)
	if overlay_stack.is_empty() and Game.state == Game.AppState.IN_GAME:
		GameInput.capture_mouse()
	if overlay == Overlay.PAUSE:
		Game.resume_game()

func close_top() -> void:
	if overlay_stack.is_empty():
		return
	close(overlay_stack[overlay_stack.size() - 1])

func any_overlay_open() -> bool:
	return not overlay_stack.is_empty()

# --------------------------------------------------------- Conveniences --

func open_pause() -> void: open(Overlay.PAUSE)
func open_settings() -> void: open(Overlay.SETTINGS)
func open_save_load() -> void: open(Overlay.SAVE_LOAD)
func open_mission_board(_player: Node = null) -> void: open(Overlay.MISSION_BOARD)
func open_garage() -> void: open(Overlay.GARAGE)
func open_shop_clothes() -> void: open(Overlay.SHOP_CLOTHES)
func open_shop_vehicle() -> void: open(Overlay.SHOP_VEHICLE)
func open_shop_build() -> void: open(Overlay.SHOP_BUILD)
func open_hire() -> void: open(Overlay.HIRE)
func open_palette() -> void: open(Overlay.PALETTE)
func close_palette() -> void: close(Overlay.PALETTE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		if Game.state == Game.AppState.IN_GAME:
			if overlay_stack.is_empty():
				open_pause()
			else:
				close_top()
	elif event.is_action_pressed("open_map"):
		if Game.state == Game.AppState.IN_GAME:
			if overlay_stack.has(Overlay.MAP):
				close(Overlay.MAP)
			else:
				open(Overlay.MAP)
		return
	elif event.is_action_pressed("ui_cancel"):
		if overlay_stack.has(Overlay.PALETTE):
			close_palette()
