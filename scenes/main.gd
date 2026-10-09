extends Node2D
## All presentation lives here; RunState is the sole authority for world turns.
const State = preload("res://game/run_state.gd")
const FONT = preload("res://assets/fonts/NotoSansKR-Subset.otf")
const TILE := 32
const ORIGIN := Vector2(24, 128)
const GOLD := Color("d5b16d")
const INK := Color("111d22")
const PANEL := Color("1c2b30")
const TEXT := Color("dedbca")
const MUTED := Color("91a49e")
var state := State.new()
var sprites: Dictionary = {}
var buttons: Array = []
var panel := "title"
var back_panel := ""
var has_started := false
var detail_item := ""
var pointer_guard_until := 0
var tab := "journal"
var selected_skill := ""
var mouse := Vector2.ZERO
var hover_hint := ""
var floaters: Array = []
var effects_time := 0.0
var move_path: Array[Vector2i] = []
var walk_clock := 0.0
var notice := ""
var notice_time := 0.0
var sound_on := true
var sound_player: AudioStreamPlayer
var last_screen := ""
var screenshot_frames := -1
var screenshot_target := ""

func t(en: String, ko: String) -> String:
	return state.tr_text(en, ko)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in ["hero", "wolf", "raider", "archer", "warden", "tree", "chest", "board", "shop", "inn", "well", "loot", "bell", "door"]:
		sprites[id] = load("res://assets/sprites/%s.png" % id)
	state.new_game()
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -18
	add_child(sound_player)
	for arg in OS.get_cmdline_user_args():
		if arg == "--play":
			panel = ""
			has_started = true
		if arg == "--show-item":
			has_started = true
			tab = "pack"
			panel = "item"
			detail_item = "bandage"
		if arg == "--english":
			state.language = "en"
			state.new_game()
		if arg.begins_with("--screenshot="):
			screenshot_target = arg.trim_prefix("--screenshot=")
			screenshot_frames = 8
		if arg == "--show-ruin":
			state.area = "ruin"
			state.player.x = 12
			state.player.y = 13
			state.quest = "active"
			state._reveal()
			panel = ""
	print("Briar & Bone ready.")

func _process(delta: float) -> void:
	effects_time += delta
	notice_time = maxf(0, notice_time - delta)
	for f in floaters:
		f.age += delta
	floaters = floaters.filter(func(f): return f.age < 0.85)
	if not move_path.is_empty() and panel.is_empty():
		walk_clock -= delta
		if walk_clock <= 0:
			walk_clock = 0.14
			if _visible_danger() or state.dead:
				move_path.clear()
			else:
				var next: Vector2i = move_path.pop_front()
				var before_area := state.area
				if not _act("move", next - state.position()) or state.area != before_area:
					move_path.clear()
	queue_redraw()
	if screenshot_frames >= 0:
		screenshot_frames -= 1
		if screenshot_frames == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			print("Screenshot saved: ", img.save_png(screenshot_target))
			get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = get_global_mouse_position()
	if event is InputEventMouseButton and event.pressed:
		mouse = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			selected_skill = ""
			move_path.clear()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pointer_press(mouse)
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		move_path.clear()
		if not selected_skill.is_empty():
			selected_skill = ""
		elif panel == "":
			panel = "pause"
		elif panel != "title" and (not state.dead or panel in ["help", "confirm_load"]):
			_close_panel()
		return
	if key == KEY_F1:
		if panel == "help":
			_close_panel()
		else:
			back_panel = panel
			panel = "help"
		return
	if (key == KEY_K or key == KEY_F5) and has_started and not state.dead:
		_save()
		return
	if key == KEY_L:
		back_panel = panel
		panel = "confirm_load"
		return
	if not panel.is_empty() or state.dead:
		return
	move_path.clear()
	match key:
		KEY_UP, KEY_W: _key_direction(Vector2i.UP)
		KEY_DOWN, KEY_S: _key_direction(Vector2i.DOWN)
		KEY_LEFT, KEY_A: _key_direction(Vector2i.LEFT)
		KEY_RIGHT, KEY_D: _key_direction(Vector2i.RIGHT)
		KEY_SPACE, KEY_PERIOD: _act("wait")
		KEY_E: _interact()
		KEY_G: _act("loot")
		KEY_B: _use("bandage")
		KEY_T: _use("tonic")
		KEY_I: tab = "pack" if tab != "pack" else "journal"
		KEY_1: _select_skill("power")
		KEY_2: _act("guard")
		KEY_3: _select_skill("dash")

func _pointer_press(at: Vector2) -> void:
	mouse = at
	# Coordinates are transformed by get_global_mouse_position before reaching here.
	# A second tap must not leak through a closing item panel into the map.
	if Time.get_ticks_msec() < pointer_guard_until:
		return
	for i in range(buttons.size() - 1, -1, -1):
		var button: Dictionary = buttons[i]
		if button.rect.has_point(mouse):
			if button.enabled:
				_button_action(button.action)
			return
	if panel.is_empty() and Rect2(ORIGIN, Vector2(832,576)).has_point(mouse):
		_click_tile(Vector2i((mouse - ORIGIN) / TILE))

func _key_direction(direction: Vector2i) -> void:
	if selected_skill == "power":
		_act("power", state.position() + direction)
	elif selected_skill == "dash":
		_act("dash", state.position() + direction * 2)
	else:
		_act("move", direction)

func _act(action: String, target: Vector2i = Vector2i.ZERO) -> bool:
	var done: bool = state.command(action, target)
	_after_action(done)
	if done:
		selected_skill = ""
	return done

func _after_action(done: bool) -> void:
	if not done:
		return
	for event in state.last_events:
		floaters.append({"x": event.x, "y": event.y, "amount": event.amount, "kind": event.type, "age": 0.0})
		if event.type in ["attack", "power", "hurt"]:
			_beep(170 if event.type == "hurt" else 330, 0.09)
	if state.dead:
		panel = "death"
		move_path.clear()
	elif state.won and not last_screen == "victory":
		last_screen = "victory"
		panel = "victory"
		_save()

func _select_skill(id: String) -> void:
	if selected_skill == id:
		selected_skill = ""
	else:
		selected_skill = id
		_toast(t("Choose a target, or press a direction. Esc cancels.", "대상 또는 방향키를 선택하세요. Esc로 취소."))

func _use(id: String) -> void:
	var ok: bool = state.use_item(id)
	if not ok:
		_toast(t("You don't need that item, or have none left.", "지금은 필요 없거나 물품이 없습니다."))
	_after_action(ok)

