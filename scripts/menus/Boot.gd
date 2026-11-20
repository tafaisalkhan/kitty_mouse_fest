extends Control
const UI=preload("res://scripts/core/UI.gd")
func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop:=ColorRect.new()
	backdrop.color=Color("36a5e5")
	backdrop.size=Vector2(720,1280)
	add_child(backdrop)
	var sand:=ColorRect.new()
	sand.color=Color("ffe19a")
	sand.position=Vector2(0,865)
	sand.size=Vector2(720,415)
	add_child(sand)
	var cat=load("res://scripts/gameplay/CatVisual.gd").new()
	cat.mother=true
	cat.action_body=true
	cat.radius=155
	cat.position=Vector2(360,710)
	add_child(cat)
	for i in 2:
		var mouse=load("res://scripts/gameplay/Mouse.gd").new()
		mouse.config={"kind":"SMALL"}
		mouse.preview_mode=true
		mouse.show_label=false
		mouse.radius=63
		mouse.position=Vector2(155+i*410,855)
		mouse.origin=mouse.position
		add_child(mouse)
		mouse.kitty=cat
		mouse.set_body_palette(1+i)
	var title:=UI.label(self,"KITTY HUNT",Rect2(35,125,650,110),64)
	title.add_theme_font_override("font",UI.title_font())
	title.add_theme_color_override("font_outline_color",Color("8b4e22"))
	title.add_theme_constant_override("outline_size",10)
	UI.label(self,"E A T   ·   G R O W   ·   H U N T",Rect2(80,235,560,55),28)
	UI.label(self,"DIG A PATH. EAT SMALL. GROW BIG!",Rect2(40,1060,640,70),30,Color("8b4e22"))
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
