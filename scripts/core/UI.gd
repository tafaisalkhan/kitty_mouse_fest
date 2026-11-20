extends RefCounted

static var rounded_font: Font

static func image(parent: Node,path: String,rect: Rect2) -> TextureRect:
	var node:=TextureRect.new()
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture=load(path)
	node.position=rect.position
	node.size=rect.size
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func wallet(parent: Node,point: Vector2,coins: int) -> Label:
	var bg:=Panel.new()
	bg.position=point
	bg.size=Vector2(165,54)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel",box(Color("714628"),27))
	parent.add_child(bg)
	image(bg,"res://assets/ui/coin.png",Rect2(-10,-6,64,64))
	return label(bg,str(coins),Rect2(48,0,108,54),25)

static func game_font() -> Font:
	if rounded_font==null:
		rounded_font=load("res://assets/fonts/Fredoka-Bold.ttf")
	return rounded_font

static func title_font() -> Font:
	return load("res://assets/fonts/LuckiestGuy-Regular.ttf")

static func box(color: Color, radius:=24) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.shadow_color=Color(0.08,0.10,0.16,0.25)
	style.shadow_size=7
	style.shadow_offset=Vector2(0,5)
	style.border_color=color.lightened(0.22)
	style.border_width_top=3
	style.border_width_bottom=4
	style.content_margin_left=18
	style.content_margin_right=18
	return style

static func label(parent: Node, text: String, rect: Rect2, size:=28, color:=Color("fff8e5")) -> Label:
	var node:=Label.new()
	node.text=text
	node.position=rect.position
	node.size=rect.size
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",size)
	if game_font(): node.add_theme_font_override("font",game_font())
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_outline_color",Color("422638"))
	node.add_theme_constant_override("outline_size",2)
	node.add_theme_color_override("font_shadow_color",Color(0.1,0.1,0.15,0.35))
	node.add_theme_constant_override("shadow_offset_y",2)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func button(parent: Node,text: String,rect: Rect2,action: Callable,color:=Color("ed9c36")) -> Button:
	var node:=Button.new()
	node.text=text
	node.position=rect.position
	node.size=rect.size
	node.custom_minimum_size.y=58
	node.add_theme_font_size_override("font_size",29)
	node.add_theme_font_override("font",title_font())
	node.add_theme_color_override("font_color",Color("fff9ed"))
	node.add_theme_color_override("font_hover_color",Color("fffdf0"))
	node.add_theme_color_override("font_pressed_color",Color("fff0bc"))
	node.add_theme_color_override("font_focus_color",Color("fffdf0"))
	node.add_theme_color_override("font_disabled_color",Color("d5cdbb"))
	node.add_theme_color_override("font_outline_color",color.darkened(0.4))
	node.add_theme_constant_override("outline_size",3)
	node.add_theme_stylebox_override("normal",preload("res://scripts/core/DepthStyle.gd").box(color))
	node.add_theme_stylebox_override("hover",preload("res://scripts/core/DepthStyle.gd").box(color.lightened(0.09)))
	node.add_theme_stylebox_override("pressed",preload("res://scripts/core/DepthStyle.gd").box(color.darkened(0.08),Color.TRANSPARENT,true))
	node.add_theme_stylebox_override("disabled",preload("res://scripts/core/DepthStyle.gd").box(color.darkened(0.35)))
	node.pressed.connect(func():
		parent.get_node("/root/AudioManager").play_fx()
		action.call())
	parent.add_child(node)
	return node

static func style_dialog(dialog: AcceptDialog) -> void:
	dialog.theme=load("res://assets/ui/game_theme.tres")
	dialog.get_label().add_theme_font_override("font",game_font())
	dialog.get_label().add_theme_color_override("font_color",Color("fff8e5"))
	dialog.get_label().add_theme_font_size_override("font_size",25)
	dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var buttons: Array[Button]=[dialog.get_ok_button()]
	if dialog is ConfirmationDialog: buttons.append(dialog.get_cancel_button())
	for button in buttons:
		button.custom_minimum_size=Vector2(150,55)
		button.add_theme_font_override("font",title_font())
		button.add_theme_font_size_override("font_size",25)
		button.add_theme_stylebox_override("normal",box(Color("65aa42"),15))
		button.add_theme_stylebox_override("hover",box(Color("7bbf51"),15))
		button.add_theme_stylebox_override("pressed",box(Color("4d8c31"),15))

