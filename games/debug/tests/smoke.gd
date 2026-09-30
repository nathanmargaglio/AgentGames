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
	game.coop.network_mode = "lan"
	expect(game.coop.ice_configuration().iceServers.is_empty(),"LAN works without public address-discovery services")
	expect("isolation" in game.coop.connection_help("Test"),"LAN failures explain local network restrictions")
	game.coop.role = "host"
	game.coop.accept_code(JSON.stringify({"game":"debug-coop-1","type":"answer","sdp":"test","candidates":[],"network":"auto"}))
	expect("do not match" in game.coop.notice and not game.coop.remote_applied,"Mismatched answers cannot apply to a LAN invitation")
	game.coop.network_mode = "auto"
	expect(not game.coop.ice_configuration().iceServers.is_empty(),"Automatic retains public address discovery")
	# Headless authority checks exercise the co-op rules without a native WebRTC extension.
	game.set_process(false)
	game.coop.role = "host"
	game.coop.online = true
	game.create_teammate()
	game.start_run()
	expect(game.bugs.size() == 6,"Co-op waits for guest readiness")
	game.peer_ready = true
	game.start_run()
	game.set_physics_process(false)
	expect(game.bugs.size() == 9 and is_equal_approx(game.round_duration,41.8),"Co-op scales bugs, retaining the first-round clock")
	expect(game.player.position.x != game.teammate.position.x,"Agents spawn separately")
	var guest = load("res://src/main.tscn").instantiate()
	root.add_child(guest)
	await process_frame
	guest.set_physics_process(false)
	guest.set_process(false)
	guest.coop.role = "guest"
	guest.coop.online = true
	guest.create_teammate()
	guest.apply_snapshot(game.snapshot())
	expect(guest.bugs.size() == 9 and guest.mode == "playing","Guest receives the authoritative arena")
	game.receive_packet({"type":"state","score":999999})
	game.receive_packet({"type":"upgrade","index":0})
	expect(game.score == 0 and game.power == 1,"Guest cannot choose scores or upgrades")
	game.receive_packet({"type":"input","move":[INF,0],"yaw":0,"pitch":0})
	expect(game.teammate_input.is_empty(),"Nonfinite guest input is rejected")
	game.receive_packet({"type":"input","move":[100,100],"yaw":0,"pitch":100,"paused":false,"serial":0,"ready":true})
	expect(game.teammate_input.move.length() <= 1.001 and game.teammate_pitch <= 1.25,"Guest movement and pitch are bounded")
	game.receive_packet({"type":"input","move":[1e100,-1e100],"yaw":0,"pitch":0,"ready":true})
	expect(game.teammate_input.move.is_finite() and game.teammate_input.move.length() <= 1.001,"Huge finite input cannot overflow the movement vector")
	game.teammate_pitch = 0
	game.teammate_input = {}
	var remote_bug = game.bugs[0]
	remote_bug.position = game.teammate.position + Vector3(0,0.65,-2)
	for other in game.bugs:
		if other != remote_bug: other.position = Vector3(3,1,-8)
	await physics_frame
	game.receive_packet({"type":"swat"})
	game.step_teammate(0.01)
	expect(game.score == 125 and game.team_kills == [0,1],"Guest swat is validated and credited by host")
	game.bugs[0].position = game.teammate.position + Vector3(0,0.65,-2)
	game.receive_packet({"type":"swat"})
	game.step_teammate(0.01)
	expect(game.score == 125,"Guest swat spam respects its own cooldown")
	game.teammate_cooldown = 0
	var remote_wall = game.box(game.teammate.position + Vector3(0,0.65,-1),Vector3(2,3,.2),Color.GRAY,true)
	await physics_frame
	game.receive_packet({"type":"swat"})
	game.step_teammate(0.01)
	expect(game.score == 125,"Guest swats respect wall collision")
	remote_wall.queue_free()
	await physics_frame
	for target in game.bugs.duplicate():
		target.position = game.camera.global_position + Vector3(0,0,-2)
		game.cooldown = 0
		await physics_frame
		game.attack()
	guest.apply_snapshot(game.snapshot())
	expect(guest.mode == "upgrade" and guest.score == game.score and guest.team_kills == game.team_kills,"Both agents see a single score and round completion")
	guest.apply_upgrade(0)
	expect(guest.wave == 1 and guest.power == 1,"Only host may select the shared upgrade")
	game.apply_upgrade(0)
	game.set_physics_process(false)
	guest.apply_snapshot(game.snapshot())
	expect(guest.wave == 2 and guest.power == 2 and guest.bugs.size() == 12,"Host upgrade and next wave reach both agents")
	game.pause_game()
	game.accept_pause({"paused":true,"serial":1})
	game.resume_play()
	expect(game.mode == "paused","Host cannot resume a guest that is paused")
	var team_time: float = game.remaining
	game._physics_process(1.0)
	expect(game.remaining == team_time,"Shared pause stops timer and bugs")
	game.accept_pause({"paused":false,"serial":2})
	expect(game.mode == "playing","Both agents ready resumes the shared clock")
	game.accept_pause({"paused":true,"serial":1})
	expect(game.mode == "playing","Old pause packets cannot undo a resume")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.mode == "paused" and game.local_paused,"Host focus loss pauses co-op")
	game.resume_play()
	game.remaining = 0.01
	game._physics_process(0.1)
	guest.apply_snapshot(game.snapshot())
	expect(game.mode == "over" and guest.mode == "over","Round timeout ends the same run for both agents")
	game.start_run()
	game.set_physics_process(false)
	guest.apply_snapshot(game.snapshot())
	expect(guest.mode == "playing" and guest.wave == 1 and guest.score == 0 and guest.power == 1,"Host restart resets both players")
	game.coop.fail("Test disconnect")
	expect(game.mode == "disconnected","Disconnect stops co-op with retry choices")
	for stream in [guest.music,guest.swat_sound,guest.hit_sound,guest.clear_sound]:
		stream.stop()
		stream.stream = null
	root.remove_child(guest)
	guest.queue_free()
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