func _interact() -> void:
	var obj: Dictionary = state.nearest_object()
	if obj.is_empty():
		_toast(t("Stand beside a person, board, well, or cache.", "사람, 게시판, 우물, 보급함 옆으로 이동하세요."))
		return
	if obj.id in ["shop", "inn", "board"]:
		panel = obj.id
	else:
		_after_action(state.interact(str(obj.id)))

func _button_action(action: String) -> void:
	move_path.clear()
	if action.begins_with("inspect:"):
		detail_item = action.trim_prefix("inspect:")
		if state.player.inventory.has(detail_item):
			back_panel = ""
			panel = "item"
			selected_skill = ""
	elif action.begins_with("tab:"):
		tab = action.trim_prefix("tab:")
	elif action.begins_with("use:"):
		_use(action.trim_prefix("use:"))
	elif action.begins_with("buy:"):
		if not state.buy(action.trim_prefix("buy:")):
			_toast(t("Not enough crowns or pack space.", "크라운이나 배낭 공간이 부족합니다."))
	elif action.begins_with("sell:"):
		state.sell(action.trim_prefix("sell:"))
	else:
		match action:
			"new":
				back_panel = panel
				panel = "confirm_new" if FileAccess.file_exists(State.SAVE_PATH) else "start"
			"start":
				state.new_game()
				has_started = true
				back_panel = ""
				panel = ""
				last_screen = ""
				selected_skill = ""
				_save()
			"load":
				if state.load_game():
					has_started = true
					back_panel = ""
					panel = "death" if state.dead else ""
					last_screen = "victory" if state.won else ""
					selected_skill = ""
					floaters.clear()
				else:
					_toast(t("No valid save found. Your current journey is unchanged.", "유효한 저장이 없습니다. 현재 여정은 유지됩니다."))
			"item_use": _item_action("use")
			"item_drop_one": _item_action("drop_one")
			"item_drop_all": _item_action("drop_all")
			"save": _save()
			"language": state.language = "en" if state.language == "ko" else "ko"
			"sound": sound_on = not sound_on
			"help":
				back_panel = panel
				panel = "help"
			"menu":
				back_panel = ""
				panel = "pause"
			"close": _close_panel()
			"title": panel = "title"
			"interact": _interact()
			"loot": _act("loot")
			"wait": _act("wait")
			"power": _select_skill("power")
			"guard": _act("guard")
			"dash": _select_skill("dash")
			"contract":
				var accepted: bool = state.interact("board")
				panel = ""
				_after_action(accepted)
			"rest":
				if state.rest():
					_save()
					panel = ""
				else:
					_toast(t("A bed costs 10 crowns.", "숙박에는 10 크라운이 필요합니다."))
			"confirm_load":
				back_panel = panel
				panel = "confirm_load"
	if panel == "start":
		_button_action("start")

func _item_action(action: String) -> void:
	if panel != "item" or detail_item.is_empty() or not state.player.inventory.has(detail_item):
		return
	var done := false
	match action:
		"use": done = state.use_item(detail_item)
		"drop_one": done = state.drop_item(detail_item, 1)
		"drop_all": done = state.drop_item(detail_item, int(state.player.inventory[detail_item]))
	if done:
		pointer_guard_until = Time.get_ticks_msec() + 280
		detail_item = ""
		panel = ""
		back_panel = ""
		_after_action(true)
	else:
		_toast(t("That item cannot be used now. Nothing was spent.", "지금은 사용할 수 없습니다. 물품과 턴은 소모되지 않았습니다."))

func _close_panel() -> void:
	if not panel.is_empty():
		pointer_guard_until = Time.get_ticks_msec() + 280
	panel = "death" if state.dead else back_panel
	back_panel = ""
	if panel != "item":
		detail_item = ""
	if panel.is_empty() and not has_started:
		panel = "title"

func _save() -> void:
	_toast(t("Journey saved. L to restore.", "저장했습니다. L로 불러오기.") if state.save_game() else t("Could not write the save file.", "저장 파일을 기록하지 못했습니다."))

func _toast(message: String) -> void:
	notice = message
	notice_time = 3.8

func _click_tile(p: Vector2i) -> void:
	move_path.clear()
	if not selected_skill.is_empty():
		_act(selected_skill, p)
		return
	if not state.is_revealed(p):
		_toast(t("Explore the nearby path first.", "먼저 가까운 길을 탐험하세요."))
		return
	var dist := state._distance(state.position(), p)
	if dist <= 1 and not state.object_at(p).is_empty():
		var obj: Dictionary = state.object_at(p)
		if not obj.id.begins_with("exit_"):
			_interact()
			return
	if dist == 1:
		_act("move", p - state.position())
		return
	if p == state.position():
		_act("loot")
		return
	var route := _walking_path(p)
	if route.is_empty():
		return
	if _visible_danger():
		_act("move", route[0] - state.position())
		_toast(t("Enemy in sight: click once per step.", "적 발견: 클릭 한 번에 한 칸씩 이동합니다."))
	else:
		move_path = route
		walk_clock = 0.0

func _walking_path(goal: Vector2i) -> Array[Vector2i]:
	var start: Vector2i = state.position()
	var queue: Array[Vector2i] = [start]
	var came := {start: start}
	var index := 0
	while index < queue.size():
		var p: Vector2i = queue[index]
		index += 1
		if p == goal:
			var path: Array[Vector2i] = []
			while p != start:
				path.push_front(p)
				p = came[p]
			return path
		for direction in State.DIRS:
			var n: Vector2i = p + direction
			if came.has(n) or not state.passable(n) or not state.is_revealed(n) or not state.actor_at(n).is_empty():
				continue
			var obj: Dictionary = state.object_at(n)
			if not obj.is_empty() and (not obj.id.begins_with("exit_") or n != goal):
				continue
			came[n] = p
			queue.append(n)
	return []

func _visible_danger() -> bool:
	for actor in state.maps[state.area].actors:
		if int(actor.hp) > 0 and state.is_visible(Vector2i(int(actor.x), int(actor.y))):
			return true
	return false

