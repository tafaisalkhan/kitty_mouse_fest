extends Node2D

const UI=preload("res://scripts/core/UI.gd")
var faces: Array=[]
var mom: Node2D

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(720,1280))
	var background:=ColorRect.new()
	background.color=Color("65bddd")
	background.size=Vector2(720,1280)
	add_child(background)
	UI.label(self,"LIVING CAT FACES",Rect2(40,35,640,80),42)
	UI.label(self,"Blinking · breathing · curious eyes",Rect2(40,115,640,50),25)
	for i in 6:
		var face=load("res://scripts/gameplay/CatVisual.gd").new()
		face.radius=66
		face.variant=i
		face.position=Vector2(140+(i%3)*220,300+(i/3)*230)
		add_child(face)
		faces.append(face)
	mom=load("res://scripts/gameplay/CatVisual.gd").new()
	mom.mother=true
	mom.radius=138
	mom.position=Vector2(360,915)
	add_child(mom)
	faces.append(mom)
	UI.label(self,"Mom watches her kittens and celebrates their rescue",Rect2(35,1140,650,65),23)
	call_deferred("run")

func capture(path: String) -> Image:
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	image.save_png(path)
	return image

func run() -> void:
	for face in faces: face.blink_override=0.0
	var open_image: Image=await capture("res://docs/faces-open.png")
	for face in faces: face.blink_override=1.0
	var shut_image: Image=await capture("res://docs/faces-blink.png")
	var difference:=0.0
	for y in range(845,935):
		for x in range(265,455):
			var a:=open_image.get_pixel(x,y)
			var b:=shut_image.get_pixel(x,y)
			difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	difference/=17100.0
	for face in faces: face.blink_override=-1.0
	for frame in 192:
		await get_tree().process_frame
		mom.look_toward(faces[int(frame/32)%6].global_position)
		if frame==140: mom.celebrate()
		if frame%2==0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/face-frames/frame_%03d.png"%(frame/2))
	var counts: Array=[]
	var passed:=difference>0.04
	for face in faces:
		counts.append(face.blink_count)
		passed=passed and face.blink_count>0
	var report:=FileAccess.open("res://tests/face-animation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":passed,"eye_pixel_difference":difference,"blink_counts":counts,"frames":96,"fps":12},"\t"))
	report.close()
	print("FACE ANIMATION: ","PASS" if passed else "FAIL"," eye difference=",difference," blinks=",counts)
	get_tree().quit(0 if passed else 1)
