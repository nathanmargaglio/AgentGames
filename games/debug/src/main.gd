extends Node3D

const Bug = preload("res://src/bug.gd")
const Coop = preload("res://src/coop.gd")
const LIME := Color("c9ee83")
const INK := Color("10201f")
const WHITE := Color("ecf0e5")
var player: CharacterBody3D
var camera: Camera3D
var weapon: Node3D
var bugs: Array[Node3D] = []
var mode: String = "title"
var wave: int = 0
var score: int = 0
var best: int = 0
var remaining: float = 0
var round_duration: float = 0
var power: int = 1
var reach: float = 3.5
var interval: float = 0.43
var cooldown: float = 0
var swing: float = 0
var elapsed: float = 0
var look_sensitivity: float = 0.0022
var muted: bool = false
var controller_active: bool = false
var hud: Control
var menu: Control
var stats: Label
var time_label: Label
var status: Label
var tracker: Label
var timer_bar: ProgressBar
var crosshair: Label
var score_label: Label
var menu_box: VBoxContainer
var music: AudioStreamPlayer
var swat_sound: AudioStreamPlayer
var hit_sound: AudioStreamPlayer
var clear_sound: AudioStreamPlayer
var hit_marker: float = 0
var saved_mode: String = "playing"
var debug_tick: float = 0
var coop: Node
var teammate: CharacterBody3D
var teammate_weapon: Node3D
var teammate_pitch: float = 0
var teammate_cooldown: float = 0
var teammate_swing: float = 0
var teammate_input: Dictionary = {}
var input_age: float = 0
var net_tick: float = 0
var local_paused: bool = false
var remote_paused: bool = false
var run_id: int = 0
var bug_serial: int = 0
var team_kills: Array[int] = [0,0]
var lobby_bridge: JavaScriptObject
var jump_pending: bool = false
var control_serial: int = 0
var last_control: int = -1
var agent_ready: bool = false
var peer_ready: bool = false

func _ready() -> void:
	setup_input()
	load_best()
	create_world()
	create_player()
	create_audio()
	create_hud()
	coop = Coop.new()
	add_child(coop)
	coop.connected.connect(coop_connected)
	coop.disconnected.connect(coop_disconnected)
	coop.packet.connect(receive_packet)
	coop.pairing_changed.connect(refresh_pairing)
	if OS.has_feature("web"):
		lobby_bridge = JavaScriptBridge.get_interface("debugLobby")
	show_title()

func action(name_: String, keys: Array, joy_button: int = -1, mouse: int = -1) -> void:
	if not InputMap.has_action(name_):
		InputMap.add_action(name_, 0.18)
	for code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(name_, event)
	if joy_button >= 0:
		var event := InputEventJoypadButton.new()
		event.button_index = joy_button
		InputMap.action_add_event(name_, event)
	if mouse >= 0:
		var event := InputEventMouseButton.new()
		event.button_index = mouse
		InputMap.action_add_event(name_, event)

