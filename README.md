# GODOT--DDA_SDF_ACCELERATED_RAY_MARCHING_VOXELS

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
