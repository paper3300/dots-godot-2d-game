extends SceneTree
const State = preload("res://game/run_state.gd")
var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func fresh() -> RunState:
	var s := State.new()
	s.language = "en"
	s.new_game()
	return s

func arena(kind: String = "raider") -> RunState:
	var s := fresh()
	s.area = "road"
	s.maps.road = s._empty_map(".")
	s.player.x = 10
	s.player.y = 10
	if not kind.is_empty():
		s._enemy(s.maps.road,kind,Vector2i(11,10))
	s._reveal()
	return s

func _initialize() -> void:
	_test_turns_and_combat()
	_test_status_and_skills()
	_test_inventory_and_economy()
	_test_quest_and_save()
	_test_world_and_replay()
	_test_full_adventure()
	_test_direct_adventure()
	print("RULE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_turns_and_combat() -> void:
	var s := fresh()
	check(s.position() == Vector2i(12,9),"spawn adjacent to contract board")
	check(s.near_object("board"),"first E can open board")
	check(not s.command("move",Vector2i(1,1)),"diagonal command rejected")
	check(s.turn == 0,"invalid movement costs no turn")
	check(not s.command("power",Vector2i(20,10)),"invalid target rejected")
	check(s.turn == 0 and s.player.energy == 30,"invalid skill costs no energy or turn")
	check(s.command("wait") and s.turn == 1,"wait advances exactly one turn")
	s = arena()
	var a: Dictionary = s.maps.road.actors[0]
	s.command("move",Vector2i.RIGHT)
	check(s.turn==1 and a.hp==16 and a.turns==1,"one attack means exactly one enemy action")
	check(s.player.hp==59,"armor reduces incoming damage")
	a.hp=1
	var hp := int(s.player.hp)
	s.command("move",Vector2i.RIGHT)
	check(a.hp==0 and a.turns==1 and s.player.hp==hp,"enemy killed by player does not act")
	check(s.maps.road.loot.size()==1,"kill creates one loot pile")
	s.command("move",Vector2i.RIGHT)
	check(s.maps.road.loot.size()==1,"corpse cannot be killed twice")
	check(s.player.coins==44,"walking onto loot collects coins once")
	s = arena()
	s.maps.road.tiles[10][9]="#"
	check(not s.command("move",Vector2i.LEFT) and s.turn==0,"wall bump consumes no turn")
	s.maps.road.tiles[10][9]="+"
	check(s.command("move",Vector2i.LEFT) and s.turn==1,"opening door consumes one turn")
	check(s.position()==Vector2i(10,10) and s.tile_at(Vector2i(9,10))=="d","opening door does not also move")
	s.player.hp=1
	s.command("wait")
	check(s.dead and s.player.hp==0,"lethal hit enters death state")
	var before := s.turn
	check(not s.command("wait") and s.turn==before,"dead player cannot act")

func _test_status_and_skills() -> void:
	var s := arena()
	s.command("guard")
	check(s.player.hp==63 and s.player.guard==1,"brace protects its casting turn")
	s.command("wait")
	check(s.player.hp==62 and s.player.guard==0,"brace protects exactly second enemy turn")
	s.command("wait")
	check(s.player.hp==57,"brace expires after two enemy turns")
	s = arena()
	check(s.command("power",Vector2i(11,10)),"hew succeeds against adjacent enemy")
	check(s.player.hp==64 and s.maps.road.actors[0].hp==9,"hew damages and interrupts current enemy action")
	check(s.player.energy==23 and s.player.cooldowns.power==4,"skill cost and full initial cooldown")
	var n := s.turn
	check(not s.command("power",Vector2i(11,10)) and s.turn==n,"cooldown failure costs no turn")
	for i in 4:
		s.command("wait")
	check(s.player.cooldowns.power==0,"skill recovers after four further turns")
	s=arena("")
	s.player.bleed=3
	s.command("wait")
	check(s.player.hp==63 and s.player.bleed==2,"one existing bleed tick per action")
	var bandages := int(s.player.inventory.bandage)
	s.use_item("bandage")
	check(s.player.bleed==0 and s.player.inventory.bandage==bandages-1 and s.player.hp==64,"bandage applies before status and consumes once")
	check(not s.use_item("bandage"),"unneeded treatment is not wasted")
	s.player.injury=2
	s.player.pain=40
	s.player.hp=40
	s.use_item("splint")
	check(s.player.injury==1 and s.max_hp()==58 and s.player.pain<=5,"poultice treats one injury and pain")
	s=arena("")
	check(s.command("dash",Vector2i(12,10)) and s.position()==Vector2i(12,10) and s.turn==1,"dash moves two tiles in one turn")
	s=arena("")
	s.maps.road.tiles[10][11]="#"
	check(not s.command("dash",Vector2i(12,10)) and s.turn==0,"dash cannot pass through a wall")
	s=arena()
	s.maps.road.actors[0].turns=3
	s.command("wait")
	check(s.player.bleed==5,"new bleeding isn't decremented on the infliction turn")
	s=arena("warden")
	s.command("wait")
	check(s.maps.road.actors[0].windup and s.player.hp==64,"warden telegraphs instead of hitting")
	s.command("move",Vector2i.LEFT)
	check(s.player.hp==64 and not s.maps.road.actors[0].windup,"stepping away avoids telegraphed heavy attack")
	s=arena("archer")
	s.maps.road.actors[0].x=14
	s.command("wait")
	check(s.maps.road.actors[0].windup and s.player.hp==64,"archer aims before firing")
	s.maps.road.tiles[10][12]="#"
	s.command("wait")
	check(s.player.hp==64,"archer cannot fire through wall")

func _test_inventory_and_economy() -> void:
	var s := fresh()
	check(not s.buy("tonic"),"cannot buy remotely")
	s.player.x=18
	s.player.y=9
	var money := int(s.player.coins)
	check(s.buy("bandage") and s.player.coins==money-8 and s.player.inventory.bandage==5,"buy conserves money and item count")
	check(s.turn==0,"safe trading does not spend turns")
	check(s.sell("bandage") and s.player.coins==money-4,"selling gives half price")
	check(not s.sell("water"),"free refill water cannot be sold for arbitrage")
	s.player.inventory.bell=1
	check(not s.sell("bell"),"quest object cannot be sold")
	s=arena("")
	for id in ["scrap","gem","fine_sword"]:
		s.add_item(id)
	check(s.pack_slots()==State.PACK_CAPACITY,"pack reaches its slot cap")
	check(not s.add_item("mail"),"full pack rejects a new item type")
	s.maps.road.loot.append({"x":10,"y":10,"coins":0,"items":{"mail":1}})
	check(not s.command("loot") and s.maps.road.loot[0].items.mail==1,"failed loot stays on ground and costs no turn")
	check(s.add_item("bandage"),"existing stacks remain usable when pack full")
	check(s.add_item("bell") and s.pack_slots()==State.PACK_CAPACITY,"quest pouch bypasses pack cap")
	check(s.use_item("fine_sword") and s.player.weapon=="fine_sword" and s.player.inventory.sword==1,"equipment swap preserves old weapon")
	s.player.inventory.fine_sword=2
	check(not s.use_item("fine_sword"),"equipping currently equipped item does not duplicate or consume it")
	s=fresh()
	s.player.x=12
	s.player.y=11
	check(not s.interact("well"),"full water inventory and no thirst need no refill")
	s.player.inventory.water=1
	s.player.thirst=25
	check(s.interact("well") and s.player.thirst==0 and s.player.inventory.water==2,"well relieves thirst and refills a flask")
	s.player.inventory={"bandage":1,"splint":1,"ration":1,"tonic":1,"fine_sword":1,"mail":1,"scrap":1,"gem":1}
	s.player.thirst=0
	var well_turn := s.turn
	check(not s.interact("well") and s.turn==well_turn,"full pack no-op well interaction costs no turn")
	s.player.x=7
	s.player.y=9
	s.player.hp=11
	s.player.bleed=5
	s.player.injury=2
	check(s.rest() and s.player.hp==64 and s.player.bleed==0 and s.player.injury==0,"inn cures and restores all condition")

func _test_quest_and_save() -> void:
	var s := fresh()
	check(s.interact("board") and s.quest=="active","accept contract")
	check(not s.interact("board") and s.player.coins==34,"cannot collect early reward")
	s.area="ruin"
	s.player.x=23
	s.player.y=3
	check(not s.interact("reliquary"),"living warden blocks quest relic")
	for actor in s.maps.ruin.actors:
		actor.hp=0
	check(s.interact("reliquary") and s.quest=="recovered" and s.player.coins==34,"relic pickup does not grant reward")
	check(not s.interact("reliquary") and s.player.inventory.bell==1,"relic cannot be duplicated")
	s.area="village"
	s.player.x=12
	s.player.y=9
	check(s.interact("board") and s.won and s.player.coins==124,"return grants exact reward")
	check(not s.interact("board") and s.player.coins==124,"reward cannot be claimed twice")
	check(not s.player.inventory.has("bell"),"reward consumes quest relic")
	s.maps.ruin.tiles[8][4]="d"
	s.player.injury=1
	s.player.bleed=3
	s.player.hp=41
	s.player.cooldowns.power=2
	s._reveal()
	var path := "user://rule_test_save.json"
	check(s.save_game(path),"atomic save writes successfully")
	var loaded := fresh()
	check(loaded.load_game(path),"save loads successfully")
	check(loaded.player==JSON.parse_string(JSON.stringify(s.player)) and loaded.maps==JSON.parse_string(JSON.stringify(s.maps)) and loaded.quest==s.quest,"save round-trip preserves inventory wounds doors enemies quest")
	check(not loaded.interact("board") and loaded.player.coins==124,"reward remains claimed after load")
	var before := loaded.snapshot()
	check(not loaded.restore({"version":999}) and loaded.snapshot()==before,"incompatible save rejected atomically")
	var bad := before.duplicate(true)
	bad.player.erase("hp")
	check(not loaded.restore(bad) and loaded.snapshot()==before,"missing required player state rejected")
	for key in ["turn", "seed", "dead", "won", "rng_state", "version"]:
		bad = before.duplicate(true)
		bad.turn = 99
		bad[key] = {}
		check(not loaded.restore(bad) and loaded.snapshot()==before,"corrupt scalar rejected atomically: " + key)
	bad = before.duplicate(true)
	bad.maps.village.objects[0].id = "fake_cache"
	check(not loaded.restore(bad) and loaded.snapshot()==before,"unknown object ID rejected atomically")
	var corrupt := FileAccess.open("user://bad.json",FileAccess.WRITE)
	corrupt.store_string("{broken file")
	corrupt.close()
	check(not loaded.load_game("user://bad.json") and loaded.snapshot()==before,"malformed JSON does not replace current game")
	loaded.dead=true
	check(not loaded.save_game(path),"death cannot overwrite a good save")
	check(loaded.load_game(path) and not loaded.dead,"load after death restores live checkpoint")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("user://bad.json")

func _test_world_and_replay() -> void:
	var s := fresh()
	for map_id in s.maps:
		s.area=map_id
		for o in s.maps[map_id].objects:
			check(s.tile_at(Vector2i(o.x,o.y)) not in ["#","T","R","~"],"object on reachable terrain: "+map_id+"/"+o.id)
		for a in s.maps[map_id].actors:
			check(s.passable(Vector2i(a.x,a.y)),"enemy on passable tile: "+map_id+"/"+a.kind)
	s=arena("")
	s.maps.road.tiles[10][12]="#"
	check(not s.line_of_sight(Vector2i(10,10),Vector2i(14,10)),"walls block line of sight")
	check(s.line_of_sight(Vector2i(10,10),Vector2i(12,10)),"wall face itself remains visible")
	s = fresh()
	s.area = "road"
	s.player.x = 24
	s.player.y = 2
	s.maps.road.actors[0].x = 23
	s.maps.road.actors[0].y = 3
	s.command("move",Vector2i.DOWN)
	s.command("move",Vector2i.LEFT)
	check(s.area == "road" and s.actor_at(s.position()).is_empty(),"occupied return point chooses a free arrival tile")
	s = fresh()
	s.area = "ruin"
	var symmetric := true
	for y in State.HEIGHT:
		for x in State.WIDTH:
			var from := Vector2i(x,y)
			if not s.passable(from):
				continue
			for oy in range(-5,6):
				for ox in range(-5,6):
					var to := from + Vector2i(ox,oy)
					if s.passable(to) and s.line_of_sight(from,to) != s.line_of_sight(to,from):
						symmetric = false
	check(symmetric,"ruin sight lines are symmetric at all nearby passable tile pairs")
	var a := arena()
	var b := arena()
	for action in ["guard","wait","power","wait","move","wait"]:
		var target := Vector2i(11,10) if action=="power" else Vector2i.RIGHT
		a.command(action,target)
		b.command(action,target)
	check(a.snapshot()==b.snapshot(),"identical initial state and commands replay deterministically")

func _test_full_adventure() -> void:
	var s := fresh()
	check(s.interact("board"),"full loop: accept contract")
	check(walk_to(s,Vector2i(24,9)),"full loop: leave village")
	check(s.area=="road","full loop: road entered")
	check(walk_to(s,Vector2i(24,3)),"full loop: travel old road")
	check(s.area=="ruin","full loop: dungeon entered")
	check(walk_to(s,Vector2i(5,15)) and s.interact("entry_cache"),"full loop: collect starting cache")
	check(walk_to(s,Vector2i(2,3)) and s.interact("blade_cache"),"full loop: reach northern room and sword")
	check(s.use_item("fine_sword"),"full loop: equip recovered sword")
	check(walk_to(s,Vector2i(22,15)) and s.interact("mail_cache"),"full loop: explore southern rooms and armor")
	check(s.use_item("mail"),"full loop: equip recovered armor")
	check(walk_to(s,Vector2i(23,3)),"full loop: reach final chamber alive")
	# Chase the Warden if it has moved while approaching the relic.
	for i in 30:
		var boss: Dictionary = {}
		for actor in s.maps.ruin.actors:
			if actor.kind=="warden" and int(actor.hp)>0:
				boss=actor
		if boss.is_empty() or s.dead:
			break
		walk_to(s,Vector2i(boss.x,boss.y),1)
	check(walk_to(s,Vector2i(23,3)) and s.interact("reliquary"),"full loop: defeat warden and recover bell")
	check(walk_to(s,Vector2i(1,14)) and s.area=="road","full loop: leave dungeon")
	check(walk_to(s,Vector2i(0,9)) and s.area=="village","full loop: return to village")
	check(walk_to(s,Vector2i(12,9)) and s.interact("board"),"full loop: claim reward")
	check(s.won and not s.dead and s.quest=="complete","full loop: complete adventure alive")
	check(walk_to(s,Vector2i(7,9)) and s.rest(),"full loop: rest after return")
	print("FULL ADVENTURE: turns=%d hp=%d coins=%d rank=%d"%[s.turn,s.player.hp,s.player.coins,s.player.level])
	if s.dead:
		for line in s.logs:
			print(line)

func _test_direct_adventure() -> void:
	# A player who follows only the contract is not required to find optional upgrades.
	var s := fresh()
	s.interact("board")
	walk_to(s,Vector2i(24,9))
	walk_to(s,Vector2i(24,3))
	walk_to(s,Vector2i(23,3))
	for i in 30:
		var boss: Dictionary = {}
		for actor in s.maps.ruin.actors:
			if actor.kind == "warden" and int(actor.hp) > 0:
				boss = actor
		if boss.is_empty() or s.dead:
			break
		walk_to(s,Vector2i(boss.x,boss.y),1)
	walk_to(s,Vector2i(23,3))
	s.interact("reliquary")
	walk_to(s,Vector2i(1,14))
	walk_to(s,Vector2i(0,9))
	walk_to(s,Vector2i(12,9))
	s.interact("board")
	check(s.won and not s.dead,"direct contract route is survivable without purchases or optional caches")
	check(s.player.weapon == "sword" and s.player.armor == "leather","direct route uses only starting equipment")
	print("DIRECT ADVENTURE: turns=%d hp=%d rank=%d" % [s.turn,s.player.hp,s.player.level])

func walk_to(s: RunState, goal: Vector2i, maximum: int = 600) -> bool:
	var original_area := s.area
	for i in maximum:
		if s.dead:
			return false
		if s.position()==goal or s.area!=original_area:
			return true
		if int(s.player.bleed)>0 and s.player.inventory.has("bandage"):
			s.use_item("bandage")
			continue
		if int(s.player.injury)>0 and s.player.inventory.has("splint"):
			s.use_item("splint")
			continue
		if int(s.player.hp)<s.max_hp()-25 and s.player.inventory.has("tonic"):
			s.use_item("tonic")
			continue
		var adjacent: Dictionary = {}
		for d in State.DIRS:
			var enemy: Dictionary=s.actor_at(s.position()+d)
			if not enemy.is_empty():
				adjacent=enemy
				break
		if not adjacent.is_empty():
			var ap := Vector2i(adjacent.x,adjacent.y)
			if int(s.player.cooldowns.power)==0 and int(s.player.energy)>=7:
				s.command("power",ap)
			elif adjacent.windup and adjacent.kind=="warden" and int(s.player.cooldowns.guard)==0 and int(s.player.energy)>=4:
				s.command("guard")
			else:
				s.command("move",ap-s.position())
			continue
		var step := navigation_step(s,goal)
		if step==s.position():
			return false
		if not s.command("move",step-s.position()):
			return false
	return s.position()==goal or s.area!=original_area

func navigation_step(s: RunState, goal: Vector2i) -> Vector2i:
	var start := s.position()
	var queue: Array[Vector2i]=[start]
	var came := {start:start}
	var cursor:=0
	while cursor<queue.size():
		var p:Vector2i=queue[cursor]
		cursor+=1
		if p==goal:
			var step:=goal
			while came[step]!=start:
				step=came[step]
			return step
		for d in State.DIRS:
			var n:Vector2i=p+d
			if came.has(n) or s.tile_at(n) in ["#","T","~","R"]:
				continue
			var obj:Dictionary=s.object_at(n)
			if not obj.is_empty() and (not obj.id.begins_with("exit_") or n!=goal):
				continue
			came[n]=p
			queue.append(n)
	return start
