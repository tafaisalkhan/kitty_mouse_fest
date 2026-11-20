extends Control

const Commerce=preload("res://scripts/menus/CommerceUI.gd")
const UI=preload("res://scripts/core/UI.gd")
var content: Control
var world_index:=0
var page: String="MainMenu"
var wallet_label: Label
var shop_tab:="powers"
var next_daily_check:=0

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=Node2D.new()
	background.set_script(load("res://scripts/menus/Backdrop.gd"))
	add_child(background)
	content=Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	page=String(name)
	world_index=int((int(SaveManager.progress.highest_unlocked)-1)/20)
	PlatformServices.service_event.connect(service_event)
	AdsService.availability_changed.connect(ad_availability)
	show_page(page)
	if SaveManager.get_meta("open_trial",false):
		SaveManager.remove_meta("open_trial")
		show_page("Trial")
	get_tree().auto_accept_quit=false

func clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func show_page(which: String) -> void:
	if which!="MainMenu" and Economy.home_seen: Economy.left_home=true
	clear()
	page=which
	match which:
		"Settings": settings_page()
		"LevelSelect": levels_page()
		"Shop": shop_page()
		"Leaderboard": leaderboard_page()
		"Achievements": achievements_page()
		"Trial": trial_page()
		_: main_page()

func go(scene: String) -> void:
	Economy.left_home=true
	AdsService.home_visible(false)
	get_tree().change_scene_to_file("res://scenes/menus/"+scene+".tscn")

func start(number: int, daily:=false) -> void:
	SaveManager.trial_mode=false
	Economy.left_home=true
	AdsService.home_visible(false)
	SaveManager.level_number=number
	SaveManager.daily_mode=daily
	get_tree().change_scene_to_file("res://scenes/gameplay/Gameplay.tscn")

