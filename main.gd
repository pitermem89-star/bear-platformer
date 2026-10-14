extends Node3D

const SPEED = 6.0
const JUMP_FORCE = 8.0
const GRAVITY = 20.0

var player: CharacterBody3D
var camera: Camera3D
var touch_dir = 0.0

func _ready():
	# Свет
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)

	# Пол
	var floor_body = StaticBody3D.new()
	floor_body.position = Vector3(0, -0.5, 0)
	var floor_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(30, 1, 4)
	floor_mesh.mesh = box
	var floor_col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(30, 1, 4)
	floor_col.shape = box_shape
	floor_body.add_child(floor_mesh)
	floor_body.add_child(floor_col)
	add_child(floor_body)

	# Медведь (пока капсула)
	player = CharacterBody3D.new()
	player.position = Vector3(-8, 2, 0)
	var body_mesh = MeshInstance3D.new()
	body_mesh.mesh = CapsuleMesh.new()
	var body_col = CollisionShape3D.new()
	body_col.shape = CapsuleShape3D.new()
	player.add_child(body_mesh)
	player.add_child(body_col)
	add_child(player)

	# Камера
	camera = Camera3D.new()
	add_child(camera)

func _physics_process(delta):
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta

	# Клавиатура или касание
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir == 0:
		dir = touch_dir
	player.velocity.x = dir * SPEED
	player.velocity.z = 0
	player.move_and_slide()

func _process(_delta):
	# Камера следит за медведем сбоку-сзади
	camera.position = player.position + Vector3(0, 3, 8)
	camera.look_at(player.position + Vector3(0, 1, 0))

func _input(event):
	# Касание: левая половина экрана - влево, правая - вправо
	if event is InputEventScreenTouch:
		if event.pressed:
			var half = get_viewport().get_visible_rect().size.x / 2.0
			touch_dir = -1.0 if event.position.x < half else 1.0
			jump()
		else:
			touch_dir = 0.0

	# Для теста на компьютере: пробел - прыжок
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			jump()

func jump():
	if player.is_on_floor():
		player.velocity.y = JUMP_FORCE
