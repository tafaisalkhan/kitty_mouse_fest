extends Node
signal changed
var home_seen:=false
var left_home:=false
var support_shown:=false
var daily_prompt_shown:=false
var daily_prompt_date:=""
const PACKS={"bombs":{"title":"BOMB BUNDLE","cost":60,"bombs":3,"hints":0},"hints":{"title":"HELPING PAWS","cost":45,"bombs":0,"hints":3},"rescue":{"title":"EPIC HUNT PACK","cost":225,"bombs":10,"hints":5}}
const RETRY_COST:=25
const AD_COIN_REWARD:=50

func today() -> String:
	return Time.get_date_string_from_system()

func refresh_daily_prompt(date: String="") -> bool:
	if date.is_empty(): date=today()
	var changed_day:=not daily_prompt_date.is_empty() and daily_prompt_date!=date
	daily_prompt_date=date
	if changed_day: daily_prompt_shown=false
	return changed_day

func daily_status(date: String="") -> Dictionary:
	if date.is_empty(): date=today()
	var state: Dictionary=SaveManager.progress.get("daily_streak",{})
	var last: String=state.get("last_claimed","")
	var difference:=999.0
	if not last.is_empty(): difference=(Time.get_unix_time_from_datetime_string(date+"T00:00:00")-Time.get_unix_time_from_datetime_string(last+"T00:00:00"))/86400.0
	var day:=int(state.get("day",0))+1 if difference==1 else 1
	if difference<=0: day=maxi(1,int(state.get("day",1)))
	return {"day":day,"reward":day*10,"can_claim":difference>0,"claimed_today":difference==0}

func commit(previous: Dictionary) -> bool:
	if SaveManager.atomic_save("user://savegame.json",SaveManager.progress):
		changed.emit()
		return true
	SaveManager.progress=previous
	return false

func claim_daily(date: String="") -> int:
	if date.is_empty(): date=today()
	var status:=daily_status(date)
	if not status.can_claim: return 0
	var previous:=SaveManager.progress.duplicate(true)
	SaveManager.progress.daily_streak={"last_claimed":date,"day":status.day}
	SaveManager.progress.coins+=status.reward
	if not commit(previous): return 0
	AudioManager.play_fx("coin")
	return status.reward

func claim_chest() -> int:
	if SaveManager.progress.get("chest_date","")==today(): return 0
	var previous:=SaveManager.progress.duplicate(true)
	SaveManager.progress.chest_date=today()
	SaveManager.progress.coins+=25
	if not commit(previous): return 0
	AudioManager.play_fx("coin")
	return 25

func buy_pack(key: String) -> bool:
	if not PACKS.has(key): return false
	var pack: Dictionary=PACKS[key]
	if int(SaveManager.progress.coins)<pack.cost: return false
	var previous:=SaveManager.progress.duplicate(true)
	SaveManager.progress.coins-=pack.cost
	for booster in ["bombs","hints"]: SaveManager.progress.boosters[booster]=int(SaveManager.progress.boosters.get(booster,0))+pack[booster]
	return commit(previous)

func spend_coins(amount: int) -> bool:
	if amount<=0 or int(SaveManager.progress.get("coins",0))<amount: return false
	var previous:=SaveManager.progress.duplicate(true)
	SaveManager.progress.coins=int(SaveManager.progress.get("coins",0))-amount
	return commit(previous)

func add_coins(amount: int) -> bool:
	if amount<=0: return false
	var previous:=SaveManager.progress.duplicate(true)
	SaveManager.progress.coins=int(SaveManager.progress.get("coins",0))+amount
	if not commit(previous): return false
	AudioManager.play_fx("coin")
	return true

func consume_booster(key: String) -> bool:
	if int(SaveManager.progress.boosters.get(key,0))<=0: return false
	var previous:=SaveManager.progress.duplicate(true)
	SaveManager.progress.boosters[key]-=1
	return commit(previous)

func should_support_popup() -> bool:
	if not home_seen:
		home_seen=true
		return false
	if support_shown or not left_home: return false
	support_shown=true
	return true