func axis(name_: String, index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	InputMap.action_add_event(name_, event)

func setup_input() -> void:
	action("ui_accept", [], JOY_BUTTON_A)
	action("ui_cancel", [], JOY_BUTTON_B)
	action("forward", [KEY_W, KEY_UP])
	action("back", [KEY_S, KEY_DOWN])
	action("left", [KEY_A, KEY_LEFT])
	action("right", [KEY_D, KEY_RIGHT])
	axis("forward", JOY_AXIS_LEFT_Y, -1)
	axis("back", JOY_AXIS_LEFT_Y, 1)
	axis("left", JOY_AXIS_LEFT_X, -1)
	axis("right", JOY_AXIS_LEFT_X, 1)
	action("swat", [], JOY_BUTTON_RIGHT_SHOULDER, MOUSE_BUTTON_LEFT)
	axis("swat", JOY_AXIS_TRIGGER_RIGHT, 1)
	action("jump", [KEY_SPACE], JOY_BUTTON_A)
	action("sprint", [KEY_SHIFT], JOY_BUTTON_LEFT_STICK)
	action("pause_game", [KEY_ESCAPE], JOY_BUTTON_START)
	action("mute_game", [KEY_M], JOY_BUTTON_BACK)

func material(color: Color, glow: float = 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func box(at: Vector3, size_: Vector3, color: Color, solid: bool = false, glow: float = 0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size_
	mesh.mesh = shape
	mesh.material_override = material(color, glow)
	mesh.position = at
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = size_
		collision.shape = cube
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func create_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("17292e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4d5d1")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -25, 0)
	light.light_color = Color("d4e9e4")
	light.light_energy = 1.1
	add_child(light)
	box(Vector3(0,-0.2,0), Vector3(22,0.4,26), Color("203437"), true)
	box(Vector3(-11,2.5,0), Vector3(0.4,5,26), Color("34464a"), true)
	box(Vector3(11,2.5,0), Vector3(0.4,5,26), Color("34464a"), true)
	box(Vector3(0,2.5,-13), Vector3(22,5,0.4), Color("34464a"), true)
	box(Vector3(0,2.5,13), Vector3(22,5,0.4), Color("34464a"), true)
	box(Vector3(0,5.1,0), Vector3(22,0.2,26), Color("15272c"))
	for i in range(-10,11,2):
		box(Vector3(i,0.008,0),Vector3(0.015,0.01,26),Color("405254"))
	for i in range(-12,13,2):
		box(Vector3(0,0.008,i),Vector3(22,0.01,0.015),Color("405254"))
	for x in [-4.7,4.7]:
		box(Vector3(x,0.015,0),Vector3(0.055,0.015,25),LIME, false, 0.5)
		for z in [-8,-4,0,4,8]:
			var rack: Node3D = preload("res://assets/models/rack.glb").instantiate()
			rack.position = Vector3(x * 1.4,0,z)
			rack.rotation.y = PI/2 if x < 0 else -PI/2
			add_child(rack)
			var body := StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.5,2.8,1.15)
			collision.shape = shape
			collision.position.y = 1.4
			body.add_child(collision)
			rack.add_child(body)
	for z in [-9,-3,3,9]:
		box(Vector3(0,4.95,z),Vector3(3.2,0.05,1.3),Color("d7e5df"),false,0.7)
		for x in [-10.75,10.75]:
			box(Vector3(x,3.8,z),Vector3(0.03,0.09,2),Color("71bdb9"),false,0.5)
	box(Vector3(0,2.5,-12.75),Vector3(5.5,2.4,0.1),INK)
	var sign_ := Label3D.new()
	sign_.text = "D E B U G\nAGENT OPERATIONS / NODE 01"
	sign_.position = Vector3(0,2.5,-12.65)
	sign_.font_size = 80
	sign_.pixel_size = 0.009
	sign_.modulate = LIME
	add_child(sign_)

func create_player() -> void:
	player = CharacterBody3D.new()
	player.collision_layer = 0
	player.position = Vector3(0,0.9,10)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.7
	capsule.radius = 0.35
	collision.shape = capsule
	player.add_child(collision)
	add_child(player)
	camera = Camera3D.new()
	camera.position.y = 0.65
	camera.fov = 80
	camera.near = 0.05
	player.add_child(camera)
	weapon = preload("res://assets/models/swatter.glb").instantiate()
	weapon.position = Vector3(0.48,-0.65,-0.75)
	weapon.rotation_degrees = Vector3(-18,-12,-12)
	camera.add_child(weapon)

func create_audio() -> void:
	music = audio("res://assets/audio/music.ogg", -20)
	music.stream.loop = true
	swat_sound = audio("res://assets/audio/swat.wav", -8)
	hit_sound = audio("res://assets/audio/hit.wav", -4)
	clear_sound = audio("res://assets/audio/clear.wav", -8)

func audio(path: String, volume: float) -> AudioStreamPlayer:
	var stream := AudioStreamPlayer.new()
	stream.stream = load(path)
	stream.volume_db = volume
	add_child(stream)
	return stream

func style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 24 if radius > 0 else 0
	s.content_margin_right = 24 if radius > 0 else 0
	s.content_margin_top = 18 if radius > 0 else 0
	s.content_margin_bottom = 18 if radius > 0 else 0
	return s

func label(text_: String, size_: int, color: Color = WHITE) -> Label:
	var l := Label.new()
	l.text = text_
	l.add_theme_font_size_override("font_size",size_)
	l.add_theme_color_override("font_color",color)
	return l

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 36
	top.offset_right = -36
	top.offset_top = 28
	top.add_theme_constant_override("separation",24)
	hud.add_child(top)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel",style(Color(0.04,0.09,0.09,0.92)))
	top.add_child(plate)
	stats = label("",24,LIME)
	plate.add_child(stats)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var time_plate := PanelContainer.new()
	time_plate.add_theme_stylebox_override("panel",style(Color(0.04,0.09,0.09,0.92)))
	top.add_child(time_plate)
	time_label = label("",24)
	time_plate.add_child(time_label)
	timer_bar = ProgressBar.new()
	timer_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	timer_bar.offset_top = 104
	timer_bar.offset_bottom = 108
	timer_bar.offset_left = 36
	timer_bar.offset_right = -36
	timer_bar.show_percentage = false
	timer_bar.add_theme_stylebox_override("background",style(Color(0.1,0.17,0.17),0))
	timer_bar.add_theme_stylebox_override("fill",style(LIME,0))
	hud.add_child(timer_bar)
	crosshair = label("+",32,LIME)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -20
	crosshair.offset_right = 20
	crosshair.offset_top = -25
	crosshair.offset_bottom = 25
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(crosshair)
	status = label("",22,LIME)
	status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status.offset_top = 145
	status.offset_left = -300
	status.offset_right = 300
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(status)
	tracker = label("",20)
	tracker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tracker.offset_left = 36
	tracker.offset_top = -82
	hud.add_child(tracker)
	score_label = label("",20,LIME)
	score_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	score_label.offset_left = -460
	score_label.offset_right = -36
	score_label.offset_top = -82
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(score_label)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.06,0.065,0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 640
	panel.add_theme_stylebox_override("panel",style(Color("142a29"),18))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation",16)
	margin.add_child(menu_box)

func clear_menu(kicker: String, title_: String, text_: String) -> void:
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	menu_box.add_child(label(kicker,18,LIME))
	menu_box.add_child(label(title_,56))
	var body := label(text_,22,Color("b1c7be"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 540
	menu_box.add_child(body)
	menu.show()
	hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func button(text_: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text_
	b.custom_minimum_size.y = 60
	b.add_theme_font_size_override("font_size",22)
	b.add_theme_stylebox_override("normal",style(LIME if primary else Color("24423d"),8))
	b.add_theme_stylebox_override("hover",style(Color("dafa9d") if primary else Color("34574d"),8))
	b.add_theme_stylebox_override("pressed",style(Color("91b259"),8))
	var focus := style(Color(0,0,0,0),8)
	focus.border_color = WHITE
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("focus",focus)
	b.add_theme_color_override("font_color",INK if primary else WHITE)
	b.add_theme_color_override("font_hover_color",INK if primary else WHITE)
	b.pressed.connect(callback)
	menu_box.add_child(b)
	return b

func show_title() -> void:
	leave_coop()
	mode = "title"
	clear_menu("AGENT OPERATIONS / FIRST-PERSON SWATTER", "Debug.", "The server has a bug problem. You are the fix.\nClear every bug before the clock runs out. Choose an upgrade after each clean sweep.")
	button("Initialize agent  →",start_run,true).grab_focus()
	button("Host co-op  /  2 agents",func(): open_coop("host"))
	button("Join co-op",func(): open_coop("guest"))
	menu_box.add_child(label("WASD  Move   ·   Mouse  Look   ·   Click  Swat\nShift  Sprint   ·   Space  Jump   ·   Esc  Pause\nXbox: sticks move/look · RT swat · A jump · Start pause",18,Color("b1c7be")))
	menu_box.add_child(label("LOCAL BEST  %06d   /   SOLO OR 2-PLAYER CO-OP" % best,18,LIME))

func start_run() -> void:
	if coop.role == "guest" or (coop.role == "host" and (not coop.online or not peer_ready)):
		return
	run_id += 1
	team_kills = [0,0]
	jump_pending = false
	local_paused = false
	remote_paused = false
	teammate_input = {}
	teammate_cooldown = 0
	if teammate != null:
		teammate.position = Vector3(1.2,0.9,10)
		teammate.velocity = Vector3.ZERO
		teammate.rotation = Vector3.ZERO
		teammate_pitch = 0
		input_age = 0
	if lobby_bridge != null:
		lobby_bridge.hide()
	for bug in bugs:
		bug.queue_free()
	bugs.clear()
	wave = 0
	score = 0
	power = 1
	reach = 3.5
	interval = 0.43
	player.position = Vector3(-1.2 if coop.online else 0.0,0.9,10)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	music.play()
	next_round()

func next_round() -> void:
	wave += 1
	elapsed = 0
	var count := mini(4 + wave * 2,28)
	if coop.online:
		count = mini(int(count * 1.5),42)
	round_duration = 25.0 + count * 2.8 / (1.5 if coop.online else 1.0)
	remaining = round_duration
	cooldown = 0
	for i in range(count):
		var bug := Bug.new()
		add_child(bug)
		bug.position = Vector3(randf_range(-3.8,3.8),1.4,randf_range(-9,5))
		bug.configure(1 + mini((wave - 1) / 3,5), 0.85 + wave * 0.16, i * 2.1)
		bug_serial += 1
		bug.set_meta("net_id",bug_serial)
		bugs.append(bug)
	resume_play()
	status.text = "ROUND %02d / CLEAR THE SERVER" % wave

func resume_play() -> void:
	if coop.online:
		local_paused = false
		control_serial += 1
		if coop.role == "guest":
			coop.send({"type":"pause","paused":false,"serial":control_serial})
			return
		if remote_paused:
			show_team_pause()
			return
	enter_play()

func enter_play() -> void:
	mode = "playing"
	menu.hide()
	hud.show()
	var capture: bool = not controller_active
	if OS.has_feature("web") and coop.online:
		capture = capture and bool(JavaScriptBridge.eval("navigator.userActivation.isActive",true))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

func round_clear() -> void:
	mode = "upgrade"
	clear_sound.play()
	score += int(remaining) * 10
	store_best()
	show_upgrade_menu()

func show_upgrade_menu() -> void:
	clear_menu("ROUND %02d COMPLETE / %06d POINTS" % [wave,score], "Clean sweep.", "Patch your agent. Choose one upgrade for the next round.\nThe next infestation will be faster and tougher.")
	if coop.online:
		menu_box.add_child(label("Shared score · The host picks one upgrade for BOTH agents.",18,LIME))
		if coop.role == "guest":
			button("Leave session",show_title).grab_focus()
			return
	button("1  /  Hotfix        +1 swat damage",func(): apply_upgrade(0),true).grab_focus()
	button("2  /  Long arm     +0.7 m reach",func(): apply_upgrade(1))
	button("3  /  Overclock    18% faster swats",func(): apply_upgrade(2))

func apply_upgrade(index: int) -> void:
	if mode != "upgrade" or coop.role == "guest" or index not in [0,1,2]:
		return
	if index == 0:
		power += 1
	elif index == 1:
		reach += 0.7
	else:
		interval = maxf(0.1,interval * 0.82)
	next_round()

func game_over() -> void:
	mode = "over"
	store_best()
	show_over_menu()

func show_over_menu() -> void:
	clear_menu("SESSION TERMINATED / ROUND %02d" % wave,"Time out.", "The remaining bugs escaped your patch.\nScore  %06d     ·     Best  %06d\nTake another run at the server." % [score,best])
	if coop.role == "guest":
		button("Waiting for host to restart · Leave session",show_title,true).grab_focus()
		return
	button("Reinitialize  →",start_run,true).grab_focus()
	button("Back to briefing",show_title)

func pause_game() -> void:
	if coop.online and mode in ["playing","paused"]:
		local_paused = not local_paused
		control_serial += 1
		if coop.role == "guest":
			coop.send({"type":"pause","paused":local_paused,"serial":control_serial})
		update_team_pause()
		return
	if mode == "playing":
		mode = "paused"
		clear_menu("AGENT ON STANDBY", "Paused.", "The round clock is stopped. Ready when you are.")
		button("Resume  →",resume_play,true).grab_focus()
		button("Music & effects: " + ("off" if muted else "on"),func(): toggle_mute(); pause_menu_refresh())
		button("End run",game_over)
	elif mode == "paused":
		resume_play()

func pause_menu_refresh() -> void:
	if coop.online:
		show_team_pause()
		return
	mode = "playing"
	pause_game()

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0,muted)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		controller_active = true
	elif event is InputEventMouseButton or event is InputEventKey:
		controller_active = false

func _unhandled_input(event: InputEvent) -> void:
	if mode == "playing" and event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("mute_game"):
		toggle_mute()
	if event.is_action_pressed("pause_game"):
		pause_game()
		get_viewport().set_input_as_handled()
	if mode == "playing" and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotation.y -= event.relative.x * look_sensitivity
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * look_sensitivity,-1.25,1.25)
	if mode == "upgrade" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
			apply_upgrade(event.physical_keycode - KEY_1)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		focus_lost()

func focus_lost() -> void:
	if coop != null and coop.online and mode in ["playing","paused"]:
		if not local_paused:
			pause_game()
	elif mode == "playing":
		pause_game()

func _physics_process(delta: float) -> void:
	if mode != "playing":
		return
	elapsed += delta
	if coop.role != "guest":
		remaining = maxf(0,remaining-delta)
	if remaining <= 0 and coop.role != "guest":
		game_over()
		return
	var pad_ids := Input.get_connected_joypads()
	if not pad_ids.is_empty():
		var pad: int = pad_ids[0]
		var look := Vector2(Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X),Input.get_joy_axis(pad,JOY_AXIS_RIGHT_Y))
		if look.length() > 0.18:
			look = look.normalized() * ((look.length()-0.18)/0.82)
			player.rotation.y -= look.x * delta * 2.4
			camera.rotation.x = clampf(camera.rotation.x - look.y * delta * 2.1,-1.25,1.25)
	var move := Input.get_vector("left","right","forward","back")
	var dir := player.transform.basis * Vector3(move.x,0,move.y)
	var speed_: float = 9.0 if Input.is_action_pressed("sprint") else 6.0
	player.velocity.x = dir.x * speed_
	player.velocity.z = dir.z * speed_
	if not player.is_on_floor():
		player.velocity.y -= 24 * delta
	elif Input.is_action_just_pressed("jump"):
		player.velocity.y = 8
	player.move_and_slide()
	if Input.is_action_just_pressed("jump"):
		jump_pending = true
	if coop.role != "guest":
		if coop.online:
			step_teammate(delta)
		for bug in bugs:
			var target := player.position
			if teammate != null and bug.position.distance_squared_to(teammate.position) < bug.position.distance_squared_to(target):
				target = teammate.position
			bug.step(delta,target)
	cooldown = maxf(0,cooldown-delta)
	if Input.is_action_pressed("swat") and cooldown <= 0:
		attack()
	swing = maxf(0,swing-delta)
	var motion := sin(swing / 0.24 * PI)
	weapon.rotation_degrees = Vector3(-18 - motion * 65,-12 + motion * 30,-12 - motion * 24)
	weapon.position = Vector3(0.48,-0.65 + motion * 0.12,-0.75 + motion * -0.25)
	weapon.position.y += sin(elapsed * 10) * move.length() * 0.015
	hit_marker = maxf(0,hit_marker-delta)
	update_hud()

func attack() -> void:
	if mode != "playing" or cooldown > 0:
		return
	cooldown = interval
	swing = 0.24
	swat_sound.pitch_scale = randf_range(0.92,1.08)
	swat_sound.play()
	if coop.role == "guest":
		coop.send({"type":"swat"})
		return
	authority_swat(player,camera.global_position,-camera.global_basis.z,0)

func authority_swat(body: CharacterBody3D, origin: Vector3, forward: Vector3, agent: int) -> void:
	if mode != "playing" or coop.role == "guest":
		return
	var target: Node3D = null
	var closest: float = reach + 0.001
	for bug in bugs:
		var offset: Vector3 = bug.global_position - origin
		var distance: float = offset.length()
		if distance < closest and forward.dot(offset.normalized()) > 0.82:
			var ray := PhysicsRayQueryParameters3D.create(origin,bug.global_position,1,[body.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				target = bug
				closest = distance
	if target:
		if agent == 0:
			hit_sound.pitch_scale = randf_range(0.9,1.15)
			hit_sound.play()
			hit_marker = 0.18
		else:
			coop.send({"type":"hit"})
		if target.damage(power):
			score += 100 + wave * 25
			team_kills[agent] += 1
			bugs.erase(target)
			var tween := create_tween()
			tween.tween_property(target,"scale",Vector3.ONE*0.01,0.16)
			tween.tween_callback(target.queue_free)
			if bugs.is_empty():
				round_clear()

func update_hud() -> void:
	stats.text = "ROUND %02d    /    %02d BUGS" % [wave,bugs.size()]
	time_label.text = "%02d:%02d  REMAINING" % [int(remaining)/60,int(remaining)%60]
	time_label.modulate = Color("ff936f") if remaining < 10 else WHITE
	timer_bar.value = remaining / round_duration * 100
	score_label.text = "SCORE %06d\nDMG %d  ·  REACH %.1fm  ·  %.2fs" % [score,power,reach,interval]
	if coop.online:
		score_label.text = "TEAM %06d · HOST %d / GUEST %d\nDMG %d · REACH %.1fm · %.2fs" % [score,team_kills[0],team_kills[1],power,reach,interval]
	var nearest: Node3D = null
	var distance: float = INF
	for bug in bugs:
		var dist: float = camera.global_position.distance_to(bug.global_position)
		if dist < distance:
			distance = dist
			nearest = bug
	if nearest:
		var local: Vector3 = camera.to_local(nearest.global_position)
		var dot: float = (-camera.global_basis.z).dot((nearest.global_position-camera.global_position).normalized())
		var heading: String = "AHEAD" if dot > 0.7 else ("BEHIND" if dot < -0.7 else ("LEFT" if local.x < 0 else "RIGHT"))
		tracker.text = "NEAREST BUG  /  %s  /  %.1f m\nWASD + MOUSE or XBOX  ·  ESC / START pause  ·  M mute" % [heading,distance]
		crosshair.text = "×" if hit_marker > 0 else ("⊕" if distance < reach and dot > 0.82 else "+")
	if elapsed > 2:
		status.text = ""

func _process(delta: float) -> void:
	process_coop(delta)
	debug_tick += delta
	if OS.has_feature("web") and debug_tick > 0.25:
		debug_tick = 0
		var state := {"mode":mode,"wave":wave,"score":score,"best":best,"bugs":bugs.size(),"remaining":remaining,"power":power,"reach":reach,"interval":interval,"position":[player.position.x,player.position.y,player.position.z],"rotation":[player.rotation.y,camera.rotation.x],"joypads":Input.get_connected_joypads(),"a_pressed":Input.is_joy_button_pressed(0,JOY_BUTTON_A),"role":coop.role,"connected":coop.online,"network":coop.network_mode,"run":run_id,"kills":team_kills,"teammate":vec(teammate.position) if teammate != null else [],"bug_state":bug_snapshot()}
		JavaScriptBridge.eval("window.agentgamesState=" + JSON.stringify(state),true)

func load_best() -> void:
	if FileAccess.file_exists("user://score.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://score.json"))
		if data is Dictionary:
			best = int(data.get("best",0))

func store_best() -> void:
	if score > best:
		best = score
		var file := FileAccess.open("user://score.json",FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"best":best}))

