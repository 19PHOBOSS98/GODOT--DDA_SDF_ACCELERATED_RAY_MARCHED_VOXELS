shader_type canvas_item;
render_mode blend_disabled;

//uniform sampler2D image : hint_albedo;
uniform bool active = false;

uniform mat3 camera_basis = mat3(1.0); //connect real world camera global_transform.basis here
uniform vec3 camera_global_position; //connect real world camera global_transform.origin here
//varying vec3 fragColor;

//uniform int mat:hint_range(0, 4) = 1;//for switching between albedo and specular material setup
//const float PI = 3.14159265f;
//uniform sampler2D texture_here; //2D skybox image here
//
//uniform sampler2D pos_memory: hint_albedo; //2D skybox image here

//uniform int BOUNCE = 2;
uniform vec2 viewport_size = vec2(1024,600);

uniform vec3 Center = vec3(0.,0.,-150.);
uniform float Radius = 10f;
uniform vec3 Dimensions = vec3(1.,1.,1.);

void CreateRay(vec3 origin, vec3 direction, inout vec3 ray_origin, inout vec3 ray_direction)
{
    ray_origin = origin;
    ray_direction = direction;
}

//this creates a bunch of rays from your camera origin impaling your whole entire screen out to the virtual world
void CreateCameraRay(vec2 vps, vec2 coord,inout vec3 ray_origin,inout vec3 ray_direction)
{
	vec2 uv = (coord * 2.0 - vps)/(vps.y);
    vec3 ro = camera_global_position;
	vec3 rd = mat3(camera_basis[0],camera_basis[1],-camera_basis[2]) * vec3(uv,1.0);
	rd = normalize(rd);
	CreateRay(ro, rd,ray_origin, ray_direction);
}

float sdSphere(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
    return length(p-c)-atmosphere_thickness-radius;
}
const float h = 1f;
const vec2 k = vec2(1,-1);

vec3 sdSphereWNormalTetrahedron(vec3 p,float radius,vec3 cen){
	vec3 normal = k.xyy*sdSphere(p+k.xyy*h,radius,cen) + k.yyx*sdSphere(p+k.yyx*h,radius,cen) + k.yxy*sdSphere(p+k.yxy*h,radius,cen) + k.xxx*sdSphere(p+k.xxx*h,radius,cen);
	return normalize(normal);
}

float gridMapNoNormals(vec3 p){
	return sdSphere(p,Radius,Center);
}

vec3 DDA_SDF_Skipping_Voxel2_get_Normals(inout vec3 ray_origin, vec3 ray_direction, inout vec3  hit_position){

	vec3 stp = sign(ray_direction);
    vec3 USS = abs(1.0/ray_direction);//Unit Step Size
	hit_position=ray_origin;

	vec3 oro;
	
	vec3 voxID;

		for(int j=0;j<6;++j){
	        oro=hit_position;
			//bool stop = false;

			// Lightspeed
			float t=0.;
			for(int i=0;i<10;++i){
				hit_position=oro+ray_direction*t;
				float dist = gridMapNoNormals(hit_position);
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
					//stop = true;//break out of main loop
					//break;
					//return voxID;
					return sdSphereWNormalTetrahedron(voxID,Radius,Center);
				}
			}
			//if(stop) break;
		}
		//return voxID;
		return sdSphereWNormalTetrahedron(voxID,Radius,Center);
}

u/niform sampler2D posMemory:hint_albedo;

void fragment() {

	vec4 savedPosMemory = textureLod(posMemory, SCREEN_UV, 0.0);
	
	if(savedPosMemory.a<1f){//0.5 : nothing changed ; 1: has changed
		vec3 savedVoxNormal = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
		COLOR = vec4(savedVoxNormal,1f);
		return
	}else{
		vec3 ray_origin;
		vec3 ray_direction;
		//float dist;
		vec3 hit_position;
		CreateCameraRay(viewport_size,FRAGCOORD.xy,ray_origin,ray_direction);
		vec3 newVoxNormal = DDA_SDF_Skipping_Voxel2_get_Normals(ray_origin, ray_direction, hit_position);
		COLOR = vec4(newVoxNormal,1f);
		return
	}
	
	//float hasChanged = mix(0.5,1f,sign(distance(savedVoxNormal,newVoxID)));
	
	//COLOR = vec4(1f,0f,0f, hasChanged);
	//COLOR = vec4(savedVoxID, 1.0);
	//COLOR.rgb = savedVoxID;
	/*
	if(hasChanged>0f){//0:not changed ; 1:changed
		//COLOR = vec4(newVoxID, 1.0);
		//COLOR = vec4(newVoxID, 1.0);
		COLOR.a = 1f;
	}else{
		//COLOR = vec4(newVoxID, 0.1);
		COLOR.a = 0.1f;
	}
	*/
	//COLOR = vec4(newVoxID, 0.5);

	//COLOR = vec4(newVoxID, hasChanged);
}