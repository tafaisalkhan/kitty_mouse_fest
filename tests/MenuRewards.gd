extends Node
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	var original:=SaveManager.progress.duplicate(true)
	SaveManager.reset_progress()
	check(SaveManager.complete(1,2,10,1)==100,"first rescue awards completion and two stars")
	check(SaveManager.complete(1,2,10,1)==0,"replay cannot duplicate coins")
	check(SaveManager.complete(1,3,9,1)==25,"improved star awards only the difference")
	check(SaveManager.read_valid("user://savegame.json",SaveManager.progress).coins==125,"coin balance persists")
	SaveManager.daily_mode=true
	check(SaveManager.complete(25,3,10,1)==175,"first daily awards coins")
	check(SaveManager.complete(25,3,10,1)==0,"daily coins awarded once")
	SaveManager.daily_mode=false
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.8).timeout
	for node in menu.content.get_children():
		if node is TextureRect and node.name!="MenuHero": check(node.size.x<=76,"menu currency art stays compact")
	var hero=menu.content.get_node("MenuHero")
	check(hero.texture!=null and hero.size.x<=656 and hero.position.y+hero.size.y<866,"rendered menu hero fits above the play button")
	await capture("res://docs/menu-redesign.png")
	check(menu.content.get_children().any(func(n):return n is Button and n.text=="PLAY"),"Home has one progress-driven Play button")
	check(not menu.content.get_children().any(func(n):return n is Button and "TRIAL" in n.text),"Home does not expose a level selector")
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.level_number=1
	var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	game.test_mode=true
	add_child(game)
	await get_tree().process_frame
	game.ended=true
	game.reward_coins=125
	game.rescued=1
	game.result_panel(true,3)
	for node in game.overlay.get_children():
		if node is TextureRect: check(node.size.x<=76,"result coins and stars stay compact")
	await get_tree().create_timer(1.1).timeout
	await capture("res://docs/rewards-flying.png")
	await get_tree().create_timer(1.5).timeout
	check(game.coin_label.text==str(game.displayed_coins+125),"all flying coins reach HUD balance")
	await capture("res://docs/rewards-complete.png")
	game.queue_free()
	await get_tree().process_frame
	SaveManager.progress=original
	SaveManager.atomic_save("user://savegame.json",original)
	print("MENU REWARDS RESULT: ",failures," failures")
	get_tree().quit(failures)
