extends Node3D

const SPEED = 6.0
const JUMP_FORCE = 9.0
const GRAVITY = 20.0

var player: CharacterBody3D
var body_mesh: MeshInstance3D
var camera: Camera3D
var ui: Control

var u = 1.0
var stick = Vector2.ZERO
var stick_finger = -1
var stick_center = Vector2.ZERO
var knob_pos = Vector2.ZERO
var jump_pos = Vector2.ZERO
var hit_pos = Vector2.ZERO
var jump_finger = -1
var hit_finger = -1

func _ready():
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)

	# Пол и две ступеньки
	make_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.4, 0.7, 0.4))
	make_box(Vector3(3, 0.5, -3), Vector3(4, 1, 4), Color(0.8, 0.6, 0.3))
	make_box(Vector3(7, 1, -3), Vector3(4, 2, 4), Color(0.7, 0.4, 0.3))

	# Медведь (пока капсула)
	player = CharacterBody3D.new()
	player.position = Vector3(0, 2, 5)
	body_mesh = MeshInstance3D.new()
	body_mesh.mesh = CapsuleMesh.new()
	var col = CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	player.add_child(body_mesh)
	player.add_child(col)
	add_child(player)

	camera = Camera3D.new()
	add_child(camera)

	# Слой с кнопками
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	layer.add_child(ui)
	get_viewport().size_changed.connect(_layout)
	_layout()

func make_box(pos: Vector3, size: Vector3, color: Color):
	var body = StaticBody3D.new()
	body.position = pos
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	mesh.mesh = box
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mesh)
	body.add_child(col)
	add_child(body)

func _layout():
	var s = get_viewport().get_visible_rect().size
	u = s.y / 720.0
	stick_center = Vector2(s.x * 0.16, s.y * 0.73)
	jump_pos = Vector2(s.x * 0.77, s.y * 0.675)
	hit_pos = Vector2(s.x * 0.90, s.y * 0.625)
	if stick_finger == -1:
		knob_pos = stick_center
	ui.queue_redraw()

func _draw_ui():
	# Джойстик
	ui.draw_circle(stick_center, 128 * u, Color.WHITE)
	ui.draw_arc(stick_center, 124 * u, 0, TAU, 64, Color.BLACK, 8 * u)
	ui.draw_circle(knob_pos, 48 * u, Color.BLACK)
	var g = Color(0.3, 0.3, 0.3)
	for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		ui.draw_circle(knob_pos + d * 26 * u, 6 * u, g)
	ui.draw_circle(knob_pos, 6 * u, g)

	# Кнопка прыжка
	_draw_button(jump_pos, jump_finger != -1)
	var arrow = [Vector2(0, -45), Vector2(32, -5), Vector2(10, -5), Vector2(10, 45), Vector2(-10, 45), Vector2(-10, -5), Vector2(-32, -5)]
	var pts = PackedVector2Array()
	for p in arrow:
		pts.append(jump_pos + p * u)
	ui.draw_colored_polygon(pts, Color.BLACK)

	# Кнопка удара
	_draw_button(hit_pos, hit_finger != -1)
	var star = PackedVector2Array()
	for i in 24:
		var ang = TAU * i / 24.0
		var r = (46 if i % 2 == 0 else 24) * u
		star.append(hit_pos + Vector2(cos(ang), sin(ang)) * r)
	ui.draw_colored_polygon(star, Color.BLACK)

func _draw_button(pos: Vector2, pressed: bool):
	var c = Color(0.5, 0.5, 0.5) if pressed else Color(0.62, 0.62, 0.62)
	ui.draw_circle(pos, 92 * u, c)
	ui.draw_arc(pos, 88 * u, 0, TAU, 64, Color.BLACK, 8 * u)

func _input(event):
	if event is InputEventScreenTouch:
		var p = event.position
		if event.pressed:
			if stick_finger == -1 and p.distance_to(stick_center) < 170 * u:
				stick_finger = event.index
				_move_stick(p)
			elif jump_finger == -1 and p.distance_to(jump_pos) < 100 * u:
				jump_finger = event.index
				jump()
			elif hit_finger == -1 and p.distance_to(hit_pos) < 100 * u:
				hit_finger = event.index
				hit()
		else:
			if event.index == stick_finger:
				stick_finger = -1
				stick = Vector2.ZERO
				knob_pos = stick_center
			if event.index == jump_finger:
				jump_finger = -1
			if event.index == hit_finger:
				hit_finger = -1
		ui.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == stick_finger:
			_move_stick(event.position)
			ui.queue_redraw()

	# Для проверки на компьютере: пробел - прыжок, F - удар
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			jump()
		if event.keycode == KEY_F:
			hit()

func _move_stick(p: Vector2):
	var off = p - stick_center
	var max_r = 80 * u
	if off.length() > max_r:
		off = off.normalized() * max_r
	knob_pos = stick_center + off
	stick = off / max_r
	if stick.length() < 0.15:
		stick = Vector2.ZERO

func _physics_process(delta):
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	var dir = stick
	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.velocity.x = dir.x * SPEED
	player.velocity.z = dir.y * SPEED
	player.move_and_slide()

func _process(_delta):
	camera.position = player.position + Vector3(0, 5, 9)
	camera.look_at(player.position + Vector3(0, 1, 0))

func jump():
	if player.is_on_floor():
		player.velocity.y = JUMP_FORCE

func hit():
	# Пока удар просто сжимает медведя, потом сделаем настоящий
	var t = create_tween()
	t.tween_property(body_mesh, "scale", Vector3(1.4, 0.8, 1.4), 0.08)
	t.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)
