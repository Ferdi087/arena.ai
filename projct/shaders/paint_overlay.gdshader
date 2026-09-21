shader_type spatial;
// Paint-Overlay: Weltraum-Boxprojektion auf eine 2x2-Quadranten-Textur.
// Kanonisches Layout in UV-Raum (0..1, v zeigt nach oben – Shader-Konvention):
//   FRONT (+Z)  = unten-links   origin (0.0, 0.0)
//   BACK  (-Z)  = unten-rechts   origin (0.5, 0.0)
//   LEFT  (-X)  = oben-links     origin (0.0, 0.5)
//   RIGHT (+X)  = oben-rechts    origin (0.5, 0.5)
// PaintProjector (GDScript) garantiert dieselbe Zuordnung fürs Zeichnen/Speichern.
// Ein Shader für Charakter, Möbel, Truck, Wände -> PaintSurface setzt nur Uniforms.

@group_category("Paint")
@export var base_color: vec4 = vec4(0.8, 0.8, 0.8, 1.0);
@export var paint_texture: sampler2D;
@export_range(0.0, 1.0) var paint_strength: float = 1.0;
@export var paint_center: vec3 = vec3(0.0, 0.0, 0.0);
@export var paint_size: vec3 = vec3(1.0, 1.0, 1.0);
@export_range(0.0, 1.0) var roughness: float = 0.72;
@export_range(0.0, 1.0) var metallic: float = 0.0;
@export_range(0.0, 1.0) var damage_tint: float = 0.0; // DamageComponent steuert das

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 local = (world_pos - paint_center) / max(paint_size, vec3(0.0001));
	vec2 uv_xy = local.xy * 0.5 + 0.5;   // für Front/Back
	vec2 uv_zy = local.zy * 0.5 + 0.5;   // für Left/Right

	vec4 paint = vec4(0.0);
	if (abs(n.z) >= abs(n.x) && abs(n.z) > abs(n.y)) {
		vec2 uv = (n.z > 0.0) ? uv_xy : vec2(1.0 - uv_xy.x, uv_xy.y);
		vec2 origin = (n.z > 0.0) ? vec2(0.0, 0.0) : vec2(0.5, 0.0);
		paint = texture(paint_texture, uv * 0.5 + origin);
	} else if (abs(n.x) > abs(n.y)) {
		// Blick von +X auf rechte Seite: lokale -Z zeigt nach rechts im Bild -> x flippen
		vec2 uv = (n.x > 0.0) ? vec2(1.0 - uv_zy.x, uv_zy.y) : uv_zy;
		vec2 origin = (n.x > 0.0) ? vec2(0.5, 0.5) : vec2(0.0, 0.5);
		paint = texture(paint_texture, uv * 0.5 + origin);
	}
	// Y-Flächen (oben/unten) bewusst unbemalt – verhindert Schmieren beim Kippen.

	vec3 albedo = mix(base_color.rgb, paint.rgb, clamp(paint.a, 0.0, 1.0) * paint_strength);
	albedo = mix(albedo, albedo * vec3(0.32, 0.26, 0.2), damage_tint);
	ALBEDO = albedo;
	ROUGHNESS = mix(roughness, 0.95, paint.a * paint_strength * 0.5);
	METALLIC = metallic;
}