func main_page() -> void:
	Economy.refresh_daily_prompt()
	AdsService.home_visible(true)
	PlatformServices.enter_home()
	var bar:=Commerce.card(content,Rect2(-10,-20,740,168),Color("2132a0"),Color("ffc643"))
	wallet_label=UI.wallet(content,Vector2(500,47),int(SaveManager.progress.coins))
	UI.image(content,"res://assets/ui/star.png",Rect2(319,47,55,55))
	UI.label(content,str(SaveManager.stars_total()),Rect2(379,47,90,55),30)
	var gear=load("res://scripts/core/GameButton.gd").new()
	gear.kind="settings"
	gear.base=Color("bd64cf")
	gear.position=Vector2(27,36)
	gear.size=Vector2(85,85)
	gear.tooltip_text="Settings"
	gear.pressed.connect(func(): go("Settings"))
	content.add_child(gear)
	var title:=Commerce.heading(content,"KITTY HUNT",Rect2(98,170,524,83),53)
	for entry in [[2,Vector2(30,280),"SHOP"],[4,Vector2(565,280),"DAILY GIFT"]]:
		var button:=UI.button(content,"",Rect2(entry[1],Vector2(125,125)),func():
			if entry[0]==2: show_page("Shop"); Economy.left_home=true; AdsService.home_visible(false)
			else: Commerce.daily_popup(self,func(): show_page("MainMenu")),Color("3678dd"))
		Commerce.icon(button,entry[0],Rect2(0,-12,125,125))
		var ribbon:=Commerce.card(button,Rect2(-4,94,133,33),Color("63bb39"),Color("e5ff7b"))
		UI.label(ribbon,entry[2],Rect2(0,-2,133,35),18)
	var streak:=Economy.daily_status()
	UI.label(content,"DAY %d\n%s"%[streak.day,"+%d COINS"%streak.reward if streak.can_claim else "CLAIMED"],Rect2(552,414,148,48),18,Color("fff5d9"))
	var hero:=UI.image(content,"res://assets/branding/menu-3d-hero-v2.png",Rect2(32,435,656,420))
	hero.name="MenuHero"
	hero.pivot_offset=hero.size/2
	if not SaveManager.settings.reduce_motion:
		var float_tween:=hero.create_tween().set_loops()
		float_tween.tween_property(hero,"position:y",429.0,2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		float_tween.tween_property(hero,"position:y",435.0,2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var play:=UI.button(content,"PLAY",Rect2(143,866,434,112),func(): start(int(SaveManager.progress.highest_unlocked)),Color("55ce17"))
	play.add_theme_font_size_override("font_size",49)
	UI.label(content,"LEVEL %d · ENDLESS BURROWS"%int(SaveManager.progress.highest_unlocked),Rect2(130,988,460,35),21,Color("d8ffba"))
	var levels_btn:=UI.button(content,"LEVELS",Rect2(195,368,330,58),func(): go("LevelSelect"),Color("3b8bd6"))
	levels_btn.add_theme_font_size_override("font_size",26)
	UI.button(content,"DAILY CHALLENGE",Rect2(155,1035,410,62),func(): start(25,true),Color("7d65dc"))
	var lb_btn:=UI.button(content,"LEADERBOARD",Rect2(45,1120,305,62),func(): show_page("Leaderboard"); Economy.left_home=true; AdsService.home_visible(false),Color("4278be"))
	lb_btn.add_theme_font_size_override("font_size",23)
	var ach_btn:=UI.button(content,"ACHIEVEMENTS",Rect2(370,1120,305,62),func(): show_page("Achievements"); Economy.left_home=true; AdsService.home_visible(false),Color("8e5bd6"))
	ach_btn.add_theme_font_size_override("font_size",23)
	if PlatformServices.native and PlatformServices.native.take_daily_launch():
		call_deferred("start",25,true)
		return
	elif PlatformServices.update_downloaded: call_deferred("service_event","update_downloaded","")
	elif PlatformServices.update_available: call_deferred("service_event","update_available","")
	call_deferred("open_home_prompt")

func start_trial(number: int) -> void:
	Economy.left_home=true
	AdsService.home_visible(false)
	SaveManager.trial_mode=true
	SaveManager.daily_mode=false
	SaveManager.trial_number=number
	SaveManager.level_number=number
	get_tree().change_scene_to_file("res://scenes/gameplay/Gameplay.tscn")

func trial_page() -> void:
	AdsService.home_visible(false)
	UI.label(content,"5-LEVEL TRIAL",Rect2(35,80,650,75),48)
	UI.label(content,"Try every level · Main progress stays safe",Rect2(35,170,650,45),23)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://levels/trial/manifest.json"))
	for entry in manifest.levels:
		var number: int=int(entry.number)
		var source:=preload("res://scripts/generation/TrialLevels.gd").read_source(number)
		var ready: bool=preload("res://scripts/generation/TrialLevels.gd").is_verified(source)
		var row:=number-1
		var button:=UI.button(content,"%d · %s"%[number,entry.name],Rect2(50,250+row*150,620,90),start_trial.bind(number),Color("6d66ce") if number%2 else Color("388fb8"))
		button.add_theme_font_size_override("font_size",30)
		button.disabled=not ready
		var done: Dictionary=SaveManager.progress.get("trial",{}).get("completed",{}).get(str(number),{})
		var mouse_count:=0
		for part in source.sections: mouse_count+=part.mice.size()
		UI.label(content,"%d MICE · %d SCREEN%s · %d BOMBS%s"%[mouse_count,entry.sections,"S" if int(entry.sections)>1 else "",source.resources.bombs," · CLEARED" if not done.is_empty() else ""],Rect2(50,345+row*150,620,35),22)
	UI.label(content,"Small strokes. Bigger Kitty. Reach each room's base.",Rect2(40,1050,640,60),22)
	UI.button(content,"MAIN MENU",Rect2(150,1150,420,70),func(): show_page("MainMenu"))

func open_home_prompt() -> void:
	if page!="MainMenu" or not is_inside_tree(): return
	# Consume the once-per-launch prompt only when it can actually be displayed.
	var existing:=get_node_or_null("CommercePopup")
	if existing:
		if not existing.tree_exited.is_connected(queue_home_prompt): existing.tree_exited.connect(queue_home_prompt,CONNECT_ONE_SHOT)
		return
	for child in get_children():
		if child is Window and child.visible:
			if not child.visibility_changed.is_connected(queue_home_prompt): child.visibility_changed.connect(queue_home_prompt,CONNECT_ONE_SHOT)
			return
	if not Economy.daily_prompt_shown:
		Economy.daily_prompt_shown=true
		if Economy.daily_status().can_claim:
			open_daily()
			var daily:=get_node_or_null("CommercePopup")
			if daily and not daily.tree_exited.is_connected(queue_home_prompt): daily.tree_exited.connect(queue_home_prompt,CONNECT_ONE_SHOT)
			return
	if Economy.should_support_popup(): Commerce.support_popup(self,randi_range(0,2))

func queue_home_prompt() -> void:
	call_deferred("open_home_prompt")

func open_support_menu() -> void:
	if page!="MainMenu" or get_node_or_null("CommercePopup")!=null: return
	Commerce.support_menu(self)

func open_daily() -> void:
	if page=="MainMenu" and get_node_or_null("CommercePopup")==null:
		Commerce.daily_popup(self,func(): show_page("MainMenu"))

func service_event(kind: String,payload: String) -> void:
	if kind in ["pack_price","coins_purchased","play_games_signed_in"]:
		if kind=="coins_purchased": message("Coins Added!","+%s coins have been added to your balance."%payload)
		if page in ["Shop","Leaderboard","Achievements","MainMenu"]: show_page(page)
	if kind in ["message","restore_complete"]: message("Kitty Hunt",payload)
	elif kind in ["update_available","update_downloaded"] and page=="MainMenu":
		if PlatformServices.update_prompts.get(kind,false): return
		PlatformServices.update_prompts[kind]=true
		var dialog:=ConfirmationDialog.new()
		dialog.title="Kitty Hunt update"
		dialog.dialog_text="An update is ready. Restart to finish?" if kind=="update_downloaded" else "A new Kitty Hunt update is available. Download it?"
		dialog.confirmed.connect(func():
			if kind=="update_downloaded": PlatformServices.native.complete_update()
			else: PlatformServices.native.start_update())
		add_child(dialog)
		UI.style_dialog(dialog)
		dialog.popup_centered(Vector2i(500,220))

func shop_page() -> void:
	AdsService.home_visible(false)
	Economy.left_home=true
	var backdrop:=ColorRect.new()
	backdrop.color=Color("17184f")
	backdrop.size=Vector2(720,1280)
	content.add_child(backdrop)
	for i in 8:
		var stripe:=Panel.new()
		stripe.position=Vector2(i*90,180)
		stripe.size=Vector2(90,50)
		stripe.add_theme_stylebox_override("panel",UI.box(Color("643ae4") if i%2==0 else Color("7b98fa"),15))
		content.add_child(stripe)
	header("SHOP")
	UI.wallet(content,Vector2(490,120),int(SaveManager.progress.coins))
	UI.label(content,"BUY COIN PACKS",Rect2(45,126,420,44),25,Color("ffe074"))
	for i in Economy.COIN_PACKS.size():
		var pack: Dictionary=Economy.COIN_PACKS[i]
		var tile:=Commerce.card(content,Rect2(45,270+i*250,630,220),Color("5a86de") if i!=1 else Color("7640cd"),Color("ffcb45"))
		for j in 3:
			UI.image(tile,"res://assets/ui/coin.png",Rect2(25+j*24,62-abs(1-j)*10,72,72))
		Commerce.heading(tile,pack.title,Rect2(165,24,430,56),36)
		UI.label(tile,"Use coins to retry & play longer",Rect2(165,82,430,40),21,Color("d8ffba"))
		var price: String=PlatformServices.pack_prices.get(pack.id,pack.fallback)
		var buy:=UI.button(tile,"BUY · "+price,Rect2(205,134,350,66),func(): PlatformServices.buy_coin_pack(pack.id),Color("55ce17"))
		buy.add_theme_font_size_override("font_size",26)
	UI.label(content,"Google Play coin purchases work in Play Store test & release builds.",Rect2(45,1070,630,70),21,Color("fff8e5"))
	UI.button(content,"BACK TO MENU",Rect2(165,1165,390,64),func(): show_page("MainMenu"),Color("3298bd"))

func header(title: String) -> void:
	var home=load("res://scripts/core/GameButton.gd").new()
	home.kind="home"
	home.position=Vector2(35,42)
	home.size=Vector2(76,76)
	home.tooltip_text="Main menu"
	home.pressed.connect(func(): show_page("MainMenu"))
	content.add_child(home)
	var title_label:=UI.label(content,title,Rect2(120,48,480,65),44,Color("ffe46b"))
	title_label.add_theme_font_override("font",UI.title_font())
	title_label.add_theme_color_override("font_outline_color",Color("5b2d6e"))
	title_label.add_theme_constant_override("outline_size",8)

func levels_page() -> void:
	header("YOUR ADVENTURE")
	var worlds:=["Sandy Beginnings","Rolling Trouble","Rotating Machines","Dangerous Tunnels","Underground Adventure","Mechanical Mayhem","Water and Wind","Portal Puzzles","Expert Rescue","Master of Sand"]
	UI.label(content,"WORLD %d  ·  ENDLESS ADVENTURE"%(world_index+1),Rect2(100,145,520,35),21,Color("ffd86b"))
	UI.label(content,worlds[world_index%worlds.size()],Rect2(100,188,520,55),32,Color("fff9e8"))
	UI.button(content,"‹",Rect2(35,185,60,60),func(): world_index=maxi(0,world_index-1); show_page("LevelSelect"))
	UI.button(content,"›",Rect2(625,185,60,60),func(): world_index=mini(int((int(SaveManager.progress.highest_unlocked)-1)/20)+1,world_index+1); show_page("LevelSelect"))
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(48,280)
	scroll.size=Vector2(632,850)
	content.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=4
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",25)
	scroll.add_child(grid)
	for index in 20:
		var level:=world_index*20+index+1
		var unlocked:=level<=int(SaveManager.progress.highest_unlocked)
		var stars:=int(SaveManager.progress.completed.get(str(level),{}).get("stars",0))
		var text:="%d\n%s"%[level,"★".repeat(stars)+"☆".repeat(3-stars)] if unlocked else "%d\nLOCKED"%level
		var button:=UI.button(grid,text,Rect2(0,0,140,125),func(): start(level),Color("64a85d") if unlocked else Color("7c9a9f"))
		button.custom_minimum_size=Vector2(140,125)
		button.disabled=not unlocked
	UI.label(content,"Keep hunting. New mouse mazes keep appearing!\nEat small, grow big, and catch them all.",Rect2(45,1150,630,65),20,Color("fff8e5"))

func settings_page() -> void:
	header("SETTINGS")
	var rows:=[ ["Music","music"],["Sound effects","effects"],["Vibration","vibration"],["Left-handed tools","left_handed"],["Reduce motion","reduce_motion"] ]
	var y:=175
	for row in rows:
		var row_label:=UI.label(content,row[0],Rect2(60,y,370,60),28)
		row_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var check:=CheckButton.new()
		check.position=Vector2(490,y)
		check.size=Vector2(140,60)
		check.text="ON"
		check.button_pressed=SaveManager.settings[row[1]]
		check.add_theme_font_override("font",UI.game_font())
		check.add_theme_font_size_override("font_size",24)
		var key: String=row[1]
		check.toggled.connect(func(value): SaveManager.settings[key]=value; SaveManager.save_settings())
		content.add_child(check)
		y+=90
	for pair in [["Music volume","music_volume"],["Effects volume","effects_volume"]]:
		var vol_label:=UI.label(content,pair[0],Rect2(60,y,260,65),24)
		vol_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var slider:=HSlider.new()
		slider.position=Vector2(345,y+15)
		slider.size=Vector2(280,40)
		slider.max_value=1
		slider.step=0.01
		slider.value=SaveManager.settings[pair[1]]
		var key: String=pair[1]
		slider.value_changed.connect(func(value): SaveManager.settings[key]=value; SaveManager.save_settings())
		content.add_child(slider)
		y+=85
	UI.button(content,"RATE GAME",Rect2(45,840,300,64),PlatformServices.rate_game,Color("5596dd"))
	UI.button(content,"SHARE GAME",Rect2(375,840,300,64),PlatformServices.share_game,Color("5596dd"))
	UI.button(content,"RESTORE COINS",Rect2(45,925,630,64),PlatformServices.restore_purchases,Color("8568c2"))
	UI.button(content,"DAILY CHALLENGE ALERT",Rect2(45,1010,630,64),func(): PlatformServices.update_notification(not SaveManager.settings.get("challenge_notifications",false)); show_page("Settings"),Color("65a852"))
	UI.label(content,"Notifications: "+("ON" if SaveManager.settings.get("challenge_notifications",false) else "OFF"),Rect2(80,1080,560,35),21)
	UI.button(content,"PRIVACY",Rect2(45,1130,300,60),func():
		if PlatformServices.native and not AdsService.no_fill_this_launch: PlatformServices.native.privacy_options()
		else: message("Privacy","Progress is stored on your device. Google Play handles purchases. AdMob requests ads only when configured and consent allows. For privacy questions, contact muhammadfaysal.khan7@gmail.com."))
	UI.button(content,"RESET",Rect2(375,1130,300,60),reset_confirm,Color("ca6b65"))

func leaderboard_page() -> void:
	AdsService.home_visible(false)
	Economy.left_home=true
	header("LEADERBOARD")
	var cleared: int=SaveManager.progress.get("completed",{}).size()
	var stars: int=SaveManager.stars_total()
	var coins: int=int(SaveManager.progress.get("coins",0))
	var my_score: int=PlatformServices.player_score()
	var my_card:=Commerce.card(content,Rect2(45,175,630,220),Color("3f5fe6"),Color("ffcb45"))
	Commerce.heading(my_card,"YOUR SCORE: %d"%my_score,Rect2(20,24,590,56),38)
	UI.label(my_card,"%d Levels Cleared  ·  %d Stars"%[cleared,stars],Rect2(20,96,590,42),24,Color("d8ffba"))
	UI.label(my_card,"%d Coins Balance"%coins,Rect2(20,144,590,42),24,Color("ffe566"))
	var status_card:=Commerce.card(content,Rect2(45,440,630,310),Color("4a5cb8"),Color("8cb4ff"))
	var player_title: String="Signed in as %s ✓"%PlatformServices.play_games_player if not PlatformServices.play_games_player.is_empty() else "Google Play Games"
	Commerce.heading(status_card,player_title,Rect2(20,24,590,52),30)
	var detail_text:="View live global rankings and compete with other Kitty Hunt players." if not PlatformServices.play_games_player.is_empty() else "Sign in to submit your real score and view the live global leaderboard."
	var detail_lbl:=UI.label(status_card,detail_text,Rect2(35,88,560,72),22,Color("fff8e5"))
	detail_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var open_lb:=UI.button(status_card,"OPEN GLOBAL LEADERBOARD",Rect2(65,188,500,72),PlatformServices.show_google_leaderboard,Color("55ce17"))
	open_lb.add_theme_font_size_override("font_size",24)
	if PlatformServices.play_games_player.is_empty():
		var pg_btn:=UI.button(content,"SIGN IN · GOOGLE PLAY",Rect2(135,810,450,64),PlatformServices.sign_in_play_games,Color("7d65dc"))
		pg_btn.add_theme_font_size_override("font_size",24)
	UI.button(content,"BACK TO MENU",Rect2(165,1120,390,64),func(): show_page("MainMenu"),Color("3298bd"))

func achievements_page() -> void:
	AdsService.home_visible(false)
	Economy.left_home=true
	header("ACHIEVEMENTS")
	var cleared: int=SaveManager.progress.get("completed",{}).size()
	var stars: int=SaveManager.stars_total()
	var coins: int=int(SaveManager.progress.get("coins",0))
	var streak: int=int(Economy.daily_status().day)
	var list: Array=[
		{"title":"FIRST CATCH","desc":"Complete your first level","cur":mini(cleared,1),"goal":1},
		{"title":"BURROW EXPLORER","desc":"Complete 5 levels","cur":mini(cleared,5),"goal":5},
		{"title":"MASTER HUNTER","desc":"Complete 20 levels","cur":mini(cleared,20),"goal":20},
		{"title":"STAR COLLECTOR","desc":"Earn 15 stars","cur":mini(stars,15),"goal":15},
		{"title":"COIN HOARDER","desc":"Hold 500 coins","cur":mini(coins,500),"goal":500},
		{"title":"DAILY REGULAR","desc":"Reach a 3-day streak","cur":mini(streak,3),"goal":3}
	]
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(35,140)
	scroll.size=Vector2(650,975)
	content.add_child(scroll)
	var body:=Control.new()
	body.custom_minimum_size=Vector2(630,list.size()*158)
	scroll.add_child(body)
	for i in list.size():
		var item: Dictionary=list[i]
		var unlocked: bool=int(item.cur)>=int(item.goal)
		var card:=Commerce.card(body,Rect2(10,8+i*155,610,136),Color("55aa3b") if unlocked else Color("4155a8"),Color("eaff7c") if unlocked else Color("8cb4ff"))
		var title_lbl:=UI.label(card,item.title,Rect2(24,14,390,46),26,Color("ffe566") if unlocked else Color("fff8e5"))
		title_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var desc_lbl:=UI.label(card,item.desc,Rect2(24,66,390,46),21,Color("d8ffba") if unlocked else Color("dbe6ff"))
		desc_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var status_text:="UNLOCKED ✓" if unlocked else "%d / %d"%[item.cur,item.goal]
		UI.label(card,status_text,Rect2(410,36,180,64),23,Color("d8ffba") if unlocked else Color("ffe074"))
	UI.button(content,"BACK TO MENU",Rect2(165,1150,390,64),func(): show_page("MainMenu"),Color("3298bd"))

func message(title: String,text: String) -> void:
	var dialog:=AcceptDialog.new()
	dialog.title=title
	dialog.dialog_text=text
	add_child(dialog)
	UI.style_dialog(dialog)
	dialog.popup_centered(Vector2i(500,230))

func reset_confirm() -> void:
	var dialog:=ConfirmationDialog.new()
	dialog.title="Reset progress?"
	dialog.dialog_text="Your stars, records and unlocks will be erased."
	dialog.confirmed.connect(func(): SaveManager.reset_progress(); show_page("Settings"))
	add_child(dialog)
	UI.style_dialog(dialog)
	dialog.popup_centered(Vector2i(480,200))

func quit_confirm() -> void:
	var dialog:=ConfirmationDialog.new()
	dialog.title="See you soon?"
	dialog.dialog_text="Quit Kitty Hunt?"
	dialog.confirmed.connect(func(): get_tree().quit())
	add_child(dialog)
	UI.style_dialog(dialog)
	dialog.popup_centered(Vector2i(400,180))

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_RESUMED: refresh_home_day()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST or what==NOTIFICATION_WM_CLOSE_REQUEST:
		if page!="MainMenu": go("MainMenu")
		else: quit_confirm()

func _process(_delta: float) -> void:
	if page=="MainMenu" and Time.get_ticks_msec()>=next_daily_check:
		next_daily_check=Time.get_ticks_msec()+30000
		refresh_home_day()

func refresh_home_day() -> void:
	if page!="MainMenu" or not is_instance_valid(content) or not Economy.refresh_daily_prompt(): return
	var popup:=get_node_or_null("CommercePopup")
	if popup and popup.get_meta("popup_kind","")=="daily_reward": popup.queue_free()
	show_page("MainMenu")

func ad_availability() -> void:
	if page=="Shop" and get_node_or_null("CommercePopup")==null: show_page("Shop")
	var popup:=get_node_or_null("CommercePopup")
	if popup:
		var notice:=popup.get_node_or_null("NoAdsToday")
		if notice: notice.visible=AdsService.no_fill_this_launch
