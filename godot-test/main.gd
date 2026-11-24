extends Node3D
# Godot-Leistungstest: Gelände, 6000 Bäume, 40 Häuser, 150 laufende Siedler, Schatten + SSAO.

const SIZE := 160.0
var noise := FastNoiseLite.new()
var cam: Camera3D
var pivot := Vector3.ZERO
var yaw := 0.6
var pitch := -0.9
var dist := 45.0
var fps_label: Label
var settlers: Array = []
var dragging := false

func h(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 6.0

func mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _ready() -> void:
	noise.seed = 7
	noise.frequency = 0.012
	_env()
	_ground()
	_trees()
	_houses()
	_settlers()
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)
	_ui()

func _env() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	add_child(sun)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.55, 0.85)
	sm.sky_horizon_color = Color(0.75, 0.82, 0.9)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = Color(0.75, 0.82, 0.9)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 160
	var step := SIZE * 2.0 / n
	for i in n:
		for j in n:
			var x0 := -SIZE + i * step
			var z0 := -SIZE + j * step
			var pts := [Vector3(x0, 0, z0), Vector3(x0 + step, 0, z0), Vector3(x0, 0, z0 + step), Vector3(x0 + step, 0, z0 + step)]
			for p in pts:
				p.y = h(p.x, p.z)
			for idx in [0, 1, 2, 1, 3, 2]:
				var p: Vector3 = pts[idx]
				var g := 0.45 + noise.get_noise_2d(p.x * 3.0, p.z * 3.0) * 0.12
				st.set_color(Color(0.33, g + 0.1, 0.18))
				st.add_vertex(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	add_child(mi)

func _multi(mesh: Mesh, m: Material, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)

func _trees() -> void:
	var trunk := CylinderMesh.new(); trunk.top_radius = 0.12; trunk.bottom_radius = 0.18; trunk.height = 1.6
	var crown := CylinderMesh.new(); crown.top_radius = 0.0; crown.bottom_radius = 1.0; crown.height = 3.0; crown.radial_segments = 8
	var a := []; var b := []
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	while a.size() < 6000:
		var x := rng.randf_range(-SIZE, SIZE); var z := rng.randf_range(-SIZE, SIZE)
		if Vector2(x, z).length() < 25: continue
		if noise.get_noise_2d(x * 2.0 + 50, z * 2.0) < -0.05: continue
		var s := rng.randf_range(0.7, 1.4); var y := h(x, z)
		var basis := Basis().scaled(Vector3(s, s, s))
		a.append(Transform3D(basis, Vector3(x, y + 0.8 * s, z)))
		b.append(Transform3D(basis.rotated(Vector3.UP, rng.randf() * TAU), Vector3(x, y + 2.9 * s, z)))
	_multi(trunk, mat(Color(0.4, 0.27, 0.15)), a)
	_multi(crown, mat(Color(0.16, 0.38, 0.2)), b)

func _houses() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	for i in 40:
		var ang := rng.randf() * TAU; var r := rng.randf_range(4, 22)
		var p := Vector3(cos(ang) * r, 0, sin(ang) * r); p.y = h(p.x, p.z)
		var house := Node3D.new(); house.position = p; house.rotation.y = rng.randf() * TAU
		add_child(house)
		var body := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(2.4, 1.8, 1.9); body.mesh = bm
		body.position.y = 0.9; body.material_override = mat(Color(0.93, 0.88, 0.78)); house.add_child(body)
		for k in 5:
			var beam := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.1, 1.8, 0.05); beam.mesh = bb
			beam.position = Vector3(-1.1 + k * 0.55, 0.9, 0.96); beam.material_override = mat(Color(0.35, 0.2, 0.1)); house.add_child(beam)
		var roof := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(2.7, 1.3, 2.2); roof.mesh = pm
		roof.position.y = 2.45; roof.material_override = mat(Color(0.65, 0.25, 0.15)); house.add_child(roof)

func _settlers() -> void:
	var cm := CapsuleMesh.new(); cm.radius = 0.18; cm.height = 0.9
	var hm := SphereMesh.new(); hm.radius = 0.14; hm.height = 0.28
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i in 150:
		var s := Node3D.new(); add_child(s)
		var body := MeshInstance3D.new(); body.mesh = cm; body.position.y = 0.45
		body.material_override = mat(Color.from_hsv(rng.randf(), 0.6, 0.7)); s.add_child(body)
		var head := MeshInstance3D.new(); head.mesh = hm; head.position.y = 1.0; head.material_override = mat(Color(0.95, 0.8, 0.65)); s.add_child(head)
		s.position = Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
		settlers.append({"n": s, "t": s.position, "ph": rng.randf() * TAU})

func _ui() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	fps_label = Label.new(); fps_label.position = Vector2(12, 8)
	fps_label.add_theme_font_size_override("font_size", 22)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 6)
	cl.add_child(fps_label)

func _process(dt: float) -> void:
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	if Input.is_key_pressed(KEY_Q): yaw += dt * 1.5
	if Input.is_key_pressed(KEY_E): yaw -= dt * 1.5
	pivot += mv.rotated(Vector3.UP, yaw) * dt * dist * 0.8
	pivot.y = h(pivot.x, pivot.z)
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	cam.position = pivot + off
	cam.look_at(pivot)
	for s in settlers:
		var n: Node3D = s.n
		var to: Vector3 = s.t - n.position; to.y = 0
		if to.length() < 0.3:
			s.t = Vector3(randf_range(-22, 22), 0, randf_range(-22, 22))
		else:
			n.position += to.normalized() * dt * 1.6
			n.look_at(Vector3(s.t.x, n.position.y, s.t.z))
		s.ph += dt * 10
		n.position.y = h(n.position.x, n.position.z) + abs(sin(s.ph)) * 0.06
	fps_label.text = "FPS: %d   ·   WASD/Pfeile bewegen · Q/E drehen · Mausrad zoomen · rechte Maus ziehen = drehen" % Engine.get_frames_per_second()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: dist = max(8.0, dist * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = min(140.0, dist * 1.1)
		elif e.button_index == MOUSE_BUTTON_RIGHT: dragging = e.pressed
	elif e is InputEventMouseMotion and dragging:
		yaw -= e.relative.x * 0.005
		pitch = clamp(pitch - e.relative.y * 0.004, -1.45, -0.25)
