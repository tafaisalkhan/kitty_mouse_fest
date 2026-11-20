extends Node2D
const UI=preload("res://scripts/core/UI.gd")
var number:=1
var ready_count:=0
var total:=1
var opening:=0.0:
	set(value):
		opening=value
		queue_redraw()

func set_arrivals(count: int) -> void:
	if ready_count!=count:
		ready_count=count
		queue_redraw()

func _draw() -> void:
	var wood:=UI.box(Color("9a602d"),6)
	wood.border_color=Color("f4c76a")
	wood.set_border_width_all(3)
	for side in [-1,1]:
		draw_style_box(wood,Rect2(Vector2(-330-opening*330 if side<0 else opening*330,-10),Vector2(330,20)))
		for i in 7:
			var x: float=(-305+i*45-opening*330) if side<0 else 25+i*45+opening*330
			draw_line(Vector2(x,-5),Vector2(x,4),Color("ffdc88"),2,true)
		draw_style_box(UI.box(Color("586d89"),5),Rect2(side*318-12,-20,24,42))
	var sign:=UI.box(Color("4a3975"),12)
	sign.border_color=Color("ffd672")
	sign.set_border_width_all(2)
	draw_style_box(sign,Rect2(-150,-79,300,46))
	var text:="BASE %d  ·  %d / %d"%[number,ready_count,total]
	draw_string(UI.game_font(),Vector2(-143,-48),text,HORIZONTAL_ALIGNMENT_CENTER,286,23,Color("fff5d8"))
