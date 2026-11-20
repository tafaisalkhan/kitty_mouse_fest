extends RefCounted
static var cache: Dictionary={}
static func atlas_texture(name: String,index: int) -> Texture2D:
	var key:=name+str(index)
	if cache.has(key): return cache[key]
	var path:="res://assets/obstacles/"+name+".png"
	var metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/obstacles/"+name+".frames.json"))
	var bounds: Array=metadata.frames[index]
	var texture:=AtlasTexture.new()
	texture.atlas=load(path)
	texture.region=Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	texture.filter_clip=true
	cache[key]=texture
	return texture
static func material() -> ShaderMaterial:
	if not cache.has("material"):
		var result:=ShaderMaterial.new()
		result.shader=preload("res://assets/obstacles/prop_alpha.gdshader")
		cache.material=result
	return cache.material
static func fit(texture: Texture2D,box: Rect2) -> Rect2:
	var factor:=minf(box.size.x/texture.get_width(),box.size.y/texture.get_height())
	var size:=texture.get_size()*factor
	return Rect2(box.get_center()-size/2,size)
static func bar(index: int) -> StyleBoxTexture:
	var key:="bar"+str(index)
	if cache.has(key): return cache[key]
	var style:=StyleBoxTexture.new()
	style.texture=atlas_texture("mechanisms-v2",index)
	style.set_texture_margin(SIDE_LEFT,60)
	style.set_texture_margin(SIDE_RIGHT,60)
	style.set_texture_margin(SIDE_TOP,12)
	style.set_texture_margin(SIDE_BOTTOM,12)
	cache[key]=style
	return style
static func draw_bar(canvas: CanvasItem,index: int,rect: Rect2) -> void:
	var texture:=atlas_texture("mechanisms-v2",index)
	var source:=texture.get_size()
	var cap:=minf(source.y*0.8,source.x/3)
	var end_width:=minf(rect.size.x/2,rect.size.y*cap/source.y)
	canvas.draw_texture_rect_region(texture,Rect2(rect.position,Vector2(end_width,rect.size.y)),Rect2(0,0,cap,source.y))
	canvas.draw_texture_rect_region(texture,Rect2(rect.position+Vector2(end_width,0),Vector2(rect.size.x-end_width*2,rect.size.y)),Rect2(cap,0,source.x-cap*2,source.y))
	canvas.draw_texture_rect_region(texture,Rect2(rect.end-Vector2(end_width,rect.size.y),Vector2(end_width,rect.size.y)),Rect2(source.x-cap,0,cap,source.y))
