# GODOT--DDA_SDF_ACCELERATED_RAY_MARCHED_VOXELS
<img width="1008" alt="Screen Shot 2021-12-31 at 6 57 18 PM" src="https://user-images.githubusercontent.com/37253663/147819756-83d5e552-b8b1-435a-b9a9-606a5c752a05.png">
<img width="1022" alt="Screen Shot 2021-12-31 at 6 52 59 PM" src="https://user-images.githubusercontent.com/37253663/147819799-a5a4d5ba-de67-403f-8d37-c30e1e309f11.png">
<img width="1016" alt="Screen Shot 2021-12-31 at 6 53 40 PM" src="https://user-images.githubusercontent.com/37253663/147819805-c942324a-2fe7-4b31-92c7-406796a2d577.png">
<img width="1014" alt="Screen Shot 2021-12-31 at 6 52 43 PM" src="https://user-images.githubusercontent.com/37253663/147819819-658ec2d1-f1a6-48b8-8d90-1070fdc5f411.png">
<img width="1019" alt="Screen Shot 2021-12-31 at 6 55 31 PM" src="https://user-images.githubusercontent.com/37253663/147819864-18c25e32-a5fc-43fa-b848-8f93fc79a74f.png">
<img width="1000" alt="Screen Shot 2021-12-31 at 6 51 33 PM" src="https://user-images.githubusercontent.com/37253663/147819868-ccbe759b-19d7-485c-b3f6-f73143ffb399.png">

<img width="1018" alt="Screen Shot 2021-12-31 at 6 56 31 PM" src="https://user-images.githubusercontent.com/37253663/147819765-538416ce-a8b3-4847-b6f7-e807e1fd0984.png">


<img width="1019" alt="Screen Shot 2021-12-31 at 6 46 30 PM" src="https://user-images.githubusercontent.com/37253663/147819256-8b3679db-e89d-4470-a752-e593a8671c9e.png">

watch the [video](https://youtu.be/9p9JJ-nDqUg)

Godot Version: 3.4.stable

My System: MacBook Pro Intel Iris 1536 MB (Without NVIDIA :( )

This is based on my old ray casting project a few months back. I just needed something to render a lot of things from far away... but I ended up over doing it.

A ray travels through a uniform grid using the Digital Differential Analyzer Algorithm but skips the empty grids using a signed distance field.

I also made it write to the depth buffer so it could render with regular polygon meshes.


I can't really trust the FPS readout (may be it has something to do with my Mac). Weirder still, recording it with [henriquelalves' in game recorder](https://godotengine.org/asset-library/asset/220) speeds everything up for some reason. That's why you could see me moving around like it wasn't dipping under 15FPS.

It's slow when using Texture3D voxel maps. It's either cause I'm using a Mac or I'm using an old Mac (the kind that DOESN'T have an NVIDIA GPU). Try it out, it should run faster with better hardware.

The voxels might be a bit dirty and they might be surrounded by bubbles. I still need to work on those.





Thanks to:
Sjoerd Wouters: https://www.youtube.com/channel/UC8sR8zJ2sJyLDIjB5tIRJvw

Voxelbee: https://www.youtube.com/c/voxelbee

Javdix9 (DDA Algorithm): https://www.youtube.com/watch?v=NbSee-XM7WA&t=1245s

Inigo Quilez (SDFs): https://iquilezles.org/www/articles/distfunctions/distfunctions.htm

Mikael Hvidtfeldt Christensen (Depth Buffer): http://blog.hvidtfeldts.net/index.php/2014/01/combining-ray-tracing-and-polygons/

 henriquelalves (Godot Recorder): https://godotengine.org/asset-library/asset/220
and everyone from r/Godot and r/openGL

EDIT:
Sorry, almost forgot to thank these guys as reference:
Xor: https://www.shadertoy.com/view/fstSRH
fizzer: https://www.shadertoy.com/view/MllcD7
