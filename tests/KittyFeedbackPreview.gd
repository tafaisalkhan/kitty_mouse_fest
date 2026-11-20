extends Node2D
const UI=preload("res://scripts/core/UI.gd")
var failures:=0
var caption: Label
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func capture(path: String,text: String) -> void:
	caption.text=text
	if DisplayServer.get_name()=="headless": return
	await get_tree().create_timer(0.14).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var background:=ColorRect.new()
	background.color=Color("4e9cce")
	background.size=Vector2(720,1280)
	add_child(background)
	caption=UI.label(self,"",Rect2(40,90,640,110),33)
	var cat=preload("res://scripts/gameplay/CatVisual.gd").new()
	cat.mother=true
	cat.action_body=true
	cat.radius=165
	cat.position=Vector2(360,620)
	add_child(cat)
	cat.set_process(false)
	for tick in 40:
		cat.focus_on(cat.position+Vector2(-200,180),"object")
		cat.advance_animation(1.0/60)
	await capture("res://docs/kitty-food-far.png","WATCHING THE NEXT MOUSE")
	cat.food_interest=1.0
	for tick in 40:
		cat.focus_on(cat.position+Vector2(150,20),"object")
		cat.advance_animation(1.0/60)
	check(cat.food_excitement>0.9 and cat.quality_sprite.pose==4,"nearby food gives Kitty an excited open-mouth expression")
	check(cat.gaze.x>0.08,"Kitty visibly looks toward the mouse she is approaching")
	await capture("res://docs/kitty-food-near.png","MOUSE NEARBY · EXCITED")
	cat.react_eat()
	for tick in 40: cat.advance_animation(1.0/60)
	check(cat.get_eating_stage()=="tongue_lick" and cat.eating_time>0.75,"the final tongue lick stays visible for almost a second")
	check(cat.quality_sprite.pose==3 and cat.sparkle_time>0.5,"tongue artwork and eye shine are actually rendered")
	await capture("res://docs/kitty-tongue-closeup.png","AFTER EATING · TONGUE + SHINE")
	cat.eating_time=0
	cat.celebration=0
	cat.food_interest=0
	cat.food_excitement=0
	cat.react_collision(480)
	cat.set_physics_motion(Vector2.ZERO,true)
	cat.advance_animation(1.0/60)
	check(cat.elastic_scale.y<0.85 and cat.elastic_scale.x>1.18,"landing visibly squashes the elastic Kitty ball")
	await capture("res://docs/kitty-landing-squash.png","LANDING · SOFT SQUASH")
	var rebound:=false
	for tick in 60:
		cat.advance_animation(1.0/60)
		if cat.elastic_scale.y>1.02:
			rebound=true
			break
	check(rebound,"Kitty springs back above her round shape")
	await capture("res://docs/kitty-landing-rebound.png","LANDING · ELASTIC REBOUND")
	print("KITTY FEEDBACK RESULT: ",failures," failures")
	get_tree().quit(failures)