func open_coop(kind: String, network: String = "") -> void:
	if network.is_empty():
		network = coop.network_mode
	mode = "lobby"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.hide()
	hud.hide()
	if lobby_bridge != null:
		lobby_bridge.show(kind)
	coop.begin(kind,network)

func refresh_pairing() -> void:
	if lobby_bridge != null and mode == "lobby":
		lobby_bridge.update(JSON.stringify({"role":coop.role,"code":coop.code,"addresses":coop.addresses,"notice":coop.notice,"connected":coop.online,"ready":agent_ready if coop.role == "guest" else peer_ready,"failed":coop.failed,"network":coop.network_mode,"received_invitation":coop.remote_applied,"started":coop.peer != null}))

func leave_coop() -> void:
	if coop != null:
		coop.close()
	if lobby_bridge != null:
		lobby_bridge.hide()
	if teammate != null:
		teammate.queue_free()
	teammate = null
	local_paused = false
	remote_paused = false
	teammate_input = {}
	control_serial = 0
	last_control = -1
	agent_ready = false
	peer_ready = false

func coop_connected() -> void:
	if teammate == null:
		create_teammate()
	refresh_pairing()

func coop_disconnected(reason: String) -> void:
	mode = "disconnected"
	if lobby_bridge != null:
		lobby_bridge.hide()
	if teammate != null:
		teammate.hide()
	clear_menu("CO-OP SESSION STOPPED","Disconnected.",reason + "\nNo gameplay relay is configured. Both players can create a fresh invitation.")
	button("Retry pairing",retry_coop,true).grab_focus()
	button("Back to briefing",show_title)

