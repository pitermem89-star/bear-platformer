extends Node3D

const SPEED = 6.0
const JUMP_FORCE = 9.0
const GRAVITY = 20.0
const MAX_JUMPS = 2
const CAM_DIST = 5.0

var player: CharacterBody3D
var model: Node3D
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
var cam_pos = Vector2.ZERO
var jump_finger = -1
var hit_finger = -1
var look_finger = -1

var yaw = 0.0
var pitch = -0.4
var first_person = false
var jumps_used = 0

func _ready():
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)

	# Пол и две ступеньки
	make_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.4, 0.7, 0.4))
	make_box(Vector3(3, 0.5, -3), Vector3(4, 1, 4), Color(0.8, 0.6, 0.3))
	make_box(Vector3(7, 1, -3), Vector3(4, 2, 4), Color(0.7, 0.4, 0.3))

	# Медведь: капсула + носик, чтобы было видно, куда он смотрит
	player = CharacterBody3D.new()
	player.position = Vector3(0, 2, 5)
	model = Node3D.new()
	player.add_child(model)

	body_mesh = MeshInstance3D.new()
	body_mesh.mesh = CapsuleMesh.new()
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.6, 0.4, 0.25)
	body_mesh.material_override = body_mat
	model.add_child(body_mesh)

	var nose = MeshInstance3D.new()
	var nose_box = BoxMesh.new()
	nose_box.size = Vector3(0.3, 0.3, 0.4)
	var nose_mat = StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.1, 0.1, 0.1)
	nose_box.material = nose_mat
	nose.mesh = nose_box
	nose.position = Vector3(0, 0.4, -0.5)
	model.add_child(nose)

	var col = CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
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
	cam_pos = Vector2(s.x * 0.94, s.y * 0.14)
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
	_draw_button(jump_pos, 92, jump_finger != -1)
	var arrow = [Vector2(0, -45), Vector2(32, -5), Vector2(10, -5), Vector2(10, 45), Vector2(-10, 45), Vector2(-10, -5), Vector2(-32, -5)]
	var pts = PackedVector2Array()
	for p in arrow:
		pts.append(jump_pos + p * u)
	ui.draw_colored_polygon(pts, Color.BLACK)

	# Кнопка удара
	_draw_button(hit_pos, 92, hit_finger != -1)
	var star = PackedVector2Array()
	for i in 24:
		var ang = TAU * i / 24.0
		var r = (46 if i % 2 == 0 else 24) * u
		star.append(hit_pos + Vector2(cos(ang), sin(ang)) * r)
	ui.draw_colored_polygon(star, Color.BLACK)

	# Кнопка камеры (глаз). Темнее, когда включён вид от 1 лица
	_draw_button(cam_pos, 52, first_person)
	var eye = PackedVector2Array()
	for i in range(0, 17):
		var t = i / 16.0
		eye.append(cam_pos + Vector2(lerp(-34.0, 34.0, t), -18.0 * sin(PI * t)) * u * 0.8)
	for i in range(15, 0, -1):
		var t = i / 16.0
		eye.append(cam_pos + Vector2(lerp(-34.0, 34.0, t), 18.0 * sin(PI * t)) * u * 0.8)
	ui.draw_colored_polygon(eye, Color.BLACK)
	ui.draw_circle(cam_pos, 11 * u, Color.WHITE)
	ui.draw_circle(cam_pos, 6 * u, Color.BLACK)

func _draw_button(pos: Vector2, radius: float, pressed: bool):
	var c = Color(0.5, 0.5, 0.5) if pressed else Color(0.62, 0.62, 0.62)
	ui.draw_circle(pos, radius * u, c)
	ui.draw_arc(pos, (radius - 4) * u, 0, TAU, 64, Color.BLACK, 8 * u)

func _on_control(p: Vector2) -> bool:
	return p.distance_to(stick_center) < 170 * u \
		or p.distance_to(jump_pos) < 100 * u \
		or p.distance_to(hit_pos) < 100 * u \
		or p.distance_to(cam_pos) < 60 * u

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
			elif p.distance_to(cam_pos) < 60 * u:
				toggle_view()
			elif look_finger == -1 and not _on_control(p):
				# Палец на свободном месте экрана крутит камеру
				look_finger = event.index
		else:
			if event.index == stick_finger:
				stick_finger = -1
				stick = Vector2.ZERO
				knob_pos = stick_center
			if event.index == jump_finger:
				jump_finger = -1
			if event.index == hit_finger:
				hit_finger = -1
			if event.index == look_finger:
				look_finger = -1
		ui.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == stick_finger:
			_move_stick(event.position)
			ui.queue_redraw()
		elif event.index == look_finger:
			yaw -= event.relative.x * 0.005
			pitch -= event.relative.y * 0.005

	# Для проверки на компьютере: пробел - прыжок, F - удар, V - вид
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			jump()
		if event.keycode == KEY_F:
			hit()
		if event.keycode == KEY_V:
			toggle_view()

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
	if player.is_on_floor() and player.velocity.y <= 0:
		jumps_used = 0
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta

	var dir = stick
	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Идём туда, куда смотрит камера
	var move = Vector3(dir.x, 0, dir.y).rotated(Vector3.UP, yaw)
	player.velocity.x = move.x * SPEED
	player.velocity.z = move.z * SPEED
	if move.length() > 0.1:
		var target = atan2(-move.x, -move.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, 0.2)
	player.move_and_slide()

func _process(_delta):
	if first_person:
		pitch = clamp(pitch, -1.5, 1.5)
		camera.rotation = Vector3(pitch, yaw, 0)
		camera.position = player.position + Vector3(0, 0.6, 0)
	else:
		pitch = clamp(pitch, -1.4, -0.05)
		camera.rotation = Vector3(pitch, yaw, 0)
		camera.position = player.position + Vector3(0, 0.8, 0) + camera.basis.z * CAM_DIST

func toggle_view():
	first_person = not first_person
	model.visible = not first_person
	ui.queue_redraw()

func jump():
	if jumps_used < MAX_JUMPS:
		player.velocity.y = JUMP_FORCE
		jumps_used += 1

func hit():
	# Пока удар просто сжимает медведя, потом сделаем настоящий
	var t = create_tween()
	t.tween_property(body_mesh, "scale", Vector3(1.4, 0.8, 1.4), 0.08)
	t.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)