func _draw() -> void:
	buttons.clear()
	hover_hint = ""
	draw_rect(Rect2(0, 0, 1280, 800), INK)
	# Fine, unobtrusive paper grain behind the interface.
	for y in range(0, 800, 4):
		draw_line(Vector2(0,y), Vector2(1280,y), Color(0.25,0.35,0.33,0.025))
	_text(Vector2(25, 49), "BRIAR & BONE", 31, GOLD)
	_text(Vector2(27, 75), t("A small tale of steel, scars, and the road home.", "검과 상처, 그리고 돌아오는 길에 관한 작은 이야기"), 14, MUTED)
	_text(Vector2(26, 113), state.area_name(), 17, TEXT)
	_text(Vector2(590, 113), t("TURN %04d  ·  %s", "%04d 턴  ·  %s") % [state.turn, t("DANGER", "위험") if _visible_danger() else t("EXPLORING", "탐험 중")], 13, Color("cc8366") if _visible_danger() else MUTED)
	_button(Rect2(970, 28, 78, 35), "한국어" if state.language == "en" else "EN", "language")
	_button(Rect2(1058, 28, 82, 35), t("Help", "도움말"), "help")
	_button(Rect2(1150, 28, 105, 35), t("Menu", "메뉴"), "menu")
	_draw_map()
	_draw_sidebar()
	_draw_hotbar()
	if not selected_skill.is_empty() and panel.is_empty():
		_draw_targeting()
	if panel.is_empty() and Rect2(ORIGIN, Vector2(832,576)).has_point(mouse):
		var tile := Vector2i((mouse - ORIGIN) / TILE)
		if state.is_visible(tile):
			var a: Dictionary = state.actor_at(tile)
			if not a.is_empty():
				hover_hint = "%s  |  HP %d/%d\n%s" % [state.actor_name(a.kind), a.hp, a.max_hp, t("Move into an adjacent enemy to attack.", "인접한 적 방향으로 이동하면 공격합니다.")]
	if not panel.is_empty():
		buttons.clear()
		hover_hint = ""
		_draw_modal()
	if not hover_hint.is_empty():
		_tooltip(hover_hint)
	if notice_time > 0:
		var width := minf(920, FONT.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 36)
		_box(Rect2((1280-width)/2, 86, width, 34), Color("31443f"), GOLD)
		_text(Vector2((1280-width)/2+18, 109), notice, 15, TEXT)

func _draw_map() -> void:
	_box(Rect2(ORIGIN - Vector2(2,2), Vector2(836,580)), Color("24342f"), Color("596350"))
	for y in State.HEIGHT:
		for x in State.WIDTH:
			var p := Vector2i(x,y)
			var at := ORIGIN + Vector2(p) * TILE
			if not state.is_revealed(p):
				draw_rect(Rect2(at, Vector2(TILE,TILE)), Color("0c151b"))
				continue
			_draw_tile(p, at, state.tile_at(p))
	if state.area == "village":
		_draw_house(Vector2i(3,3), Vector2i(6,4), t("THE GREEN LANTERN", "초록 등불 여관"), Color("805247"))
		_draw_house(Vector2i(16,3), Vector2i(6,4), t("TRAIL & TRADE", "길손 상점"), Color("6a715d"))
		_draw_house(Vector2i(3,13), Vector2i(6,3), "", Color("6e6150"))
		_draw_house(Vector2i(17,13), Vector2i(6,3), "", Color("6e6150"))
	# Objects are drawn by row together with actors to preserve top-down overlap.
	for y in State.HEIGHT:
		for x in State.WIDTH:
			var p := Vector2i(x,y)
			if not state.is_revealed(p):
				continue
			if state.tile_at(p) == "T":
				_sprite("tree", p, 1.3)
		for o in state.maps[state.area].objects:
			var p := Vector2i(int(o.x), int(o.y))
			if p.y == y and state.is_revealed(p):
				_draw_object(o)
		for loot in state.maps[state.area].loot:
			var p := Vector2i(int(loot.x), int(loot.y))
			if p.y == y and state.is_visible(p) and (not loot.items.is_empty() or int(loot.coins) > 0):
				_sprite("loot", p, 1.5)
		for actor in state.maps[state.area].actors:
			var p := Vector2i(int(actor.x), int(actor.y))
			if p.y == y and state.is_visible(p):
				if int(actor.hp) <= 0:
					draw_rect(Rect2(ORIGIN + Vector2(p)*TILE + Vector2(9,20), Vector2(15,5)), Color("603b3b"))
				else:
					_draw_actor(actor, p)
		if state.position().y == y:
			var pp: Vector2 = ORIGIN + Vector2(state.position()) * TILE
			draw_arc(pp+Vector2(16,25), 13, 0, TAU, 24, Color("b9d694"), 1.0)
			_sprite("hero", state.position(), 1.55)
			if int(state.player.guard) > 0:
				draw_arc(pp+Vector2(16,12), 22, 0, TAU, 24, Color("78bac6"), 2)
	for y in State.HEIGHT:
		for x in State.WIDTH:
			var p := Vector2i(x,y)
			if state.is_revealed(p) and not state.is_visible(p):
				draw_rect(Rect2(ORIGIN+Vector2(p)*TILE, Vector2(TILE,TILE)), Color(0.025,0.065,0.08,0.73))
	for f in floaters:
		if not state.is_visible(Vector2i(f.x,f.y)):
			continue
		var at := ORIGIN + Vector2(f.x,f.y)*TILE + Vector2(10,-float(f.age)*30)
		var color := Color("edc77e") if f.kind != "hurt" and f.kind != "bleed" else Color("ed8c80")
		color.a = 1-float(f.age)/0.85
		_text(at, "!" if f.kind == "warn" else ("-%s" % f.amount if int(f.amount)>0 else ""), 20, color)
	if panel.is_empty() and Rect2(ORIGIN, Vector2(832,576)).has_point(mouse):
		var p := Vector2i((mouse-ORIGIN)/TILE)
		if state.is_visible(p):
			draw_rect(Rect2(ORIGIN+Vector2(p)*TILE+Vector2(1,1),Vector2(30,30)),Color(0.88,0.80,0.57,0.6),false,1)