func retry_coop() -> void:
	var kind: String = coop.role
	var network: String = coop.network_mode
	leave_coop()
	open_coop(kind,network)

func create_teammate() -> void:
	teammate = CharacterBody3D.new()
	teammate.position = Vector3(1.2,0.9,10)
	# Agents do not block each other or the swatting rays.
	teammate.collision_layer = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.7
	capsule.radius = 0.35
	collision.shape = capsule
	teammate.add_child(collision)
	add_child(teammate)
	var avatar := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.height = 1.7
	body_mesh.radius = 0.35
	avatar.mesh = body_mesh
	avatar.material_override = material(Color("71bdb9"),0.25)
	teammate.add_child(avatar)
	var face := MeshInstance3D.new()
	var visor := BoxMesh.new()
	visor.size = Vector3(0.5,0.17,0.16)
	face.mesh = visor
	face.position = Vector3(0,0.5,-0.29)
	face.material_override = material(LIME,0.5)
	teammate.add_child(face)
	var nameplate := Label3D.new()
	nameplate.text = "GUEST AGENT" if coop.role == "host" else "HOST AGENT"
	nameplate.position.y = 1.2
	nameplate.font_size = 40
	nameplate.pixel_size = 0.005
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.modulate = LIME
	teammate.add_child(nameplate)
	teammate_weapon = preload("res://assets/models/swatter.glb").instantiate()
	teammate_weapon.position = Vector3(0.5,0.1,-0.7)
	teammate.add_child(teammate_weapon)

