extends SceneTree
const State=preload("res://game/run_state.gd")
var checks=0
var failures=0
func check(ok,label):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",label)
func normalized_equal(a,b):
	if (a is int or a is float) and (b is int or b is float):return float(a)==float(b)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for k in a:
			if not b.has(k) or not normalized_equal(a[k],b[k]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not normalized_equal(a[i],b[i]):return false
		return true
	return a==b
func do_action(s,action,dir):
	match action:
		0,1,2,3:return s.command("move",dir)
		4:return s.command("wait")
		5:return s.command("power",s.position()+dir)
		6:return s.command("guard")
		7:return s.command("dash",s.position()+dir*2)
		8:return s.command("loot")
		9:return s.use_item("bandage")
		10:return s.use_item("tonic")
		11:return s.use_item("splint")
		12:return s.use_item("ration")
		13:return s.use_item("water")
		14:return s.drop_item("bandage",1)
		15:return s.drop_item("ration",int(s.player.inventory.get("ration",0)))
	return false
func _initialize():
	var rr=RandomNumberGenerator.new();rr.seed=552789
	for game in 40:
		var s=State.new();s.new_game()
		s.area="road" if game%2==0 else "ruin"
		s.player.x=1 if game%2==0 else 2;s.player.y=9 if game%2==0 else 14;s._reveal()
		for step in 150:
			var action=rr.randi_range(0,15);var dir=State.DIRS[rr.randi_range(0,3)]
			var r=State.new();r.new_game();check(r.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"valid replay restore")
			var oldturn=s.turn;var oldhp=s.player.hp;var oldinv=s.player.inventory.duplicate(true)
			var result=do_action(s,action,dir);var result2=do_action(r,action,dir)
			check(result==result2 and normalized_equal(s.player,r.player) and normalized_equal(s.maps,r.maps) and s.turn==r.turn,"replay game %d step%d"%[game,step])
			check(s.turn==oldturn+(1 if result else 0),"one turn or zero")
			if not result:check(s.player.hp==oldhp and s.player.inventory==oldinv,"invalid keeps HP/items")
			check(s.player.hp>=0 and s.player.hp<=s.max_hp(),"HP bound")
			check(s.player.energy>=0 and s.player.energy<=s.max_energy(),"energy bound")
			check(s.pack_slots()<=s.PACK_CAPACITY,"pack bound")
			var occupancy={}
			for a in s.maps[s.area].actors:
				if a.hp<=0:continue
				var p=Vector2i(int(a.x),int(a.y));check(not occupancy.has(p) and p!=s.position(),"actor collision");occupancy[p]=true
			if s.dead:break
	print("FUZZ REVIEW: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
