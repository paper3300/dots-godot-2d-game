extends RefCounted
class_name RunState
## Pure turn-based rules. Rendering and input never advance time directly.

const WIDTH := 26
const HEIGHT := 18
const SAVE_VERSION := 1
const PACK_CAPACITY := 8
const SAVE_PATH := "user://briar_and_bone_save.json"
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const ITEMS := {
	"bandage": {"en": "Linen bandage", "ko": "아마포 붕대", "price": 8, "kind": "use"},
	"splint": {"en": "Herbal poultice", "ko": "약초 찜질약", "price": 12, "kind": "use"},
	"ration": {"en": "Trail ration", "ko": "여행 식량", "price": 6, "kind": "use"},
	"water": {"en": "Water flask", "ko": "물병", "price": 4, "kind": "use"},
	"tonic": {"en": "Restoring tonic", "ko": "회복 물약", "price": 16, "kind": "use"},
	"sword": {"en": "Weathered sword", "ko": "낡은 검", "price": 18, "kind": "weapon", "power": 8},
	"fine_sword": {"en": "Warden's sword", "ko": "파수꾼의 검", "price": 45, "kind": "weapon", "power": 12},
	"leather": {"en": "Leather coat", "ko": "가죽 외투", "price": 18, "kind": "armor", "armor": 2},
	"mail": {"en": "Riveted mail", "ko": "사슬 갑옷", "price": 48, "kind": "armor", "armor": 4},
	"scrap": {"en": "Bronze scrap", "ko": "청동 조각", "price": 8, "kind": "sell"},
	"gem": {"en": "Smoky amber", "ko": "연기빛 호박", "price": 20, "kind": "sell"},
	"bell": {"en": "The briar bell", "ko": "가시나무 종", "price": 0, "kind": "quest"}
}
var language := "ko"
var area := "village"
var maps: Dictionary = {}
var player: Dictionary = {}
var quest := "available"
var turn := 0
var dead := false
var won := false
var logs: Array = []
var visible: Dictionary = {}
var last_events: Array = []
var rng := RandomNumberGenerator.new()
var seed_value := 73021

func tr_text(en: String, ko: String) -> String:
	return ko if language == "ko" else en

func item_name(id: String) -> String:
	return str(ITEMS.get(id, {"en": id, "ko": id})[language])

func actor_name(id: String) -> String:
	var names := {"wolf": ["Briar wolf", "가시숲 늑대"], "raider": ["Grave robber", "도굴꾼"], "archer": ["Bowman", "궁수"], "warden": ["Hollow Warden", "공허의 파수꾼"]}
	return str(names.get(id, [id, id])[1 if language == "ko" else 0])

func area_name() -> String:
	return {"village": tr_text("BRIARHAVEN", "가시나루 마을"), "road": tr_text("THE OLD ROAD", "오래된 숲길"), "ruin": tr_text("THE SUNKEN PRIORY", "가라앉은 수도원")}[area]

func new_game(seed_number: int = 73021) -> void:
	seed_value = seed_number
	rng.seed = seed_number
	area = "village"
	quest = "available"
	turn = 0
	dead = false
	won = false
	logs.clear()
	last_events.clear()
	player = {"x": 12, "y": 9, "hp": 64, "energy": 30, "bleed": 0, "injury": 0, "pain": 0, "hunger": 0, "thirst": 0, "coins": 34, "level": 1, "xp": 0, "weapon": "sword", "armor": "leather", "guard": 0, "cooldowns": {"power": 0, "guard": 0, "dash": 0}, "inventory": {"bandage": 4, "splint": 2, "ration": 3, "water": 3, "tonic": 2}}
	_build_maps()
	_reveal()
	log_text("You arrive at Briarhaven. Read the contract board beside you [E].", "가시나루에 도착했다. 바로 옆 의뢰 게시판을 살펴보자 [E].")

func position() -> Vector2i:
	return Vector2i(int(player.x), int(player.y))

func max_hp() -> int:
	return 64 + (int(player.level) - 1) * 6 - int(player.injury) * 6

func max_energy() -> int:
	return 30 + (int(player.level) - 1) * 3

func attack_power() -> int:
	return int(ITEMS[player.weapon].power) + int(player.level) - 1

func armor_value() -> int:
	return int(ITEMS[player.armor].armor)

func tile_at(p: Vector2i, map_id: String = "") -> String:
	if p.x < 0 or p.y < 0 or p.x >= WIDTH or p.y >= HEIGHT:
		return "#"
	var m: Dictionary = maps[area if map_id.is_empty() else map_id]
	return m.tiles[p.y][p.x]

func passable(p: Vector2i) -> bool:
	return tile_at(p) not in ["#", "T", "~", "R", "+"]

