/*
PUT THIS ON A PLANE MESH
AND TAPE IT INFRONT OF YOUR PERSON'S CAMERA

or tape it onto somewhere else like a door frame or a picture...
just imagine having a lowrez game and then suddenly the game shows you this room with Ray Tracing XD 
just have an "RTX on" png overlay on the corner of the screen

otherwise you could try and convert this into a canvas 2D shader and stick it on the camera's viewport like that...
I wouldn't recommend you doing that actually
just wait for Godot 4 it would be way easier
*/


shader_type spatial;
render_mode unshaded,depth_draw_alpha_prepass,world_vertex_coords;

uniform bool active = true; // on/off switch for entire shader

uniform bool shadow = true; //enables shadows & directional lighting

uniform bool sun = false;
uniform float d_light_energy : hint_range(0, 16) = 1.0; //directional light energy
uniform vec3 d_light_dir = vec3(0.0,0.0,1.0); //directional light vector (global_transform.basis.z)... you don't need an actual directional light object. I used a 3DPoint and it works just fine

uniform int mat:hint_range(0, 3) = 1;//for switching between albedo and specular material setup
//0 = dark grey for directional lighting demo
//1 = default chrome
//2 = gold
//3 = individual albedo and specular material
uniform vec4 light_color:hint_color;
uniform vec3 light_coordinates;

uniform float sky_energy  : hint_range(0, 16) = 0.209; //skybox brightness
uniform mat3 camera_basis = mat3(1.0); //connect real world camera global_transform.basis here
uniform vec3 camera_global_position; //connect real world camera global_transform.origin here

uniform sampler2D texture_here; //2D skybox image here


const float PI = 3.14159265f;
const int BOUNCE = 1; //light bounce count

//const vec4 groundplane = vec4(0.707,0.707,0.0,10.0);
const vec4 groundplane = vec4(0.0,1.0,0.0,-10.0); //vec4(normal_vector.xyz,distance from origin along normal_vector)
uniform vec3 sphere_o10 = vec3(0.0);
//uniform vec3 sphere_o11 = vec3(0.0);

//uniform vec2 PixelOffset = vec2(0f);
/*

the tutorial used structures to create Rays.

struct Ray
{
    float3 origin;
    float3 direction;
};

Godot 3 doesn't "support" structures (see what I-)
so, as a painful substitute, I used "inout" qualifiers to pass on "structure" values instead
I mean it works but the code could have been a lot shorter:

Ray CreateRay(float3 origin, float3 direction)
{
    Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    return ray;
}

and that's just ONE of the reasons why I do NOT recommend what I'm doing
*/

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

/*
initialises a "RayHit", basically 
where a ray hits (position), 
how far from the camera it hit something (distance), 
the surface normal ,
and the color (albedo) and shine(specular) of the surface it hit
*/
void CreateRayHit(inout vec3 hit_position,inout float hit_distance,inout vec3 hit_normal,inout vec3 hit_albedo,inout vec3 hit_specular,inout float hit_emission)
{

    hit_position = vec3(0.0f, 0.0f, 0.0f);
    hit_distance = 9999.0;
    hit_normal = vec3(0.0f, 0.0f, 0.0f);
	hit_albedo = vec3(0.0f, 0.0f, 0.0f);
	hit_specular = vec3(0.0f, 0.0f, 0.0f);
	hit_emission = 0.0f;

}


//checks if a ray hits an infinite plane
void IntersectGroundPlane(vec3 ray_origin, vec3 ray_direction, inout vec3 bestHit_position,inout float bestHit_distance,inout vec3 bestHit_normal,inout vec3 bestHit_albedo, inout vec3 bestHit_specular,inout float bestHit_emission, vec3 pn, float pd,vec3 plane_albedo,vec3 plane_specular,float plane_emission)
{
    // Calculate distance along the ray where the ground plane is intersected
	float rdnpd = dot(pn,-ray_origin)+pd;
	if(rdnpd<0f){//culls back face
		float denominator = dot(ray_direction, pn);
	    float t = rdnpd / denominator;
		if (t > 0.0 && t < bestHit_distance)
		{
			bestHit_distance = t;
			bestHit_position = ray_origin + t * ray_direction;
			bestHit_normal = pn;
			bestHit_albedo = plane_albedo;
			bestHit_specular = plane_specular;
		}
	}
}

