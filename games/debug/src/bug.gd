extends Node3D

var hp: int = 1
var max_hp: int = 1
var speed: float = 1.0
var phase: float = 0.0
var alive: bool = true
var visual: Node3D
var bar: Label3D
var flash: float = 0.0

func configure(health: int, pace: float, offset: float) -> void:
	hp = health
	max_hp = health
	speed = pace
	phase = offset
	visual = preload("res://assets/models/bug.glb").instantiate()
	add_child(visual)
	bar = Label3D.new()
	bar.position.y = 0.7
	bar.font_size = 42
	bar.pixel_size = 0.006
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.modulate = Color("f8b55d")
	bar.no_depth_test = false
	add_child(bar)
	update_bar()

func update_bar() -> void:
	bar.text = "●".repeat(hp) if max_hp > 1 else ""

func step(delta: float, target: Vector3) -> void:
	if not alive:
		return
	phase += delta * (2.0 + speed * 0.25)
	var offset := Vector3(sin(phase * 0.47), 0, cos(phase * 0.31))
	var direction := target - position
	direction.y = 0
	if direction.length() > 1.6:
		position += (direction.normalized() + offset * 0.4).normalized() * speed * delta
	else:
		position += offset * speed * delta * 0.5
	position.x = clampf(position.x, -4.0, 4.0)
	position.z = clampf(position.z, -10.0, 10.0)
	position.y = 1.35 + sin(phase) * 0.28
	if direction.length() > 0.1:
		rotation.y = atan2(direction.x, direction.z)
	visual.rotation.z = sin(phase * 3.0) * 0.10
	flash = maxf(0, flash - delta)
	visual.scale = Vector3.ONE * (1.15 if flash > 0 else 1.0)

func damage(amount: int) -> bool:
	if not alive:
		return false
	hp = maxi(0, hp - amount)
	flash = 0.14
	update_bar()
	if hp == 0:
		alive = false
		return true
	return false
