//DO NOT FORGET TO SET FOV TO 90

shader_type spatial;
render_mode unshaded,world_vertex_coords,depth_draw_alpha_prepass;

uniform bool active = false;

uniform float sky_energy  : hint_range(0, 16) = 0.209; //skybox brightness
uniform mat3 camera_basis = mat3(1.0); //connect real world camera global_transform.basis here
uniform vec3 camera_global_position; //connect real world camera global_transform.origin here
varying vec3 fragColor;

uniform int mat:hint_range(0, 4) = 1;//for switching between albedo and specular material setup
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

vec4 sdSphereFastNorm(vec3 p,float radius,vec3 c){
	float atmosphere_thickness = 2f;
	vec3 diff = p-c;
	vec3 normal = normalize(diff);
    return vec4(normal,length(diff)-atmosphere_thickness-radius);
}

const float h = 1f;
const vec2 k = vec2(1,-1);

//https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
vec4 sdBoxWNormalTetrahedron(vec3 p,vec3 dim,vec3 cen){
	float value = sdBox(p,dim,cen);
	vec3 normal = k.xyy*sdBox(p+k.xyy*h,dim,cen) + k.yyx*sdBox(p+k.yyx*h,dim,cen) + k.yxy*sdBox(p+k.yxy*h,dim,cen) + k.xxx*sdBox(p+k.xxx*h,dim,cen);
	return vec4(normalize(normal),value);
}

vec4 sdSphereWNormalTetrahedron(vec3 p,float radius,vec3 cen){
	float value = sdSphere(p,radius,cen);
	vec3 normal = k.xyy*sdSphere(p+k.xyy*h,radius,cen) + k.yyx*sdSphere(p+k.yyx*h,radius,cen) + k.yxy*sdSphere(p+k.yxy*h,radius,cen) + k.xxx*sdSphere(p+k.xxx*h,radius,cen);
	return vec4(normalize(normal),value);
}




uniform sampler3D inputVoxelMap;
float sdtexture3DMap(vec3 x){
	x += 0.5;
	vec3 fx = fract( x );
	x = floor( x ) + fx*fx*(3.0-2.0*fx);
    return texture( inputVoxelMap, (x-0.5)/64.0 ).x-2f;
}

vec4 sdtexture3DMapNormalTetrahedron( vec3 p ){
	float value = sdtexture3DMap(p);
	vec3 normal = k.xyy*sdtexture3DMap(p+k.xyy*h) + k.yyx*sdtexture3DMap(p+k.yyx*h) + k.yxy*sdtexture3DMap(p+k.yxy*h) + k.xxx*sdtexture3DMap(p+k.xxx*h);
	return vec4(normalize(normal),value);
}




vec4 sdSphereWMyNormal(vec3 p,vec3 p_b,vec3 p_f,float radius,vec3 cen){
	vec3 voxelCenter = floor(p_f)+0.5f;
	float value = sdSphere(voxelCenter,radius,cen);
	
	//vec3 normal = floor((p_b - voxelCenter)*2f);
	vec3 hitCenter = p_b - voxelCenter;
	//vec3 hitCenter = p - voxelCenter;
	vec3 normal = step(0.5,abs(hitCenter)) * sign(hitCenter);
	return vec4(normal,value);
}

vec4 sdBoxWMyNormal(vec3 pb,vec3 pf,vec3 dim,vec3 cen){
	vec3 voxelCenter = floor(pf)+0.5f;
	float value = sdBox(voxelCenter,dim,cen);
	
	//vec3 normal = floor((pb - voxelCenter)*2f);
	//vec3 normal = floor((pb - voxelCenter)/4f*2f);
	//vec3 normal = floor((pb - voxelCenter)*.5);//voxel is 2x2x2 in world space; max value of all hitCenter components is 1; must divide by 2 to reach 1
	vec3 hitCenter = pb - voxelCenter;
	vec3 normal = step(0.5,abs(hitCenter)) * sign(hitCenter);// better
	return vec4(normal,value);
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

vec4 gridMap(vec3 p){
	//return sdtexture3DMapNormalTetrahedron(p);
	//return sdMapTerrainNormalTetrahedron(p);
	//return sdHeightMapNormalTetrahedron(p);
	//return sdBoxWNormalTetrahedron(p,dimensions,center);
	return sdSphereWNormalTetrahedron(p,radius,center);
	//return sdSphereFastNorm(p,radius,center);
	//return vec4(vec3(0f,0f,1f),infSpheres(p,radius));
	
}


vec4 gridMap2(vec3 p,vec3 p_b,vec3 p_f){// p+ray_diraction*0.01;

	return sdSphereWMyNormal(p,p_b,p_f,radius,center);
	//return sdBoxWMyNormal(p_b,p_f,dimensions,center);

	
}

void DDA_SDF_Skipping_Voxel(inout float isSolid, inout float dist,inout vec3 ray_origin, inout vec3 ray_direction,inout vec3  hit_position,inout vec3 hit_normal){

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
	            vec4 map = gridMap(floor(hit_position)+0.5);
				//vec4 map = gridMap2(hit_position,hit_position-ray_direction*0.001,hit_position+ray_direction*0.001);
				if (map.a >= 3.7) break;//exiting atmosphere
				if(map.a <= -1.9){
					isSolid = 1f;
					hit_normal = map.xyz;//getVoxelNormal(hit_position);
					stop = true;//break out of main loop
					break;
	            }
				
				/*
				float mapp = gridMapNoNormals(floor(hit_position));
				if (mapp >= 3.7) break;//exiting atmosphere
				if(mapp <= -1.9){
					isSolid = 1f;
					hit_normal = vec3(0f,0f,1f);
					stop = true;//break out of main loop
					break;
	            }
				*/
	        }
			if(stop)break;
		}
		
		
}