//checks if a ray hits a sphere
void IntersectSphere(vec3 ray_origin, vec3 ray_direction, inout vec3 bestHit_position,inout float bestHit_distance,inout vec3 bestHit_normal,inout vec3 bestHit_albedo, inout vec3 bestHit_specular,inout float bestHit_emission, vec4 sphere,vec3 sphere_albedo,vec3 sphere_specular,float sphere_emission)
{
	//better algorithm
	float t = dot((sphere.xyz-ray_origin),ray_direction);
	vec3 p = ray_origin + ray_direction*t;
	float y = length(sphere.xyz-p);
	if(y<sphere.a){
		float x = abs(sqrt((sphere.a*sphere.a)-y*y));
		float t1 = t-x;
	    if (t1 > 0.0 && t1 < bestHit_distance)
	    {
			bestHit_distance = t1;
			bestHit_position = ray_origin + t1 * ray_direction;
			bestHit_normal = normalize(bestHit_position - sphere.xyz);
			bestHit_albedo = sphere_albedo;
			bestHit_specular = sphere_specular;
			bestHit_emission = sphere_emission;
	    }
	}

}


vec3 getVoxelNormal(vec3 intersect, vec3 voxCenter){
	vec3 intrCntr = intersect - voxCenter;
	return trunc(intrCntr*2f);
}

const vec3 mapSize = vec3(1,1,1);
const float cellSize = 1f;
const float maxDist = 100f;


const float boxes[] = {2f};
float getBox(ivec3 where){
	vec3 w = vec3(where);
	return boxes[int(w.z*mapSize.x*mapSize.y + w.y*mapSize.x + w.x)]; // i = x + y*W + z*W*H
}

//https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdSphere(vec3 p){
    float radius = 5.0;
    return length(p-vec3(10.,-5.,-30.))-2.-radius;
}
float gridMap(vec3 p)
{
    //return infSpheres(p);
    return sdSphere(p);//keep camera at origin
    //return sdBox(p,vec3(5.,5.,7.));
    //return infBoxes(p,vec3(5.,3.,7.));
}
void DDA_SDF_IntersectVoxels(vec3 ray_origin, vec3 ray_direction, inout vec3 bestHit_position,inout float bestHit_distance,inout vec3 bestHit_normal,inout vec3 bestHit_albedo, inout vec3 bestHit_specular,inout float bestHit_emission, vec3 voxel_specular,float voxel_emission)
{
	//vec3 cellRayOrigin = ray_origin/cellSize;
	vec3 stp = sign(ray_direction);
    vec3 USS = abs(1.0/ray_direction);//Unit Step Size
	 for(int j=0;j<4;++j){
        vec3 oro=ray_origin;
		vec3 ro=ray_origin;

		// Lightspeed
        float t=0.;
        for(int i=0;i<40;++i)
        {
            ro=oro+ray_direction*t;
            float dist=gridMap(ro);
            if(dist<-3.){//Enter Atmosphere
                break;
            }
            t+=dist;
        }

        //float dist = gridMap(floor(ro));
        bool stop = false;


        for(int i=0;i<32;++i){
        
            vec3 boxPointDifference = fract(-ro * stp) + 1e-4,
            legs = boxPointDifference*USS;
            
            //n=step(legs,legs.yzx)*step(legs,legs.zxy);
            
            float leg = min(legs.x,min(legs.y,legs.z));
            ro += ray_direction * leg;
            vec3 gridBox = floor(ro);
            float dist = gridMap(gridBox);
            if (dist > 1.7) break;//exiting atmosphere
            if(dist<-1.7){
				stop = true;//break out of main loop
				bestHit_position = ro;
				bestHit_distance = length(ro - oro);
				bestHit_normal = getVoxelNormal(ro, (gridBox+0.5));
				bestHit_albedo = gridBox;
				return;
				break;
            }
        }
        if(stop)break;
    }
	
}




