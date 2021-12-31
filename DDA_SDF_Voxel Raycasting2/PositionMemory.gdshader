shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D image : hint_albedo;
uniform bool active = false;

uniform float sky_energy  : hint_range(0, 16) = 0.209; //skybox brightness
uniform mat3 camera_basis = mat3(1.0); //connect real world camera global_transform.basis here
uniform vec3 camera_global_position; //connect real world camera global_transform.origin here
varying vec3 fragColor;

uniform int mat:hint_range(0, 4) = 1;//for switching between albedo and specular material setup
const float PI = 3.14159265f;
uniform sampler2D texture_here; //2D skybox image here

uniform sampler2D pos_memory: hint_albedo; //2D skybox image here

uniform int BOUNCE = 2;
uniform vec2 viewport_size = vec2(1024,600);

uniform vec3 Center = vec3(0.,0.,-150.);
uniform float Radius = 10f;
uniform vec3 Dimensions = vec3(1.,1.,1.);

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

float sdSphere(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
    return length(p-c)-atmosphere_thickness-radius;
}

float gridMapNoNormals(vec3 p){
	return sdSphere(p,Radius,Center);
}

vec3 DDA_SDF_Skipping_Voxel2(inout float isSolid, inout float dist,inout vec3 ray_origin, inout vec3 ray_direction,inout vec3  hit_position){

	vec3 stp = sign(ray_direction);
    vec3 USS = abs(1.0/ray_direction);//Unit Step Size
    isSolid = 0f;
	hit_position=ray_origin;

	vec3 oro;
	
	vec3 voxID;

		for(int j=0;j<6;++j){
	        oro=hit_position;
			bool stop = false;

			// Lightspeed
	        float t=0.;
			for(int i=0;i<10;++i){
	            hit_position=oro+ray_direction*t;
	            //dist = gridMap(hit_position).a;
				dist = gridMapNoNormals(hit_position);
				//dist = gridMapNoNormals(floor(hit_position)+0.5);
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
					stop = true;//break out of main loop
					break;
	            }
	        }
			if(stop)break;
		}
		return voxID;
}


void fragment() {
	/*
	//float calculated_coord =420f;// -32768  to +32767
	float color_coord = 1f;
	//float v = color_coord/4096f;// limit reached, need 32bit color vector components
	//float hasChanged = 0.5f; // 0.1: hasChanged; 1:!hasChanged //set transparency on
	float hasChanged = 1f; // 0.1: hasChanged; 1:!hasChanged //set transparency on
	//COLOR = vec4(color_coord,0f,0f,1f);
	//vec4 comp = texture(SCREEN_TEXTURE,SCREEN_UV);
	//COLOR = vec4(color_coord,0f,0f,1f);
	vec3 c = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	if(float(c.g) >= 1f){
		COLOR = vec4(color_coord,0f,0f,0.5f);
	}else{
		COLOR = vec4(color_coord,0f,1f,1f);
	}
	*/
	
	vec3 newVoxID;
	
	vec3 ray_origin;
	vec3 ray_direction;
	vec3 ray_energy;
	float dist;
	
	vec3 camera_forward;
	CreateCameraRay(SCREEN_UV,viewport_size,FRAGCOORD.xy,ray_origin,ray_direction,ray_energy,camera_forward);
	vec3 camera_origin = ray_origin;
	vec3 camera_ray = ray_direction;
	vec3 result = vec3(0.0, 0.0, 0.0);

	vec3 m_ray_energy;
	vec3 hit_position;
	vec3 hit_normal = vec3(0f);
	float isSolid = 0f;
	
	newVoxID = DDA_SDF_Skipping_Voxel2(isSolid, dist, ray_origin, ray_direction, hit_position);
	vec3 savedVoxID = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	float hasChanged = distance(savedVoxID,newVoxID);
	
	//COLOR = vec4(1f,0f,0f, hasChanged);
	//COLOR = vec4(savedVoxID, 1.0);
	
	/if(hasChanged>0f){//0:not changed ; 1:changed
		//COLOR = vec4(newVoxID, 1.0);
		COLOR = vec4(newVoxID, 1.0);
	}else{
		COLOR = vec4(newVoxID, 0.1);
	}
	
	//COLOR = vec4(newVoxID, 0.5);
}