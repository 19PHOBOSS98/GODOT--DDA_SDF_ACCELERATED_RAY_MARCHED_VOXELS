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
float sdSphere(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
    return length(p-c)-atmosphere_thickness-radius;
}
float sdBox( vec3 p, vec3 b ){
	float atmosphere_thickness = 2f;
	vec3 q = abs(p-vec3(10.,-5.,-30.)) - atmosphere_thickness - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float gridMap(vec3 p)
{
    //return infSpheres(p,10.);
    return sdSphere(p,10.0,vec3(10.,-5.,-30.));//keep camera at origin
	//return sdSphere(p,10.0,vec3(0.,0.,0.));//keep camera at origin
	//return sdBox(p,vec3(5.,3.,7.));
    //return sdBox(p,vec3(.5,.5,.5));
    //return infBoxes(p,vec3(10.,10.,10.));
}

vec3 getVoxelNormal(vec3 intersect, vec3 voxCenter){
	vec3 intrCntr = intersect - voxCenter;
	return trunc(intrCntr*2f);
}

void DDA_SDF_Skipping_Voxel(inout float dist,inout vec3 ray_origin, inout vec3 ray_direction, inout vec3 ray_energy,inout vec3  hit_position,inout vec3 hit_normal){

	vec3 stp = sign(ray_direction);
    vec3 USS = abs(1.0/ray_direction);//Unit Step Size
    
	hit_position=ray_origin;

	vec3 oro;

	    //for(int j=0;j<4;++j){
		for(int j=0;j<6;++j){
			//if(distance(ray_origin,oro)>1000f)break;
	        oro=hit_position;
			bool stop = false;
			// Lightspeed
	        float t=0.;
			
	        //for(int i=0;i<40;++i)
			//for(int i=0;i<20;++i)
			for(int i=0;i<10;++i)
	        {
	            hit_position=oro+ray_direction*t;
	            dist = gridMap(hit_position);
				//if(dist<-1.7){//Enter Atmosphere
				if(dist<=0.){//Enter Atmosphere
	                break;
	            }
	            t+=dist;
	        }
	        //for(int i=0;i<32;++i){
			//for(int i=0;i<16;++i){
			for(int i=0;i<16;++i){
	            vec3 boxPointDifference = fract(-hit_position * stp) + 1e-4,
	            legs = boxPointDifference*USS;
	            
	            float leg = min(legs.x,min(legs.y,legs.z));
	            hit_position += ray_direction * leg;
	            
	            dist = gridMap(floor(hit_position));
				//travel += dist;
				if (dist >= 3.7) break;//exiting atmosphere
	            //if(dist<-4.7){//for 5 units thick atmosphere // atmosphere_thickness - 0.7
				if(dist<-1.9){
	                stop = true;//break out of main loop
	                break;
	            }
	        }
			
			if(stop)break;
			//if(stop||length(ray_origin-camera_o)>1000f)break;
	    }
		hit_normal = getVoxelNormal(hit_position, floor(hit_position)+0.5);
}

vec3 Shade(float dist,inout vec3 ray_origin,inout vec3 ray_direction,inout vec3 ray_energy, vec3 hit_position, vec3 hit_normal,vec3 hit_albedo,vec3 hit_specular,float hit_emission){
	vec3 albedo;
	vec3 specular;
	float emission = 0f;

	float isSolid = step(dist,0f);
	float isSpace = 1f-step(dist,0f);

	ray_origin = hit_position + hit_normal * 0.001f*isSolid;
	ray_direction = reflect(ray_direction, hit_normal)*isSolid + ray_direction*isSpace;
	
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
	ray_energy *= specular*isSolid;//turns zero if not solid

	if(isSolid>0f){
		return emission*albedo;
	}else{
        //ray_energy = vec3(0.0);
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
	vec3 hit_normal;
	
	/*
	vec3 stp = sign(ray_direction);
    vec3 USS = abs(1.0/ray_direction);//Unit Step Size
    
    vec3 co=ray_origin;
    vec3 n;
	vec3 hit_position=ray_origin;
	if(active){
		vec3 oro;
		
		//vec3 camera_o=ray_origin;
		//float travel=0f;
	    //for(int j=0;j<4;++j){
		for(int j=0;j<6;++j){
			//if(distance(ray_origin,oro)>1000f)break;
	        oro=hit_position;
			bool stop = false;
			// Lightspeed
	        float t=0.;
			
	        //for(int i=0;i<40;++i)
			//for(int i=0;i<20;++i)
			for(int i=0;i<10;++i)
	        {
	            hit_position=oro+ray_direction*t;
	            dist = gridMap(hit_position);
				//if(dist<-1.7){//Enter Atmosphere
				if(dist<=0.){//Enter Atmosphere
	                break;
	            }
	            t+=dist;
	        }
			//travel += t;
	        //float dist = gridMap(floor(ray_origin));
	        //for(int i=0;i<32;++i){
			//for(int i=0;i<16;++i){
			for(int i=0;i<16;++i){
	            vec3 boxPointDifference = fract(-hit_position * stp) + 1e-4,
	            legs = boxPointDifference*USS;
	            
	            n=step(legs,legs.yzx)*step(legs,legs.zxy);
	            
	            float leg = min(legs.x,min(legs.y,legs.z));
	            hit_position += ray_direction * leg;
	            
	            dist = gridMap(floor(hit_position));
				//travel += dist;
				if (dist >= 3.7) break;//exiting atmosphere
	            //if(dist<-4.7){//for 5 units thick atmosphere // atmosphere_thickness - 0.7
				if(dist<-1.9){
	                stop = true;//break out of main loop
	                break;
	            }
	        }
			
			if(stop)break;
			//if(stop||length(ray_origin-camera_o)>1000f)break;
	    }
	*/
		if(active){
			DDA_SDF_Skipping_Voxel(dist,ray_origin, ray_direction,ray_energy,hit_position,hit_normal);
			vec3 voxColor = floor(hit_position);
			result += m_ray_energy * Shade(dist,ray_origin,ray_direction,ray_energy,hit_position, hit_normal,voxColor,vec3(0.3f, 0f, 1f),1f);
		/*
		// Checkerboard texture.
		float isSolid = step(dist,0f);
	    ray_origin+=1e-3;
	    float tex=.8+.2*step(.5,fract(ray_origin.x+.5*step(.5,fract(ray_origin.y+.5*step(.5,fract(ray_origin.z))))))*isSolid;

	    // Basic lighting.
	    vec3 ld=normalize(vec3(3,4,1));
	    fragColor = tex*vec3(.5+.5*dot(n*-sign(ray_direction),ld));

	    // Distance fading.
	    float fogstrength=.01;
	    float fogamount=exp(-distance(ray_origin,co)*fogstrength);
	    fragColor=mix(vec3(0),fragColor.rgb,fogamount);
	    
	    // Gamma.
	    fragColor=sqrt(fragColor.rgb);
		*/
		ALBEDO = result;//fragColor;
	}
}