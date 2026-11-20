extends Node2D
var radius:=30.0
var skin: Texture2D
func _ready() -> void:
    skin=preload("res://scripts/obstacles/PropSkins.gd").atlas_texture("props-v2",1)
    material=preload("res://scripts/obstacles/PropSkins.gd").material()
    texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _draw() -> void:
    if skin:
        var box:=Rect2(-radius,-radius,radius*2,radius*2)
        draw_texture_rect(skin,preload("res://scripts/obstacles/PropSkins.gd").fit(skin,box),false)
