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
	ui.state.dead = true
	ui.state.player.hp = 0
	ui._after_action(true)
	check(ui.panel == "death" and ui.move_path.is_empty(),"death clears movement and opens recovery")
	press(KEY_SPACE)
	check(ui.state.turn == 0,"dead keyboard action cannot advance")
	ui._button_action("load")
	check(not ui.state.dead and ui.panel.is_empty(),"death load returns to live play")
	DirAccess.remove_absolute(ui.State.SAVE_PATH)
	print("UI FLOW TESTS: %d checks, %d failures" % [checks,failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)
