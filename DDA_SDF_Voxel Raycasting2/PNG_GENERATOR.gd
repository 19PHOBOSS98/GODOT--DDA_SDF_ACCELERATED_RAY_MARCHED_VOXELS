extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var img = Image.new()
	img.create(1024,600,false,Image.FORMAT_RGBAF)
	#img.create(1024,600,false,11)
	img.fill(Color.white)
	img.save_exr("white2.exr")
	print("Bingus: "+String(img.get_format()))
