extends RefCounted
const UI=preload("res://scripts/core/UI.gd")

static func icon(parent: Node,index: int,rect: Rect2) -> TextureRect:
	var node:=UI.image(parent,"res://assets/ui/commerce-icons.png",rect)
	var atlas:=AtlasTexture.new()
	atlas.atlas=node.texture
	var cell:=atlas.atlas.get_size()/Vector2(3,2)
	atlas.region=Rect2(Vector2(index%3,index/3)*cell,cell)
	node.texture=atlas
	return node

static func card(parent: Node,rect: Rect2,color:=Color("3f5fe6"),border:=Color("ffcb45")) -> Panel:
	var panel:=Panel.new()
	panel.position=rect.position
	panel.size=rect.size
	var box:=preload("res://scripts/core/DepthStyle.gd").box(color,border)
	panel.add_theme_stylebox_override("panel",box)
	parent.add_child(panel)
	return panel

static func heading(parent: Node,text: String,rect: Rect2,font_size:=43) -> Label:
	var label:=UI.label(parent,text,rect,font_size,Color("fff450"))
	label.add_theme_font_override("font",UI.title_font())
	label.add_theme_color_override("font_outline_color",Color("60349d"))
	label.add_theme_constant_override("outline_size",6)
	return label

static func modal(parent: Node,title: String,rect: Rect2) -> Control:
	var root:=Control.new()
	root.name="CommercePopup"
	root.size=Vector2(720,1280)
	root.z_index=30
	root.mouse_filter=Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var shade:=ColorRect.new()
	shade.color=Color(0.02,0.015,0.12,0.76)
	shade.size=Vector2(720,1280)
	root.add_child(shade)
	card(root,rect,Color("6652d7"))
	card(root,Rect2(rect.position+Vector2(70,-32),Vector2(rect.size.x-140,100)),Color("bc65dd"))
	heading(root,title,Rect2(rect.position+Vector2(60,-25),Vector2(rect.size.x-120,85)))
	var close:=UI.button(root,"×",Rect2(rect.end.x-64,rect.position.y+78,45,48),func(): root.queue_free(),Color("ec6fa7"))
	close.custom_minimum_size=Vector2(45,48)
	return root

