extends SceneTree
const Main = preload("res://scenes/main.gd")
var failures := 0
var checks := 0
var ui: Node2D

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("UI FAIL: " + label)

func press(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	ui._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if FileAccess.file_exists("user://briar_and_bone_save.json"):
		push_error("UI tests refuse to overwrite an existing journey. Run scripts/smoke-test.sh for isolated save storage.")
		quit(2)
		return
	ui = Main.new()
	root.add_child(ui)
	check(ui.panel == "title" and not ui.has_started,"startup stays at title")
	ui._button_action("help")
	check(ui.panel == "help","help opens from title")
	ui._button_action("close")
	check(ui.panel == "title" and not ui.has_started,"closing title help does not start game")
	press(KEY_F1)
	press(KEY_ESCAPE)
	check(ui.panel == "title" and not ui.has_started,"Escape from title help returns to title")
	press(KEY_F1)
	press(KEY_F1)
	check(ui.panel == "title","F1 toggle preserves title")
	press(KEY_K)
	check(not FileAccess.file_exists(ui.State.SAVE_PATH),"K cannot save a nonstarted title run")
	ui._button_action("start")
	check(ui.has_started and ui.panel.is_empty(),"begin enters gameplay")
	check(FileAccess.file_exists(ui.State.SAVE_PATH),"new journey writes initial save")
	var before: int = ui.state.turn
	ui._button_action("tab:pack")
	press(KEY_I)
	check(ui.state.turn == before,"inventory UI does not consume turn")
	press(KEY_ESCAPE)
	check(ui.panel == "pause","Escape opens pause menu")
	ui._button_action("help")
	ui._button_action("close")
	check(ui.panel == "pause","help returns to pause origin")
	ui._button_action("close")
	check(ui.panel.is_empty(),"resume returns to gameplay")
	press(KEY_1)
	check(ui.selected_skill == "power" and ui.state.turn == before,"skill selection costs no turn")
	press(KEY_ESCAPE)
	check(ui.selected_skill.is_empty() and ui.panel.is_empty() and ui.state.turn == before,"skill cancellation costs no turn")
	press(KEY_SPACE)
	check(ui.state.turn == before + 1,"keyboard wait advances once")
	var echo := InputEventKey.new()
	echo.keycode = KEY_SPACE
	echo.pressed = true
	echo.echo = true
	ui._input(echo)
	check(ui.state.turn == before + 1,"key-repeat ignored")
	ui._button_action("new")
	check(ui.panel == "confirm_new","existing save requires new-game confirmation")
	ui._button_action("close")
	check(ui.state.turn == before + 1,"cancel new does not reset state")
	press(KEY_L)
	check(ui.panel == "confirm_load","load requires progress-loss confirmation")
	ui._button_action("close")
	check(ui.state.turn == before + 1,"cancel load preserves progress")
	press(KEY_L)
	ui._button_action("load")
	check(ui.state.turn == 0 and ui.panel.is_empty(),"confirmed load restores actual initial save")
	var turn_before_detail: int = ui.state.turn
	ui._button_action("inspect:bandage")
	check(ui.panel=="item" and ui.detail_item=="bandage" and ui.state.turn==turn_before_detail,"item detail opens without consuming a turn")
	press(KEY_SPACE)
	check(ui.state.turn==turn_before_detail,"world hotkeys do not act behind item panel")
	press(KEY_ESCAPE)
	check(ui.panel.is_empty() and ui.detail_item.is_empty() and ui.state.turn==turn_before_detail,"closing item panel consumes no turn")
	ui._button_action("inspect:bandage")
	ui._button_action("item_use")
	check(ui.panel=="item" and ui.state.player.inventory.bandage==4 and ui.state.turn==turn_before_detail,"unneeded item use stays in detail without consuming item or turn")
	ui._button_action("close")
	ui.pointer_guard_until=0
	ui._button_action("inspect:bandage")
	ui.buttons=[{"rect":Rect2(400,607,480,34),"action":"close","enabled":true}]
	ui._pointer_press(Vector2(500,624))
	ui.buttons.clear()
	ui._pointer_press(Vector2(500,624))
	check(ui.state.turn==turn_before_detail and ui.move_path.is_empty(),"double tap on Back does not leak into map or queue walking")
	ui.pointer_guard_until=0
	ui.state.player.hp=40
	ui._button_action("inspect:tonic")
	ui.buttons=[{"rect":Rect2(400,483,480,43),"action":"item_use","enabled":true}]
	var tap := InputEventMouseButton.new()
	tap.button_index=MOUSE_BUTTON_LEFT
	tap.pressed=true
	tap.position=Vector2(500,505)
	ui._pointer_press(tap.position)
	check(ui.panel.is_empty() and ui.state.player.inventory.tonic==1 and ui.state.turn==turn_before_detail+1,"explicit Use button consumes one item and turn")
	ui.buttons.clear()
	ui._pointer_press(tap.position)
	check(ui.state.turn==turn_before_detail+1 and ui.move_path.is_empty(),"double tap after item use cannot leak into map movement")
	ui.pointer_guard_until=0
	ui._button_action("inspect:ration")
	ui._button_action("item_drop_all")
	var after_drop: int=ui.state.turn
	check(not ui.state.player.inventory.has("ration") and ui.state.maps.village.loot[0].items.ration==3,"Drop stack leaves every item on ground")
	ui._button_action("item_drop_all")
	check(ui.state.turn==after_drop and ui.state.maps.village.loot[0].items.ration==3,"stale repeated drop action cannot repeat a turn or duplicate loot")
	ui._button_action("loot")
	check(ui.state.player.inventory.ration==3 and ui.state.turn==after_drop+1,"dropped stack can be collected again through visible Loot action")
	ui.state.add_item("fine_sword")
	ui._button_action("inspect:fine_sword")
	ui._button_action("item_use")
	check(ui.state.player.weapon=="fine_sword" and ui.state.player.inventory.sword==1,"Equip detail action preserves displaced weapon")
	ui.state.add_item("bell")
	ui._button_action("inspect:bell")
	var quest_turn: int=ui.state.turn
	ui._button_action("item_drop_one")
	check(ui.state.player.inventory.bell==1 and ui.state.turn==quest_turn,"quest detail refuses drop without advancing turn")
	ui._button_action("close")
	ui.state.dead = true
	ui.state.player.hp = 0
	ui._after_action(true)
	check(ui.panel == "death" and ui.move_path.is_empty(),"death clears movement and opens recovery")
	press(KEY_SPACE)
	check(ui.state.turn == quest_turn,"dead keyboard action cannot advance")
	ui._button_action("load")
	check(not ui.state.dead and ui.panel.is_empty(),"death load returns to live play")
	ui.state.language="en"
	ui.state.quest="recovered"
	check(not ui._relic_present() and "recovered" in ui._board_story(),"recovered relic is absent and board acknowledges possession")
	ui.state.quest="complete"
	check(not ui._relic_present() and "reward has been paid" in ui._board_story() and not "missing" in ui._board_story(),"completed board and empty relic plinth reflect completed state")
	ui.state.quest="active"
	check(ui._relic_present() and "missing" in ui._board_story(),"active contract still displays the guarded relic")
	DirAccess.remove_absolute(ui.State.SAVE_PATH)
	print("UI FLOW TESTS: %d checks, %d failures" % [checks,failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)