//Traces each ray through the environment checking if it hits something along the way and adjusting color, lighting etc. accordingly
void Trace(vec3 ray_origin,vec3 ray_direction,vec3 ray_energy,out vec3 bestHit_position,out float bestHit_distance,out vec3 bestHit_normal,out vec3 bestHit_albedo,out vec3 bestHit_specular,out float bestHit_emission, inout bool is_portal, out vec3 next_rd, bool for_shadowing)
{
/*
/*	
	this would have been way better with a for loop 
	but seeing that GPU Data buffers are still coming soon 
	and arrays are under renovation 
	I think this is good enough for now
*/
	CreateRayHit(bestHit_position, bestHit_distance, bestHit_normal,bestHit_albedo, bestHit_specular,bestHit_emission);
	

	//IntersectBoundedPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal,bestHit_albedo,bestHit_specular,bestHit_emission, p1n, p1o, plane_dimension,p1T_inv,p1ox,vec3(0.5),vec3(0.4),0f);//rectangular mirror
	//IntersectSphere(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, bestHit_albedo, bestHit_specular,bestHit_emission, vec4(sphere_o10.xyz,10.0),vec3(0.3f, 0f, 1f),vec3(0.0f, 0f, 0.0),0f);
	//IntersectGroundPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal,bestHit_albedo,bestHit_specular,bestHit_emission, groundplane.xyz, groundplane.a,vec3(0.5),vec3(0.04),0f);
	DDA_SDF_IntersectVoxels(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, bestHit_albedo, bestHit_specular,bestHit_emission, vec3(1f, 1f, 1f),0f);

	if(for_shadowing){ return; }//I merged the "TraceShadow" function... I just realised I could do this all along
	//IntersectPortalPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, portal1An, portal1Ao,  portal1A_dimension, portal1AT4_inv, portal1AT3_inv,portal1Bn, portal1BT4,portal1BT3,is_portal,next_rd);
	//IntersectPortalPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, portal2An, portal2Ao,  portal2A_dimension, portal2AT4_inv, portal2AT3_inv,portal2Bn, portal2BT4,portal2BT3,is_portal,next_rd);
	//IntersectPortalPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, portal3An, portal3Ao,  portal3A_dimension, portal3AT4_inv, portal3AT3_inv,portal3Bn, portal3BT4,portal3BT3,is_portal,next_rd);
	//IntersectPortalPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, portal4An, portal4Ao,  portal4A_dimension, portal4AT4_inv, portal4AT3_inv,portal4Bn, portal4BT4,portal4BT3,is_portal,next_rd);
	//IntersectPortalPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, portal7An, portal7Ao,  portal7A_dimension, portal7AT4_inv, portal7AT3_inv,portal7Bn, portal7BT4,portal7BT3,is_portal,next_rd);
	//IntersectPortalPlane(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, portal8An, portal8Ao,  portal8A_dimension, portal8AT4_inv, portal8AT3_inv,portal8Bn, portal8BT4,portal8BT3,is_portal,next_rd);
	vec3 light_control = d_light_energy * vec3(1.0, 0.78, 0.14);
	//IntersectSphere(ray_origin, ray_direction, bestHit_position, bestHit_distance, bestHit_normal, bestHit_albedo, bestHit_specular,bestHit_emission, vec4(sphere_o8.xyz,7.0),light_control,vec3(0.0001f),100f); //have to put this after the portals otherwise you can see the emissive sphere through the portal


}