func _empty_map(fill: String) -> Dictionary:
	var tiles: Array = []
	for y in HEIGHT:
		var row: Array = []
		for x in WIDTH:
			row.append(fill)
		tiles.append(row)
	return {"tiles": tiles, "actors": [], "objects": [], "revealed": {}, "loot": []}

func _rect(m: Dictionary, r: Rect2i, t: String) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			m.tiles[y][x] = t

func _object(m: Dictionary, id: String, p: Vector2i, label: String) -> void:
	m.objects.append({"id": id, "x": p.x, "y": p.y, "label": label, "used": false})

func _enemy(m: Dictionary, kind: String, p: Vector2i) -> void:
	var data: Array = {"wolf": [16, 5, 8], "raider": [24, 7, 12], "archer": [19, 5, 12], "warden": [56, 10, 36]}[kind]
	m.actors.append({"kind": kind, "x": p.x, "y": p.y, "hp": data[0], "max_hp": data[0], "damage": data[1], "xp": data[2], "alert": false, "windup": false, "stun": 0, "turns": 0})

func _build_maps() -> void:
	maps.clear()
	var v := _empty_map("g")
	_rect(v, Rect2i(0, 0, WIDTH, 1), "T")
	_rect(v, Rect2i(0, 17, WIDTH, 1), "T")
	_rect(v, Rect2i(0, 0, 1, HEIGHT), "T")
	_rect(v, Rect2i(25, 0, 1, HEIGHT), "T")
	_rect(v, Rect2i(1, 9, 25, 2), ".")
	_rect(v, Rect2i(11, 3, 3, 14), ".")
	_rect(v, Rect2i(3, 3, 6, 4), "R")
	_rect(v, Rect2i(16, 3, 6, 4), "R")
	_rect(v, Rect2i(3, 13, 6, 3), "R")
	_rect(v, Rect2i(17, 13, 6, 3), "R")
	for p in [Vector2i(2, 2), Vector2i(10, 2), Vector2i(23, 2), Vector2i(2, 12), Vector2i(15, 15), Vector2i(23, 12)]:
		v.tiles[p.y][p.x] = "T"
	_object(v, "board", Vector2i(12, 8), "contract")
	_object(v, "inn", Vector2i(7, 8), "inn")
	_object(v, "shop", Vector2i(18, 8), "shop")
	_object(v, "well", Vector2i(12, 12), "well")
	_object(v, "exit_road", Vector2i(24, 9), "exit")
	maps.village = v
	var r := _empty_map("g")
	for y in HEIGHT:
		for x in WIDTH:
			if y == 0 or y == HEIGHT - 1 or x == 0 or x == WIDTH - 1 or (x * 19 + y * 31) % 13 < 3:
				r.tiles[y][x] = "T"
	_rect(r, Rect2i(0, 8, 12, 3), ".")
	_rect(r, Rect2i(10, 2, 3, 8), ".")
	_rect(r, Rect2i(11, 2, 14, 3), ".")
	_rect(r, Rect2i(17, 8, 2, 9), "~")
	_rect(r, Rect2i(12, 10, 12, 2), ".")
	_rect(r, Rect2i(19, 10, 6, 6), "g")
	_rect(r, Rect2i(22, 11, 2, 4), ".")
	_object(r, "exit_village", Vector2i(0, 9), "exit")
	_object(r, "exit_ruin", Vector2i(24, 3), "exit")
	_object(r, "road_cache", Vector2i(23, 13), "chest")
	for p in [Vector2i(7, 8), Vector2i(11, 5), Vector2i(20, 3)]:
		_enemy(r, "wolf", p)
	_enemy(r, "raider", Vector2i(21, 12))
	maps.road = r
	var d := _empty_map("#")
	for rect in [Rect2i(1, 1, 7, 6), Rect2i(10, 1, 6, 6), Rect2i(18, 1, 7, 6), Rect2i(1, 10, 7, 7), Rect2i(10, 10, 6, 7), Rect2i(18, 10, 7, 7)]:
		_rect(d, rect, "d")
	for x in [4, 13, 21]:
		_rect(d, Rect2i(x, 6, 1, 5), "d")
	for y in [3, 13]:
		_rect(d, Rect2i(7, y, 12, 1), "d")
	for p in [Vector2i(4, 8), Vector2i(13, 8), Vector2i(21, 8), Vector2i(8, 3), Vector2i(16, 3), Vector2i(8, 13), Vector2i(16, 13)]:
		d.tiles[p.y][p.x] = "+"
	_object(d, "exit_road", Vector2i(1, 14), "stairs")
	_object(d, "entry_cache", Vector2i(6, 15), "chest")
	_object(d, "blade_cache", Vector2i(2, 2), "chest")
	_object(d, "mail_cache", Vector2i(23, 15), "chest")
	_object(d, "reliquary", Vector2i(23, 2), "reliquary")
	_enemy(d, "raider", Vector2i(12, 13))
	_enemy(d, "archer", Vector2i(6, 3))
	_enemy(d, "raider", Vector2i(12, 4))
	_enemy(d, "archer", Vector2i(20, 13))
	_enemy(d, "warden", Vector2i(21, 4))
	maps.ruin = d

