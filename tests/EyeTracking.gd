extends Node2D
const UI=preload("res://scripts/core/UI.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var bg:=ColorRect.new()
	bg.color=Color("22527b")
	bg.size=Vector2(720,1280)
	add_child(bg)
	UI.label(self,"BIG EYES FOLLOW TARGETS",Rect2(20,25,680,70),36)
	UI.label(self,"CAT WATCHES MOUSE     MOUSE WATCHES CAT",Rect2(20,100,680,45),21)
	var directions:=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
	for i in 4:
		var y:=260+i*260
		var cat=preload("res://scripts/gameplay/CatVisual.gd").new()
		cat.mother=true
		cat.action_body=true
		cat.radius=65
		cat.position=Vector2(190,y)
		add_child(cat)
		cat.set_process(false)
		for tick in 40:
			cat.focus_on(cat.global_position+directions[i]*1000,"object")
			cat.advance_animation(1.0/60)
		check(cat.gaze.normalized().dot(directions[i])>0.98,"cat eyes track "+str(directions[i]))
		check(cat.ball_face_material.get_shader_parameter("eye_gaze")==cat.gaze,"cat gaze reaches rendered eyes")
		cat.set_physics_motion(Vector2(0,420),false)
		for tick in 40:
			cat.focus_on(cat.global_position+directions[i]*1000,"object")
			cat.advance_animation(1.0/60)
		var cat_world_gaze:=Vector2(cat.gaze.x/0.060,cat.gaze.y/0.050).rotated(cat.global_rotation).normalized()
		check(cat_world_gaze.dot(directions[i])>0.94,"cat keeps watching prey during a rotating drop")
		cat.set_physics_motion(Vector2.ZERO,true)
		for tick in 40:
			cat.focus_on(cat.global_position+directions[i]*1000,"object")
			cat.advance_animation(1.0/60)
		var target:=Node2D.new()
		target.position=Vector2(530,y)+directions[i]*1000
		add_child(target)
		var mouse=preload("res://scripts/gameplay/Mouse.gd").new()
		mouse.config={"kind":"SMALL"}
		mouse.radius=53
		mouse.preview_mode=true
		mouse.show_label=false
		mouse.position=Vector2(530,y)
		mouse.origin=mouse.position
		mouse.kitty=target
		add_child(mouse)
		mouse.set_process(false)
		mouse.time=1.2
		mouse.set_body_palette(i+1)
		for tick in 40: mouse._process(1.0/60)
		check(mouse.pupil_gaze.normalized().dot(directions[i])>0.98,"mouse eyes watch cat "+str(directions[i]))
		mouse.preview_mode=false
		mouse.set_physics_process(false)
		mouse.velocity=Vector2(0,240)
		for tick in 40: mouse._process(1.0/60)
		var mouse_world_gaze:=Vector2(mouse.pupil_gaze.x/0.060,mouse.pupil_gaze.y/0.050).rotated(mouse.ball_spin.angle).normalized()
		check(mouse_world_gaze.dot(directions[i])>0.94,"mouse keeps watching Kitty during a rotating drop")
		mouse.preview_mode=true
		mouse.velocity=Vector2.ZERO
		for tick in 40: mouse._process(1.0/60)
		UI.label(self,["LEFT","RIGHT","UP","DOWN"][i],Rect2(260,y+90,200,40),23)
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/eye-tracking-gallery.png")
	print("EYE TRACKING RESULT: ",failures," failures")
	get_tree().quit(failures)
