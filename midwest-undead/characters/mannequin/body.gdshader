shader_type spatial;
// The mannequin's body (characters/mannequin/). One material for everyone; the
// mesh marks each part's region in its vertex color's red (skin 0, shirt 1/3,
// pants 2/3, shoes 1), and each character sets its own colors, and the flash
// when it's hit, as instance parameters (zombie.gd does).

instance uniform vec4 skin : source_color = vec4(0.45, 0.52, 0.4, 1.0);
instance uniform vec4 shirt : source_color = vec4(0.35, 0.3, 0.28, 1.0);
instance uniform vec4 pants : source_color = vec4(0.22, 0.24, 0.3, 1.0);
// 0 to 1: how far it's flashed toward pale red (just hit).
instance uniform float flash = 0.0;

const vec3 SHOES = vec3(0.12, 0.1, 0.09);

void fragment() {
	float region = COLOR.r * 3.0;
	vec3 base = skin.rgb;
	if (region > 2.5) {
		base = SHOES;
	} else if (region > 1.5) {
		base = pants.rgb;
	} else if (region > 0.5) {
		base = shirt.rgb;
	}
	ALBEDO = mix(base, vec3(1.0, 0.85, 0.85), flash);
	ROUGHNESS = 0.95;
}
