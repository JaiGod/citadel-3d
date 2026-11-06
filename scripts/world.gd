extends RefCounted
## Builds a map: plateau, tiles, path, build pads, spawn portal, the Citadel and themed decorations.

const D = preload("res://scripts/data.gd")
const M = preload("res://scripts/models.gd")

const HALF_W := 23.0
const HALF_D := 15.5

static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var q := a + ab * t
	return Vector2(p.x - q.x, p.z - q.z).length()

static func path_dist(p: Vector3, pts: Array) -> float:
	var best := 1e9
	for i in pts.size() - 1:
		best = minf(best, seg_dist(p, pts[i], pts[i + 1]))
	return best

static func build(g, mi: int) -> void:
	var map: Dictionary = D.MAPS[mi]
	var root: Node3D = g.world
	M.clear(root)
	var pts: Array = []
	for v in map["pts"]:
		pts.append(Vector3(v.x, 0, v.y))
	g.pts = pts
	var cum: Array = [0.0]
	for i in range(1, pts.size()):
		cum.append(float(cum[i - 1]) + (pts[i] as Vector3).distance_to(pts[i - 1]))
	g.cum = cum
	g.path_len = cum[cum.size() - 1]
	var ground: Color = map["ground"]
	var ground2: Color = map["ground2"]
	var edge: Color = map["edge"]
	var pathc: Color = map["path"]
	# far floor + plateau
	M.box(root, Vector3(260, 1, 260), Vector3(0, -3.5, 0), ground.darkened(0.55))
	M.box(root, Vector3(HALF_W * 2 + 0.6, 3.2, HALF_D * 2 + 0.6), Vector3(0, -1.6, 0), edge)
	M.box(root, Vector3(HALF_W * 2, 0.4, HALF_D * 2), Vector3(0, -0.2, 0), ground)
	_tiles(root, ground, ground2, mi)
	# path
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var ang := atan2(b.x - a.x, b.z - a.z)
		var border := M.box(root, Vector3(2.9, 0.1, len + 2.9), mid + Vector3(0, 0.04, 0), pathc.darkened(0.25))
		border.rotation.y = ang
		var top := M.box(root, Vector3(2.4, 0.1, len + 2.4), mid + Vector3(0, 0.08, 0), pathc)
		top.rotation.y = ang
		border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# path chevrons showing direction
	var d := 2.0
	while d < float(g.path_len) - 2.0:
		var p: Vector3 = g.path_pos(d)
		var dir: Vector3 = g.path_dir(d)
		var ch := M.prism(root, Vector3(0.7, 0.5, 0.05), p + Vector3(0, 0.14, 0), pathc.lightened(0.18), Vector3(-90, 0, 0))
		ch.rotation.y = atan2(-dir.x, -dir.z)
		ch.rotation_degrees.x = -90
		ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d += 4.0
	_portal(root, pts[0], (pts[1] - pts[0]).normalized())
	var last: Vector3 = pts[pts.size() - 1]
	var ldir: Vector3 = (last - pts[pts.size() - 2]).normalized()
	g.citadel = _citadel(root, last + ldir * 0.6, ldir)
	# build pads
	var pads: Array = []
	for si in pts.size() - 1:
		var a: Vector3 = pts[si]
		var b: Vector3 = pts[si + 1]
		var sd := (b - a).normalized()
		var nrm := Vector3(-sd.z, 0, sd.x)
		var L := a.distance_to(b)
		var s := 1.2
		while s < L:
			for side in [-1.0, 1.0]:
				var p: Vector3 = a + sd * s + nrm * float(side) * 3.1
				if absf(p.x) > HALF_W - 1.4 or absf(p.z) > HALF_D - 1.3:
					continue
				if path_dist(p, pts) < 2.75:
					continue
				var ok := true
				for q in pads:
					if (q["pos"] as Vector3).distance_to(p) < 2.6:
						ok = false
						break
				if ok and p.distance_to(last) > 4.0 and p.distance_to(pts[0]) > 3.0:
					pads.append({"pos": p, "tower": null})
			s += 2.9
	for pd in pads:
		var pn := Node3D.new()
		pn.position = pd["pos"]
		root.add_child(pn)
		M.cyl(pn, 1.0, 1.08, 0.22, Vector3(0, 0.11, 0), Color(0.7, 0.7, 0.74), Vector3.ZERO, 6)
		var topm := M.cyl(pn, 0.82, 0.82, 0.04, Vector3(0, 0.235, 0), Color(0.5, 0.52, 0.58), Vector3.ZERO, 6)
		pd["node"] = topm
		pd["root"] = pn
	g.pads = pads
	_decorate(root, map, pts, pads, mi)

