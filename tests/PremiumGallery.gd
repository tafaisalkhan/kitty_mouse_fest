extends Node2D
const UI=preload("res://scripts/core/UI.gd")
const Cat=preload("res://scripts/gameplay/CatVisual.gd")
func _ready() -> void:
	call_deferred("run")
func cat_at(point: Vector2):
	var cat:=Cat.new()
	cat.mother=true
	cat.action_body=true
	cat.radius=52
	cat.position=point
	add_child(cat)
	cat.set_process(false)
	cat.idle_phase=0
	return cat
func run() -> void:
	var bg:=ColorRect.new()
	bg.color=Color("22527b")
	bg.size=Vector2(720,1280)
	add_child(bg)
	UI.label(self,"ROUND CHARACTER ART",Rect2(40,45,640,65),43)
	var failures:=0
	for i in 3:
		var x:=125+i*235
		var cat=cat_at(Vector2(x,330))
		cat.set_physics_motion(Vector2(42,0) if i==0 else Vector2(50,300) if i==1 else Vector2.ZERO,i!=1)
		for tick in 25: cat.advance_animation(1.0/60)
		if not cat.has_quality_art(): failures+=1
		UI.label(self,["CAT BALL","FALLING BALL","RESTING BALL"][i],Rect2(x-105,430,210,38),23)
		var eater=cat_at(Vector2(x,650))
		eater.react_eat()
		eater.eating_time=[0.75,0.5,0.2][i]
		eater.update_quality_pose()
		UI.label(self,["MOUTH OPEN","CHEW","TONGUE + SHINE"][i],Rect2(x-110,755,220,38),22)
		var mouse=preload("res://scripts/gameplay/Mouse.gd").new()
		mouse.config={"kind":"SMALL"}
		mouse.preview_mode=true
		mouse.radius=37
		mouse.position=Vector2(x,1000)
		mouse.origin=mouse.position
		mouse.show_label=false
		add_child(mouse)
		mouse.set_process(false)
		mouse.time=1.2
		mouse.walking=i==0
		mouse.fleeing=i==2
		mouse.panic=0.9 if i==2 else 0
		mouse.update_quality_pose()
		if not mouse.quality_sprite.ready_art: failures+=1
		UI.label(self,["MOUSE BALL","BIG EYES","PANIC"][i],Rect2(x-105,1110,210,38),23)
	UI.label(self,"Sideways movement · head turns · front-facing rest",Rect2(40,1200,640,40),22)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/ball-character-gallery.png")
	print("PREMIUM GALLERY: ",failures," missing assets")
	get_tree().quit(failures)