func _draw_tile(p: Vector2i, at: Vector2, tile: String) -> void:
	var variation := (p.x * 71 + p.y * 29) % 11
	var base := Color("344638")
	match tile:
		".": base = Color("766b4f") if state.area == "village" else Color("675f45")
		"d", "+": base = Color("455052")
		"#": base = Color("253338")
		"~": base = Color("2c535b")
		"R": base = Color("514b3a")
	base = base.lightened(variation * 0.006)
	draw_rect(Rect2(at, Vector2(32,32)), base)
	if tile == "#":
		draw_rect(Rect2(at+Vector2(1,2),Vector2(30,10)),Color("465054"))
		draw_rect(Rect2(at+Vector2(1,14),Vector2(14,12)),Color("3b474c"))
		draw_rect(Rect2(at+Vector2(17,14),Vector2(14,12)),Color("414b4d"))
		draw_line(at+Vector2(2,3),at+Vector2(29,3),Color("5b6460"),1)
	elif tile == "d" or tile == "+":
		draw_rect(Rect2(at+Vector2(1,1),Vector2(30,30)),Color("67706a"),false,1)
		draw_line(at+Vector2(4+variation,8),at+Vector2(9+variation,11),Color("343f42"),1)
	elif tile == "~":
		var shift := int(effects_time*2 + p.y)%3
		draw_line(at+Vector2(3+shift,9),at+Vector2(18+shift,9),Color("5b8284"),2)
		draw_line(at+Vector2(13-shift,22),at+Vector2(27-shift,22),Color("3a6874"),2)
	elif tile in ["g","T"]:
		for i in 3:
			var q := at + Vector2((p.x*17+p.y*7+i*9)%28+2,(p.y*11+p.x*3+i*11)%27+3)
			draw_line(q,q+Vector2(1,-3),Color("486043"),1)
		if variation == 2 and tile == "g":
			draw_rect(Rect2(at+Vector2(9,13),Vector2(2,2)),Color("c4b972"))
	elif tile == ".":
		draw_rect(Rect2(at+Vector2(4+variation,8),Vector2(4,2)),Color("91856a"))
		draw_rect(Rect2(at+Vector2(19,21+variation%5),Vector2(3,2)),Color("514e3d"))
	if tile == "+":
		_sprite("door",p,2)