func process_coop(delta: float) -> void:
	if lobby_bridge != null:
		var raw: String = lobby_bridge.take()
		if not raw.is_empty():
			var commands = JSON.parse_string(raw)
			if commands is Array:
				for command in commands:
					match command.get("type",""):
						"host", "guest": open_coop(command.type)
						"network":
							if mode == "lobby" and coop.role == "host" and not coop.online and command.get("network") in ["auto","lan"]:
								leave_coop()
								open_coop("host",command.network)
						"invite":
							if mode == "lobby" and coop.role == "host" and not coop.online:
								coop.create_invitation()
						"code": coop.accept_code(str(command.get("code","")))
						"ready":
							if coop.role == "guest" and coop.online:
								agent_ready = true
								music.play()
								refresh_pairing()
						"start":
							if coop.role == "host" and coop.online and mode == "lobby": start_run()
						"leave": show_title()
						"focus_lost": focus_lost()
	if not coop.online:
		return
	if coop.role == "host":
		input_age += delta
		if mode == "playing" and input_age > 1.5:
			remote_paused = true
			update_team_pause()
	net_tick += delta
	if net_tick >= 0.05:
		net_tick = 0
		if coop.role == "host":
			if mode in ["playing","paused","upgrade","over"]:
				coop.send(snapshot())
		else:
			var movement := Input.get_vector("left","right","forward","back") if mode == "playing" else Vector2.ZERO
			coop.send({"type":"input","move":[movement.x,movement.y],"yaw":player.rotation.y,"pitch":camera.rotation.x,"sprint":Input.is_action_pressed("sprint"),"jump":jump_pending,"paused":local_paused,"serial":control_serial,"ready":agent_ready})
			jump_pending = false
	teammate_swing = maxf(0,teammate_swing-delta)
	if teammate_weapon != null:
		teammate_weapon.rotation.x = -sin(teammate_swing / 0.24 * PI) * 1.3

