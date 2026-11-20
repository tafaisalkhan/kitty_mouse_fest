extends Node2D
const UI=preload("res://scripts/core/UI.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	SaveManager.level_number=1
	var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	game.test_mode=true
	add_child(game)
	await get_tree().physics_frame
	var baby: Node=game.kittens[0]
	for tick in 30: await get_tree().physics_frame
	check(baby.supported,"resting kitten detects terrain support")
	game.dig_attention_point=baby.position+Vector2(90,140)
	game.dig_attention_time=1.0
	game.update_face_attention()
	baby.visual.advance_animation(0.12)
	check(baby.visual.attention_kind=="dig" and baby.visual.gaze_target.x>0 and baby.visual.gaze_target.y>0,"kitten looks toward the opening being dug")
	game.terrain.dig_segment(baby.position,baby.position+Vector2(0,300))
	for tick in 20: await get_tree().physics_frame
	check(not baby.supported and baby.visual.expression=="falling" and baby.visual.surprise_amount>0.2,"digging away support produces falling face")
	baby.freeze=true
	var bee_point: Vector2=baby.position+Vector2(130,0)
	game.terrain.dig_segment(baby.position,bee_point)
	var bee=load("res://scripts/obstacles/Obstacle.gd").new()
	game.add_child(bee)
	bee.setup({"id":"attention_bee","type":"bee","position":[bee_point.x,bee_point.y],"radius":18})
	bee.set_physics_process(false)
	game.obstacles.attention_bee=bee
	for tick in 2: await get_tree().physics_frame
	game.update_face_attention()
	check(baby.visual.attention_kind=="danger","nearby visible bee takes attention priority over digging")
	var wall:=StaticBody2D.new()
	wall.position=baby.position+Vector2(65,0)
	wall.collision_layer=1
	var wall_shape:=CollisionShape2D.new()
	var wall_box:=RectangleShape2D.new()
	wall_box.size=Vector2(15,200)
	wall_shape.shape=wall_box
	wall.add_child(wall_shape)
	game.add_child(wall)
	await get_tree().physics_frame
	check(game.nearby_attention(baby.global_position).is_empty(),"solid wall hides the bee from eye tracking")
	game.queue_free()
	await get_tree().process_frame
	var room:=Node2D.new()
	add_child(room)
	var floor:=StaticBody2D.new()
	floor.position=Vector2(360,700)
	floor.collision_layer=1
	var collider:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(600,25)
	collider.shape=shape
	floor.add_child(collider)
	room.add_child(floor)
	var falling=load("res://scenes/gameplay/Kitten.tscn").instantiate()
	falling.configure({"id":"fall","position":[360,420],"radius":25})
	falling.rotation=PI/2
	falling.muted=true
	room.add_child(falling)
	var saw_landing:=false
	for tick in 100:
		await get_tree().physics_frame
		if falling.visual.landing_time>0:
			saw_landing=true
			break
	check(saw_landing,"rotated kitten's real physics landing triggers squash reaction")
	check(falling.get_child(0).shape.radius==25,"visual squash preserves physics radius")
	room.queue_free()
	await get_tree().process_frame
	var face=load("res://scripts/gameplay/CatVisual.gd").new()
	add_child(face)
	face.focus_on(Vector2(100,0),"danger",1.0)
	face.advance_animation(0.15)
	check(face.expression=="scared" and face.fear_amount>0.5,"visible threat makes a scared face")
	face.set_physics_motion(Vector2(0,400),false)
	face.celebrate()
	check(face.fear_amount==0.0,"reunion immediately clears the worried face")
	check(face.supported and face.motion==Vector2.ZERO,"rescued face returns from falling stretch to normal")
	face.advance_animation(0.1)
	check(face.expression=="happy" and face.sparkle_time>0,"reunion overrides fear")
	face.defeat()
	face.focus_on(Vector2(-100,0),"dig")
	check(face.expression=="defeated","attention cannot replace defeated reaction")
	face.queue_free()
	if OS.get_cmdline_user_args().has("--capture"):
		var background:=ColorRect.new()
		background.color=Color("309dc9")
		background.size=Vector2(720,1280)
		add_child(background)
		UI.label(self,"KITTY REACTIONS",Rect2(30,30,660,80),45)
		for i in 6:
			var cat=load("res://scripts/gameplay/CatVisual.gd").new()
			cat.position=Vector2(200+(i%2)*320,260+(i/2)*330)
			cat.radius=85
			cat.variant=i
			add_child(cat)
			cat.set_process(false)
			cat.blink_override=0
			var label: String=["LOOK AT PATH","WATCH OBJECT","FALLING","DANGER NEARBY","LANDING","REUNITED"][i]
			match i:
				0: cat.focus_on(cat.position+Vector2(100,130),"dig")
				1: cat.focus_on(cat.position+Vector2(-150,0),"object")
				2: cat.set_physics_motion(Vector2(50,500),false)
				3: cat.focus_on(cat.position+Vector2(140,-70),"danger",1.0)
				4: cat.react_collision(430)
				5: cat.celebrate()
			cat.advance_animation(0.15)
			UI.label(self,label,Rect2(cat.position+Vector2(-145,140),Vector2(290,55)),25)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/kitty-reactions.png")
	print("EXPRESSION RESULT: ",failures," failures")
	get_tree().quit(failures)