func _draw_house(p: Vector2i, size: Vector2i, sign_text: String, roof: Color) -> void:
	var at := ORIGIN + Vector2(p)*TILE
	var dims := Vector2(size)*TILE
	draw_rect(Rect2(at+Vector2(4,14),dims),Color(0,0,0,0.25))
	draw_rect(Rect2(at+Vector2(0,dims.y-28),Vector2(dims.x,28)),Color("b29d74"))
	draw_rect(Rect2(at,Vector2(dims.x,dims.y-25)),roof)
	for y in range(5,int(dims.y)-28,8):
		draw_line(at+Vector2(0,y),at+Vector2(dims.x,y),roof.darkened(0.2),2)
		for x in range((y%16)*2,int(dims.x),24):
			draw_line(at+Vector2(x,y),at+Vector2(x,y+6),roof.lightened(0.12),1)
	draw_rect(Rect2(at+Vector2(-2,dims.y-30),Vector2(dims.x+4,5)),Color("403a2e"))
	for x in [24,int(dims.x)-45]:
		draw_rect(Rect2(at+Vector2(x,dims.y-22),Vector2(17,15)),Color("393d35"))
		draw_rect(Rect2(at+Vector2(x+2,dims.y-20),Vector2(5,11)),Color("c9b779"))
		draw_rect(Rect2(at+Vector2(x+9,dims.y-20),Vector2(5,11)),Color("c9b779"))
	if not sign_text.is_empty():
		var width := FONT.get_string_size(sign_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x + 18
		_box(Rect2(at+Vector2((dims.x-width)/2,dims.y-5),Vector2(width,22)),Color("413c2e"),Color("ae9462"))
		_text(at+Vector2((dims.x-width)/2+9,dims.y+11),sign_text,12,Color("e1cc98"))

func _draw_object(o: Dictionary) -> void:
	var p := Vector2i(int(o.x),int(o.y))
	var at := ORIGIN+Vector2(p)*TILE
	if o.id.begins_with("exit_"):
		if state.area == "ruin" or o.id == "exit_ruin":
			for i in 5:
				draw_rect(Rect2(at+Vector2(3+i*2,4+i*4),Vector2(26-i*4,3)),Color("a7a080"))
		else:
			draw_line(at+Vector2(6,16),at+Vector2(26,16),GOLD,2)
			var flip := -1 if o.id == "exit_village" else 1
			draw_line(at+Vector2(16+flip*10,16),at+Vector2(16+flip*4,10),GOLD,2)
			draw_line(at+Vector2(16+flip*10,16),at+Vector2(16+flip*4,22),GOLD,2)
	elif o.id.ends_with("cache"):
		_sprite("chest",p,1.75,Color("777c70") if o.used else Color.WHITE)
	elif o.id == "reliquary":
		if _relic_present():
			_sprite("bell",p,1.75)
		else:
			draw_rect(Rect2(at+Vector2(5,22),Vector2(22,7)),Color("65736b"))
			draw_rect(Rect2(at+Vector2(8,18),Vector2(16,5)),Color("879184"))
	else:
		_sprite(o.id,p,1.5)
	if state.near_object(o.id) and not o.id.begins_with("exit_") and (o.id != "reliquary" or _relic_present()):
		_text(at+Vector2(8,-14),"E",12,GOLD)

func _draw_actor(actor: Dictionary, p: Vector2i) -> void:
	_sprite(str(actor.kind),p,1.7 if actor.kind == "warden" else 1.5)
	var at := ORIGIN+Vector2(p)*TILE
	draw_rect(Rect2(at+Vector2(3,-10),Vector2(26,3)),Color("2b2826"))
	draw_rect(Rect2(at+Vector2(3,-10),Vector2(26*float(actor.hp)/float(actor.max_hp),3)),Color("b4665b"))
	if actor.windup:
		_text(at+Vector2(12,-15),"!",20,Color("edb866"))
	elif int(actor.stun)>0:
		_text(at+Vector2(10,-15),"*",18,Color("9ec9d0"))

func _sprite(id: String, p: Vector2i, scale_factor: float, tint: Color = Color.WHITE) -> void:
	var tex: Texture2D = sprites[id]
	var size := tex.get_size()*scale_factor
	var at := ORIGIN + Vector2(p)*TILE + Vector2((TILE-size.x)/2,TILE-size.y)
	draw_texture_rect(tex,Rect2(at,size),false,tint)

func _draw_sidebar() -> void:
	_box(Rect2(880,106,376,434),PANEL,Color("495c54"))
	_text(Vector2(900,137),t("THE WAYFARER", "길을 걷는 자"),18,TEXT)
	_text(Vector2(1140,137),t("RANK %d", "등급 %d")%state.player.level,13,GOLD)
	_bar(Rect2(900,155,336,20),float(state.player.hp)/state.max_hp(),Color("9d5d54"),t("HEALTH  %d / %d", "체력  %d / %d")%[state.player.hp,state.max_hp()])
	_bar(Rect2(900,184,336,20),float(state.player.energy)/state.max_energy(),Color("537e8c"),t("ENERGY  %d / %d", "기력  %d / %d")%[state.player.energy,state.max_energy()])
	var status := t("Steady", "양호")
	if int(state.player.bleed)>0:
		status = t("BLEEDING (%d)", "출혈 (%d턴)")%state.player.bleed
	elif int(state.player.injury)>0:
		status = t("INJURED x%d", "부상 %d곳")%state.player.injury
	_text(Vector2(900,229),status,14,Color("e8a082") if status!=t("Steady","양호") else Color("aac693"))
	_text(Vector2(1124,229),t("%d crowns", "%d 크라운")%state.player.coins,14,GOLD)
	_text(Vector2(900,258),state.item_name(state.player.weapon)+"  ·  "+t("ATK %d", "공격 %d")%state.attack_power(),14,MUTED)
	_text(Vector2(900,280),state.item_name(state.player.armor)+"  ·  "+t("ARM %d", "방어 %d")%state.armor_value(),14,MUTED)
	for i in 3:
		var id: String = ["journal","pack","condition"][i]
		var label: String = [t("Contract","의뢰"),t("Pack [I]","배낭 [I]"),t("Condition","몸 상태")][i]
		_button(Rect2(896+i*116,296,110,33),label,"tab:"+id,true,tab==id)
	if tab == "journal":
		_text(Vector2(900,356),t("THE BELL IN THE BRIAR", "가시나무 속의 종"),17,GOLD)
		var desc := ""
		match state.quest:
			"available": desc = t("The old bell has fallen silent.\nRead the village board beside the square.\nPrepare supplies before taking the east road.", "오래된 종소리가 끊겼다.\n광장 옆 게시판에서 의뢰를 받자.\n동쪽 길로 떠나기 전에 물품을 준비하자.")
			"active": desc = t("Follow the east road to the ruined priory.\nDefeat the Hollow Warden.\nRecover the bell in the northeast chamber.\nReward on return: 90 crowns.", "동쪽 숲길을 따라 수도원으로 가자.\n공허의 파수꾼을 처치하고\n북동쪽 방에서 종을 회수하자.\n귀환 보수: 90 크라운.")
			"recovered": desc = t("The bell is safe in your pack.\nReturn through the old road to Briarhaven.\nReport at the village contract board.", "종을 배낭에 안전하게 챙겼다.\n숲길을 돌아 가시나루로 귀환하자.\n의뢰 게시판에서 보수를 받을 수 있다.")
			"complete": desc = t("The bell rings over Briarhaven once more.\nYou made it home.\nVisit the inn for free recovery and a save.", "가시나루에 종소리가 다시 울린다.\n무사히 집으로 돌아왔다.\n여관에서 무료로 회복하고 저장하자.")
		_lines(Vector2(900,384),desc,15,TEXT,25)
		_button(Rect2(900,487,160,34),t("Interact [E]","상호작용 [E]"),"interact")
		_button(Rect2(1072,487,164,34),t("Loot [G]","줍기 [G]"),"loot")
	elif tab == "pack":
		_draw_pack()
	else:
		var rows := [[t("Pain","통증"),"%d / 100"%state.player.pain],[t("Hunger","허기"),"%d / 100"%state.player.hunger],[t("Thirst","갈증"),"%d / 100"%state.player.thirst],[t("Injuries","부상"),str(int(state.player.injury))],[t("Experience","경험치"),"%d / %d"%[state.player.xp,int(state.player.level)*30]]]
		for i in rows.size():
			_text(Vector2(901,356+i*29),rows[i][0],15,MUTED)
			_text(Vector2(1136,356+i*29),rows[i][1],15,TEXT)
		_text(Vector2(900,516),t("Injury: -6 max HP each. Poultice treats one.","부상마다 최대 체력 -6. 찜질약으로 치료."),12,GOLD)
	_box(Rect2(880,552,376,222),Color("17262c"),Color("3b504b"))
	_text(Vector2(900,579),t("ON THE ROAD", "여정 기록"),13,GOLD)
	var recent: Array[String] = []
	for i in range(maxi(0,state.logs.size()-8),state.logs.size()):
		for line in _wrap(str(state.logs[i]),330,13):
			recent.append(line)
	var first := maxi(0,recent.size()-8)
	for i in range(first,recent.size()):
		_text(Vector2(900,604+(i-first)*21),recent[i],13,TEXT if i >= recent.size()-2 else MUTED)

func _draw_pack() -> void:
	var ids: Array = state.ordered_inventory()
	ids.erase("bell")
	while ids.size() < 8:
		ids.append("")
	if state.player.inventory.has("bell"):
		ids.append("bell")
	for i in 9:
		var rect := Rect2(899+(i%3)*113,341+floori(float(i)/3.0)*53,108,46)
		if i<ids.size() and ids[i]!="":
			var id: String = ids[i]
			_button(rect,state.item_name(id)+" ×"+str(int(state.player.inventory[id])),"inspect:"+id,true,false,_item_hint(id),11)
		else:
			_box(rect,Color("17262b"),Color("2d413d"))
	_text(Vector2(900,529),t("8 slots + quest pouch. Click an item for actions.","배낭 8칸 + 의뢰 주머니. 물품 클릭: 자세히."),12,MUTED)

func _item_hint(id: String) -> String:
	var hints := {
		"bandage":t("Stops bleeding; restores 5 HP. [B]","출혈을 멈추고 체력을 5 회복합니다. [B]"),
		"splint":t("Treats one injury and reduces pain by 35.","부상 한 곳을 치료하고 통증을 35 줄입니다."),
		"tonic":t("Restores 25 HP. Does not treat injuries. [T]","체력 25 회복. 부상은 치료하지 않습니다. [T]"),
		"ration":t("Reduces hunger by 45; restores 4 HP.","허기 45 감소, 체력 4 회복."),
		"water":t("Reduces thirst by 50; restores 10 energy. Refillable; not sold.","갈증 50 감소, 기력 10 회복. 우물에서 보충 가능, 판매 불가."),
		"sword":t("8 base attack. Equip from the item panel.","기본 공격력 8. 물품 정보에서 장착."),
		"fine_sword":t("12 base attack. Equip from the item panel.","기본 공격력 12. 물품 정보에서 장착."),
		"leather":t("2 armor. Equip from the item panel.","방어력 2. 물품 정보에서 장착."),
		"mail":t("4 armor. Equip from the item panel.","방어력 4. 물품 정보에서 장착."),
		"scrap":t("Sell at the village shop for 4 crowns.","마을 상점에서 4 크라운에 판매 가능."),
		"gem":t("Sell at the village shop for 10 crowns.","마을 상점에서 10 크라운에 판매 가능."),
		"bell":t("Return this to the contract board.","의뢰 게시판에 가져가자.")}
	return state.item_name(id)+"\n"+hints.get(id,"")

func _draw_hotbar() -> void:
	var entries := [["power",t("1  HEW","1  내려베기"),"7",t("+7 damage, interrupts one enemy turn; 4-turn cooldown.","피해 +7, 적 행동 1회 저지. 재사용 4턴.")],["guard",t("2  BRACE","2  방어 자세"),"4",t("-6 incoming damage for two enemy turns; 4-turn cooldown.","적 행동 2회 동안 받는 피해 -6. 재사용 4턴.")],["dash",t("3  SIDESTEP","3  빠른 발걸음"),"5",t("Move two clear tiles in a line; 4-turn cooldown.","직선으로 빈 공간 두 칸 이동. 재사용 4턴.")]]
	for i in 3:
		var e: Array = entries[i]
		var cd := int(state.player.cooldowns[e[0]])
		var caption: String = e[1]+("  [%d]"%cd if cd>0 else "")
		_button(Rect2(24+i*210,717,200,55),caption,e[0],cd==0 and int(state.player.energy)>=int(e[2]),selected_skill==e[0],e[3]+"\n"+t("Energy: ","기력: ")+e[2],14)
	_button(Rect2(654,717,202,55),t("WAIT  [Space]","대기  [Space]"),"wait",true,false,t("Recover energy; enemies also act.","기력을 회복합니다. 적도 행동합니다."),14)
	_text(Vector2(25,794),t("WASD / arrows: move & attack   ·   E: interact   ·   G: loot   ·   I: pack   ·   K: save   ·   F1: help", "WASD / 방향키: 이동·공격   ·   E: 상호작용   ·   G: 줍기   ·   I: 배낭   ·   K: 저장   ·   F1: 도움말"),11,MUTED)

func _draw_targeting() -> void:
	var distance := 1 if selected_skill=="power" else 2
	for direction in State.DIRS:
		var p: Vector2i = state.position()+direction*distance
		if state.is_visible(p):
			draw_rect(Rect2(ORIGIN+Vector2(p)*TILE+Vector2(2,2),Vector2(28,28)),Color("d4b773"),false,2)

func _draw_modal() -> void:
	draw_rect(Rect2(0,0,1280,800),Color(0.025,0.055,0.065,0.86))
	if panel == "title":
		_draw_title()
		return
	var big: bool = panel in ["help","shop"]
	var rect := Rect2(224,121,832,571) if big else Rect2(367,143,546,519)
	_box(rect,Color("1e3033"),Color("957f56"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x,4)),GOLD)
	if panel == "help":
		_text(Vector2(258,172),t("THE ROAD HOME · FIELD GUIDE","돌아오는 길 · 여행 안내서"),24,GOLD)
		var en := "EVERY ACTION MATTERS\nMove or attack with WASD / arrows. Click a nearby tile to step.\nSafe paths can be clicked to walk; movement stops when enemies appear.\nEnemies act only after you act. Menus and invalid actions cost no turns.\n\n1: Hew (+7 damage, interrupt)    2: Brace (two turns of protection)\n3: Sidestep (two clear tiles)    Space: wait and regain energy\nE: interact    G: collect loot    I: pack/details    B: bandage    T: tonic\nSelect a skill, then click a target or press a direction. Esc cancels.\n\nPREPARE, EXPLORE, RETURN\nAccept the board's contract. Buy supplies, refill water, and rest at the inn.\nThe east road leads to a six-room ruin. Recover its bell and return home.\nBleeding costs HP each turn. Injury lowers max HP. Treat both separately.\nWatch an enemy's ! tell: retreat, interrupt, or brace before the strike.\nK saves anywhere. L restores the last save. The inn saves after resting."
		var ko := "한 번의 행동이 중요합니다\nWASD / 방향키로 이동·공격. 가까운 칸을 클릭해 한 칸 이동합니다.\n안전할 때 먼 곳을 클릭하면 자동 이동하며, 적을 발견하면 멈춥니다.\n내가 행동해야 적도 움직입니다. 메뉴와 실패한 행동은 턴을 쓰지 않습니다.\n\n1: 내려베기 (피해 +7, 행동 저지)    2: 방어 자세 (2턴 보호)\n3: 빠른 발걸음 (빈 공간 두 칸)    Space: 대기·기력 회복\nE: 상호작용    G: 줍기    I: 배낭/물품 정보    B: 붕대    T: 물약\n기술을 선택한 뒤 대상 클릭 또는 방향키를 누르세요. Esc로 취소합니다.\n\n준비하고, 탐험하고, 돌아오세요\n게시판 의뢰를 받고 물품을 준비하세요. 우물과 여관도 이용할 수 있습니다.\n동쪽 숲길 너머 여섯 방의 수도원에서 종을 찾아 마을로 귀환하세요.\n출혈은 턴마다 체력을 깎고 부상은 최대 체력을 줄입니다. 따로 치료하세요.\n적의 ! 표시는 강한 공격 예고입니다. 피하거나 기술로 저지하세요.\nK: 어디서나 저장. L: 최근 저장 불러오기. 여관은 숙박 후 자동 저장."
		_lines(Vector2(258,205),t(en,ko),16,TEXT,26)
		_button(Rect2(822,635,196,37),t("Got it · Esc","알겠습니다 · Esc"),"close")
		return
	if panel == "shop":
		_text(Vector2(257,166),t("TRAIL & TRADE","길손 상점"),24,GOLD)
		_text(Vector2(779,165),t("Purse: %d crowns","소지금: %d 크라운")%state.player.coins,16,TEXT)
		_text(Vector2(258,204),t("SUPPLIES · click to buy","보급품 · 클릭하여 구매"),14,MUTED)
		_text(Vector2(652,204),t("YOUR PACK · click to sell one","내 배낭 · 클릭하여 1개 판매"),14,MUTED)
		var goods := ["bandage","splint","ration","water","tonic","fine_sword","mail"]
		for i in goods.size():
			var id: String = goods[i]
			_button(Rect2(257,222+i*49,352,40),state.item_name(id)+"  ·  "+str(State.ITEMS[id].price),"buy:"+id,int(state.player.coins)>=int(State.ITEMS[id].price),false,_item_hint(id),15)
		var ids: Array = state.ordered_inventory()
		for i in mini(9,ids.size()):
			var id: String = ids[i]
			_button(Rect2(652,222+i*40,370,34),state.item_name(id)+" ×"+str(int(state.player.inventory[id]))+"  ·  "+str(maxi(1,floori(float(State.ITEMS[id].price)/2.0))),"sell:"+id,State.ITEMS[id].kind!="quest" and id!="water",false,_item_hint(id),14)
		_button(Rect2(822,635,196,37),t("Leave shop","상점 나가기"),"close")
		_text(Vector2(258,661),t("Trading is safe and costs no turns.","거래는 안전하며 턴을 소모하지 않습니다."),13,MUTED)
		return
	if panel == "item":
		_draw_item_panel(rect)
		return
	var title := ""
	var body := ""
	match panel:
		"pause": title=t("A MOMENT'S REST","잠시 쉬어 가기")
		"board":
			title=t("THE BELL IN THE BRIAR","가시나무 속의 종")
			body=_board_story()
		"inn":
			title=t("THE GREEN LANTERN","초록 등불 여관")
			body=t("A clean bed and a bowl of warm broth.\n\nRestore health and energy.\nTreat all bleeding, injuries, and pain.\nFood and water are included.\nYour journey is saved after resting.\n\nCost: %s crowns.","깨끗한 침대와 따뜻한 수프 한 그릇.\n\n체력과 기력을 모두 회복합니다.\n출혈, 부상, 통증을 치료합니다.\n식량과 물도 제공됩니다.\n숙박 후 여정을 자동 저장합니다.\n\n숙박비: %s 크라운.")%("0" if state.won else "10")
		"death":
			title=t("THE ROAD GOES QUIET","길 위에 고요가 내려앉다")
			body=t("Your journey ended after %d turns.\n\nRestore your last saved journey,\nor begin anew.\nProgress since the last save will be lost.","%d턴 만에 여정이 끝났습니다.\n\n마지막으로 저장한 여정을 불러오거나\n새로운 여정을 시작할 수 있습니다.\n마지막 저장 이후의 진행은 사라집니다.")%state.turn
		"victory":
			title=t("THE BELL RINGS AGAIN","종이 다시 울린다")
			body=t("You returned with the briar bell.\nBriarhaven will remember your name.\n\n90 crowns earned. Journey saved.\n\nThis small story is complete.\nYou may explore any rooms you missed,\nor rest for free at the Green Lantern.","가시나무 종을 되찾아 돌아왔습니다.\n가시나루는 당신을 기억할 것입니다.\n\n90 크라운 획득. 여정을 저장했습니다.\n\n작은 이야기가 끝났습니다.\n남은 방을 탐험하거나\n초록 등불 여관에서 무료로 쉬어 가세요.")
		"confirm_new":
			title=t("A NEW JOURNEY?","새 여정을 시작할까요?")
			body=t("Starting over replaces the saved journey.\nYour current progress will be lost.","새로 시작하면 기존 저장을 덮어씁니다.\n현재 진행 상황은 사라집니다.")
		"confirm_load":
			title=t("RETURN TO YOUR SAVE?","저장 지점으로 돌아갈까요?")
			body=t("Progress since your last save will be lost.\nThe saved journey will be restored.","마지막 저장 이후의 진행은 사라집니다.\n저장해 둔 여정을 불러옵니다.")
	_text(rect.position+Vector2(31,53),title,24,GOLD)
	if panel == "pause":
		var options := [[t("Resume journey","계속하기"),"close"],[t("Save journey · K","여정 저장 · K"),"save"],[t("Load journey · L","저장 불러오기 · L"),"confirm_load"],[t("Field guide · F1","여행 안내서 · F1"),"help"],[t("Sound: ","효과음: ")+(t("ON","켜짐") if sound_on else t("OFF","꺼짐")),"sound"],[t("New journey","새 여정"),"new"]]
		for i in options.size():
			_button(Rect2(401,224+i*60,478,46),options[i][0],options[i][1])
		return
	_lines(rect.position+Vector2(31,96),body,17,TEXT,30)
	match panel:
		"board":
			if state.quest in ["available","recovered"]:
				_button(Rect2(400,549,480,43),t("Accept contract","의뢰 수락") if state.quest=="available" else t("Return the bell · claim reward","종 전달 · 보수 받기"),"contract")
			else:
				_text(Vector2(401,576),t("Contract completed.","의뢰 완료.") if state.quest=="complete" else t("Return when you have the bell.","종을 회수한 뒤 돌아오세요."),16,GOLD)
		"inn": _button(Rect2(400,549,480,43),t("Rest & save","숙박하고 저장"),"rest")
		"death": _button(Rect2(400,489,480,43),t("Load last save","마지막 저장 불러오기"),"load",FileAccess.file_exists(State.SAVE_PATH)); _button(Rect2(400,549,480,43),t("Begin a new journey","새 여정 시작"),"new")
		"confirm_new": _button(Rect2(400,489,480,43),t("Start over","새로 시작"),"start")
		"confirm_load": _button(Rect2(400,489,480,43),t("Restore saved journey","저장 불러오기"),"load",FileAccess.file_exists(State.SAVE_PATH))
	if panel != "death":
		_button(Rect2(400,607,480,34),t("Continue / cancel · Esc","계속 / 취소 · Esc"),"close")

