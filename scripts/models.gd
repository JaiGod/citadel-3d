extends RefCounted
## Primitive mesh / material helpers plus every tower and enemy model. No imported assets.

const D = preload("res://scripts/data.gd")

static var _meshes := {}
static var _mats := {}

const GOLD := Color(1.0, 0.82, 0.25)
const STONE := Color(0.58, 0.6, 0.64)
const STEEL := Color(0.4, 0.43, 0.48)
const DARK := Color(0.16, 0.17, 0.2)

static func mat(c: Color, unshaded := false, alpha := 1.0, emit := 0.0) -> StandardMaterial3D:
	var k := "%s|%s|%.2f|%.2f" % [c.to_html(), unshaded, alpha, emit]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.8
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[k] = m
	return m

static func box_mesh(s: Vector3) -> Mesh:
	var k := "b%s" % s
	if not _meshes.has(k):
		var m := BoxMesh.new()
		m.size = s
		_meshes[k] = m
	return _meshes[k]

static func cyl_mesh(top: float, bot: float, h: float, segs := 12) -> Mesh:
	var k := "c%.3f|%.3f|%.3f|%d" % [top, bot, h, segs]
	if not _meshes.has(k):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bot
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[k] = m
	return _meshes[k]

static func sph_mesh(r: float, segs := 12) -> Mesh:
	var k := "s%.3f|%d" % [r, segs]
	if not _meshes.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = maxi(4, segs / 2)
		_meshes[k] = m
	return _meshes[k]

static func tor_mesh(inner: float, outer: float) -> Mesh:
	var k := "t%.3f|%.3f" % [inner, outer]
	if not _meshes.has(k):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 20
		m.ring_segments = 8
		_meshes[k] = m
	return _meshes[k]

static func prism_mesh(s: Vector3) -> Mesh:
	var k := "p%s" % s
	if not _meshes.has(k):
		var m := PrismMesh.new()
		m.size = s
		_meshes[k] = m
	return _meshes[k]

static func add(p: Node3D, mesh: Mesh, pos: Vector3, c: Color, rot := Vector3.ZERO, emit := 0.0, alpha := 1.0, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, unshaded, alpha, emit)
	mi.position = pos
	mi.rotation_degrees = rot
	p.add_child(mi)
	return mi