func actor_at(p: Vector2i) -> Dictionary:
	for a in maps[area].actors:
		if int(a.hp) > 0 and Vector2i(int(a.x), int(a.y)) == p:
			return a
	return {}

func object_at(p: Vector2i) -> Dictionary:
	for o in maps[area].objects:
		if Vector2i(int(o.x), int(o.y)) == p:
			return o
	return {}

func near_object(id: String) -> bool:
	for o in maps[area].objects:
		if o.id == id and position().distance_to(Vector2i(int(o.x), int(o.y))) <= 1.01:
			return true
	return false

func nearest_object() -> Dictionary:
	for o in maps[area].objects:
		if position().distance_to(Vector2i(int(o.x), int(o.y))) <= 1.01 and not o.id.begins_with("exit_"):
			return o
	return {}

func command(action: String, target: Vector2i = Vector2i.ZERO) -> bool:
	last_events.clear()
	if dead:
		return false
	var performed := false
	var used_skill := ""
	match action:
		"move":
			if absi(target.x) + absi(target.y) != 1:
				return false
			var dest := position() + target
			var actor := actor_at(dest)
			if not actor.is_empty():
				_player_hit(actor, attack_power(), "attack")
				performed = true
			elif tile_at(dest) == "+":
				maps[area].tiles[dest.y][dest.x] = "d"
				log_text("You ease the door open.", "문을 조심스럽게 열었다.")
				performed = true
			elif passable(dest):
				var obj := object_at(dest)
				if not obj.is_empty() and not obj.id.begins_with("exit_"):
					return false
				player.x = dest.x
				player.y = dest.y
				performed = true
				if not obj.is_empty() and obj.id.begins_with("exit_"):
					_travel(str(obj.id))
				_pickup_coins()
		"wait":
			player.energy = mini(max_energy(), int(player.energy) + 3)
			performed = true
		"power":
			if not _skill_ready("power", 7):
				return false
			var actor := actor_at(target)
			if actor.is_empty() or _distance(position(), target) != 1:
				log_text("Choose an adjacent enemy for Hew.", "인접한 적을 선택해 내려베기를 사용하자.")
				return false
			player.energy -= 7
			_player_hit(actor, attack_power() + 7, "power")
			actor.stun = 1
			player.cooldowns.power = 4
			used_skill = "power"
			performed = true
		"guard":
			if not _skill_ready("guard", 4):
				return false
			player.energy -= 4
			player.guard = 2
			player.cooldowns.guard = 4
			log_text("Shield raised. Strong protection for two turns.", "방패를 들었다. 두 턴 동안 피해를 크게 줄인다.")
			used_skill = "guard"
			performed = true
		"dash":
			if not _skill_ready("dash", 5):
				return false
			var delta := target - position()
			if (delta.x != 0 and delta.y != 0) or _distance(position(), target) != 2:
				log_text("Choose a clear tile exactly two steps away.", "직선으로 두 칸 떨어진 빈 공간을 선택하자.")
				return false
			var mid := position() + Vector2i(signi(delta.x), signi(delta.y))
			if not passable(mid) or not passable(target) or not actor_at(mid).is_empty() or not actor_at(target).is_empty() or not object_at(mid).is_empty() or not object_at(target).is_empty():
				return false
			player.x = target.x
			player.y = target.y
			player.energy -= 5
			player.cooldowns.dash = 4
			used_skill = "dash"
			performed = true
		"loot":
			performed = _loot_ground()
	if performed:
		_finish_turn(used_skill)
	return performed

func _skill_ready(id: String, cost: int) -> bool:
	if int(player.cooldowns[id]) > 0:
		log_text("That skill is still recovering.", "아직 기술을 다시 사용할 수 없다.")
		return false
	if int(player.energy) < cost:
		log_text("Not enough energy. Wait to recover.", "기력이 부족하다. 대기하며 기력을 회복하자.")
		return false
	return true

