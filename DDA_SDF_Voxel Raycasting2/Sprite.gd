extends Sprite


func update_view(gt):
	#if(Engine.editor_hint):
		self.get_material().set_shader_param("camera_basis", gt.basis)
		#self.get_active_material(0).set_shader_param("camera_basis", Basis(gt.basis.x,gt.basis.y,gt.basis.z))
		self.get_material().set_shader_param("camera_global_position", gt.origin)