static func daily_popup(parent: Node,on_claim: Callable) -> Control:
	Economy.refresh_daily_prompt()
	Economy.daily_prompt_shown=true
	var status:=Economy.daily_status()
	var root:=modal(parent,"DAILY REWARD",Rect2(48,215,624,870))
	root.set_meta("popup_kind","daily_reward")
	UI.label(root,"%d DAY STREAK  ·  KEEP IT GROWING!"%status.day,Rect2(72,315,576,44),24)
	var first:=int((status.day-1)/7)*7+1
	for i in 7:
		var day:=first+i
		var rect:=Rect2(89+(i%3)*184,385+(i/3)*178,172,163)
		if i==6: rect=Rect2(89,741,540,145)
		var claimed: bool=day<status.day or (day==status.day and not status.can_claim)
		var current: bool=day==status.day and status.can_claim
		var tile:=card(root,rect,Color("59cbe7") if not current else Color("73cb42"),Color("9cecff") if not current else Color("eaff7c"))
		UI.label(tile,"DAY %d"%day,Rect2(0,2,rect.size.x,38),25)
		if claimed:
			UI.label(tile,"✓",Rect2(20,42,rect.size.x-40,73),54,Color("d4ff9a"))
		elif i in [1,4,6]:
			icon(tile,1,Rect2(rect.size.x/2-43,39,86,78))
		else: UI.image(tile,"res://assets/ui/coin.png",Rect2(rect.size.x/2-35,43,70,70))
		UI.label(tile,"+%d"%(day*10),Rect2(5,rect.size.y-44,rect.size.x-10,36),27,Color("fff8cf"))
	var claim:=UI.button(root,"CLAIM %d COINS"%status.reward if status.can_claim else "CLAIMED TODAY",Rect2(145,930,430,85),func():
		var amount:=Economy.claim_daily()
		if amount<=0: return
		for child in root.get_children():
			if child is Button: child.disabled=true
		for i in 8:
			var coin:=UI.image(root,"res://assets/ui/coin.png",Rect2(330,930,48,48))
			var tween:=root.create_tween()
			tween.tween_interval(i*0.06)
			tween.tween_property(coin,"position",Vector2(520,45),0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(coin.queue_free)
		var finish:=root.create_tween()
		finish.tween_interval(1.25)
		finish.tween_callback(func(): root.queue_free(); on_claim.call()),Color("55ce17"))
	claim.disabled=not status.can_claim
	UI.label(root,"A missed day restarts the streak at 10 coins.",Rect2(65,1025,590,40),20)
	return root

static func support_popup(parent: Node,action: int) -> Control:
	var titles: Array=["LOVE THE KITTIES?","SHARE THE LOVE","A COFFEE FOR THE DEV?"]
	var root:=modal(parent,titles[action],Rect2(45,335,630,600))
	var notice:=UI.label(root,"No Ads Today",Rect2(215,440,290,40),27,Color("d6ff9c"))
	notice.name="NoAdsToday"
	notice.visible=AdsService.no_fill_this_launch
	if action==0:
		for i in 5: UI.image(root,"res://assets/ui/star.png",Rect2(185+i*70,515,62,62))
	else: icon(root,5 if action==1 else 3,Rect2(275,500,170,150))
	var texts: Array=["Enjoying the mouse hunts?\nYour review helps us grow.","Invite a friend to play\nKitty’s next mouse maze.","Support more little adventures.\nCoffee is a one-time consumable."]
	UI.label(root,texts[action],Rect2(80,650,560,90),28)
	var labels: Array=["RATE GAME","SHARE GAME","COFFEE · "+(PlatformServices.coffee_price if not PlatformServices.coffee_price.is_empty() else "$1.99")]
	var button:=UI.button(root,labels[action],Rect2(140,775,440,78),func():
		root.queue_free()
		if action==0: PlatformServices.rate_game()
		elif action==1: PlatformServices.share_game()
		else: PlatformServices.buy_coffee(),Color("55ce17"))
	if action==2:
		button.name="CoffeeButton"
		root.set_meta("coffee_prefix","COFFEE · ")
		button.disabled=PlatformServices.coffee_price.is_empty()
		var detail:=UI.label(root,"Available through Google Play." if button.disabled else "Thank you for supporting new adventures!",Rect2(85,865,550,45),21)
		detail.name="CoffeeAvailability"
	return root

static func support_menu(parent: Node) -> Control:
	var root:=modal(parent,"SUPPORT KITTY HUNT",Rect2(45,280,630,740))
	var notice:=UI.label(root,"No Ads Today",Rect2(185,410,350,44),27,Color("d6ff9c"))
	notice.name="NoAdsToday"
	notice.visible=AdsService.no_fill_this_launch
	UI.label(root,"Help Kitty grow her next adventure.",Rect2(85,473,550,50),27)
	UI.button(root,"RATE GAME  ★★★★★",Rect2(125,555,470,78),PlatformServices.rate_game,Color("55ce17"))
	UI.button(root,"SHARE GAME",Rect2(125,660,470,78),PlatformServices.share_game,Color("4278be"))
	var price: String=PlatformServices.coffee_price if not PlatformServices.coffee_price.is_empty() else "$1.99"
	var coffee:=UI.button(root,"BUY A COFFEE · "+price,Rect2(125,765,470,78),PlatformServices.buy_coffee,Color("b77943"))
	coffee.name="CoffeeButton"
	root.set_meta("coffee_prefix","BUY A COFFEE · ")
	coffee.disabled=PlatformServices.coffee_price.is_empty()
	var detail:=UI.label(root,"Coffee purchases are available through Google Play." if coffee.disabled else "A one-time consumable to support new adventures.",Rect2(85,870,550,80),22)
	detail.name="CoffeeAvailability"
	return root

static func offer_popup(parent: Node,key: String,on_bought: Callable) -> Control:
	var pack: Dictionary=Economy.PACKS[key]
	var root:=modal(parent,"SPECIAL OFFER",Rect2(50,320,620,620))
	icon(root,1,Rect2(100,445,190,190))
	heading(root,pack.title,Rect2(285,460,320,65),30)
	UI.label(root,"%d bombs\n%d hint tokens"%[pack.bombs,pack.hints],Rect2(290,530,300,115),32)
	UI.label(root,"Powers for your next rescue",Rect2(90,680,540,50),27)
	UI.image(root,"res://assets/ui/coin.png",Rect2(180,785,55,55))
	UI.button(root,"%d COINS"%pack.cost,Rect2(240,775,330,80),func():
		if root.get_meta("purchased",false): return
		if Economy.buy_pack(key):
			root.set_meta("purchased",true)
			root.queue_free()
			on_bought.call()
		else: UI.label(root,"Not enough coins yet",Rect2(100,875,520,42),25),Color("55ce17"))
	return root
