shader_type canvas_item;

uniform vec2 source_texel = vec2(0.001, 0.001);
uniform vec4 outline_color : source_color = vec4(0.795, 0.630, 0.300, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec2 region_min = vec2(0.0, 0.0);
uniform vec2 region_max = vec2(1.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 texel = max(source_texel, fwidth(UV));
	vec2 edge_inset = texel * 5.0;
	vec2 sample_min = region_min + edge_inset;
	vec2 sample_max = region_max - edge_inset;
	float nearby = 0.0;
	nearby = max(nearby, texture(TEXTURE, clamp(UV + vec2(texel.x, 0.0), sample_min, sample_max)).a);
	nearby = max(nearby, texture(TEXTURE, clamp(UV - vec2(texel.x, 0.0), sample_min, sample_max)).a);
	nearby = max(nearby, texture(TEXTURE, clamp(UV + vec2(0.0, texel.y), sample_min, sample_max)).a);
	nearby = max(nearby, texture(TEXTURE, clamp(UV - vec2(0.0, texel.y), sample_min, sample_max)).a);
	nearby = max(nearby, texture(TEXTURE, clamp(UV + texel, sample_min, sample_max)).a);
	nearby = max(nearby, texture(TEXTURE, clamp(UV - texel, sample_min, sample_max)).a);
	float inside_region = step(sample_min.x, UV.x) * step(sample_min.y, UV.y) * step(UV.x, sample_max.x) * step(UV.y, sample_max.y);
	float outline = max(nearby - base.a, 0.0) * outline_alpha * inside_region;
	vec4 outlined = vec4(outline_color.rgb, outline_color.a * outline);
	COLOR = mix(outlined, base, base.a);
	COLOR.a = max(base.a, outlined.a);
}