func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func receive_packet(data: Dictionary) -> void:
	if not coop.online:
		return
	var kind = data.get("type","")
	if coop.role == "host":
		if kind == "input":
			var move = data.get("move")
			if not (move is Array) or move.size() != 2 or not finite_number(move[0]) or not finite_number(move[1]) or not finite_number(data.get("yaw")) or not finite_number(data.get("pitch")):
				return
			input_age = 0
			if peer_ready != (data.get("ready") == true):
				peer_ready = data.get("ready") == true
				refresh_pairing()
			teammate_input = {"move":Vector2(clampf(float(move[0]),-1,1),clampf(float(move[1]),-1,1)).limit_length(),"sprint":data.get("sprint") == true,"jump":teammate_input.get("jump",false) or data.get("jump") == true,"swat":teammate_input.get("swat",false)}
			teammate.rotation.y = wrapf(float(data.yaw),-PI,PI)
			teammate_pitch = clampf(float(data.pitch),-1.25,1.25)
			accept_pause(data)
		elif kind == "pause":
			accept_pause(data)
		elif kind == "swat" and mode == "playing":
			teammate_input["swat"] = true
		# All other guest messages (scores, positions, upgrades, snapshots) are ignored.
	else:
		if kind == "state":
			apply_snapshot(data)
		elif kind == "hit":
			hit_marker = 0.18
			hit_sound.play()

