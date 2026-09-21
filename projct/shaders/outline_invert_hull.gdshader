shader_type spatial;
// Inverted-Hull-Outline als next_pass-Material (Godot 4.2+ Standardweg).
// Warum Inverted Hull statt Post-Process: funktioniert pro-Objekt ohne Depth-
// Prepass, kostet ~1 Draw extra, skaliert mit tausenden Objekten und ist
// Multiplayer-frei (keine Viewport-Effekte). Post-Process-Outline wäre
// alternativer Ansatz (Compositor), aber mit Overdraw-Kosten & AA-Konflikten.
render_method unshaded;
cull_mode front;

@group_category("Outline")
@export_range(0.0, 0.06, 0.001) var width: float = 0.014;
@export var outline_color: vec4 = vec4(0.02, 0.02, 0.035, 1.0);

void vertex() {
	// Weltkonstante Breite trotz Skalarmorphs (Charakter-Slider):
	float model_scale = length(MODELVIEW_MATRIX[0].xyz);
	VERTEX += NORMAL * width * max(model_scale, 0.25);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
