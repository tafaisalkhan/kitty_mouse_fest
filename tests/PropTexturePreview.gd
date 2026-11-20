extends Node2D
const UI=preload("res://scripts/core/UI.gd")
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var background:=ColorRect.new()
	background.color=Color("67b0d5")
	background.size=Vector2(720,1280)
	add_child(background)
	UI.label(self,"TEXTURED WORLD PROPS",Rect2(20,20,680,70),35)
	var kinds: Array=["falling_rock","bomb","bee","spikes","dangerous_plant","pressure_switch","rotating_wheel","portal","fan","water","gate","moving_platform","laser"]
	for i in kinds.size():
		var x:=120+(i%3)*240
		var y:=190+int(i/3)*225
		var obstacle=preload("res://scripts/obstacles/Obstacle.gd").new()
		add_child(obstacle)
		obstacle.setup({"id":"prop_"+str(i),"type":kinds[i],"position":[x,y],"radius":45,"width":185})
		if obstacle.body is RigidBody2D: obstacle.body.freeze=true
		UI.label(self,str(kinds[i]).replace("_"," ").to_upper(),Rect2(x-115,y+75,230,45),19)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/textured-world-props.png")
	print("PROP TEXTURE PREVIEW: 13 types rendered")
	get_tree().quit()
