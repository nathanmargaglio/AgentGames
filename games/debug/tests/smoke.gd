extends SceneTree

var failures: int = 0
func expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("test_game")

func test_game() -> void:
	var game = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	expect(game.mode == "title","Game opens at briefing")
	game.start_run()
	game.set_physics_process(false)
	expect(game.wave == 1 and game.bugs.size() == 6,"Initial wave spawns six bugs")
	# Real camera arc and physics ray tests, rather than calling damage directly.
	var bug = game.bugs[0]
	bug.position = game.camera.global_position + Vector3(0,0,-2)
	for other in game.bugs:
		if other != bug:
			other.position = Vector3(3,1,-8)
	await physics_frame
	game.attack()
	expect(game.score == 125 and game.bugs.size() == 5,"Swat awards score and removes target")
	game.attack()
	expect(game.bugs.size() == 5,"Cooldown prevents duplicate attack")
	# Swats must not pass through a cabinet/wall.
	var blocked = game.bugs[0]
	blocked.position = game.camera.global_position + Vector3(0,0,-2)
	var wall = game.box(game.camera.global_position + Vector3(0,0,-1),Vector3(2,3,.2),Color.GRAY,true)
	await physics_frame
	game.cooldown = 0
	game.attack()
	expect(game.bugs.size() == 5,"Line of sight prevents swatting through walls")
	wall.queue_free()
	await physics_frame
	for target in game.bugs.duplicate():
		target.position = game.camera.global_position + Vector3(0,0,-2)
		game.cooldown = 0
		await physics_frame
		game.attack()
	expect(game.mode == "upgrade" and game.bugs.is_empty(),"Clearing a round opens upgrades")
	game.apply_upgrade(0)
	game.set_physics_process(false)
	expect(game.power == 2 and game.wave == 2 and game.bugs.size() == 8,"Damage upgrade and next wave")
	# Exercise all upgrade paths and escalation.
	for target in game.bugs:target.queue_free()
	game.bugs.clear()
	game.round_clear()
	game.apply_upgrade(1)
	game.set_physics_process(false)
	expect(is_equal_approx(game.reach,4.2),"Reach upgrade")
	for target in game.bugs:target.queue_free()
	game.bugs.clear()
	game.round_clear()
	game.apply_upgrade(2)
	game.set_physics_process(false)
	expect(game.interval < 0.43 and game.bugs[0].hp == 2,"Overclock and tougher round four bugs")
	game.pause_game()
	var time: float = game.remaining
	game._physics_process(1.0)
	expect(game.remaining == time and game.mode == "paused","Paused clock stays stopped")
	game.resume_play()
	game.remaining = 0.01
	game._physics_process(0.1)
	expect(game.mode == "over","Timer expiry ends the run")
	expect(game.best >= game.score,"Local high score saved")
	game.start_run()
	game.set_physics_process(false)
	expect(game.power == 1 and game.wave == 1 and game.score == 0,"Restart resets upgrades and score")
	for name_ in ["forward","back","left","right","swat","jump","sprint","pause_game","ui_accept","ui_cancel"]:
		var has_joy: bool = false
		for event in InputMap.action_get_events(name_):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:has_joy = true
		expect(has_joy,"Controller action missing: "+name_)
	await create_timer(0.3).timeout
	for stream in [game.music,game.swat_sound,game.hit_sound,game.clear_sound]:
		stream.stop()
		stream.stream = null
	await create_timer(0.1).timeout
	root.remove_child(game)
	game.queue_free()
	await process_frame
	print("Debug gameplay checks: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
