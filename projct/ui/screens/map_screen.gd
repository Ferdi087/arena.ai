extends BaseScreen
class_name MapScreen
## Vollkarte: großes MapWidget + Legende + Missionsziel-Info. Esc/M schließen.

func _ready() -> void:
	title = "STADTKARTE"
	overlay_enum = UI.Overlay.MAP
	super()

func _panel_size() -> Vector2:
	return Vector2(1100, 760)

func build_body(body: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var map_host := PanelContainer.new()
	map_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(map_host)
	var widget := MapWidget.new()
	widget.full = true
	widget.name = "BigMap"
	widget.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_host.add_child(widget)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(240, 0)
	row.add_child(sidebar)
	var legend := Label.new()
	legend.text = "● Du\n◆ orange = Route\n● rot = Zielzone\n\nGrün = HQ\nBlau = Garage/Shop"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(legend)
	if Missions.has_active_mission():
		var m := Missions.active_mission
		var info := Label.new()
		info.text = "AKTIVER AUFTRAG\n%s\n\nQuelle: %s\nZiel: %s" % [m.display_name, m.source_building if not m.source_building.is_empty() else String(m.source_district), m.dest_building if not m.dest_building.is_empty() else String(m.destination_district)]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sidebar.add_child(info)
	var hint := Label.new()
	hint.text = "Hinweis: Karte folgt der Spielfigur."
	sidebar.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map") or event.is_action_pressed("ui_cancel"):
		UI.close(UI.Overlay.MAP)
		get_viewport().set_input_as_handled()
