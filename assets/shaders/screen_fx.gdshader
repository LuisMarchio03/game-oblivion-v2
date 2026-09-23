shader_type canvas_item;
// Vinheta + granulação de filme + leve aberração nas bordas.
uniform float vignette = 0.55;
uniform float grain = 0.045;
uniform vec4 tint : source_color = vec4(0.0, 0.02, 0.06, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c * vec2(1.25, 1.0));
	float v = smoothstep(0.35, 0.95, d) * vignette;
	float n = (hash(uv * 900.0 + fract(TIME * 7.3)) - 0.5) * grain;
	COLOR = vec4(tint.rgb + vec3(n), clamp(v + abs(n) * 0.8, 0.0, 1.0));
}
