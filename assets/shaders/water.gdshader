shader_type spatial;
render_mode cull_disabled;
// Água escura com ondulação pixelada.
uniform vec4 deep : source_color = vec4(0.02, 0.07, 0.12, 1.0);
uniform vec4 shallow : source_color = vec4(0.1, 0.25, 0.35, 1.0);
uniform float pixel = 24.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = floor(wpos.xz * pixel) / pixel;
	float n = noise(p * 1.5 + vec2(TIME * 0.4, TIME * 0.25)) * 0.6 + noise(p * 3.0 - vec2(TIME * 0.3, 0.0)) * 0.4;
	float band = step(0.72, n);
	ALBEDO = mix(deep.rgb, shallow.rgb, n * 0.6) + band * 0.12;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