func _player_hit(actor: Dictionary, damage: int, kind: String) -> void:
	actor.hp = maxi(0, int(actor.hp) - damage)
	actor.alert = true
	last_events.append({"type": kind, "x": actor.x, "y": actor.y, "amount": damage})
	log_text("You strike %s for %d." % [actor_name(actor.kind), damage], "%s에게 %d 피해를 입혔다." % [actor_name(actor.kind), damage])
	if int(actor.hp) <= 0:
		player.xp += int(actor.xp)
		var drops := {"scrap": 1}
		if actor.kind == "wolf":
			drops = {"ration": 1}
		elif actor.kind == "warden":
			drops = {"gem": 2, "tonic": 1}
		maps[area].loot.append({"x": actor.x, "y": actor.y, "coins": 5 if actor.kind == "wolf" else 10, "items": drops})
		log_text("%s falls. Spoils lie on the ground [G]." % actor_name(actor.kind), "%s 처치. 바닥에 전리품이 남았다 [G]." % actor_name(actor.kind))
		if int(player.xp) >= int(player.level) * 30 and int(player.level) < 4:
			player.xp -= int(player.level) * 30
			player.level += 1
			player.hp = mini(max_hp(), int(player.hp) + 12)
			player.energy = max_energy()
			log_text("Resolve grows. Rank %d: health and strength increased." % player.level, "각오가 단단해졌다. 등급 %d: 체력과 공격력 증가." % player.level)

func _finish_turn(used_skill: String = "") -> void:
	turn += 1
	player.hunger = mini(100, int(player.hunger) + (1 if turn % 6 == 0 else 0))
	player.thirst = mini(100, int(player.thirst) + (1 if turn % 4 == 0 else 0))
	if int(player.bleed) > 0:
		player.hp -= 1
		player.bleed -= 1
		last_events.append({"type": "bleed", "x": player.x, "y": player.y, "amount": 1})
	if int(player.hunger) >= 85 or int(player.thirst) >= 85:
		if turn % 4 == 0:
			player.hp -= 1
			log_text("Your body needs food and water.", "몸에 식량과 물이 필요하다.")
	if int(player.hp) <= 0:
		_die()
		return
	if area != "village":
		_enemy_turns()
	if dead:
		return
	for skill in player.cooldowns:
		if skill != used_skill:
			player.cooldowns[skill] = maxi(0, int(player.cooldowns[skill]) - 1)
	player.guard = maxi(0, int(player.guard) - 1)
	if used_skill.is_empty():
		player.energy = mini(max_energy(), int(player.energy) + (1 if int(player.pain) < 50 else 0))
	if turn % 5 == 0:
		player.pain = maxi(0, int(player.pain) - 1)
	_reveal()

func _enemy_turns() -> void:
	for actor in maps[area].actors:
		if int(actor.hp) <= 0 or dead:
			continue
		var ap := Vector2i(int(actor.x), int(actor.y))
		var distance := _distance(ap, position())
		var sees := distance <= 7 and line_of_sight(ap, position())
		if sees:
			actor.alert = true
		if not actor.alert:
			continue
		actor.turns += 1
		if int(actor.stun) > 0:
			actor.stun -= 1
			actor.windup = false
			continue
		if actor.kind == "warden" and actor.windup:
			actor.windup = false
			if distance <= 1:
				_enemy_hit(actor, int(actor.damage) + 6, true)
			else:
				log_text("The Warden's heavy blow hits empty stone.", "파수꾼의 강타가 빈 돌바닥을 내리쳤다.")
			continue
		if actor.kind == "warden" and distance == 1 and int(actor.turns) % 3 == 1:
			actor.windup = true
			log_text("The Warden raises its axe! Step away or use Hew.", "파수꾼이 도끼를 치켜든다! 피하거나 내려베기로 저지하자.")
			last_events.append({"type": "warn", "x": actor.x, "y": actor.y, "amount": 0})
			continue
		if actor.kind == "archer" and sees and distance >= 2 and distance <= 5:
			if actor.windup:
				actor.windup = false
				_enemy_hit(actor, int(actor.damage), false)
			else:
				actor.windup = true
				log_text("A bowman draws. Break line of sight or close in.", "궁수가 활시위를 당긴다. 시야를 벗어나거나 접근하자.")
			continue
		actor.windup = false
		if distance == 1:
			_enemy_hit(actor, int(actor.damage), false)
		else:
			var step := _path_step(ap, position())
			if step != ap and step != position() and actor_at(step).is_empty():
				actor.x = step.x
				actor.y = step.y