func accept_pause(data: Dictionary) -> void:
	if not (data.get("paused") is bool) or not finite_number(data.get("serial")):
		return
	var serial := int(data.serial)
	if serial < last_control:
		return
	last_control = serial
	var changed: bool = remote_paused != data.paused
	remote_paused = data.paused
	if changed:
		update_team_pause()

func update_team_pause() -> void:
	if mode not in ["playing","paused"]:
		return
	if local_paused or remote_paused:
		if mode != "paused":
			mode = "paused"
		show_team_pause()
	elif coop.role == "host":
		enter_play()

func show_team_pause() -> void:
	mode = "paused"
	clear_menu("BOTH AGENTS ON STANDBY","Paused.","The team clock is stopped. Each paused player must resume.\nYour agent: %s · Teammate: %s" % ["paused" if local_paused else "ready","paused" if remote_paused else "ready"])
	button("Resume my agent  →",resume_play,true).grab_focus()
	button("Music & effects: " + ("off" if muted else "on"),func(): toggle_mute(); show_team_pause())
	button("Leave session",show_title)

func step_teammate(delta: float) -> void:
	if teammate == null:
		return
	var movement: Vector2 = teammate_input.get("move",Vector2.ZERO)
	var direction := teammate.transform.basis * Vector3(movement.x,0,movement.y)
	var speed_: float = 9.0 if teammate_input.get("sprint",false) else 6.0
	teammate.velocity.x = direction.x * speed_
	teammate.velocity.z = direction.z * speed_
	if not teammate.is_on_floor():
		teammate.velocity.y -= 24 * delta
	elif teammate_input.get("jump",false):
		teammate.velocity.y = 8
	teammate_input["jump"] = false
	teammate.move_and_slide()
	teammate_cooldown = maxf(0,teammate_cooldown-delta)
	if teammate_input.get("swat",false) and teammate_cooldown <= 0:
		teammate_cooldown = interval
		teammate_swing = 0.24
		var forward := -Basis(Vector3.UP,teammate.rotation.y).z
		forward = forward * cos(teammate_pitch) + Vector3.UP * sin(teammate_pitch)
		authority_swat(teammate,teammate.position + Vector3(0,0.65,0),forward,1)
	teammate_input["swat"] = false

