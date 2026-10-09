extends SceneTree
const State=preload("res://game/run_state.gd")
const Main=preload("res://scenes/main.gd")
var checks=0
var failures=0
func check(ok,label):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func fresh():
	var s=State.new();s.new_game();return s
func totals(s):
	var counts={}
	for id in s.player.inventory: counts[id]=int(s.player.inventory[id])
	counts[s.player.weapon]=int(counts.get(s.player.weapon,0))+1
	counts[s.player.armor]=int(counts.get(s.player.armor,0))+1
	for area in s.maps:
		for pile in s.maps[area].loot:
			for id in pile.items: counts[id]=int(counts.get(id,0))+int(pile.items[id])
	return counts
func _initialize(): call_deferred("run")
func run():
	var rr=RandomNumberGenerator.new();rr.seed=14989
	for run_id in 15:
		var s=fresh()
		s.player.inventory={"sword":1,"fine_sword":3,"leather":1,"mail":3,"bandage":4,"splint":2,"scrap":3,"gem":5}
		var original=totals(s)
		for step in 180:
			s.player.hunger=0;s.player.thirst=0
			var before=s.snapshot();var old_turn=s.turn;var done=false
			var id=State.ITEMS.keys()[rr.randi_range(0,State.ITEMS.size()-1)]
			match rr.randi_range(0,3):
				0: done=s.drop_item(id,rr.randi_range(-1,5))
				1: done=s.command("loot")
				2:
					if State.ITEMS[id].kind in ["weapon","armor"]:done=s.use_item(id)
				3: done=s.command("move",State.DIRS[rr.randi_range(0,3)])
			check(totals(s)==original,"all equipment/items conserved run %d step %d"%[run_id,step])
			check(s.turn==old_turn+(1 if done else 0),"one turn or none")
			check(s.pack_slots()<=8,"capacity")
			if not done:check(s.player==before.player and s.maps==before.maps,"invalid action no world mutation")
			var r=fresh()
			check(r.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"post-drop/move/equip save accepted")
			check(totals(r)==original,"round trip conserves all items")
	# Legacy loot without dropped flag and explicit false are found before true.
	for mode in [0,1]:
		var s=fresh();s.player.inventory={"bandage":1,"splint":1,"ration":1,"water":1,"tonic":1,"sword":1,"leather":1,"gem":1}
		check(s.drop_item("gem"),"free slot")
		var pile={"x":12,"y":10,"coins":0,"items":{"mail":1}}
		if mode: pile.dropped=false
		s.maps.village.loot.append(pile)
		var r=fresh();check(r.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"legacy loot save accepts")
		check(r.command("loot") and r.player.inventory.has("mail") and not r.player.inventory.has("gem"),"legacy found loot priority")
		check(r.maps.village.loot[0].items.gem==1,"dropped item remains on full-pack")
		var before=r.turn
		check(not r.command("loot") and r.turn==before,"unpickable full pack consumes no turn")
		check(r.drop_item("sword") and r.command("loot") and r.player.inventory.has("gem"),"free another slot and re-pickup")
	# Corrupt marker / quantities are rejected atomically.
	var s=fresh();s.drop_item("bandage");var good=s.snapshot()
	for bad_value in [null,0,1,"true",{},[]]:
		var bad=good.duplicate(true);bad.maps.village.loot[0].dropped=bad_value
		check(not s.restore(bad) and s.snapshot()==good,"corrupt dropped marker atomic rejection")
	for bad_value in [null,0,-1,1.5,"2",{},[]]:
		var bad=good.duplicate(true);bad.maps.village.loot[0].items.bandage=bad_value
		check(not s.restore(bad) and s.snapshot()==good,"corrupt dropped quantity atomic rejection")
	print("REVIEW RULE CHECKS: ",checks," checks, ",failures," failures")
	# Reproduce zero-turn Back-to-pack double-tap after a redraw.
	var ui=Main.new();root.add_child(ui);ui.set_process(false);ui.has_started=true;ui.panel="";ui.tab="pack";ui.sound_on=false
	ui._button_action("inspect:bandage")
	await process_frame
	await process_frame
	print("UI buttons ready: ",ui.buttons.size()," panel ",ui.panel)
	ui._pointer_press(Vector2(500,624))
	check(ui.panel.is_empty() and ui.state.turn==0,"first Back tap costs no turn")
	ui.queue_redraw()
	await process_frame
	await process_frame
	ui._pointer_press(Vector2(500,624))
	print("REPRO Back-to-pack double tap: guard=",ui.pointer_guard_until," queued steps=",ui.move_path.size()," turn before process=",ui.state.turn)
	check(ui.move_path.is_empty(),"Back double tap never queues movement")
	ui._process(0.15)
	check(ui.state.turn==0,"Back double tap never advances a turn")
	print("REPRO Back-to-pack after process: turn=",ui.state.turn," position=",ui.state.position())
	print("FINAL REVIEW CHECKS: ",checks," checks, ",failures," failures")
	ui.queue_free();await process_frame
	quit(1 if failures else 0)