// here's where everything on the screen is coloured in
vec3 Shade(inout vec3 ray_origin,inout vec3 ray_direction,inout vec3 ray_energy, vec3 hit_position,float hit_distance,vec3 hit_normal,vec3 hit_albedo,vec3 hit_specular,float hit_emission,bool is_portal,vec3 next_rd)
{
	
    if (hit_distance < 9900.0)// basically when a ray hits something
    {
		 ray_origin = hit_position + hit_normal * 0.001f; // have to offset the ray origin a little to stop the ray from getting caught behind the surface it's suppose to bounce off of
        // Reflect the ray and multiply energy with specular reflection
		vec3 albedo;
        vec3 specular;
		float emission = 0f;
		vec3 light_dir = d_light_dir;
		vec3 light_origin;
		vec3 light_albedo = light_color.xyz;
		float light_dist = 9900f;
		
		if(!sun){
			light_origin = ray_origin + light_coordinates;
			//light_origin = ray_origin - sphere_o8.xyz;
			
			light_dist = length(light_origin);
			
			light_dir = normalize(light_origin);
			//light_albedo = light_color.xyz;
			//light_albedo = vec3(0.20, 0.78, 0.84);
			light_albedo = vec3(1.0, 0.78, 0.34);
		}
		
		switch(mat){
			case 0:{
				specular = vec3(0.04);//shaded
				//vec3 albedo = vec3(0.0,0.0,0.70);//blue
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

		if(!is_portal){
			ray_direction = reflect(ray_direction, hit_normal);
			ray_energy *= specular;
		}
		else{
			ray_direction = next_rd;
			//ray_energy *= 0.5f;
/*			
			specular = vec3(0.0);
			albedo = vec3(1.0);
*/
		}

		if(shadow)// surprisingly shadows are their own rays but backwards
		{
			vec3 shadowRay_origin;
			vec3 shadowRay_direction;
			vec3 shadowRay_energy;
			
			//CreateRay(ray_origin,-d_light_dir, shadowRay_origin, shadowRay_direction, shadowRay_energy);
			CreateRay(ray_origin,-light_dir, shadowRay_origin, shadowRay_direction, shadowRay_energy);
			vec3 shadowHit_position;
			float shadowHit_distance;
			vec3 shadowHit_normal;
			vec3 shadowHit_albedo;
			vec3 shadowHit_specular;
			float shadowHit_emission;
			//shadow rays skip over emissive objects
			Trace(shadowRay_origin,shadowRay_direction,shadowRay_energy,shadowHit_position,shadowHit_distance,shadowHit_normal,shadowHit_albedo,shadowHit_specular,shadowHit_emission,is_portal,next_rd,true);
			//if (shadowHit_distance <= 9900.0)// if the shadow Ray hits something (ie the ray is blocked from reaching infinity) the passed on light ray energy is multiplied by 0.0
			if (shadowHit_distance <= light_dist)
			{
				return vec3(0.0) + albedo*emission * light_albedo; // basically a shadow
			}
			if(emission > 0f){
				return emission*albedo;
			}else{
				//return clamp(dot(hit_normal, d_light_dir)*-1.0,0.0,1.0) * d_light_energy * albedo; //every other ray gets to be coloured in
				if(is_portal){
					return vec3(0f);
					//return clamp(dot(hit_normal, light_dir)*-1.0,0.0,1.0) * d_light_energy * light_albedo ; //every other ray gets to be coloured in
				}
				return clamp(dot(hit_normal, light_dir)*-1.0,0.0,1.0) * d_light_energy* albedo * light_albedo ; //every other ray gets to be coloured in

			}
			
		}
		else{ //else if shadows are disabled
				return emission*albedo;

			//return clamp(dot(hit_normal, d_light_dir)*-1.0,0.0,1.0) * d_light_energy * albedo; //colors pixel by albedo and d_light
			//return vec3(0.0, 0.0, 0.0);// Return nothing
			/*
			//default black
			return vec3(0.0, 0.0, 0.0);// Return nothing

			 at the end of each trace if the ray hits anything, the pixel that the ray is attached to is initially coloured black
			 as the ray bounces around the scene it should eventually reach infinity(9900.0f), shooting off into the sky
			 only then is the pixel coloured with a sample from the sky texture on the next else statement
			 if the ray kept bouncing, exceeding the "BOUNCE" limit, 
			 it's left as is: a black spot on the screen (specifically on the reflective sphere/plane) where the light never escaped			 
*/	 
		}
        
    }
    else
    {
        // Erase the ray's energy - the sky doesn't reflect anything
        ray_energy = vec3(0.0);
	
// this samples the 2D texture as if it was a sphere	
		float theta = acos(ray_direction.y) / PI;
		//float phi = (atan(ray_direction.x, ray_direction.z)-(180.0f*PI/180f)) / -PI*0.5;
		float phi = (atan(ray_direction.x, ray_direction.z)-PI) / -PI*0.5;
		return textureLod(texture_here,vec2(phi,theta),0).xyz*sky_energy;//needs to be textureLod else a weird line appears in sample

/*//from ShaderToy Test
        //For 2D texture only
        float theta = acos(ray.direction.y) / -PI;
        float phi = atan(ray.direction.x, -ray.direction.z) / -PI * 0.5f;
        return texture(iChannel0, vec2(phi, theta)).xyz;
		//For Cubemaps
        //return texture(texture_here, ray_direction).xyz;//texture
        //return ray_direction* 0.5 + 0.5;//uv rainbow
*/
    }
}

void fragment() {
	if(active){
		vec3 ray_origin;
		vec3 ray_direction;
		vec3 ray_energy;
		
		vec3 hit_position;
		float hit_distance;
		vec3 hit_normal;
		vec3 hit_albedo;
		vec3 hit_specular;
		float hit_emission;

		CreateCameraRay(SCREEN_UV,VIEWPORT_SIZE,FRAGCOORD.xy,ray_origin,ray_direction,ray_energy);
    
	    vec3 result = vec3(0.0, 0.0, 0.0);
	    vec3 m_ray_energy;
		vec3 next_rd;
		
	    for (int i = 0; i < BOUNCE; i++)
	    {
			bool is_portal = false;
			m_ray_energy=ray_energy; 

	        Trace(ray_origin,ray_direction,ray_energy,hit_position,hit_distance,hit_normal,hit_albedo,hit_specular,hit_emission,is_portal,next_rd,false);

			result += m_ray_energy * Shade(ray_origin,ray_direction,ray_energy, hit_position,hit_distance,hit_normal,hit_albedo,hit_specular,hit_emission,is_portal,next_rd);
/*
			here's the original code snippet from the tutorial blog:
				result += ray.energy * Shade(ray, hit);

			I had to make it remember the last ray_energy value (hence: "m_ray_energy") since the "Shade" function kept changing it right before it gets multiplied
*/

	        if (all(lessThan(ray_energy, vec3(0.001)))) break; // this breaks out of the loop if the ray_energy drops too low
								// apparently GLSL's built in "any" function takes in binary vectors as inputs, different from HLSL's (Unity's Compute Shader)
								
	    }
		ALBEDO = result;
		ALPHA = 1.80;
	}
}