func vec(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func unvec(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func bug_snapshot() -> Array:
	var result: Array = []
	for bug in bugs:
		result.append({"id":bug.get_meta("net_id",0),"p":vec(bug.position),"yaw":bug.rotation.y,"hp":bug.hp,"max_hp":bug.max_hp})
	return result

func snapshot() -> Dictionary:
	return {"type":"state","run":run_id,"mode":mode,"wave":wave,"score":score,"remaining":remaining,"duration":round_duration,"power":power,"reach":reach,"interval":interval,"kills":team_kills,"host":vec(player.position),"guest":vec(teammate.position),"yaw":player.rotation.y,"swing":swing,"guest_swing":teammate_swing,"host_paused":local_paused,"bugs":bug_snapshot()}

func apply_snapshot(data: Dictionary) -> void:
	if not (data.get("bugs") is Array) or data.bugs.size() > 42 or data.get("mode") not in ["playing","paused","upgrade","over"]:
		return
	var reset: bool = run_id != int(data.run)
	run_id = int(data.run)
	wave = int(data.wave)
	score = int(data.score)
	remaining = float(data.remaining)
	round_duration = float(data.duration)
	power = int(data.power)
	reach = float(data.reach)
	interval = float(data.interval)
	team_kills.assign(data.kills)
	remote_paused = data.host_paused
	if reset:
		local_paused = false
		player.position = unvec(data.guest)
		player.velocity = Vector3.ZERO
		player.rotation = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		cooldown = 0
		jump_pending = false
		music.play()
		if lobby_bridge != null: lobby_bridge.hide()
	elif player.position.distance_to(unvec(data.guest)) > 0.8:
		player.position = player.position.lerp(unvec(data.guest),0.4)
	teammate.position = unvec(data.host)
	teammate.rotation.y = float(data.yaw)
	teammate_swing = float(data.swing)
	var active: Array = []
	for record in data.bugs:
		var bug: Node3D = null
		for existing in bugs:
			if existing.get_meta("net_id") == int(record.id):
				bug = existing
				break
		if bug == null:
			bug = Bug.new()
			add_child(bug)
			bug.configure(int(record.max_hp),0,0)
			bug.set_meta("net_id",int(record.id))
			bugs.append(bug)
		bug.position = unvec(record.p)
		bug.rotation.y = float(record.yaw)
		bug.hp = int(record.hp)
		bug.update_bar()
		active.append(int(record.id))
	for bug in bugs.duplicate():
		if bug.get_meta("net_id") not in active:
			bugs.erase(bug)
			bug.queue_free()
	var next_mode: String = data.mode
	if next_mode == "playing" and local_paused:
		next_mode = "paused"
	if mode != next_mode or reset:
		mode = next_mode
		match mode:
			"playing": enter_play()
			"paused": show_team_pause()
			"upgrade": show_upgrade_menu(); clear_sound.play(); store_best()
			"over": show_over_menu(); store_best()
	update_hud()
