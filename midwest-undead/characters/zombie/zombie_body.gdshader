shader_type spatial;
// Every zombie is one mesh (its body, head and arms combined, zombie.gd) with
// this one material. The mesh marks which parts are its shirt (vertex color
// alpha 1) and which are skin (0); each zombie sets its own colors and the
// flash when it's hit.

instance uniform vec4 skin : source_color = vec4(0.45, 0.52, 0.4, 1.0);
instance uniform vec4 shirt : source_color = vec4(0.35, 0.3, 0.28, 1.0);
// 0 to 1: how far it's flashed toward pale red (just hit).
instance uniform float flash = 0.0;

void fragment() {
	vec3 base = mix(skin.rgb, shirt.rgb, COLOR.a);
	ALBEDO = mix(base, vec3(1.0, 0.85, 0.85), flash);
	ROUGHNESS = 1.0;
}