func _relic_present() -> bool:
	return state.quest in ["available", "active"]

func _board_story() -> String:
	if state.quest == "complete":
		return t("The bell has returned to Briarhaven.\nIts sound carries over the old road again.\n\nYour 90-crown reward has been paid.\nThe contract is complete.\n\nThe Green Lantern offers you a free bed.", "종이 가시나루로 돌아왔습니다.\n오래된 숲길에 다시 종소리가 울립니다.\n\n보수 90 크라운은 이미 지급되었습니다.\n의뢰가 완료되었습니다.\n\n초록 등불 여관에서 무료로 쉬어 가세요.")
	if state.quest == "recovered":
		return t("You have recovered the briar bell.\nBriarhaven has waited for this sound.\n\nHand over the bell to finish the contract\nand receive your 90-crown reward.", "가시나무 종을 회수했습니다.\n가시나루가 이 종소리를 기다렸습니다.\n\n종을 전달해 의뢰를 완료하고\n보수 90 크라운을 받으세요.")
	return t("Our priory bell is missing.\nThe Hollow Warden holds the old halls.\n\nFollow the east road. Bring back the bell\nfrom the northeast chamber of the ruins.\n\nReward upon return: 90 crowns.", "수도원의 종을 잃어버렸습니다.\n공허의 파수꾼이 옛 전당을 지키고 있습니다.\n\n동쪽 숲길을 따라 유적으로 가서\n북동쪽 방에 있는 종을 가져와 주세요.\n\n귀환 후 보수: 90 크라운.")