func _enemy_hit(actor: Dictionary, raw_damage: int, heavy: bool) -> void:
	var damage := maxi(1, raw_damage - armor_value() - (6 if int(player.guard) > 0 else 0))
	player.hp -= damage
	player.pain = mini(100, int(player.pain) + damage * 2)
	last_events.append({"type": "hurt", "x": player.x, "y": player.y, "amount": damage})
	log_text("%s hits you for %d." % [actor_name(actor.kind), damage], "%s에게 %d 피해를 입었다." % [actor_name(actor.kind), damage])
	if int(player.guard) == 0 and damage >= 3 and (int(actor.turns) % 4 == 0 or heavy):
		player.bleed = mini(12, int(player.bleed) + 5)
		log_text("Bleeding! A bandage will stop it [B].", "출혈! 붕대로 지혈하자 [B].")
	if heavy and int(player.guard) == 0 and int(player.injury) < 3:
		player.injury += 1
		player.hp = mini(max_hp(), int(player.hp))
		log_text("A deep injury limits your health. Use a poultice.", "깊은 부상으로 최대 체력이 줄었다. 찜질약이 필요하다.")
	if int(player.hp) <= 0:
		_die()

func _die() -> void:
	player.hp = 0
	dead = true
	log_text("Your journey ends here. Load a save or begin again.", "여정이 끝났다. 저장을 불러오거나 다시 시작하자.")

func _travel(id: String) -> void:
	var next := ""
	var destination := Vector2i.ZERO
	if area == "village" and id == "exit_road":
		next = "road"
		destination = Vector2i(1, 9)
	elif area == "road" and id == "exit_village":
		next = "village"
		destination = Vector2i(23, 9)
	elif area == "road" and id == "exit_ruin":
		next = "ruin"
		destination = Vector2i(2, 14)
	elif area == "ruin" and id == "exit_road":
		next = "road"
		destination = Vector2i(23, 3)
	if next.is_empty():
		return
	area = next
	destination = _safe_arrival(destination)
	player.x = destination.x
	player.y = destination.y
	log_text("You enter %s." % area_name(), "%s에 들어섰다." % area_name())
	last_events.append({"type": "travel", "x": player.x, "y": player.y, "amount": 0})

