extends Label

func _process(_delta):
	set_text("FPS: "+str(Performance.get_monitor(Performance.TIME_FPS)))
