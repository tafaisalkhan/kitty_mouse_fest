extends Node
var failures:=0
var grants:=0
const Screens=preload("res://scripts/menus/CommerceUI.gd")
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	var original:=SaveManager.progress.duplicate(true)
	SaveManager.reset_progress()
	check(Economy.claim_daily("2026-01-01")==10,"day one grants 10 coins")
	check(Economy.claim_daily("2026-01-01")==0,"same day cannot be claimed twice")
	check(Economy.claim_daily("2026-01-02")==20,"consecutive day grants 20 coins")
	check(Economy.claim_daily("2026-01-03")==30,"day three grants 30 coins")
	check(Economy.claim_daily("2026-01-05")==10,"missing a day resets streak")
	check(Economy.claim_daily("2026-01-04")==0,"clock rollback cannot duplicate a reward")
	SaveManager.progress.daily_streak={"last_claimed":"2026-01-08","day":8}
	check(Economy.claim_daily("2026-01-09")==90,"streak continues beyond seven days")
	check(SaveManager.read_valid("user://savegame.json",SaveManager.progress).daily_streak.day==9,"streak persists on disk")
	Economy.daily_prompt_date="2026-01-09"
	Economy.daily_prompt_shown=true
	check(not Economy.refresh_daily_prompt("2026-01-09") and Economy.daily_prompt_shown,"same day does not repeat daily prompt")
	check(Economy.refresh_daily_prompt("2026-01-10") and not Economy.daily_prompt_shown,"next day re-arms reward prompt even without restarting app")
	Economy.daily_prompt_date=Economy.today()
	SaveManager.progress.coins=500
	check(Economy.buy_pack("bombs") and SaveManager.progress.coins==440 and SaveManager.progress.boosters.bombs==3,"shop subtracts coins and grants boosters")
	SaveManager.progress.coins=0
	check(not Economy.buy_pack("rescue"),"insufficient coins cannot buy pack")
	check(Economy.consume_booster("bombs") and SaveManager.progress.boosters.bombs==2,"booster consumption persists")
	AdsService.mark_no_fill()
	check(AdsService.no_fill_this_launch,"ad load failure latches no-fill for launch")
	AdsService.request_reward(func(): grants+=1)
	check(grants==1,"no-fill gives reward directly without an ad")
	AdsService.on_native_event("reward_earned","old")
	check(grants==1,"late ad callback cannot double grant")
	Economy.home_seen=false
	Economy.left_home=false
	Economy.support_shown=false
	check(not Economy.should_support_popup(),"support popup excluded from initial Home")
	Economy.left_home=true
	check(Economy.should_support_popup() and not Economy.should_support_popup(),"support popup once on Home return")
	SaveManager.progress.coins=780
	SaveManager.progress.daily_streak={}
	Economy.daily_prompt_shown=true
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await capture("res://docs/commerce-home.png")
	var daily:=Screens.daily_popup(menu,func(): pass)
	await capture("res://docs/commerce-daily.png")
	daily.queue_free()
	await get_tree().process_frame
	menu.show_page("Shop")
	await capture("res://docs/commerce-shop.png")
	menu.shop_tab="coins"
	menu.show_page("Shop")
	await capture("res://docs/commerce-shop-coins.png")
	menu.shop_tab="powers"
	menu.show_page("Shop")
	var offer:=Screens.offer_popup(menu,"rescue",func(): pass)
	await capture("res://docs/commerce-offer.png")
	offer.queue_free()
	await get_tree().process_frame
	menu.show_page("MainMenu")
	var support:=Screens.support_popup(menu,1)
	await capture("res://docs/commerce-support.png")
	support.queue_free()
	await get_tree().process_frame
	menu.show_page("Settings")
	await capture("res://docs/font-settings.png")
	menu.message("Kitty Rescue","Your settings are saved.\nEvery little paw belongs at home.")
	await capture("res://docs/font-dialog.png")
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.progress=original
	SaveManager.atomic_save("user://savegame.json",original)
	print("COMMERCE RESULT: ",failures," failures")
	get_tree().quit(failures)