func _safe_arrival(preferred: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [preferred]
	var seen := {preferred: true}
	var index := 0
	while index < queue.size():
		var p: Vector2i = queue[index]
		index += 1
		if passable(p) and actor_at(p).is_empty() and object_at(p).is_empty():
			return p
		for direction in DIRS:
			var n: Vector2i = p + direction
			if not seen.has(n) and passable(n):
				seen[n] = true
				queue.append(n)
	return preferred

func ordered_inventory() -> Array:
	var result: Array = []
	for id in ITEMS:
		if player.inventory.has(id):
			result.append(id)
	return result

func interact(id: String) -> bool:
	last_events.clear()
	if dead or not near_object(id):
		return false
	match id:
		"board":
			if quest == "available":
				quest = "active"
				log_text("Contract accepted: recover the briar bell from the Sunken Priory. Reward: 90 crowns.", "의뢰 수락: 가라앉은 수도원에서 가시나무 종을 회수하자. 보수: 90 크라운.")
				return true
			if quest == "recovered":
				quest = "complete"
				player.inventory.erase("bell")
				player.coins += 90
				won = true
				log_text("Contract fulfilled. The bell rings again. You earned 90 crowns.", "의뢰 완료. 종이 다시 울린다. 보수 90 크라운을 받았다.")
				return true
			return false
		"well":
			if int(player.thirst) == 0 and int(player.inventory.get("water", 0)) >= 3:
				log_text("Your flasks are full (3) and you are not thirsty.", "물병이 가득 찼고 (3개) 갈증도 없다.")
				return false
			var was_thirsty := int(player.thirst) > 0
			var filled := false
			if int(player.inventory.get("water", 0)) < 3:
				filled = add_item("water", 1)
			if not filled and not was_thirsty:
				return false
			player.thirst = 0
			if filled:
				log_text("Cool well water. Thirst relieved; a flask refilled (up to 3).", "시원한 우물물. 갈증이 사라지고 물병을 채웠다 (최대 3개).")
			else:
				log_text("You drink cool well water. Thirst relieved.", "시원한 우물물을 마셨다. 갈증이 사라졌다.")
			_finish_turn()
			return true
		"reliquary":
			if quest == "available":
				log_text("A village seal. Accept the contract before taking the bell.", "마을의 봉인이다. 의뢰를 수락한 뒤 종을 가져가자.")
				return false
			for actor in maps.ruin.actors:
				if actor.kind == "warden" and int(actor.hp) > 0:
					log_text("The Warden still guards the bell.", "파수꾼이 아직 종을 지키고 있다.")
					return false
			if quest == "active":
				# Quest items never compete for pack capacity.
				player.inventory.bell = 1
				quest = "recovered"
				log_text("The briar bell is yours. Return to the village board.", "가시나무 종을 회수했다. 마을 게시판으로 돌아가자.")
				_finish_turn()
				return true
		_:
			if id.ends_with("cache"):
				for o in maps[area].objects:
					if o.id == id and not o.used:
						var rewards: Dictionary = {"road_cache": {"gem": 1, "bandage": 2}, "entry_cache": {"tonic": 1, "bandage": 2}, "blade_cache": {"fine_sword": 1}, "mail_cache": {"mail": 1}}[id]
						maps[area].loot.append({"x": o.x, "y": o.y, "coins": 0, "items": rewards.duplicate(true)})
						o.used = true
						_loot_ground()
						log_text("You open the cache. Supplies recovered.", "보급함을 열어 물품을 챙겼다.")
						_finish_turn()
						return true
				return _loot_near_cache(id)
	return false

func _loot_near_cache(_id: String) -> bool:
	if _loot_ground():
		_finish_turn()
		return true
	return false

func pack_slots() -> int:
	var count := 0
	for id in player.inventory:
		if ITEMS[id].kind != "quest":
			count += 1
	return count

func add_item(id: String, amount: int = 1) -> bool:
	if not player.inventory.has(id) and pack_slots() >= PACK_CAPACITY and ITEMS[id].kind != "quest":
		log_text("Your pack is full. Use or sell an item first.", "배낭이 가득 찼다. 물건을 사용하거나 판매하자.")
		return false
	player.inventory[id] = int(player.inventory.get(id, 0)) + amount
	return true

func _pickup_coins() -> void:
	for loot in maps[area].loot:
		if Vector2i(int(loot.x), int(loot.y)) == position() and int(loot.coins) > 0:
			player.coins += int(loot.coins)
			log_text("Picked up %d crowns." % loot.coins, "%d 크라운을 주웠다." % loot.coins)
			loot.coins = 0

func _loot_ground() -> bool:
	var found := false
	for loot in maps[area].loot:
		if _distance(position(), Vector2i(int(loot.x), int(loot.y))) > 1:
			continue
		if int(loot.coins) > 0:
			player.coins += int(loot.coins)
			loot.coins = 0
			found = true
		var ids: Array = loot.items.keys()
		ids.sort()
		for id in ids:
			if add_item(str(id), int(loot.items[id])):
				log_text("Collected %s x%d." % [item_name(id), loot.items[id]], "%s %d개 획득." % [item_name(id), loot.items[id]])
				loot.items.erase(id)
				found = true
	if not found:
		log_text("No reachable loot. Stand beside a dropped pack.", "주울 전리품이 없다. 전리품 바로 옆으로 이동하자.")
	return found

func use_item(id: String) -> bool:
	last_events.clear()
	if dead or not player.inventory.has(id):
		return false
	var item: Dictionary = ITEMS[id]
	if item.kind == "quest" or item.kind == "sell":
		return false
	if item.kind == "weapon" or item.kind == "armor":
		var slot := "weapon" if item.kind == "weapon" else "armor"
		var old: String = player[slot]
		if old == id:
			return false
		if int(player.inventory[id]) > 1 and not player.inventory.has(old) and pack_slots() >= PACK_CAPACITY:
			log_text("No room to store your old equipment.", "기존 장비를 넣을 공간이 없다.")
			return false
		_consume(id)
		player[slot] = id
		# Replacing an occupied stack may free a slot; equipment swaps must never lose the old item.
		player.inventory[old] = int(player.inventory.get(old, 0)) + 1
		log_text("Equipped %s." % item_name(id), "%s 장착." % item_name(id))
	else:
		match id:
			"bandage":
				if int(player.bleed) == 0 and int(player.hp) >= max_hp():
					return false
				player.bleed = 0
				player.hp = mini(max_hp(), int(player.hp) + 5)
			"splint":
				if int(player.injury) == 0 and int(player.pain) == 0:
					return false
				player.injury = maxi(0, int(player.injury) - 1)
				player.pain = maxi(0, int(player.pain) - 35)
			"tonic":
				if int(player.hp) >= max_hp():
					return false
				player.hp = mini(max_hp(), int(player.hp) + 25)
			"ration":
				if int(player.hunger) == 0 and int(player.hp) >= max_hp():
					return false
				player.hunger = maxi(0, int(player.hunger) - 45)
				player.hp = mini(max_hp(), int(player.hp) + 4)
			"water":
				if int(player.thirst) == 0 and int(player.energy) >= max_energy():
					return false
				player.thirst = maxi(0, int(player.thirst) - 50)
				player.energy = mini(max_energy(), int(player.energy) + 10)
		_consume(id)
		log_text("Used %s." % item_name(id), "%s 사용." % item_name(id))
	_finish_turn()
	return true

func _consume(id: String) -> void:
	player.inventory[id] -= 1
	if int(player.inventory[id]) <= 0:
		player.inventory.erase(id)

func buy(id: String) -> bool:
	if dead or not near_object("shop") or not ITEMS.has(id):
		return false
	var price := int(ITEMS[id].price)
	if int(player.coins) < price or ITEMS[id].kind in ["quest", "sell"]:
		return false
	if not add_item(id):
		return false
	player.coins -= price
	log_text("Bought %s for %d crowns." % [item_name(id), price], "%s 구매: %d 크라운." % [item_name(id), price])
	return true

func sell(id: String) -> bool:
	if dead or not near_object("shop") or not player.inventory.has(id) or ITEMS[id].kind == "quest" or id == "water":
		return false
	var price := maxi(1, int(ITEMS[id].price) / 2)
	_consume(id)
	player.coins += price
	log_text("Sold %s for %d crowns." % [item_name(id), price], "%s 판매: %d 크라운." % [item_name(id), price])
	return true

func rest() -> bool:
	if dead or not near_object("inn"):
		return false
	# One free bed after the completed contract prevents a recovery softlock.
	var cost := 0 if won else 10
	if int(player.coins) < cost:
		return false
	player.coins -= cost
	player.injury = 0
	player.bleed = 0
	player.pain = 0
	player.hp = max_hp()
	player.energy = max_energy()
	player.hunger = 0
	player.thirst = 0
	player.guard = 0
	for key in player.cooldowns:
		player.cooldowns[key] = 0
	turn += 30
	log_text("A quiet night's rest. All wounds treated.", "고요한 밤, 상처를 모두 치료했다.")
	return true

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _path_step(start: Vector2i, goal: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var came := {start: start}
	var cursor := 0
	while cursor < queue.size() and cursor < WIDTH * HEIGHT:
		var p: Vector2i = queue[cursor]
		cursor += 1
		if p == goal:
			var step := goal
			while came[step] != start:
				step = came[step]
			return step
		for dir in DIRS:
			var n: Vector2i = p + dir
			if came.has(n) or not passable(n):
				continue
			var obj := object_at(n)
			if not obj.is_empty() and not obj.id.begins_with("exit_"):
				continue
			if n != goal and not actor_at(n).is_empty():
				continue
			came[n] = p
			queue.append(n)
	return start

func line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	# Reciprocal traces prevent Bresenham tie cases from creating one-way vision.
	return _line_trace(a, b) and _line_trace(b, a)

func _line_trace(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - x)
	var sx := 1 if x < b.x else -1
	var dy := -absi(b.y - y)
	var sy := 1 if y < b.y else -1
	var error := dx + dy
	while true:
		if Vector2i(x, y) != a and Vector2i(x, y) != b and tile_at(Vector2i(x, y)) in ["#", "T", "R", "+"]:
			return false
		if x == b.x and y == b.y:
			return true
		var doubled := 2 * error
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy
	return true

func _reveal() -> void:
	visible.clear()
	for y in HEIGHT:
		for x in WIDTH:
			var p := Vector2i(x, y)
			if area == "village" or (position().distance_to(p) <= (9 if area == "road" else 7) and line_of_sight(position(), p)):
				visible[_key(p)] = true
				maps[area].revealed[_key(p)] = true

func _key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]

func is_visible(p: Vector2i) -> bool:
	return visible.has(_key(p))

func is_revealed(p: Vector2i) -> bool:
	return maps[area].revealed.has(_key(p))

func log_text(en: String, ko: String) -> void:
	logs.append(tr_text(en, ko))
	if logs.size() > 80:
		logs.pop_front()

func snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "area": area, "maps": maps.duplicate(true), "player": player.duplicate(true), "quest": quest, "turn": turn, "dead": dead, "won": won, "logs": logs.duplicate(), "language": language, "seed": seed_value, "rng_state": str(rng.state)}

