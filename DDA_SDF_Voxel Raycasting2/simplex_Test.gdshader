shader_type spatial;
render_mode unshaded,depth_draw_alpha_prepass,world_vertex_coords;
uniform sampler2D NOISE_PATTERN;
uniform sampler3D NOISE_PATTERN2;

float fetchSimplex(float x,float y,float z){
	float ab = texture(NOISE_PATTERN, vec2(x,y)).x;
	float bc = texture(NOISE_PATTERN, vec2(y,z)).x;
	float ac = texture(NOISE_PATTERN, vec2(x,z)).x;
	float ba = texture(NOISE_PATTERN, vec2(y,x)).x;
	float cb = texture(NOISE_PATTERN, vec2(z,y)).x;
	float ca = texture(NOISE_PATTERN, vec2(x,x)).x;
	float abc = ab+bc+ac+ba+cb+ca;
	return abc/6f;
}
uniform float z : hint_range(0,1);
/void fragment(){
    //float noiseValue = texture(NOISE_PATTERN, UV).x;
	//vec3 noiseValue = texture(NOISE_PATTERN, UV).xyz;
	
	//vec3 noiseValue = texture(NOISE_PATTERN2, vec3(UV+vec2(0.f,.0f),.0f)).xyz;
	ivec2 intUV = ivec2(floor(UV/64f) +vec2(0.f,.0f));
	vec3 noiseValue = texelFetch(NOISE_PATTERN2, ivec3(intUV,0),1).xyz;
    //ALBEDO = round(noiseValue);
	//float p = fetchSimplex(UV.x,UV.y,z);
	//ALBEDO = vec3(p);
	ALBEDO = noiseValue;
	//ALPHA = 0.5;
}

uniform float f: hint_range(0, 16) = 1.0;
void vertex(){
    //float noiseValue = texture(NOISE_PATTERN, UV).x;
	vec3 noiseValue = texture(NOISE_PATTERN,UV).xyz;
    //VERTEX.y += round(noiseValue.y);
	//VERTEX.y += noiseValue.y;
	//VERTEX.x += vec4(noiseValue).x;
	//VERTEX.z += vec4(noiseValue).z;
	//VERTEX.y += cos(VERTEX.x * 4.0) * sin(VERTEX.z * 4.0) * 0.5;
}