extends Label

func _process(_delta):
	#set_text(String(get_parent().global_transform.origin))
	set_text("Velocity: "+ String(get_parent().velocity.length()))
	if(get_parent().velocity.length()!=0):
		get_tree().call_group("SCREENS","update_view",get_parent().get_node("Head/PCamera").global_transform)

