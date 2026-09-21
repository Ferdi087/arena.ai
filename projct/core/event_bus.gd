extends Node
## EventBus – der einzige erlaubte globale Signal-Knoten.
##
## Responsibility: lose Kopplung zwischen Systemen (Gameplay != UI != Save).
## Regel: Systeme reden NIE direkt über `get_node("../Xyz")` miteinander,
## sondern nur über diese Signale. Der EventBus hält KEINEN Zustand.
## Netzwerk: Signale sind lokal; REPLIKATION passiert in den jeweiligen
## Services über @rpc, die dann hier dieselben Signale feuern.

# --- Interaction / Grab -----------------------------------------------------
signal interaction_hover_changed(interactable: Node)
signal object_grabbed(body: RigidBody3D, grabber: Node)
signal object_released(body: RigidBody3D, grabber: Node)
signal grab_strain_changed(body: RigidBody3D, strain: float)

# --- Damage / Furniture -----------------------------------------------------
signal damage_changed(body: RigidBody3D, damage_percent: float, cause: StringName)
signal item_destroyed(body: RigidBody3D)

# --- Economy / Company --------------------------------------------------------
signal money_changed(new_amount: float, delta: float)
signal reputation_changed(new_rep: float, delta: float)
signal unlock_changed(unlock_id: StringName, unlocked: bool)
signal marketing_changed(tier: int)

# --- Missions -----------------------------------------------------------------
signal mission_accepted(mission: MissionData)
signal mission_started(mission: MissionData)
signal objective_updated(mission: MissionData, objective_id: StringName, progress: float)
signal objective_completed(mission: MissionData, objective_id: StringName)
signal mission_completed(mission: MissionData, payout: PayoutResult)
signal mission_failed(mission: MissionData, reason: StringName)
signal mission_cancelled(mission: MissionData)

# --- World / Weather / Time -----------------------------------------------------
signal time_of_day_changed(hour: float)
signal weather_changed(weather: int, intensity: float)
signal wind_changed(direction: Vector3, strength: float)
signal random_event_triggered(event_id: StringName, data: Dictionary)

# --- Vehicles -------------------------------------------------------------------
signal player_entered_vehicle(vehicle: VehicleController, player: Node)
signal player_exited_vehicle(vehicle: VehicleController, player: Node)
signal vehicle_damage_changed(vehicle: VehicleController, damage_percent: float)
signal cargo_loaded(vehicle: VehicleController, cargo: RigidBody3D)
signal cargo_unloaded(vehicle: VehicleController, cargo: RigidBody3D)

# --- HQ / Build Mode ----------------------------------------------------------------
signal build_mode_toggled(active: bool)
signal build_piece_placed(piece: BuildPieceData, cell: Vector2i)
signal hq_quality_changed(score: float)

# --- Save / Load ---------------------------------------------------------------------
signal save_requested(slot: int)
signal save_completed(slot: int, path: String)
signal save_failed(slot: int, error: String)
signal load_requested(slot: int)
signal load_completed(slot: int)
signal load_failed(slot: int, error: String)

# --- Multiplayer ------------------------------------------------------------------------
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal connection_state_changed(state: int)

# --- Character Customization / Paint -------------------------------------------------------
signal paint_stroke_finished(target: StringName, quadrant: int)
signal accessory_equipped(slot: StringName, cosmetic: CosmeticData)
signal character_applied(character: CharacterData)