static func box(p: Node3D, s: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	return add(p, box_mesh(s), pos, c, rot, emit)

static func cyl(p: Node3D, top: float, bot: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO, segs := 12, emit := 0.0) -> MeshInstance3D:
	return add(p, cyl_mesh(top, bot, h, segs), pos, c, rot, emit)

static func sph(p: Node3D, r: float, pos: Vector3, c: Color, emit := 0.0, segs := 12) -> MeshInstance3D:
	return add(p, sph_mesh(r, segs), pos, c, Vector3.ZERO, emit)

static func tor(p: Node3D, inner: float, outer: float, pos: Vector3, c: Color, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	return add(p, tor_mesh(inner, outer), pos, c, rot, emit)

static func prism(p: Node3D, s: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	return add(p, prism_mesh(s), pos, c, rot, emit)

static func marker(p: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	p.add_child(n)
	return n

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

# ---------------------------------------------------------------- towers

## Builds tower t's model for its level. Sets t.head, t.muzzles, t.spinner, t.barrels.
static func build_tower(t) -> void:
	var m: Node3D = t.model
	clear(m)
	var L: int = t.level
	var data: Dictionary = D.TOWERS[t.kind]
	var col: Color = data["color"]
	var id: String = data["id"]
	var h := 0.35 + 0.12 * L
	t.muzzles = []
	t.barrels = []
	t.spinner = null
	# shared stepped plinth: grows with level, one colored stripe per upgrade
	cyl(m, 0.82, 0.95, h, Vector3(0, h * 0.5, 0), STONE, Vector3.ZERO, 8)
	for i in L:
		cyl(m, 0.9, 0.9, 0.05, Vector3(0, 0.09 + i * 0.11, 0), col.lightened(0.1), Vector3.ZERO, 8)
	if L >= 4:
		tor(m, 0.72, 0.9, Vector3(0, h, 0), GOLD, Vector3.ZERO, 0.4)
		for i in 6:
			var a := TAU * i / 6.0
			prism(m, Vector3(0.14, 0.3, 0.14), Vector3(cos(a) * 0.82, h + 0.15, sin(a) * 0.82), GOLD, Vector3.ZERO, 0.3)
	var head := Node3D.new()
	head.position = Vector3(0, h, 0)
	m.add_child(head)
	t.head = head
	t.head_y = h
	match id:
		"scout": _scout(t, head, L, col)
		"cannon": _cannon(t, head, L, col)
		"volt": _volt(t, head, L, col)
		"frost": _frost(t, head, L, col)
		"sky": _sky(t, head, L, col)
		"flame": _flame(t, head, L, col)
		"rail": _rail(t, head, L, col)
		"mortar": _mortar(t, head, L, col)
		"farm": _farm(t, head, L, col)
		"beacon": _beacon(t, head, L, col)

static func _barrel(t, head: Node3D, r: float, length: float, pos: Vector3, c: Color) -> void:
	var b := Node3D.new()
	b.position = pos
	head.add_child(b)
	cyl(b, r, r, length, Vector3(0, 0, -length * 0.5), c, Vector3(90, 0, 0), 8)
	t.barrels.append(b)
	t.muzzles.append(marker(b, Vector3(0, 0, -length)))

static func _scout(t, head: Node3D, L: int, col: Color) -> void:
	if L >= 1:
		tor(head.get_parent(), 0.92, 1.12, Vector3(0, 0.14, 0), Color(0.78, 0.68, 0.45))
	box(head, Vector3(0.7, 0.45, 0.7), Vector3(0, 0.25, 0), col)
	box(head, Vector3(0.5, 0.12, 0.5), Vector3(0, 0.52, 0), col.darkened(0.3))
	var n := 1 if L < 3 else (2 if L == 3 else 3)
	for i in n:
		var x := (i - (n - 1) * 0.5) * 0.18
		_barrel(t, head, 0.06, 0.8 + 0.1 * L, Vector3(x, 0.28, -0.3), DARK)
	if L >= 2:
		var dish := cyl(head, 0.28, 0.05, 0.1, Vector3(0, 0.75, 0.25), Color(0.9, 0.9, 0.9), Vector3(-35, 0, 0))
		dish.name = "dish"
		sph(head, 0.07, Vector3(0, 0.6, -0.36), Color(1, 0.3, 0.3), 2.0)
	if L >= 4:
		box(head, Vector3(0.04, 0.7, 0.04), Vector3(0.3, 0.8, 0.3), STEEL)
		box(head, Vector3(0.3, 0.18, 0.02), Vector3(0.45, 1.05, 0.3), GOLD)

static func _cannon(t, head: Node3D, L: int, col: Color) -> void:
	sph(head, 0.5 + 0.03 * L, Vector3(0, 0.35, 0), col.darkened(0.15))
	box(head, Vector3(0.9, 0.18, 0.5), Vector3(0, 0.2, 0.05), STEEL)
	if L >= 1:
		box(head, Vector3(0.12, 0.5, 0.6), Vector3(0.52, 0.4, 0), STEEL.darkened(0.2))
		box(head, Vector3(0.12, 0.5, 0.6), Vector3(-0.52, 0.4, 0), STEEL.darkened(0.2))
	var r := 0.15 + 0.03 * mini(L, 2)
	if L == 3:
		_barrel(t, head, r, 1.0, Vector3(0.2, 0.4, -0.2), DARK)
		_barrel(t, head, r, 1.0, Vector3(-0.2, 0.4, -0.2), DARK)
	elif L >= 4:
		_barrel(t, head, 0.27, 1.25, Vector3(0, 0.42, -0.2), DARK)
		for i in 3:
			tor(t.barrels[0], 0.25, 0.32, Vector3(0, 0, -0.3 - i * 0.35), GOLD, Vector3(90, 0, 0))
	else:
		_barrel(t, head, r, 0.9 + 0.1 * L, Vector3(0, 0.4, -0.2), DARK)

static func _volt(t, head: Node3D, L: int, col: Color) -> void:
	cyl(head, 0.12, 0.25, 1.2 + 0.15 * L, Vector3(0, 0.6 + 0.075 * L, 0), STEEL)
	var sp := Node3D.new()
	head.add_child(sp)
	t.spinner = sp
	var rings := 2 + L
	for i in rings:
		var rr := 0.45 - i * 0.04
		tor(sp, rr - 0.08, rr, Vector3(0, 0.3 + i * 0.25, 0), col if i % 2 == 0 else Color(0.85, 0.9, 1.0), Vector3(0, 0, 0), 0.6)
	var top := 1.35 + 0.15 * L
	sph(head, 0.22 + 0.04 * L, Vector3(0, top, 0), col, 2.5)
	t.muzzles.append(marker(head, Vector3(0, top, 0)))
	if L >= 3:
		for i in 3:
			var a := TAU * i / 3.0
			cyl(head, 0.03, 0.06, 0.8, Vector3(cos(a) * 0.55, 0.5, sin(a) * 0.55), STEEL)
			sph(head, 0.09, Vector3(cos(a) * 0.55, 0.95, sin(a) * 0.55), col, 2.0)

static func _frost(t, head: Node3D, L: int, col: Color) -> void:
	var ht := 1.2 + 0.2 * L
	cyl(head, 0.0, 0.35, ht, Vector3(0, ht * 0.5, 0), col, Vector3.ZERO, 6, 0.6)
	cyl(head, 0.0, 0.22, ht * 0.6, Vector3(0, ht * 0.3, 0), Color(0.9, 0.97, 1.0), Vector3(0, 30, 0), 6, 0.3)
	for i in L:
		var a := TAU * i / maxf(L, 1)
		cyl(head, 0.0, 0.14, 0.6, Vector3(cos(a) * 0.45, 0.3, sin(a) * 0.45), col.lightened(0.3), Vector3(cos(a) * 25, 0, -sin(a) * 25), 6, 0.6)
	var sp := Node3D.new()
	head.add_child(sp)
	t.spinner = sp
	if L >= 2:
		for i in 3:
			var a := TAU * i / 3.0
			cyl(sp, 0.0, 0.08, 0.25, Vector3(cos(a) * 0.7, ht * 0.7, sin(a) * 0.7), Color(0.85, 0.95, 1.0), Vector3.ZERO, 6, 1.5)
	if L >= 4:
		tor(sp, 0.55, 0.65, Vector3(0, ht * 0.55, 0), Color(0.8, 0.95, 1.0), Vector3(15, 0, 0), 1.5)
	t.muzzles.append(marker(head, Vector3(0, ht * 0.8, 0)))

static func _sky(t, head: Node3D, L: int, col: Color) -> void:
	box(head, Vector3(0.9, 0.25, 0.9), Vector3(0, 0.15, 0), STEEL)
	var pods := 2 if L < 2 else (4 if L < 4 else 6)
	var rack := Node3D.new()
	rack.position = Vector3(0, 0.45, 0)
	rack.rotation_degrees = Vector3(25, 0, 0)
	head.add_child(rack)
	box(rack, Vector3(0.85, 0.35 + 0.12 * (pods / 2 - 1), 0.7), Vector3(0, 0.1, 0.05), col)
	for i in pods:
		var cx := -0.22 if i % 2 == 0 else 0.22
		var cy := (i / 2) * 0.14 - 0.02
		cyl(rack, 0.07, 0.07, 0.35, Vector3(cx, cy + 0.05, -0.38), Color(0.95, 0.95, 0.95), Vector3(90, 0, 0), 8)
		sph(rack, 0.07, Vector3(cx, cy + 0.05, -0.56), Color(1, 0.3, 0.2), 1.0, 8)
		t.muzzles.append(marker(rack, Vector3(cx, cy + 0.05, -0.6)))
	if L >= 3:
		var d := cyl(head, 0.3, 0.05, 0.08, Vector3(0, 0.95, 0.3), Color(0.9, 0.9, 0.95), Vector3(-30, 0, 0))
		d.name = "dish"
	if L >= 1:
		box(head, Vector3(0.1, 0.4, 0.1), Vector3(0.5, 0.3, 0.4), STEEL.darkened(0.2))
		sph(head, 0.06, Vector3(0.5, 0.55, 0.4), Color(1, 0.2, 0.2), 2.0, 8)

static func _flame(t, head: Node3D, L: int, col: Color) -> void:
	box(head, Vector3(0.65, 0.45, 0.75), Vector3(0, 0.25, 0), col.darkened(0.35))
	var tanks := 1 + mini(L, 3) / 2 + (1 if L >= 4 else 0)
	for i in tanks:
		var x := (i - (tanks - 1) * 0.5) * 0.3
		cyl(head, 0.14, 0.14, 0.6, Vector3(x, 0.5, 0.35), Color(0.85, 0.2, 0.15), Vector3(0, 0, 0), 10)
		sph(head, 0.14, Vector3(x, 0.8, 0.35), Color(0.85, 0.2, 0.15), 0.0, 10)
	if L >= 4:
		_barrel(t, head, 0.09, 0.8, Vector3(0.16, 0.3, -0.3), DARK)
		_barrel(t, head, 0.09, 0.8, Vector3(-0.16, 0.3, -0.3), DARK)
	else:
		_barrel(t, head, 0.08 + 0.015 * L, 0.6 + 0.1 * L, Vector3(0, 0.3, -0.3), DARK)
	for b in t.barrels:
		sph(b, 0.06, Vector3(0, 0, -0.62 - 0.1 * L), Color(1, 0.6, 0.1), 2.5, 8)
	if L >= 2:
		box(head, Vector3(0.75, 0.08, 0.85), Vector3(0, 0.05, 0), GOLD if L >= 4 else STEEL)

static func _rail(t, head: Node3D, L: int, col: Color) -> void:
	box(head, Vector3(0.55, 0.4, 0.9), Vector3(0, 0.25, 0.1), STEEL.darkened(0.1))
	var length := 1.5 + 0.2 * L
	_barrel(t, head, 0.08, length, Vector3(0, 0.35, -0.2), DARK)
	for i in L + 1:
		tor(t.barrels[0], 0.08, 0.15, Vector3(0, 0, -0.3 - i * (length - 0.4) / maxf(L + 1, 1)), col, Vector3(90, 0, 0), 1.5)
	box(head, Vector3(0.12, 0.12, 0.5), Vector3(0.22, 0.55, 0.0), DARK)
	sph(head, 0.05, Vector3(0.22, 0.55, -0.27), col, 3.0, 8)
	if L >= 2:
		box(head, Vector3(0.7, 0.06, 0.25), Vector3(0, 0.12, 0.45), col, Vector3.ZERO, 0.8)
	if L >= 4:
		cyl(head, 0.2, 0.2, 0.25, Vector3(0, 0.35, 0.6), col, Vector3(90, 0, 0), 10, 2.0)

static func _mortar(t, head: Node3D, L: int, col: Color) -> void:
	cyl(head, 0.6, 0.7, 0.3, Vector3(0, 0.12, 0), col.darkened(0.2), Vector3.ZERO, 10)
	var tubes := 1 if L < 3 else (2 if L == 3 else 4)
	for i in tubes:
		var off := Vector3.ZERO
		if tubes == 2:
			off = Vector3(-0.2 if i == 0 else 0.2, 0, 0)
		elif tubes == 4:
			off = Vector3(-0.2 if i % 2 == 0 else 0.2, 0, -0.15 if i < 2 else 0.15)
		var b := Node3D.new()
		b.position = Vector3(0, 0.3, 0) + off
		b.rotation_degrees = Vector3(60, 0, 0)
		head.add_child(b)
		var r := 0.2 + 0.03 * mini(L, 2) - (0.05 if tubes == 4 else 0.0)
		cyl(b, r, r * 1.15, 0.8, Vector3(0, 0, -0.3), DARK, Vector3(90, 0, 0), 10)
		t.barrels.append(b)
		t.muzzles.append(marker(b, Vector3(0, 0, -0.7)))
	for i in 1 + L:
		var a := TAU * i / float(1 + L) + 0.4
		box(head.get_parent(), Vector3(0.3, 0.2, 0.3), Vector3(cos(a) * 1.05, 0.1, sin(a) * 1.05), Color(0.6, 0.55, 0.4))

static func _farm(t, head: Node3D, L: int, col: Color) -> void:
	box(head, Vector3(0.8, 0.7, 0.8), Vector3(0, 0.35, 0), Color(0.9, 0.85, 0.75))
	prism(head, Vector3(0.95, 0.5, 0.95), Vector3(0, 0.95, 0), GOLD if L >= 4 else Color(0.75, 0.25, 0.2))
	box(head, Vector3(0.22, 0.35, 0.04), Vector3(0, 0.18, -0.41), Color(0.45, 0.3, 0.2))
	var sp := Node3D.new()
	sp.position = Vector3(0, 0.75, -0.45)
	head.add_child(sp)
	t.spinner = sp
	for i in 4:
		var bl := Node3D.new()
		bl.rotation_degrees = Vector3(0, 0, 90 * i)
		sp.add_child(bl)
		box(bl, Vector3(0.12, 0.6 + 0.06 * L, 0.03), Vector3(0, 0.33 + 0.03 * L, 0), Color(0.95, 0.95, 0.9))
	sph(sp, 0.07, Vector3.ZERO, DARK, 0.0, 8)
	for i in L * 2:
		var a := TAU * i / float(maxi(L * 2, 1)) + 0.3
		box(head.get_parent(), Vector3(0.22, 0.25, 0.22), Vector3(cos(a) * 1.0, 0.12, sin(a) * 1.0), Color(0.35, 0.7, 0.25))
		sph(head.get_parent(), 0.08, Vector3(cos(a) * 1.0, 0.3, sin(a) * 1.0), GOLD, 0.5, 6)
	if L >= 2:
		cyl(head, 0.22, 0.22, 0.9, Vector3(0.55, 0.45, 0.3), Color(0.7, 0.72, 0.75))
		sph(head, 0.22, Vector3(0.55, 0.9, 0.3), Color(0.7, 0.72, 0.75))
	if L >= 3:
		cyl(head, 0.2, 0.2, 0.75, Vector3(-0.55, 0.38, 0.3), Color(0.7, 0.72, 0.75))
		sph(head, 0.2, Vector3(-0.55, 0.75, 0.3), Color(0.7, 0.72, 0.75))

static func _beacon(t, head: Node3D, L: int, col: Color) -> void:
	var ht := 1.0 + 0.15 * L
	cyl(head, 0.12, 0.32, ht, Vector3(0, ht * 0.5, 0), Color(0.85, 0.85, 0.9), Vector3.ZERO, 4)
	var sp := Node3D.new()
	sp.position = Vector3(0, ht + 0.45, 0)
	head.add_child(sp)
	t.spinner = sp
	var cr := add(sp, prism_mesh(Vector3(0.4, 0.45, 0.4)), Vector3(0, 0.12, 0), col, Vector3.ZERO, 2.0)
	cr.scale = Vector3(1, 1, 1) * (1.0 + 0.1 * L)
	add(sp, prism_mesh(Vector3(0.4, 0.45, 0.4)), Vector3(0, -0.12, 0), col, Vector3(180, 0, 0), 2.0).scale = cr.scale
	for i in L:
		tor(sp, 0.45 + i * 0.12, 0.5 + i * 0.12, Vector3.ZERO, col.lightened(0.3), Vector3(70 - i * 35, i * 40, 0), 1.2)
	t.muzzles.append(marker(head, Vector3(0, ht + 0.45, 0)))

# ---------------------------------------------------------------- enemies

static func build_enemy(e) -> void:
	var m: Node3D = e.model
	clear(m)
	var d: Dictionary = D.ENEMIES[e.type]
	var c: Color = d["color"]
	var s: float = d["size"]
	var al := 0.38 if e.hidden else 1.0
	match e.type:
		"grunt":
			add(m, box_mesh(Vector3(0.7, 0.7, 0.6)), Vector3(0, 0.45, 0), c, Vector3.ZERO, 0.0, al)
			_eyes(m, Vector3(0, 0.55, -0.31), 0.14)
			box(m, Vector3(0.18, 0.25, 0.2), Vector3(0.2, 0.08, 0), c.darkened(0.4))
			box(m, Vector3(0.18, 0.25, 0.2), Vector3(-0.2, 0.08, 0), c.darkened(0.4))
		"dasher":
			add(m, prism_mesh(Vector3(0.55, 0.5, 0.75)), Vector3(0, 0.35, 0), c, Vector3(-90, 0, 0), 0.0, al)
			_eyes(m, Vector3(0, 0.45, -0.18), 0.1)
			box(m, Vector3(0.5, 0.05, 0.2), Vector3(0, 0.6, 0.25), Color(1, 1, 1))
		"brute":
			box(m, Vector3(1.1, 1.0, 0.9), Vector3(0, 0.65, 0), c)
			box(m, Vector3(0.6, 0.45, 0.5), Vector3(0, 1.3, -0.1), c.lightened(0.1))
			_eyes(m, Vector3(0, 1.35, -0.36), 0.16)
			prism(m, Vector3(0.15, 0.35, 0.15), Vector3(0.3, 1.65, -0.1), Color(0.95, 0.9, 0.8))
			prism(m, Vector3(0.15, 0.35, 0.15), Vector3(-0.3, 1.65, -0.1), Color(0.95, 0.9, 0.8))
			box(m, Vector3(0.3, 0.7, 0.3), Vector3(0.7, 0.6, 0), c.darkened(0.25))
			box(m, Vector3(0.3, 0.7, 0.3), Vector3(-0.7, 0.6, 0), c.darkened(0.25))
		"shellback":
			sph(m, 0.45, Vector3(0, 0.45, 0), c)
			var sh := sph(m, 0.55, Vector3(0, 0.6, 0.08), STEEL)
			sh.scale = Vector3(1.0, 0.7, 1.1)
			for i in 3:
				box(m, Vector3(0.8, 0.08, 0.12), Vector3(0, 0.95 - i * 0.02, -0.25 + i * 0.25), STEEL.darkened(0.3))
			_eyes(m, Vector3(0, 0.5, -0.42), 0.1)
		"wisp":
			sph(m, 0.38, Vector3(0, 0.5, 0), c, 1.2)
			tor(m, 0.5, 0.6, Vector3(0, 0.5, 0), Color(0.9, 1.0, 1.0), Vector3(70, 0, 0), 1.0)
			_eyes(m, Vector3(0, 0.55, -0.34), 0.1)
			cyl(m, 0.0, 0.2, 0.5, Vector3(0, 0.05, 0), c, Vector3(180, 0, 0), 8, 1.0)
		"shade":
			add(m, cyl_mesh(0.15, 0.4, 1.1, 10), Vector3(0, 0.6, 0), c, Vector3.ZERO, 0.0, al)
			add(m, sph_mesh(0.3), Vector3(0, 1.2, 0), c.darkened(0.3), Vector3.ZERO, 0.0, al)
			add(m, box_mesh(Vector3(0.3, 0.07, 0.05)), Vector3(0, 1.22, -0.27), Color(1, 0.3, 0.9), Vector3.ZERO, 3.0, 0.9)
		"splitter":
			sph(m, 0.5, Vector3(0, 0.55, 0), c)
			tor(m, 0.48, 0.56, Vector3(0, 0.55, 0), Color(0.3, 0.15, 0.05), Vector3(90, 0, 20))
			for i in 3:
				var a := TAU * i / 3.0
				sph(m, 0.18, Vector3(cos(a) * 0.4, 0.95, sin(a) * 0.4), Color(1.0, 0.85, 0.25))
			_eyes(m, Vector3(0, 0.6, -0.47), 0.12)
		"mender":
			cyl(m, 0.35, 0.45, 0.9, Vector3(0, 0.5, 0), c)
			box(m, Vector3(0.5, 0.15, 0.15), Vector3(0, 1.15, 0), Color(0.3, 0.9, 0.4), Vector3.ZERO, 1.5)
			box(m, Vector3(0.15, 0.5, 0.15), Vector3(0, 1.15, 0), Color(0.3, 0.9, 0.4), Vector3.ZERO, 1.5)
			tor(m, 0.4, 0.48, Vector3(0, 0.2, 0), Color(0.3, 0.9, 0.4), Vector3.ZERO, 0.8)
			_eyes(m, Vector3(0, 0.75, -0.41), 0.1)
		"juggernaut":
			box(m, Vector3(1.4, 0.9, 1.8), Vector3(0, 0.75, 0), c)
			box(m, Vector3(0.4, 0.5, 2.0), Vector3(0.75, 0.3, 0), DARK)
			box(m, Vector3(0.4, 0.5, 2.0), Vector3(-0.75, 0.3, 0), DARK)
			cyl(m, 0.5, 0.6, 0.5, Vector3(0, 1.45, 0.1), c.darkened(0.2), Vector3.ZERO, 8)
			cyl(m, 0.12, 0.12, 1.1, Vector3(0, 1.45, -0.6), DARK, Vector3(90, 0, 0), 8)
			sph(m, 0.12, Vector3(0, 1.0, -0.92), Color(1, 0.2, 0.1), 3.0)
		"stormwing":
			add(m, prism_mesh(Vector3(0.7, 0.4, 1.2)), Vector3(0, 0.5, 0), c, Vector3(-90, 0, 0))
			box(m, Vector3(1.8, 0.06, 0.55), Vector3(0, 0.55, 0.15), c.lightened(0.2))
			box(m, Vector3(0.5, 0.06, 0.3), Vector3(0, 0.6, 0.55), STEEL)
			sph(m, 0.12, Vector3(0, 0.6, -0.45), Color(1, 1, 0.5), 2.0)
			tor(m, 0.1, 0.16, Vector3(0.6, 0.5, 0.2), STEEL, Vector3(90, 0, 0))
			tor(m, 0.1, 0.16, Vector3(-0.6, 0.5, 0.2), STEEL, Vector3(90, 0, 0))
		"boss":
			_boss(m, e.phase)
	m.scale = Vector3.ONE

static func _boss(m: Node3D, phase: int) -> void:
	var body := Color(0.35, 0.33, 0.38)
	var core := Color(0.3, 0.8, 1.0)
	if phase == 2:
		body = Color(0.5, 0.36, 0.25)
		core = Color(1.0, 0.6, 0.15)
	elif phase >= 3:
		body = Color(0.45, 0.15, 0.15)
		core = Color(1.0, 0.15, 0.1)
	box(m, Vector3(2.0, 1.8, 1.4), Vector3(0, 1.9, 0), body)
	box(m, Vector3(1.2, 0.9, 1.0), Vector3(0, 3.2, -0.1), body.lightened(0.1))
	box(m, Vector3(0.9, 0.12, 0.1), Vector3(0, 3.3, -0.62), core, Vector3.ZERO, 3.0)
	sph(m, 0.45, Vector3(0, 2.0, -0.7), core, 3.0)
	for sx in [-1.0, 1.0]:
		box(m, Vector3(0.55, 1.6, 0.6), Vector3(sx * 1.35, 1.6, 0), body.darkened(0.25))
		box(m, Vector3(0.7, 0.5, 0.7), Vector3(sx * 1.35, 0.6, 0), DARK)
		box(m, Vector3(0.6, 1.0, 0.6), Vector3(sx * 0.55, 0.5, 0), DARK)
		if phase >= 2:
			box(m, Vector3(0.9, 0.5, 0.9), Vector3(sx * 1.35, 2.55, 0), STEEL)
			prism(m, Vector3(0.25, 0.6, 0.25), Vector3(sx * 1.35, 3.1, 0), GOLD)
		if phase >= 3:
			prism(m, Vector3(0.2, 0.5, 0.2), Vector3(sx * 0.4, 3.85, -0.1), core, Vector3.ZERO, 2.0)
	if phase >= 3:
		tor(m, 1.4, 1.6, Vector3(0, 1.9, 0), core, Vector3(90, 0, 0), 2.5)

static func _eyes(m: Node3D, pos: Vector3, sz: float) -> void:
	box(m, Vector3(sz, sz * 1.3, 0.04), pos + Vector3(-sz * 0.9, 0, 0), Color(1, 1, 1))
	box(m, Vector3(sz, sz * 1.3, 0.04), pos + Vector3(sz * 0.9, 0, 0), Color(1, 1, 1))
	box(m, Vector3(sz * 0.5, sz * 0.6, 0.05), pos + Vector3(-sz * 0.9, -sz * 0.15, -0.01), DARK)
	box(m, Vector3(sz * 0.5, sz * 0.6, 0.05), pos + Vector3(sz * 0.9, -sz * 0.15, -0.01), DARK)