func _draw_item_panel(rect: Rect2) -> void:
	if detail_item.is_empty() or not State.ITEMS.has(detail_item):
		return
	var item: Dictionary = State.ITEMS[detail_item]
	var quantity := int(state.player.inventory.get(detail_item, 0))
	_text(rect.position+Vector2(31,53),state.item_name(detail_item),24,GOLD)
	_text(rect.position+Vector2(31,88),t("IN YOUR PACK: %d", "배낭 수량: %d") % quantity,15,MUTED)
	var description := _item_hint(detail_item).split("\n", true, 1)
	var body: String = description[1] if description.size() > 1 else ""
	var lines := _wrap(body,472,17)
	for i in lines.size():
		_text(rect.position+Vector2(31,133+i*29),lines[i],17,TEXT)
	var use_label := t("Use · 1 turn", "사용 · 1턴")
	if item.kind in ["weapon", "armor"]:
		use_label = t("Equip · 1 turn", "장착 · 1턴")
	if item.kind == "quest":
		_lines(rect.position+Vector2(31,230),t("Quest items stay in a separate pouch.\nThey cannot be dropped or sold.", "의뢰 물품은 별도의 주머니에 보관합니다.\n내려놓거나 판매할 수 없습니다."),16,MUTED,28)
	else:
		_lines(rect.position+Vector2(31,230),t("Dropped items stay on this tile.\nCollect them again with Loot [G].\nUsing, equipping, or dropping advances enemies.", "내려놓은 물품은 현재 칸에 남습니다.\n줍기 [G]로 다시 챙길 수 있습니다.\n사용·장착·내려놓기를 하면 적도 행동합니다."),15,MUTED,27)
	_button(Rect2(400,483,480,43),use_label,"item_use",quantity>0 and item.kind not in ["sell", "quest"])
	_button(Rect2(400,541,233,43),t("Drop one · 1 turn", "1개 내려놓기 · 1턴"),"item_drop_one",quantity>0 and item.kind!="quest")
	_button(Rect2(647,541,233,43),t("Drop stack · 1 turn", "모두 내려놓기 · 1턴"),"item_drop_all",quantity>1 and item.kind!="quest")
	_button(Rect2(400,607,480,34),t("Back to pack · no turn", "배낭으로 · 턴 소모 없음"),"close")

