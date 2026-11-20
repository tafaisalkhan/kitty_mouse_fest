extends Node2D
const UI=preload("res://scripts/core/UI.gd")
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var bg:=ColorRect.new()
	bg.color=Color("22527b")
	bg.size=Vector2(720,1280)
	add_child(bg)
	UI.label(self,"ELASTIC WHITE KITTY",Rect2(30,55,660,70),42)
	for i in 3:
		var cat=preload("res://scripts/gameplay/CatVisual.gd").new()
		cat.mother=true
		cat.action_body=true
		cat.radius=65
		cat.position=Vector2(125+i*235,345)
		add_child(cat)
		cat.set_process(false)
		cat.set_physics_motion(Vector2(0,620) if i==0 else Vector2.ZERO,i!=0)
		for tick in 50: cat.advance_animation(1.0/60)
		if i==1:
			cat.react_collision(620)
			cat.advance_animation(1.0/60)
		if i>0:
			var floor_line:=Line2D.new()
			floor_line.points=PackedVector2Array([Vector2(cat.position.x-85,407.4),Vector2(cat.position.x+85,407.4)])
			floor_line.default_color=Color("ffe0a0")
			floor_line.width=3
			add_child(floor_line)
		UI.label(self,["AIR STRETCH","LANDING PRESS","ROUND AGAIN"][i],Rect2(cat.position.x-110,470,220,50),22)
	var names:=["GREEN","BLUE","PURPLE","GOLD","PINK","TEAL"]
	for i in 6:
		var mouse=preload("res://scripts/gameplay/Mouse.gd").new()
		mouse.config={"kind":"SMALL"}
		mouse.preview_mode=true
		mouse.show_label=false
		mouse.radius=45
		mouse.position=Vector2(125+(i%3)*235,750+(i/3)*250)
		mouse.origin=mouse.position
		add_child(mouse)
		mouse.set_process(false)
		mouse.time=1.2
		mouse.set_body_palette(i)
		mouse.update_quality_pose()
		UI.label(self,names[i],Rect2(mouse.position.x-100,mouse.position.y+80,200,40),23)
	UI.label(self,"Stretch in air · press on impact · spring back",Rect2(30,1200,660,40),22)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/elastic-ball-gallery.png")
	print("ELASTIC GALLERY captured")
	get_tree().quit()
