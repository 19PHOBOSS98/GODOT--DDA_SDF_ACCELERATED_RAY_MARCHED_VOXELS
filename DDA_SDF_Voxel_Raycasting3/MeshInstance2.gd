tool
extends MeshInstance


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	update_view(global_transform)
	
func update_view(gt):
	#if(Engine.editor_hint):
		#self.get_active_material(0).set_shader_param("camera_basis", gt.basis)
		#self.get_active_material(0).set_shader_param("camera_basis", Basis(gt.basis.x,gt.basis.y,gt.basis.z))
		self.get_active_material(0).set_shader_param("x", gt.origin.x)
		self.get_active_material(0).set_shader_param("y", gt.origin.y)
		self.get_active_material(0).set_shader_param("z", gt.origin.z)
