extends RefCounted
# Cached nine-slice materials: a lit face, bevel, thick lower edge and shadow.
static var cache: Dictionary={}
static func rounded_distance(point: Vector2,center: Vector2,half: Vector2,radius: float) -> float:
	var q: Vector2=(point-center).abs()-half+Vector2.ONE*radius
	return q.max(Vector2.ZERO).length()+minf(maxf(q.x,q.y),0)-radius
static func box(color: Color,border:=Color.TRANSPARENT,pressed:=false) -> StyleBoxTexture:
	var key:=color.to_html()+border.to_html()+str(pressed)
	if cache.has(key): return cache[key]
	var image:=Image.create(192,112,false,Image.FORMAT_RGBA8)
	var edge: Color=color.lightened(0.38) if border.a==0 else border
	var shift:=6.0 if pressed else 0.0
	for y in 112:
		for x in 192:
			var p:=Vector2(x+0.5,y+0.5)
			var shadow:=rounded_distance(p,Vector2(96,63),Vector2(90,43),22)
			var pixel:=Color(0.06,0.04,0.15,clampf((5-shadow)/9,0,1)*0.38)
			var base:=rounded_distance(p,Vector2(96,58),Vector2(90,43),22)
			if base<1:
				pixel=color.darkened(0.52)
				pixel.a=clampf(1-base,0,1)
			var face:=rounded_distance(p,Vector2(96,49+shift),Vector2(90,43),22)
			if face<1:
				var vertical:=clampf((y-6-shift)/86.0,0,1)
				pixel=color.lightened(0.27).lerp(color.darkened(0.12),vertical)
				if face>-4: pixel=edge.lightened(0.25).lerp(color.darkened(0.42),vertical)
				elif face>-6: pixel=color.lightened(0.58).lerp(color.darkened(0.1),vertical)
				else:
					var shine:=exp(-pow((float(y)-24-shift)/12,2))*0.15
					pixel=pixel.lightened(shine)
				pixel.a=clampf(1-face,0,1)
			image.set_pixel(x,y,pixel)
	var style:=StyleBoxTexture.new()
	style.texture=ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP]: style.set_texture_margin(side,32)
	style.set_texture_margin(SIDE_BOTTOM,40)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=3+shift
	style.content_margin_bottom=13-shift
	cache[key]=style
	return style
