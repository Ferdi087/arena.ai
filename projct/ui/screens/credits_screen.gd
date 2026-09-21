extends BaseScreen
class_name CreditsScreen

func _ready() -> void:
	title = "CREDITS"
	overlay_enum = UI.Overlay.CREDITS
	super()

func _panel_size() -> Vector2:
	return Vector2(640, 560)

func build_body(body: Control) -> void:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.text = """[center][b][font_size=28]MÖBEL-RAMBO[/font_size]
Ein Physik-Umzugs-Simulator

[b]Design & Code[/b] Arena-Agent
[b]Physik[/b] Godot 4 + Jolt
[b]Grafik[/b] Toon/Shader selbstgebaut – keine Asset-Flats
[b]Sound[/b] prozedural generiert (tools/generate_sfx.py)

Das Team der fiktiven [color=#e67e22]Möbel-Rambo GmbH[/color]
wünscht gute Hände und noch bessere Laune.

Mit Liebe gebaut für: alle, die schonmal
ein Sofa zur falschen Treppe rausgetragen haben.[/center]"""
	body.add_child(t)