func _draw_title() -> void:
	_text(Vector2(165,208),t("AN ORIGINAL TACTICAL RPG", "독자 제작 턴제 탐험 RPG"),16,MUTED)
	_text(Vector2(160,292),"BRIAR & BONE",66,GOLD)
	_text(Vector2(164,334),t("Steel is only half the journey.","검을 드는 일은 여정의 절반에 불과하다."),22,TEXT)
	_lines(Vector2(166,386),t("Prepare in the village. Walk the old road.\nRead your enemy. Treat your wounds.\nAbove all, make it home.","마을에서 준비하고, 오래된 길을 걸어라.\n적의 움직임을 읽고, 상처를 돌보아라.\n무엇보다, 무사히 돌아와라."),19,MUTED,32)
	_button(Rect2(165,527,290,50),t("Begin journey","여정 시작"),"new",true,true)
	_button(Rect2(165,591,290,45),t("Continue saved journey","저장한 여정 계속하기"),"load",FileAccess.file_exists(State.SAVE_PATH))
	_button(Rect2(477,527,218,50),t("Field guide","여행 안내서"),"help")
	_button(Rect2(477,591,218,45),"한국어 / English","language")
	_text(Vector2(166,706),t("A complete small adventure · 15–25 minutes · Keyboard & mouse", "작지만 완결된 모험 · 약 15~25분 · 키보드 & 마우스"),14,MUTED)
	# Oversized original crest: blade, bell, and briar.
	var center := Vector2(986,373)
	draw_arc(center,126,0,TAU,60,Color("57694e"),2)
	for i in 16:
		var angle := i*TAU/16
		var p := center+Vector2(cos(angle),sin(angle))*126
		draw_line(p,p+Vector2(cos(angle-0.7),sin(angle-0.7))*19,Color("829065"),3)
	draw_texture_rect(sprites.bell,Rect2(930,327,112,126),false,Color("c0aa76"))
	draw_rect(Rect2(981,222,10,173),Color("9eadab"))
	draw_rect(Rect2(958,394,56,8),GOLD)
	draw_rect(Rect2(982,402,8,52),Color("765e45"))
	_text(Vector2(860,558),t("THE BELL IN THE BRIAR","가시나무 속의 종"),18,GOLD)

func _text(at: Vector2, value: String, size: int = 16, color: Color = TEXT) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _lines(at: Vector2, value: String, size: int, color: Color, line_height: int) -> void:
	var i := 0
	for line in value.split("\n"):
		_text(at+Vector2(0,i*line_height),line,size,color)
		i += 1

func _box(rect: Rect2, color: Color, border: Color) -> void:
	draw_rect(rect,color)
	draw_rect(rect,border,false,1)

func _button(rect: Rect2, caption: String, action: String, enabled: bool = true, selected: bool = false, hint: String = "", font_size: int = 15) -> void:
	var hovering := rect.has_point(mouse)
	var color := Color("35463e") if selected else Color("273b3d")
	if hovering and enabled:
		color = color.lightened(0.10)
	if not enabled:
		color = Color("1c2a2e")
	_box(rect,color,GOLD if selected else (Color("87977b") if hovering and enabled else Color("4b6058")))
	var size := FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	_text(rect.position+Vector2(maxf(6,(rect.size.x-size.x)/2),(rect.size.y+font_size)/2-2),caption,font_size,TEXT if enabled else Color("637670"))
	buttons.append({"rect":rect,"action":action,"enabled":enabled})
	if hovering and not hint.is_empty():
		hover_hint=hint

func _bar(rect: Rect2, fraction: float, color: Color, label: String) -> void:
	draw_rect(rect,Color("0f2027"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(fraction,0,1),rect.size.y)),color)
	draw_rect(rect,Color("647368"),false,1)
	_text(rect.position+Vector2(8,15),label,12,TEXT)

func _wrap(value: String, width: int, size: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in value.split("\n"):
		var line := ""
		for character in paragraph:
			if FONT.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width:
				lines.append(line)
				line = ""
			line += character
		lines.append(line)
	return lines

func _tooltip(value: String) -> void:
	var lines := _wrap(value,318,14)
	var size := Vector2(350,lines.size()*22+22)
	var at := Vector2(clampf(mouse.x+16,20,1260-size.x),clampf(mouse.y-size.y-12,120,760-size.y))
	_box(Rect2(at,size),Color("101f25"),GOLD)
	for i in lines.size():
		_text(at+Vector2(15,25+i*22),lines[i],14,TEXT)

func _beep(frequency: float, duration: float) -> void:
	if not sound_on or DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(duration*22050)*2)
	for i in int(duration*22050):
		var amplitude := sin(float(i)*frequency*TAU/22050)*0.22*pow(1-float(i)/(duration*22050),2)
		data.encode_s16(i*2,int(amplitude*32767))
	stream.data = data
	sound_player.stream = stream
	sound_player.play()