void DDA_SDF_Skipping_Voxel2(inout float isSolid, inout float dist,inout vec3 ray_origin, inout vec3 ray_direction,inout vec3  hit_position){

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
				
				float map = gridMapNoNormals(floor(hit_position)+0.5);
				if (map >= 3.7) break;//exiting atmosphere
				if(map <= -1.9){
					isSolid = 1f;
					stop = true;//break out of main loop
					break;
				/*
	            vec4 map = gridMap(floor(hit_position)+0.5);
				//vec4 map = gridMap2(hit_position,hit_position-ray_direction*0.001f,hit_position+ray_direction*0.01);
				if (map.a >= 3.7) break;//exiting atmosphere
				if(map.a <= -1.9){
					isSolid = 1f;
					hit_normal = map.xyz;//getVoxelNormal(hit_position);
					stop = true;//break out of main loop
					break;
				*/
	            }
				
				/*
				float mapp = gridMapNoNormals(floor(hit_position));
				if (mapp >= 3.7) break;//exiting atmosphere
				if(mapp <= -1.9){
					isSolid = 1f;
					hit_normal = vec3(0f,0f,1f);
					stop = true;//break out of main loop
					break;
	            }
				*/
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
/*
vec3 reconstructPosFromDepth(vec2 uv,float z, mat4 InvVP){
	float x = uv.x * 2f - 1f;
	float y = (1f-uv.y)*2f-1f;
	vec4 pos_s = vec4(x,y,z,1f);
	vec4 pos_v = InvVP*pos_s;
	return pos_v.xyz/pos_v.w;
}

vec3 reconstructNormalsFromDepth(vec3 uvHitPos,vec2 uv,sampler2D depthTxtr,vec2 viewPortSize, mat4 InvVP, mat4 WV,mat4 VP){
	//vec4 uvMat = (WV*VP*vec4(uvHitPos,1f));
	//vec2 uv = (uvMat.xy/uvMat.w)*0.5-0.5;
	vec2 uv1 = uv + vec2(1,0) / vec2(1024,600);//viewPortSize;
	vec2 uv2 = uv + vec2(0,1) / vec2(1024,600);
	float depth0 = texture(depthTxtr,uv).x;
	float depth1 = texture(depthTxtr,uv1).x;
	float depth2 = texture(depthTxtr,uv2).x;
	vec3 p0 = reconstructPosFromDepth(uv,depth0,InvVP);
	vec3 p1 = reconstructPosFromDepth(uv1,depth1,InvVP);
	vec3 p2 = reconstructPosFromDepth(uv2,depth2,InvVP);
	return normalize(cross(p2-p0,p1-p0));
}
*/


uniform float near=0.05;
uniform float far=1000f;

void fragment() {
	vec3 ray_origin;
	vec3 ray_direction;
	vec3 ray_energy;
	float dist;
	
	vec3 camera_forward;
	CreateCameraRay(SCREEN_UV,VIEWPORT_SIZE,FRAGCOORD.xy,ray_origin,ray_direction,ray_energy,camera_forward);
	vec3 camera_origin = ray_origin;
	vec3 camera_ray = ray_direction;
	vec3 result = vec3(0.0, 0.0, 0.0);
	//vec3 m_ray_energy=ray_energy;
	vec3 m_ray_energy;
	vec3 hit_position;
	vec3 hit_normal = vec3(0f);
	float isSolid = 0f;
	if(active){
		/*
		//m_ray_energy=ray_energy;
			
		//DDA_SDF_Skipping_Voxel(isSolid,dist,ray_origin, ray_direction,hit_position,hit_normal);
		DDA_SDF_Skipping_Voxel2(isSolid,dist,ray_origin, ray_direction,hit_position);
		
		//float sample_depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
		//vec3 voxColor = vec3(1f);
		//result += m_ray_energy * Shade(isSolid,dist,ray_origin,ray_direction,ray_energy,hit_position, hit_normal,voxColor,vec3(0f, 0f, 0f),1f);
		//ALBEDO = result;
		
		vec3 cam_to_hit = hit_position-camera_origin;
		//float ze = (INV_CAMERA_MATRIX*PROJECTION_MATRIX*vec4(cam_to_hit,1f)).z; //worldSpace > viewSpace > projection/ClipSpace
		float ze = -length(cam_to_hit)*dot(camera_forward,normalize(cam_to_hit));// faster
		float depth = ((far+near)+(2f*far*near/ze))/(far-near);//ndc
		//depth = depth *50f-49f;
		//ALBEDO = vec3(depth);
		DEPTH = depth;
		*/
		for (int i = 0; i < BOUNCE; i++)
		{
			
			m_ray_energy=ray_energy;
			
			DDA_SDF_Skipping_Voxel(isSolid,dist,ray_origin, ray_direction,hit_position,hit_normal);
			//DDA_SDF_Skipping_Voxel2(isSolid,dist,ray_origin, ray_direction,hit_position);
			//vec2 uv1 = SCREEN_UV + vec2(1,0) / vec2(1024,600);//viewPortSize;
			//vec2 uv2 = SCREEN_UV + vec2(0,1) / vec2(1024,600);
			//float depth0 = texture(DEPTH_TEXTURE, SCREEN_UV).x;
			//float depth1 = texture(DEPTH_TEXTURE, SCREEN_UV).x;
			//float depth2 = texture(DEPTH_TEXTURE, SCREEN_UV).x;
			
			//hit_normal = reconstructNormalsFromDepth(hit_position,SCREEN_UV,DEPTH_TEXTURE,VIEWPORT_SIZE, INV_PROJECTION_MATRIX, INV_CAMERA_MATRIX,PROJECTION_MATRIX);
			//Trace(ray_origin,ray_direction,ray_energy,hit_position,hit_normal);
			vec3 voxColor = hit_position;
			//voxColor = vec3(1f);
			result += m_ray_energy * Shade(isSolid,dist,ray_origin,ray_direction,ray_energy,hit_position, hit_normal,voxColor,vec3(0f, 0f, 0f),1f);
			if (all(lessThan(ray_energy, vec3(0.001)))) break;
		}
		ALBEDO = result;//fragColor;
		//float depth0 = texture(DEPTH_TEXTURE, SCREEN_UV).x;// why is this important?
		
		//depth0 = depth0 *50f-49f;
		//ALBEDO = vec3(depth0);
		//float depth0 = texture(DEPTH_TEXTURE, SCREEN_UV).x;// why is this important?
		
		vec3 cam_to_hit = hit_position-camera_origin;
		float diff = far - near;
		float eyeHitZ = -length(cam_to_hit) *dot(camera_forward,normalize(cam_to_hit));
 		float ndcDepth = ((far+near) + ((2.0*far*near)/eyeHitZ))/(far-near);//goes from -1 to 1
  		//DEPTH = ndcDepth;
		//DEPTH = ndcDepth*2f-1f;
		DEPTH = (ndcDepth+1f)/2f;//need to shift the functin up since Godot's depth buffer only ever goes from 0 to 1
		//ALBEDO = vec3(ndcDepth*50f-49f);
		//DEPTH = ((diff * ndcDepth) + near + far) / 2.0;
		
		//((diff * ndcDepth) + near + far) / 2.0;
		
		/*
		float diff = far - near;
		float ze = (INV_CAMERA_MATRIX*vec4(hit_position,1f)).z;
		float zn = (far+near)/(far-near) + (2f*far*near/(far-near))/ze; //((far+near)+(2f*far*near/ze))/(far-near);
		DEPTH = ((diff * zn) + near + far) / 2.0;
		*/
		
		
		//float ze = (INV_CAMERA_MATRIX*PROJECTION_MATRIX*vec4(cam_to_hit,1f)).z; //worldSpace > viewSpace > projection/ClipSpace
		/*
		vec4 z = PROJECTION_MATRIX*vec4(cam_to_hit,1f);
		float zc = z.z;
		float zw = z.w;
		float depth =zc/zw;
		DEPTH = depth;
		*/
		
		//float ze = -length(cam_to_hit)*dot(camera_forward,cam_to_hit);// faster
		//float depth = ((far+near)+(2f*far*near/ze))/(far-near);//ndc
		//float addDepth = min(depth,depth0);
		//depth = depth *2f - 1f;
		/*
		float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		float linear_depth = -view.z;
		//vec4 world = CAMERA * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		//vec3 world_position = world.xyz / world.w;
		
		//ALBEDO = vec3(view.xyz);
		*/
		//depth = PROJECTION_MATRIX[3][2] / (depth + PROJECTION_MATRIX[2][2]);
		//depth += VERTEX.z;
		//vec4 unproject = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
		//vec3 view_vertex = unproject.xyz / unproject.w;
		//ALBEDO = vec3(depth);
		//DEPTH = depth;
		//addDepth = addDepth *50f-49f;
		//ALBEDO = vec3(addDepth);
		
		
		
		/*
		float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		float linear_depth = -view.z;
		*/
		/*
		float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
		depth = depth *50f-49f;
		ALBEDO = vec3(depth);
		*/

		
		
	}
}