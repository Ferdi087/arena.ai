extends Node
## Game Manager (Autoload "Game") – zentrale Spiel-Zustandsmaschine.
##
## Responsibility: Was für ein Zustand ist gerade aktiv (Menu/Creator/InGame/...),
## Pause-Handling, Exit. KEIN Gameplay hier. Gameplay-State-Machines (BuildMode,
## Driving, JobSite ...) leben in der jeweiligen Welt-Szene, nicht global.
##
## Autoload-Begründung: Zustand muss Szenenwechsel (Menu <-> Welt) überleben.

enum AppState { BOOT, MAIN_MENU, COMPANY_SETUP, CHARACTER_CREATOR, LOADING, IN_GAME, PAUSED }

var state: AppState = AppState.BOOT
var local_coop_players: int = 1
var game_seed: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func change_state(next: AppState) -> void:
	if state == next:
		return
	state = next

func start_new_game(company_name: String, seed_value: int = 0) -> void:
	game_seed = seed_value if seed_value != 0 else randi()
	# Godot 4: kein randomize() mehr – Seed 0 wird automatisch random gesetzt.
	if seed_value != 0:
		seed(seed_value)
	Company.begin_new_company(company_name)
	change_state(AppState.LOADING)
	Scenes.change_scene("res://scenes/world/hq.tscn", func() -> void: change_state(AppState.IN_GAME))

func resume_game() -> void:
	if state == AppState.PAUSED:
		state = AppState.IN_GAME
		get_tree().paused = false

func pause_game() -> void:
	if state == AppState.IN_GAME:
		state = AppState.PAUSED
		get_tree().paused = true

func quit_to_menu() -> void:
	get_tree().paused = false
	change_state(AppState.MAIN_MENU)
	Scenes.change_scene("res://scenes/menus/main_menu.tscn")

func quit_game() -> void:
	# Save beim Exit anbieten, aber nicht erzwingen (Sandbox-Spiel).
	get_tree().quit()
