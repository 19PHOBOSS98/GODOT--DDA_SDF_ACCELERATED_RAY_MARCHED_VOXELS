extends MeshInstance

var m = 0;
var b = 2;
var voxelMap = 0;
var infVoxelMap = 7;
var texVoxelMap = 5;
var cscale = 1;

func _ready():
	change_cell_scale(1)
	change_VoxelMap(2)
	set_bounce(4)
	change_mat(2)
	#pass

func _process(_delta):
	if Input.is_action_just_pressed("change_mat"):
		change_mat(m)
		m = (m+1)%8
	if Input.is_action_just_pressed("reflection_inc"):
		b = clamp((b+1),1,4);
		set_bounce(b)
	if Input.is_action_just_pressed("reflection_dec"):
		b = clamp((b-1),1,4);
		set_bounce(b)
		
	if Input.is_action_just_pressed("cel_scale_inc"):
		cscale = clamp((cscale+1),1,10);
		change_cell_scale(cscale)
	if Input.is_action_just_pressed("cel_scale_dec"):
		cscale = clamp((cscale-1),1,10);
		change_cell_scale(cscale)
		
	if Input.is_action_just_pressed("change_voxelmap"):
		match(voxelMap): 
			0:
				b = 4
				cscale = 1
			3,4:
				b = 4
				cscale = 10
			_:
				b = 2
				cscale = 1
		change_cell_scale(cscale)
		set_bounce(b)
		change_VoxelMap(voxelMap)
		voxelMap = (voxelMap+1)%5
	if Input.is_action_just_pressed("texture_voxelmap"):
		m=2
		b=4
		set_bounce(b)
		change_mat(m)
		change_VoxelMap(texVoxelMap)
		texVoxelMap = 5 if texVoxelMap > 5 else 6;
		
	if Input.is_action_just_pressed("infinite_voxelmap"):
		b=1
		m=4
		set_bounce(b)
		change_mat(m)
		change_VoxelMap(infVoxelMap)
		infVoxelMap = 7 if infVoxelMap>7 else 8;

	#self.get_active_material(0).set_shader_param("PixelOffset", Vector2(rng.randf_range(0.0,1.0),rng.randf_range(0.0,1.0)))

##Don't forget to group this mesh as "SCREENS"
func update_view(gt):
	#if(Engine.editor_hint):
		self.get_active_material(0).set_shader_param("camera_basis", gt.basis)
		#self.get_active_material(0).set_shader_param("camera_basis", Basis(gt.basis.x,gt.basis.y,gt.basis.z))
		self.get_active_material(0).set_shader_param("camera_global_position", gt.origin)

func set_bounce(bounce):
	get_tree().call_group("BOUNCE","update_bounce",bounce)
	self.get_active_material(0).set_shader_param("BOUNCE", bounce)

func change_mat(mat):
	get_tree().call_group("MAT","update_mat",mat)
	self.get_active_material(0).set_shader_param("mat", mat)

func change_cell_scale(cell_scale):
	get_tree().call_group("SCALE","update_scale",cell_scale)
	self.get_active_material(0).set_shader_param("cell_scale", cell_scale)


func change_VoxelMap(voxMap):
	get_tree().call_group("VMAP","update_vmap",voxMap)
	self.get_active_material(0).set_shader_param("voxelMap", voxMap)

func change_radius(radius):
	self.get_active_material(0).set_shader_param("Radius", radius)

func change_Dimension(dimensions):
	self.get_active_material(0).set_shader_param("Dimensions", dimensions)