func restore(data: Dictionary) -> bool:
	# Validate before touching a live run. Corrupt or incompatible saves cannot partially replace state.
	if not _is_number(data.get("version")) or int(data.version) != SAVE_VERSION or not data.get("area", "") in ["village", "road", "ruin"]:
		return false
	for key in ["turn", "seed"]:
		if not _is_number(data.get(key)) or float(data[key]) < 0:
			return false
	if not data.get("dead") is bool or not data.get("won") is bool:
		return false
	if not data.get("rng_state") is String or not data.rng_state.is_valid_int():
		return false
	if not data.get("language") is String or data.language not in ["en", "ko"]:
		return false
	if not data.get("maps") is Dictionary or not data.get("player") is Dictionary:
		return false
	for map_id in ["village", "road", "ruin"]:
		if not data.maps.has(map_id) or not data.maps[map_id] is Dictionary:
			return false
		var m: Dictionary = data.maps[map_id]
		if not m.get("tiles") is Array or m.tiles.size() != HEIGHT or not m.get("actors") is Array or not m.get("objects") is Array or not m.get("loot") is Array or not m.get("revealed") is Dictionary:
			return false
		for row in m.tiles:
			if not row is Array or row.size() != WIDTH:
				return false
			for tile in row:
				if not tile is String or tile not in ["#", "T", "R", "~", "+", ".", "d", "g"]:
					return false
		for actor in m.actors:
			if not actor is Dictionary or not actor.get("kind", "") in ["wolf", "raider", "archer", "warden"]:
				return false
			for key in ["x", "y", "hp", "max_hp", "damage", "xp", "stun", "turns"]:
				if not _is_number(actor.get(key)):
					return false
			if not _valid_coords(actor) or int(actor.max_hp) <= 0 or not actor.get("alert") is bool or not actor.get("windup") is bool:
				return false
		for object in m.objects:
			if not object is Dictionary or not _valid_coords(object) or not object.get("id") is String or not object.get("used") is bool or not object.get("label") is String:
				return false
			if object.id not in ["board", "shop", "inn", "well", "exit_road", "exit_village", "exit_ruin", "road_cache", "entry_cache", "blade_cache", "mail_cache", "reliquary"]:
				return false
		for loot in m.loot:
			if not loot is Dictionary or not _valid_coords(loot) or not _is_number(loot.get("coins")) or not loot.get("items") is Dictionary:
				return false
			for id in loot.items:
				if not ITEMS.has(id) or not _is_number(loot.items[id]) or int(loot.items[id]) < 1:
					return false
	for key in ["x", "y", "hp", "energy", "bleed", "injury", "pain", "hunger", "thirst", "coins", "level", "xp", "weapon", "armor", "guard", "cooldowns", "inventory"]:
		if not data.player.has(key):
			return false
	for key in ["x", "y", "hp", "energy", "bleed", "injury", "pain", "hunger", "thirst", "coins", "level", "xp", "guard"]:
		if not _is_number(data.player[key]) or float(data.player[key]) < 0:
			return false
	if not _valid_coords(data.player) or int(data.player.level) < 1 or int(data.player.level) > 4 or int(data.player.injury) > 3:
		return false
	if not data.player.inventory is Dictionary or not data.player.cooldowns is Dictionary:
		return false
	for key in ["power", "guard", "dash"]:
		if not data.player.cooldowns.has(key) or not _is_number(data.player.cooldowns[key]):
			return false
	if not ITEMS.has(data.player.weapon) or not ITEMS.has(data.player.armor):
		return false
	if ITEMS[data.player.weapon].kind != "weapon" or ITEMS[data.player.armor].kind != "armor":
		return false
	if int(data.player.x) < 0 or int(data.player.x) >= WIDTH or int(data.player.y) < 0 or int(data.player.y) >= HEIGHT:
		return false
	for id in data.player.inventory:
		if not ITEMS.has(id) or not _is_number(data.player.inventory[id]) or int(data.player.inventory[id]) < 1:
			return false
	if not data.get("quest", "") in ["available", "active", "recovered", "complete"] or not data.get("logs", []) is Array:
		return false
	for entry in data.get("logs", []):
		if not entry is String:
			return false
	area = data.area
	maps = data.maps.duplicate(true)
	player = data.player.duplicate(true)
	quest = str(data.get("quest", "available"))
	turn = int(data.get("turn", 0))
	dead = bool(data.get("dead", false))
	won = bool(data.get("won", false))
	logs = data.get("logs", []).duplicate()
	language = str(data.get("language", "ko")) if str(data.get("language", "ko")) in ["en", "ko"] else "ko"
	seed_value = int(data.get("seed", 73021))
	rng.seed = seed_value
	rng.state = int(data.get("rng_state", "0"))
	last_events.clear()
	_reveal()
	return true

func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and absf(float(value)) <= 9007199254740991.0

func _valid_coords(value: Dictionary) -> bool:
	return _is_number(value.get("x")) and _is_number(value.get("y")) and int(value.x) >= 0 and int(value.x) < WIDTH and int(value.y) >= 0 and int(value.y) < HEIGHT

func save_game(path: String = SAVE_PATH) -> bool:
	if dead:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	var result := DirAccess.rename_absolute(path + ".tmp", path)
	if result != OK:
		return false
	log_text("Journey saved.", "여정을 저장했다.")
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var data = parser.data
	if not data is Dictionary or not restore(data):
		return false
	log_text("Journey restored.", "저장한 여정을 불러왔다.")
	return true
