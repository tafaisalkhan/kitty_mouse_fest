extends Button

var kind:="restart"
var base:=Color("219fe2")

func _ready() -> void:
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center:=size/2+Vector2(0,3 if button_pressed else 0)
	var r:=minf(size.x,size.y)/2-4
	draw_circle(center+Vector2(0,5),r,Color(0.15,0.15,0.2,0.3))
	draw_circle(center,r,base.darkened(0.58))
	for i in 20:
		var f:=float(i)/20
		draw_circle(center+Vector2(-f*2,-f*5),r-3-f*(r*0.65),base.darkened(0.18).lerp(base.lightened(0.35),f))
	draw_arc(center,r-5,PI*1.06,PI*1.88,32,base.lightened(0.66),2,true)
	var ink:=Color("fff9df")
	match kind:
		"bomb":
			draw_circle(center+Vector2(0,4),18,Color("343343"))
			draw_arc(center+Vector2(-2,2),12,PI,PI*1.6,16,Color("818297"),3,true)
			draw_line(center+Vector2(5,-12),center+Vector2(12,-23),Color("b78143"),5,true)
			draw_circle(center+Vector2(13,-24),5,Color("ffe375"))
		"settings":
			for i in 8:
				var angle:=i*TAU/8.0
				draw_line(center+Vector2(13,0).rotated(angle),center+Vector2(23,0).rotated(angle),ink,9,true)
			draw_circle(center,19,ink)
			draw_circle(center,9,base.darkened(0.4))
			draw_arc(center,14,PI,TAU,24,Color.WHITE,2,true)
		"home":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-23,-2),center+Vector2(0,-23),center+Vector2(23,-2)]),ink)
			draw_style_box(pill(ink),Rect2(center+Vector2(-16,-3),Vector2(32,24)))
			draw_style_box(pill(base.darkened(0.4)),Rect2(center+Vector2(-5,6),Vector2(10,15)))
		"restart":
			draw_arc(center,17,-PI*0.25,PI*1.25,32,base.darkened(0.6),9,true)
			draw_arc(center+Vector2(0,-1),17,-PI*0.25,PI*1.25,32,ink,6,true)
			draw_colored_polygon(PackedVector2Array([center+Vector2(7,-23),center+Vector2(24,-22),center+Vector2(24,-6)]),ink)
		"pause":
			for side in [-1,1]: draw_style_box(pill(ink),Rect2(center+Vector2(side*10-4,-17),Vector2(8,34)))
		"hint":
			draw_circle(center-Vector2(0,7),16,Color("fff5b0"))
			draw_arc(center-Vector2(0,7),12,PI,TAU,20,Color.WHITE,2,true)
			for y in [10,15,20]: draw_line(center+Vector2(-8,y),center+Vector2(8,y),Color("9d6e36"),4,true)

func pill(color: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=color
	box.set_corner_radius_all(3)
	return box
