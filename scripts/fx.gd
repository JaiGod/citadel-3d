extends Node3D
## Lightweight visual effects: cube particles, beams, muzzle flashes and shockwave rings.

const M = preload("res://scripts/models.gd")
const MAX_PARTS := 360

var parts: Array = []   # [node, vel, life, maxlife, size, gravity]
var beams: Array = []   # [node, life, maxlife, width]
var rings: Array = []   # [node, life, maxlife, radius]

func _mi(mesh: Mesh, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = M.mat(col, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func burst(pos: Vector3, col: Color, n: int, spd: float, life: float, size: float, grav := 1.0) -> void:
	for i in n:
		if parts.size() >= MAX_PARTS:
			var old: Array = parts.pop_front()
			(old[0] as Node).queue_free()
		var mi := _mi(M.box_mesh(Vector3.ONE), col)
		mi.position = pos
		mi.rotation = Vector3(randf() * 3.0, randf() * 3.0, 0)
		var sz := size * randf_range(0.7, 1.2)
		mi.scale = Vector3.ONE * sz
		var v := Vector3(randf_range(-1, 1), randf_range(0.3, 1.3), randf_range(-1, 1)).normalized() * spd * randf_range(0.4, 1.0)
		var l := life * randf_range(0.7, 1.0)
		parts.append([mi, v, l, l, sz, grav])

func flash(pos: Vector3, col: Color, size: float) -> void:
	if parts.size() >= MAX_PARTS:
		return
	var mi := _mi(M.sph_mesh(0.5, 8), col)
	mi.position = pos
	mi.scale = Vector3.ONE * size
	parts.append([mi, Vector3.ZERO, 0.08, 0.08, size, 0.0])

func puff(pos: Vector3, vel: Vector3, col: Color, size: float, life: float) -> void:
	if parts.size() >= MAX_PARTS:
		return
	var mi := _mi(M.sph_mesh(0.5, 8), col)
	mi.position = pos
	mi.scale = Vector3.ONE * size
	parts.append([mi, vel, life, life, size, -0.3])

func beam(a: Vector3, b: Vector3, col: Color, width: float, life: float) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var mi := _mi(M.box_mesh(Vector3.ONE), col)
	mi.position = (a + b) * 0.5
	var dir := (b - a) / len
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(dir, up)
	mi.scale = Vector3(width, width, len)
	beams.append([mi, life, life, width, len])

func bolt(a: Vector3, b: Vector3, col: Color, life: float) -> void:
	# jagged lightning built from a few beam segments
	var segs := 4
	var prev := a
	for i in range(1, segs + 1):
		var p := a.lerp(b, float(i) / segs)
		if i < segs:
			p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		beam(prev, p, col, 0.09, life)
		prev = p

func ring(pos: Vector3, col: Color, radius: float, life: float) -> void:
	var mi := _mi(M.tor_mesh(0.85, 1.0), col)
	mi.position = pos
	mi.scale = Vector3.ONE * 0.2
	rings.append([mi, life, life, radius])

func update(dt: float) -> void:
	if dt <= 0.0:
		return
	var i := 0
	while i < parts.size():
		var p: Array = parts[i]
		p[2] -= dt
		var n: MeshInstance3D = p[0]
		if p[2] <= 0.0:
			n.queue_free()
			parts.remove_at(i)
			continue
		var v: Vector3 = p[1]
		v.y -= 9.0 * dt * float(p[5])
		p[1] = v
		n.position += v * dt
		var k: float = p[2] / p[3]
		n.scale = Vector3.ONE * float(p[4]) * (k if p[5] >= 0.0 else (1.0 + (1.0 - k) * 1.5) * maxf(k, 0.2))
		i += 1
	i = 0
	while i < beams.size():
		var b: Array = beams[i]
		b[1] -= dt
		var n2: MeshInstance3D = b[0]
		if b[1] <= 0.0:
			n2.queue_free()
			beams.remove_at(i)
			continue
		var w: float = float(b[3]) * (b[1] / b[2])
		n2.scale = Vector3(w, w, float(b[4]))
		i += 1
	i = 0
	while i < rings.size():
		var r: Array = rings[i]
		r[1] -= dt
		var n3: MeshInstance3D = r[0]
		if r[1] <= 0.0:
			n3.queue_free()
			rings.remove_at(i)
			continue
		var t: float = 1.0 - r[1] / r[2]
		var rad: float = lerpf(0.2, float(r[3]), 1.0 - pow(1.0 - t, 3.0))
		n3.scale = Vector3(rad, 1.0 - t * 0.8, rad)
		i += 1

func clear_all() -> void:
	for p in parts:
		(p[0] as Node).queue_free()
	for b in beams:
		(b[0] as Node).queue_free()
	for r in rings:
		(r[0] as Node).queue_free()
	parts.clear()
	beams.clear()
	rings.clear()
