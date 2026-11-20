extends Node
const Commerce=preload("res://scripts/menus/CommerceUI.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func settle() -> void:
	for frame in 4: await get_tree().process_frame
func run() -> void:
	Economy.home_seen=false
	Economy.left_home=false
	Economy.support_shown=false
	Economy.daily_prompt_shown=true
	var original_price:=PlatformServices.coffee_price
	PlatformServices.coffee_price=""
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await settle()
	check(menu.get_node_or_null("CommercePopup")==null and not Economy.support_shown,"initial Home does not auto-prompt for support")
	menu.show_page("Settings")
	check(Economy.left_home,"all internal page navigation records leaving Home")
	var blocking:=Commerce.daily_popup(menu,func(): pass)
	menu.show_page("MainMenu")
	await settle()
	check(not Economy.support_shown and menu.get_node("CommercePopup")==blocking,"daily modal cannot consume or hide support prompt")
	blocking.queue_free()
	await settle()
	check(Economy.support_shown and menu.get_node_or_null("CommercePopup")!=null,"support opens after blocking modal closes on Home return")
	menu.get_node("CommercePopup").queue_free()
	await settle()
	menu.show_page("MainMenu")
	await settle()
	check(menu.get_node_or_null("CommercePopup")==null,"automatic support prompt appears only once per launch")
	menu.open_support_menu()
	var popup=menu.get_node("CommercePopup")
	var labels: Array=[]
	for child in popup.get_children():
		if child is Button: labels.append(child.text)
	check(labels.has("RATE GAME  ★★★★★") and labels.has("SHARE GAME") and popup.has_node("CoffeeButton"),"manual Home support menu exposes all three actions")
	check(popup.get_node("CoffeeButton").disabled,"coffee waits for a real Google Play product price")
	PlatformServices.coffee_price="$1.99"
	menu.service_event("coffee_price","$1.99")
	check(not popup.get_node("CoffeeButton").disabled and "$1.99" in popup.get_node("CoffeeButton").text,"late billing product response enables existing coffee popup")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/support-menu.png")
	menu.queue_free()
	PlatformServices.coffee_price=original_price
	await settle()
	print("SUPPORT RESULT: ",failures," failures")
	get_tree().quit(failures)
