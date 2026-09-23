shader_type canvas_item;
// Névoa animada para o espelho embaçado.
uniform float density = 0.8;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
void fragment() {
	vec2 p = UV * 6.0 + vec2(TIME * 0.05, TIME * 0.03);
	float n = noise(p) * 0.5 + noise(p * 2.0) * 0.25 + noise(p * 4.0) * 0.125;
	COLOR = vec4(vec3(0.75, 0.82, 0.9), density * (0.55 + n * 0.5));
}
