shader_type spatial;
render_mode unshaded,depth_draw_alpha_prepass,world_vertex_coords;


vec3 random3(vec3 c) {
	float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0*j);
	j *= .125;
	r.x = fract(512.0*j);
	j *= .125;
	r.y = fract(512.0*j);
	return r-0.5;
}

/* skew constants for 3d simplex functions */
/const float F3 =  0.3333333;
const float G3 =  0.1666667;
const float G3X2 =  0.3333334;
const float G3X3 =  0.5000001;

/* 3d simplex noise */
float simplex3d(vec3 p) {
	vec3 s = floor(p + dot(p, vec3(F3)));
	vec3 x = p - s + dot(s, vec3(G3));
	vec3 e = step(vec3(0.0), x - x.yzx);
	vec3 i1 = e*(1.0 - e.zxy);
	vec3 i2 = 1.0 - e.zxy*(1.0 - e);
	vec3 x1 = x - i1 + G3;
	vec3 x2 = x - i2 + G3X2;
	vec3 x3 = x - 1.0 + G3X3;
	vec4 w = vec4(dot(x, x),dot(x1, x1),dot(x2, x2),dot(x3, x3));
	vec4 d = vec4(dot(random3(s), x),dot(random3(s + i1), x1),dot(random3(s + i2), x2),dot(random3(s + 1.0), x3));
	w = max(0.6 - w, 0.0);
	w *= w;
	w *= w;
	d *= w;
	return dot(d, vec4(52.0));
	/*
	vec3 x2 = x - i2 + 2.0*G3;
	vec3 x3 = x - 1.0 + 3.0*G3;
	vec4 w, d;
	w.x = dot(x, x);
	w.y = dot(x1, x1);
	w.z = dot(x2, x2);
	w.w = dot(x3, x3);
	w = max(0.6 - w, 0.0);
	d.x = dot(random3(s), x);
	d.y = dot(random3(s + i1), x1);
	d.z = dot(random3(s + i2), x2);
	d.w = dot(random3(s + 1.0), x3);
	w *= w;
	w *= w;
	d *= w;
	return dot(d, vec4(52.0));
	*/
}



float simplexNoiseController(int oct, float pers, float lacu,float T, vec3 coordinates){
	float total = 0f;
	float frequency = 1f/T;
	float amplitude = 1f;
	float totalAmplitude = 0f;  // Used for normalizing result to 0.0 - 1.0
	for(int i=0;i<oct;i++) {
			total += simplex3d(coordinates*frequency) * amplitude;
	        totalAmplitude += amplitude;
	        amplitude *= pers;
	        frequency *= lacu;
	}
	return total/totalAmplitude;
}

uniform float x;
uniform float y;
uniform float z;
uniform int octaves: hint_range(1,9)=3;
uniform float period;//:hint_range(0.1,256) = 1;
uniform float persistence:hint_range(0,1)=0.5;
uniform float lacunarity:hint_range(1,4) = 2;

uniform float size=1;
void fragment(){

	vec2 newUV = UV*size;
	float sn = simplexNoiseController(octaves,persistence,lacunarity,period,vec3(UV.x+x,UV.y-y,z));
	//float sn = simplexNoiseController(octaves,persistence,lacunarity,period,vec3(x,y,z));
	//float sn = simplex3d(vec3(UV.x+x,UV.y-y,z));
	//ALBEDO = step(vec3(0.05),vec3(sn));
	ALBEDO = vec3(sn);

}

uniform float f: hint_range(0, 16) = 1.0;
void vertex(){
	//float sn = simplexNoiseControl(octaves,persistence,lacunarity,period,vec3(UV.x+x,UV.y-y,z));
	//VERTEX.z += sn;
    //float noiseValue = texture(NOISE_PATTERN, UV).x;
	//vec3 noiseValue = texture(NOISE_PATTERN,UV).xyz;
    //VERTEX.y += round(noiseValue.y);
	//VERTEX.y += noiseValue.y;
	//VERTEX.x += vec4(noiseValue).x;
	//VERTEX.z += vec4(noiseValue).z;
	//VERTEX.y += cos(VERTEX.x * 4.0) * sin(VERTEX.z * 4.0) * 0.5;
}