shader_type spatial;
render_mode unshaded,depth_draw_alpha_prepass,world_vertex_coords;

uniform bool active = false;

uniform float sky_energy  : hint_range(0, 16) = 0.209; //skybox brightness
uniform mat3 camera_basis = mat3(1.0); //connect real world camera global_transform.basis here
uniform vec3 camera_global_position; //connect real world camera global_transform.origin here
varying vec3 fragColor;

uniform int mat:hint_range(0, 3) = 1;//for switching between albedo and specular material setup
const float PI = 3.14159265f;
uniform sampler2D texture_here; //2D skybox image here

uniform int BOUNCE = 2;

void CreateRay(vec3 origin, vec3 direction, inout vec3 ray_origin, inout vec3 ray_direction, inout vec3 ray_energy)
{
    ray_origin = origin;
    ray_direction = direction;
    ray_energy = vec3(1.0, 1.0, 1.0);
}

//this creates a bunch of rays from your camera origin impaling your whole entire screen out to the virtual world
void CreateCameraRay(vec2 my_uv,vec2 vps, vec2 coord,inout vec3 ray_origin,inout vec3 ray_direction,inout vec3 ray_energy)
{
	vec2 uv = (coord * 2.0 - vps)/(vps.y);
    vec3 ro = camera_global_position;
	vec3 rd = mat3(camera_basis[0],camera_basis[1],-camera_basis[2]) * vec3(uv,1.0);
	rd = normalize(rd);
	CreateRay(ro, rd,ray_origin, ray_direction, ray_energy);
}
float infSpheres(vec3 p,float radius){
    p=mod(p,40.)-20.;
	float atmosphere_thickness = 2f;
    return length(p)-atmosphere_thickness-radius;
}
float infBoxes( vec3 p, vec3 b ){
    p=mod(p,40.)-20.;
	float atmosphere_thickness = 2f;
    vec3 q = abs(p) - atmosphere_thickness - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

//https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
/*
float sdSphere(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
    return length(p-c)-atmosphere_thickness-radius;
}
float sdBox( vec3 p, vec3 b ){
	float atmosphere_thickness = 2f;
	vec3 q = abs(p-vec3(10.,-5.,-30.)) - atmosphere_thickness - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}
*/


vec4 sdSphereFastNorm(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
	vec3 diff = p-c;
	vec3 normal = normalize(diff);
    return vec4(normal,length(diff)-atmosphere_thickness-radius);
}

float sdSphere(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
    return length(p-c)-atmosphere_thickness-radius;
}
float sdBox( vec3 p, vec3 b ,vec3 c){
	float atmosphere_thickness = 2f;
	vec3 q = abs(p-c) - atmosphere_thickness - b;
	/*
	vec3 qx = abs(p+h.xyy-c) - atmosphere_thickness - b;
	vec3 qy = abs(p+h.yxy-c) - atmosphere_thickness - b;
	vec3 qz = abs(p+h.yyx-c) - atmosphere_thickness - b;
	*/
	//vec3 normal = normalize(p - c);
	//return vec4(normal,length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0));
	/*
	float value = length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
	vec3 normal;
	normal.x = length(max(qx,0.0)) + min(max(qx.x,max(qx.y,qx.z)),0.0) - value;
	normal.y = length(max(qy,0.0)) + min(max(qy.x,max(qy.y,qy.z)),0.0) - value;
	normal.z = length(max(qz,0.0)) + min(max(qz.x,max(qz.y,qz.z)),0.0) - value;
	*/
	
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}
float sdBoxNA( vec3 p, vec3 b ,vec3 c){
	vec3 q = abs(p-c) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}
/*
float gridMap(vec3 p)
{
	//return infSpheres(p,10.);//best viewed with uniform MAT = 3
    return sdSphere(p,1000.0,vec3(0.,0.,-1700.));//keep camera at origin
	//return sdSphere(p,10.0,vec3(0.,0.,-17.));//keep camera at origin
	//return sdSphere(p,10.0,vec3(0.,0.,0.));//keep camera at origin
	//return sdBox(p,vec3(5.,3.,7.));
    //return sdBox(p,vec3(.5,.5,.5));
    //return infBoxes(p,vec3(10.,10.,10.));
}
*/
const float EPSILON = 1f;
const vec2 h = vec2(EPSILON,0f);

vec4 sdBoxWNorml4(vec3 p,vec3 dim,vec3 cen){
	float value = sdBox(p,dim,cen);
	float nValue = sdBoxNA(p,dim,cen);
	vec3 normal = vec3( sdBoxNA(p+h.xyy,dim,cen),sdBoxNA(p+h.yxy,dim,cen),sdBoxNA(p+h.yyx,dim,cen));
	normal -= nValue;
	return vec4(normalize(normal),value);
}

vec4 sdSphereWNorml4(vec3 p,float radius,vec3 cen){
	float value = sdSphere(p,radius,cen);
	vec3 normal = vec3(sdSphere(p+h.xyy,radius,cen),sdSphere(p+h.yxy,radius,cen),sdSphere(p+h.yyx,radius,cen));
	normal -= value;
	//normal.x = sdSphere(p+h.xyy,radius,cen)-value;
	//normal.y = sdSphere(p+h.yxy,radius,cen)-value;
	//normal.z = sdSphere(p+h.yyx,radius,cen)-value;
	return vec4(normalize(normal),value);
}

vec4 sdSphereWNorml6(vec3 p,float radius,vec3 cen){
	float value = sdSphere(p,radius,cen);
	vec3 normal = vec3(sdSphere(p+h.xyy,radius,cen),sdSphere(p+h.yxy,radius,cen),sdSphere(p+h.yyx,radius,cen));
	normal -= vec3(sdSphere(p-h.xyy,radius,cen),sdSphere(p-h.yxy,radius,cen),sdSphere(p-h.yyx,radius,cen));
	//normal.x = sdSphere(p+h.xyy,radius,cen)-value;
	//normal.y = sdSphere(p+h.yxy,radius,cen)-value;
	//normal.z = sdSphere(p+h.yyx,radius,cen)-value;
	return vec4(normalize(normal),value);
}

vec4 sdSphereWNorml3(vec3 p,float radius,vec3 cen){
	float value = sdSphere(p,radius,cen);
	vec3 normal = vec3(sdSphere(p+h.xyy,radius,cen),sdSphere(p+h.yxy,radius,cen),sdSphere(p+h.yyx,radius,cen));
	//normal -= vec3(sdSphere(p-h.xyy,radius,cen),sdSphere(p-h.yxy,radius,cen),sdSphere(p-h.yyx,radius,cen));
	//normal.x = sdSphere(p+h.xyy,radius,cen)-value;
	//normal.y = sdSphere(p+h.yxy,radius,cen)-value;
	//normal.z = sdSphere(p+h.yyx,radius,cen)-value;
	return vec4(normalize(normal),value);
}

vec4 sdBoxWNorml6(vec3 p,vec3 dim,vec3 cen){
	float value = sdBox(p,dim,cen);
	vec3 normal;
	normal.x = sdBox(p+h.xyy,dim,cen)-sdBox(p-h.xyy,dim,cen);
	normal.y = sdBox(p+h.yxy,dim,cen)-sdBox(p-h.yxy,dim,cen);
	normal.z = sdBox(p+h.yyx,dim,cen)-sdBox(p-h.yyx,dim,cen);
	return vec4(normalize(normal),value);
}

const float hh = 1f;
const vec2 k = vec2(1,-1);

vec4 sdBoxWNormalTetrahedron(vec3 p,vec3 dim,vec3 cen){
	float value = sdBox(p,dim,cen);
	vec3 normal = k.xyy*sdBox(p+k.xyy*hh,dim,cen) + k.yyx*sdBox(p+k.yyx*hh,dim,cen) + k.yxy*sdBox(p+k.yxy*hh,dim,cen) + k.xxx*sdBox(p+k.xxx*hh,dim,cen);
	return vec4(normalize(normal),value);
}

float gridMapNoNormals(vec3 p){
	vec3 center = vec3(0.,0.,-50.);
	float radius = 1000f;
	vec3 dimensions = vec3(10.,10.,10.);
	return sdBox(p,dimensions,center);
}

vec4 gridMap(vec3 p){
	vec3 center = vec3(0.,0.,-50.);
	float radius = 1000f;
	vec3 dimensions = vec3(10.,10.,10.);
    //return sdSphere(p,10.0,center);//keep camera at origin
	//return sdBoxWNorml4(p,dimensions,center);
	//return sdBoxWNorml4(p,dimensions,center);
	return sdBoxWNormalTetrahedron(p,dimensions,center);
	//return sdSphereWNorml6(p,radius,center);
	///return sdSphereWNorml4(p,radius,center);
	//return sdSphereFastNorm(p,radius,center);
	/*
	float value = sdBox(p,dimensions,center);
	vec3 normal;
	normal.x = sdBox(p+h.xyy,dimensions,center)-value;
	normal.y = sdBox(p+h.yxy,dimensions,center)-value;
	normal.z = sdBox(p+h.yyx,dimensions,center)-value;
	return vec4(normal,value);//keep camera at origin
	*/
}

void DDA_SDF_Skipping_Voxel(inout float isSolid, inout float dist,inout vec3 ray_origin, inout vec3 ray_direction, inout vec3 ray_energy,inout vec3  hit_position,inout vec3 hit_normal){

	vec3 stp = sign(ray_direction);
    vec3 USS = abs(1.0/ray_direction);//Unit Step Size
    isSolid = 0f;
	hit_position=ray_origin;

	vec3 oro;

		for(int j=0;j<6;++j){
	        oro=hit_position;
			bool stop = false;

			// Lightspeed
	        float t=0.;
			for(int i=0;i<10;++i){
	            hit_position=oro+ray_direction*t;
	            //dist = gridMap(hit_position).a;
				dist = gridMapNoNormals(hit_position);
				//if(dist<-1.7){//Enter Atmosphere
				if(dist<=0.){//Enter Atmosphere
	                break;
	            }
	            t+=dist;
			}
			for(int i=0;i<16;++i){
	            vec3 boxPointDifference = fract(-hit_position * stp) + 1e-4,
	            legs = boxPointDifference*USS;
	            float leg = min(legs.x,min(legs.y,legs.z));
	            hit_position += ray_direction * leg;
	            vec4 map = gridMap(floor(hit_position));
				if (map.a >= 3.7) break;//exiting atmosphere
				if(map.a <= -1.9){
					isSolid = 1f;
					hit_normal = map.xyz;//getVoxelNormal(hit_position);
					stop = true;//break out of main loop
					break;
	            }
	        }
			if(stop)break;
		}
		
		
}

vec3 Shade(float isSolid,float dist,inout vec3 ray_origin,inout vec3 ray_direction,inout vec3 ray_energy, vec3 hit_position, vec3 hit_normal,vec3 hit_albedo,vec3 hit_specular,float hit_emission){
	vec3 albedo;
	vec3 specular;
	float emission = 0f;

	//float isSolid = step(dist,-1.9);
	float isSpace = 1f-isSolid;

	ray_origin = hit_position + hit_normal * 0.001f*isSolid;
	ray_direction = reflect(ray_direction, hit_normal)*isSolid + ray_direction*isSpace;

	switch(mat){
		case 0:{
			specular = vec3(0.04);//shaded
			albedo = vec3(0.80);//gray
			break;
		}
		case 1:{//default
			specular = vec3(0.6);
			albedo = vec3(1.0);
			break;
		}
		case 2:{
			specular = vec3(1.0f, 0.78f, 0.34f);//shinny gold
			albedo = vec3(1.0f, 0.78f, 0.34f);
			break;
		}
		default:{
			albedo = hit_albedo;
			emission = hit_emission;
			specular = hit_specular;
			break;
		}
	}
	ray_energy *= specular*isSolid;//turns zero if not solid

	if(isSolid > 0f){
		return emission*albedo;
		//return albedo;
	}else{
		float theta = acos(ray_direction.y) / PI;
		float phi = (atan(ray_direction.x, ray_direction.z)-PI) / -PI*0.5;
		return textureLod(texture_here,vec2(phi,theta),0).xyz*sky_energy;//needs to be textureLod else a weird line appears in sample
    }
}


void fragment() {
	vec3 ray_origin;
	vec3 ray_direction;
	vec3 ray_energy;
	float dist;
	CreateCameraRay(SCREEN_UV,VIEWPORT_SIZE,FRAGCOORD.xy,ray_origin,ray_direction,ray_energy);
	vec3 result = vec3(0.0, 0.0, 0.0);
	vec3 m_ray_energy=ray_energy;
	vec3 hit_position;
	vec3 hit_normal = vec3(0f);
	float isSolid;
	if(active){
		for (int i = 0; i < BOUNCE; i++)
		{
			m_ray_energy=ray_energy;
			
			DDA_SDF_Skipping_Voxel(isSolid,dist,ray_origin, ray_direction,ray_energy,hit_position,hit_normal);
			vec3 voxColor = hit_position;
			result += m_ray_energy * Shade(isSolid,dist,ray_origin,ray_direction,ray_energy,hit_position, hit_normal,voxColor,vec3(0.3f, 0f, 1f),1f);
			if (all(lessThan(ray_energy, vec3(0.001)))) break;
		}
		ALBEDO = result;//fragColor;
	}
}