extends Node3D

const Bug = preload("res://src/bug.gd")
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

func _ready() -> void:
	setup_input()
	load_best()
	create_world()
	create_player()
	create_audio()
	create_hud()
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
	mode = "title"
	clear_menu("AGENT OPERATIONS / FIRST-PERSON SWATTER", "Debug.", "The server has a bug problem. You are the fix.\nClear every bug before the clock runs out. Choose an upgrade after each clean sweep.")
	button("Initialize agent  →",start_run,true).grab_focus()
	menu_box.add_child(label("WASD  Move   ·   Mouse  Look   ·   Click  Swat\nShift  Sprint   ·   Space  Jump   ·   Esc  Pause\nXbox: sticks move/look · RT swat · A jump · Start pause",18,Color("b1c7be")))
	menu_box.add_child(label("LOCAL BEST  %06d   /   SOLO SESSION" % best,18,LIME))

func start_run() -> void:
	for bug in bugs:
		bug.queue_free()
	bugs.clear()
	wave = 0
	score = 0
	power = 1
	reach = 3.5
	interval = 0.43
	player.position = Vector3(0,0.9,10)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	music.play()
	next_round()

func next_round() -> void:
	wave += 1
	elapsed = 0
	var count := mini(4 + wave * 2,28)
	round_duration = 25.0 + count * 2.8
	remaining = round_duration
	cooldown = 0
	for i in range(count):
		var bug := Bug.new()
		add_child(bug)
		bug.position = Vector3(randf_range(-3.8,3.8),1.4,randf_range(-9,5))
		bug.configure(1 + mini((wave - 1) / 3,5), 0.85 + wave * 0.16, i * 2.1)
		bugs.append(bug)
	resume_play()
	status.text = "ROUND %02d / CLEAR THE SERVER" % wave

func resume_play() -> void:
	mode = "playing"
	menu.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if controller_active else Input.MOUSE_MODE_CAPTURED

func round_clear() -> void:
	mode = "upgrade"
	clear_sound.play()
	score += int(remaining) * 10
	store_best()
	clear_menu("ROUND %02d COMPLETE / %06d POINTS" % [wave,score], "Clean sweep.", "Patch your agent. Choose one upgrade for the next round.\nThe next infestation will be faster and tougher.")
	button("1  /  Hotfix        +1 swat damage",func(): apply_upgrade(0),true).grab_focus()
	button("2  /  Long arm     +0.7 m reach",func(): apply_upgrade(1))
	button("3  /  Overclock    18% faster swats",func(): apply_upgrade(2))

func apply_upgrade(index: int) -> void:
	if mode != "upgrade":
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
	clear_menu("SESSION TERMINATED / ROUND %02d" % wave,"Time out.", "The remaining bugs escaped your patch.\nScore  %06d     ·     Best  %06d\nTake another run at the server." % [score,best])
	button("Reinitialize  →",start_run,true).grab_focus()
	button("Back to briefing",show_title)

func pause_game() -> void:
	if mode == "playing":
		mode = "paused"
		clear_menu("AGENT ON STANDBY", "Paused.", "The round clock is stopped. Ready when you are.")
		button("Resume  →",resume_play,true).grab_focus()
		button("Music & effects: " + ("off" if muted else "on"),func(): toggle_mute(); pause_menu_refresh())
		button("End run",game_over)
	elif mode == "paused":
		resume_play()

func pause_menu_refresh() -> void:
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing":
		pause_game()

func _physics_process(delta: float) -> void:
	if mode != "playing":
		return
	elapsed += delta
	remaining = maxf(0,remaining-delta)
	if remaining <= 0:
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
	for bug in bugs:
		bug.step(delta,player.position)
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
	var target: Node3D = null
	var closest: float = reach + 0.001
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	for bug in bugs:
		var offset: Vector3 = bug.global_position - origin
		var distance: float = offset.length()
		# A broad short-range swatting arc supports mouse and controller aim.
		if distance < closest and forward.dot(offset.normalized()) > 0.82:
			var ray := PhysicsRayQueryParameters3D.create(origin,bug.global_position,1,[player.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				target = bug
				closest = distance
	if target:
		hit_sound.pitch_scale = randf_range(0.9,1.15)
		hit_sound.play()
		hit_marker = 0.18
		if target.damage(power):
			score += 100 + wave * 25
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
	debug_tick += delta
	if OS.has_feature("web") and debug_tick > 0.25:
		debug_tick = 0
		var state := {"mode":mode,"wave":wave,"score":score,"best":best,"bugs":bugs.size(),"remaining":remaining,"power":power,"reach":reach,"interval":interval,"position":[player.position.x,player.position.y,player.position.z],"rotation":[player.rotation.y,camera.rotation.x],"joypads":Input.get_connected_joypads(),"a_pressed":Input.is_joy_button_pressed(0,JOY_BUTTON_A)}
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
