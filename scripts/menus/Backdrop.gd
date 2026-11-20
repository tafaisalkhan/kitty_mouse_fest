extends Node2D
var artwork: Texture2D
func _ready() -> void:
    artwork=load("res://assets/branding/menu-3d-background-v2.png")
    queue_redraw()
func _draw() -> void:
    if not artwork: return
    var source:=artwork.get_size()
    var width:=source.y*720.0/1280.0
    draw_texture_rect_region(artwork,Rect2(0,0,720,1280),Rect2((source.x-width)/2,0,width,source.y))