static func _tiles(root: Node3D, c1: Color, c2: Color, mi: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 11 + mi
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(1.97, 0.1, 1.97)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	bm.material = m
	mm.mesh = bm
	var nx := int(HALF_W)
	var nz := int(HALF_D)
	mm.instance_count = nx * 2 * nz * 2
	var i := 0
	for x in range(-nx, nx):
		for z in range(-nz, nz):
			var h := r.randf_range(0.0, 0.05)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x * 2 + 1, h, z * 2 + 1)))
			var c: Color = c1.lerp(c2, r.randf()) if (x + z) % 2 == 0 else c2.lerp(c1, r.randf() * 0.5)
			mm.set_instance_color(i, c)
			i += 1
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)

static func _portal(root: Node3D, p: Vector3, dir: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = atan2(dir.x, dir.z)
	root.add_child(n)
	var c := Color(0.75, 0.3, 1.0)
	M.box(n, Vector3(3.6, 0.3, 1.2), Vector3(0, 0.15, 0), Color(0.3, 0.25, 0.35))
	for sx in [-1.0, 1.0]:
		M.box(n, Vector3(0.5, 3.2, 0.6), Vector3(float(sx) * 1.6, 1.6, 0), Color(0.3, 0.25, 0.35))
		M.prism(n, Vector3(0.6, 0.6, 0.6), Vector3(float(sx) * 1.6, 3.5, 0), c, Vector3.ZERO, 1.5)
	M.tor(n, 1.05, 1.3, Vector3(0, 1.6, 0), c, Vector3(90, 0, 0), 2.5)
	var disc := M.add(n, M.cyl_mesh(1.05, 1.05, 0.05, 20), Vector3(0, 1.6, 0), Color(0.45, 0.1, 0.75), Vector3(90, 0, 0), 1.2, 0.55)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _citadel(root: Node3D, p: Vector3, dir: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = atan2(dir.x, dir.z) + PI
	root.add_child(n)
	var st := Color(0.86, 0.84, 0.8)
	var roof := Color(0.25, 0.45, 0.9)
	M.box(n, Vector3(4.2, 0.6, 4.2), Vector3(0, 0.3, 0), Color(0.6, 0.6, 0.62))
	M.box(n, Vector3(3.0, 2.2, 3.0), Vector3(0, 1.7, 0), st)
	for i in 4:
		var x: float = 1.5 if i % 2 == 0 else -1.5
		var z: float = 1.5 if i < 2 else -1.5
		M.cyl(n, 0.55, 0.6, 3.4, Vector3(x, 2.0, z), st.darkened(0.08), Vector3.ZERO, 10)
		M.cyl(n, 0.0, 0.75, 1.2, Vector3(x, 4.3, z), roof, Vector3.ZERO, 10)
	M.box(n, Vector3(1.6, 1.6, 1.6), Vector3(0, 3.5, 0), st.lightened(0.05))
	M.cyl(n, 0.0, 1.2, 1.4, Vector3(0, 5.0, 0), roof, Vector3.ZERO, 4)
	M.box(n, Vector3(0.05, 1.2, 0.05), Vector3(0, 6.1, 0), Color(0.3, 0.3, 0.3))
	M.box(n, Vector3(0.7, 0.4, 0.03), Vector3(0.36, 6.45, 0), Color(1.0, 0.82, 0.25), Vector3.ZERO, 0.6)
	M.box(n, Vector3(1.0, 1.3, 0.1), Vector3(0, 1.25, 1.52), Color(0.3, 0.2, 0.12))
	for i in 5:
		M.box(n, Vector3(0.35, 0.35, 0.35), Vector3(-1.2 + i * 0.6, 2.95, 1.45), st)
	var crystal := M.prism(n, Vector3(0.5, 0.8, 0.5), Vector3(0, 7.0, 0), Color(0.4, 0.9, 1.0), Vector3.ZERO, 2.5)
	crystal.name = "Crystal"
	return n

static func _decorate(root: Node3D, map: Dictionary, pts: Array, pads: Array, mi: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 501 + mi * 31
	var theme: String = map["deco"]
	var placed := 0
	var tries := 0
	while placed < 85 and tries < 2000:
		tries += 1
		var p := Vector3(r.randf_range(-HALF_W + 0.8, HALF_W - 0.8), 0, r.randf_range(-HALF_D + 0.8, HALF_D - 0.8))
		if path_dist(p, pts) < 2.3:
			continue
		var near := false
		for pd in pads:
			if (pd["pos"] as Vector3).distance_to(p) < 1.9:
				near = true
				break
		if near or p.distance_to(pts[pts.size() - 1]) < 4.0 or p.distance_to(pts[0]) < 2.5:
			continue
		placed += 1
		var n := Node3D.new()
		n.position = p
		n.rotation.y = r.randf() * TAU
		var s := r.randf_range(0.7, 1.3)
		n.scale = Vector3.ONE * s
		root.add_child(n)
		var roll := r.randf()
		match theme:
			"forest":
				if roll < 0.55:
					M.cyl(n, 0.12, 0.16, 0.8, Vector3(0, 0.4, 0), Color(0.45, 0.3, 0.18), Vector3.ZERO, 6)
					var gc := Color(0.2, 0.55, 0.22).lerp(Color(0.35, 0.68, 0.25), r.randf())
					if r.randf() < 0.5:
						M.sph(n, 0.7, Vector3(0, 1.3, 0), gc, 0.0, 8)
						M.sph(n, 0.45, Vector3(0.3, 1.8, 0.1), gc.lightened(0.1), 0.0, 8)
					else:
						M.cyl(n, 0.0, 0.75, 1.3, Vector3(0, 1.3, 0), gc, Vector3.ZERO, 7)
						M.cyl(n, 0.0, 0.55, 1.0, Vector3(0, 1.9, 0), gc.lightened(0.08), Vector3.ZERO, 7)
				elif roll < 0.75:
					M.sph(n, 0.35, Vector3(0, 0.2, 0), Color(0.3, 0.6, 0.25), 0.0, 8).scale = Vector3(1.4, 0.8, 1.2)
					M.sph(n, 0.07, Vector3(0.2, 0.42, 0), Color(1, 0.4, 0.6), 0.0, 6)
					M.sph(n, 0.07, Vector3(-0.15, 0.4, 0.15), Color(1, 0.95, 0.4), 0.0, 6)
				else:
					M.sph(n, 0.45, Vector3(0, 0.15, 0), Color(0.6, 0.6, 0.58), 0.0, 6).scale = Vector3(1.3, 0.7, 1.0)
			"snow":
				if roll < 0.6:
					M.cyl(n, 0.1, 0.14, 0.6, Vector3(0, 0.3, 0), Color(0.4, 0.28, 0.2), Vector3.ZERO, 6)
					for k in 3:
						var rr := 0.8 - k * 0.2
						M.cyl(n, 0.0, rr, 0.9, Vector3(0, 0.9 + k * 0.55, 0), Color(0.18, 0.4, 0.3), Vector3.ZERO, 7)
						M.cyl(n, 0.0, rr * 0.55, 0.45, Vector3(0, 1.15 + k * 0.55, 0), Color(0.95, 0.97, 1.0), Vector3.ZERO, 7)
				elif roll < 0.8:
					M.sph(n, 0.5, Vector3(0, 0.1, 0), Color(0.95, 0.97, 1.0), 0.0, 8).scale = Vector3(1.5, 0.6, 1.2)
				else:
					M.cyl(n, 0.0, 0.25, 1.2, Vector3(0, 0.6, 0), Color(0.6, 0.85, 1.0), Vector3(10, 0, 8), 5, 0.8)
					M.cyl(n, 0.0, 0.18, 0.8, Vector3(0.3, 0.4, 0.1), Color(0.7, 0.9, 1.0), Vector3(-15, 0, -20), 5, 0.8)
			_:
				if roll < 0.4:
					M.cyl(n, 0.35, 0.5, r.randf_range(1.0, 2.6), Vector3(0, 0.6, 0), Color(0.2, 0.17, 0.17), Vector3.ZERO, 6)
				elif roll < 0.7:
					var pool := M.add(n, M.cyl_mesh(0.8, 0.9, 0.06, 12), Vector3(0, 0.04, 0), Color(1.0, 0.4, 0.08), Vector3.ZERO, 2.2)
					pool.scale = Vector3(1.3, 1, 0.9)
					pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					M.sph(n, 0.12, Vector3(0.3, 0.1, 0.1), Color(1.0, 0.8, 0.2), 3.0, 6)
				else:
					M.cyl(n, 0.0, 0.2, 0.9, Vector3(0, 0.45, 0), Color(1.0, 0.25, 0.15), Vector3(8, 0, 6), 5, 1.6)
					M.sph(n, 0.4, Vector3(0.2, 0.15, 0.2), Color(0.25, 0.2, 0.2), 0.0, 6)
