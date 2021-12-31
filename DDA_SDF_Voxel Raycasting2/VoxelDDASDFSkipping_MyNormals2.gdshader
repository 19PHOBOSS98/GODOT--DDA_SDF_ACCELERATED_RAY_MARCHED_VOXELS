//DO NOT FORGET TO SET FOV TO 90

shader_type spatial;
render_mode unshaded,world_vertex_coords,depth_draw_alpha_prepass;

uniform bool active = false;

uniform float sky_energy  : hint_range(0, 16) = 0.209; //skybox brightness
uniform mat3 camera_basis = mat3(1.0); //connect real world camera global_transform.basis here
uniform vec3 camera_global_position; //connect real world camera global_transform.origin here

uniform int mat:hint_range(0, 4) = 1;//for switching between albedo and specular material setup
const float PI = 3.14159265f;
uniform sampler2D texture_here; //2D skybox image here

uniform sampler2D pos_memory : hint_albedo; //2D skybox image here

uniform int BOUNCE = 2;

void CreateRay(vec3 origin, vec3 direction, inout vec3 ray_origin, inout vec3 ray_direction, inout vec3 ray_energy)
{
    ray_origin = origin;
    ray_direction = direction;
    ray_energy = vec3(1.0, 1.0, 1.0);
}

//this creates a bunch of rays from your camera origin impaling your whole entire screen out to the virtual world
void CreateCameraRay(vec2 my_uv,vec2 vps, vec2 coord,inout vec3 ray_origin,inout vec3 ray_direction,inout vec3 ray_energy,inout vec3 camera_forward)
{
	vec2 uv = (coord * 2.0 - vps)/(vps.y);
    vec3 ro = camera_global_position;
	vec3 rd = mat3(camera_basis[0],camera_basis[1],-camera_basis[2]) * vec3(uv,1.0);
	rd = normalize(rd);
	camera_forward = -camera_basis[2];
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
float sdSphere(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
    return length(p-c)-atmosphere_thickness-radius;
}
float sdBox( vec3 p, vec3 b ,vec3 c){
	float atmosphere_thickness = 2f;
	vec3 q = abs(p-c) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - atmosphere_thickness;
}

vec4 sdSphereFastNorm(vec3 p,float radius,vec3 c){//returns normal and sdf distance
	float atmosphere_thickness = 2f;
	vec3 diff = p-c;
	vec3 normal = normalize(diff);
    return vec4(normal,length(diff)-atmosphere_thickness-radius);
}

uniform sampler3D inputVoxelMap;
float sdtexture3DMap(vec3 x){
	x += 0.5;
	vec3 fx = fract( x );
	x = floor( x ) + fx*fx*(3.0-2.0*fx);
    return texture( inputVoxelMap, (x-0.5)/64.0 ).x-2f;
}

vec3 myNormal(vec3 p_b,vec3 p_f){
	vec3 voxelCenter = floor(p_f)+0.5f;
	vec3 hitCenter = p_b - voxelCenter;
	vec3 normal = step(0.5,abs(hitCenter)) * sign(hitCenter);
	return normal;
}

uniform vec3 center = vec3(0.,0.,-150.);
uniform float radius = 10f;
uniform vec3 dimensions = vec3(1.,1.,1.);

float gridMapNoNormals(vec3 p){
	//return sdtexture3DMap(p);
	//return mapTerrain( p );
	//return sdHeightMap(p);
	//return max(sdBox(p,dimensions,center),-sdSphere(p,radius,center));
	//return sdBox(p,dimensions,center);
	return sdSphere(p,radius,center);
	//return infSpheres(p,radius);
	//return simplex3d(p);
}

void DDA_SDF_Skipping_Voxel4(inout float isSolid, inout float dist,inout vec3 ray_origin, inout vec3 ray_direction,inout vec3  hit_position,inout vec3 hit_normal){

	vec3 stp = sign(ray_direction);
    vec3 USS = abs(1.0/ray_direction);//Unit Step Size
    isSolid = 0f;
	hit_position=ray_origin;
	vec3 voxID;
	vec3 oro;

		for(int j=0;j<6;++j){
	        oro=hit_position;
			bool stop = false;

			// Lightspeed
	        float t=0.;
			for(int i=0;i<10;++i){
	            hit_position=oro+ray_direction*t;
				dist = gridMapNoNormals(hit_position);
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
				voxID = floor(hit_position)+0.5;
				float map = gridMapNoNormals(voxID);
				if (map >= 3.7) break;//exiting atmosphere
				if(map <= -1.9){
					isSolid = 1f;
					hit_normal = myNormal(hit_position-ray_direction*0.001,hit_position+ray_direction*0.001);
					stop = true;//break out of main loop
					break;
	            }
	        }
			if(stop){
				break;
			}
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
		case 3:{
			albedo = vec3(.0f, 0.78f, 0.34f);//shinny gold
			emission = hit_emission;
			specular = vec3(0.1f, 0.1f, 0.1f);
			break;
		}
		case 4:{
			albedo = hit_normal;
			emission = hit_emission;
			specular = vec3(0.1f, 0.1f, 0.1f);
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

uniform float near=0.05;
uniform float far=1000f;

void fragment(){
	if(active){
		vec3 ray_origin;
		vec3 ray_direction;
		vec3 ray_energy;
		float dist;
		
		vec3 camera_forward;
		CreateCameraRay(SCREEN_UV,VIEWPORT_SIZE,FRAGCOORD.xy,ray_origin,ray_direction,ray_energy,camera_forward);
		vec3 camera_origin = ray_origin;
		vec3 camera_ray = ray_direction;
		vec3 result = vec3(0.0, 0.0, 0.0);
		vec3 m_ray_energy;
		vec3 hit_position;
		vec3 hit_normal = vec3(0f);
		float isSolid = 0f;
		
		
			for (int i = 0; i < BOUNCE; i++){
					m_ray_energy=ray_energy;
					DDA_SDF_Skipping_Voxel4(isSolid,dist,ray_origin, ray_direction,hit_position,hit_normal);
					vec3 voxColor = hit_position;
					result += m_ray_energy * Shade(isSolid,dist,ray_origin,ray_direction,ray_energy,hit_position, hit_normal,voxColor,vec3(0f, 0f, 0f),1f);
					
					if(i==0){
						vec3 cam_to_hit = hit_position-camera_origin;
						float diff = far - near;
						float eyeHitZ = -length(cam_to_hit) *dot(camera_forward,normalize(cam_to_hit));
						float ndcDepth = ((far+near) + ((2.0*far*near)/eyeHitZ))/(far-near);//goes from -1 to 1
						DEPTH = (ndcDepth+1f)/2f;//need to shift the functin up since Godot's depth buffer only ever goes from 0 to 1
					}
					
					if (all(lessThan(ray_energy, vec3(0.001)))) break;
			}
			ALBEDO = result;//fragColor;
		}
}