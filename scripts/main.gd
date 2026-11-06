extends Node3D
## Citadel 3D: game state, wave simulation, combat, input and camera control.

const D = preload("res://scripts/data.gd")
const M = preload("res://scripts/models.gd")
const TowerS = preload("res://scripts/tower.gd")
const EnemyS = preload("res://scripts/enemy.gd")
const FxS = preload("res://scripts/fx.gd")
const HudS = preload("res://scripts/hud.gd")
const CamS = preload("res://scripts/cam.gd")
const WorldS = preload("res://scripts/world.gd")

var state := "title"   # title | play | over
var map_i := 0
var mode := "normal"   # normal | endless
var cam: Camera3D
var hud
var fx
var world: Node3D
var ents: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var citadel: Node3D
var pts: Array = []
var cum: Array = []
var path_len := 1.0
var pads: Array = []
var towers: Array = []
var enemies: Array = []
var projs: Array = []
var floats: Array = []
var cash := 0
var lives := 150
var wave := 0
var spawnq: Array = []
var intermission := -1.0
var speed := 1
var paused := false
var sel_tower = null
var place_kind := -1
var hover_pad := -1
var boss = null
var stats := {}
var sim_time := 0.0
var demo_t := 0.0
var range_disc: MeshInstance3D
var range_ring: MeshInstance3D
var sel_ring: MeshInstance3D
var pad_glow: StandardMaterial3D
var pad_norm: StandardMaterial3D
var headless := false
# input
var press_pos := Vector2.ZERO
var pressing := false
var drag_btn := 0
var moved := 0.0
var touches := {}
var pinch_d := 0.0
var touch_on_ui := false

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	var we := WorldEnvironment.new()
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	env.glow_bloom = 0.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	cam = CamS.new()
	cam.fov = 50.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	world = Node3D.new()
	add_child(world)
	ents = Node3D.new()
	add_child(ents)
	fx = FxS.new()
	add_child(fx)
	range_disc = M.add(self, M.cyl_mesh(1.0, 1.0, 0.04, 40), Vector3.ZERO, Color(0.4, 0.8, 1.0), Vector3.ZERO, 0.0, 0.16, true)
	range_ring = M.add(self, M.tor_mesh(0.97, 1.0), Vector3.ZERO, Color(0.6, 0.9, 1.0), Vector3.ZERO, 0.0, 0.85, true)
	sel_ring = M.add(self, M.tor_mesh(1.05, 1.25), Vector3.ZERO, Color(1.0, 0.85, 0.3), Vector3.ZERO, 0.0, 1.0, true)
	for n in [range_disc, range_ring, sel_ring]:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
	pad_norm = M.mat(Color(0.5, 0.52, 0.58))
	pad_glow = M.mat(Color(0.35, 0.85, 1.0), false, 1.0, 1.4)
	hud = HudS.new()
	hud.main = self
	add_child(hud)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	go_title()

func _on_resize() -> void:
	var sz := get_window().size
	if sz.x <= 0 or sz.y <= 0:
		return
	var portrait := sz.x < sz.y * 0.9
	var w := get_window()
	if portrait:
		w.content_scale_size = Vector2i(500, 720)
	elif sz.y < 560:
		w.content_scale_size = Vector2i(960, 540)
	else:
		w.content_scale_size = Vector2i(1280, 720)
	hud.layout(portrait)

func is_portrait() -> bool:
	var sz := get_window().size
	return sz.x < sz.y * 0.9

# ------------------------------------------------------------------ flow

func load_map(i: int) -> void:
	clear_run()
	map_i = i
	WorldS.build(self, i)
	var mp: Dictionary = D.MAPS[i]
	var skyc: Color = mp["sky"]
	sky_mat.sky_top_color = skyc.darkened(0.25)
	sky_mat.sky_horizon_color = skyc.lightened(0.25)
	sky_mat.ground_horizon_color = skyc.lightened(0.1)
	sky_mat.ground_bottom_color = (mp["edge"] as Color).darkened(0.5)
	if mp["deco"] == "lava":
		env.ambient_light_color = Color(0.9, 0.6, 0.5)
		sun.light_color = Color(1.0, 0.8, 0.7)
	elif mp["deco"] == "snow":
		env.ambient_light_color = Color(0.75, 0.82, 0.95)
		sun.light_color = Color(1.0, 0.98, 0.95)
	else:
		env.ambient_light_color = Color(0.75, 0.78, 0.85)
		sun.light_color = Color(1.0, 0.96, 0.88)
	cam.bounds = Rect2(-WorldS.HALF_W, -WorldS.HALF_D, WorldS.HALF_W * 2, WorldS.HALF_D * 2)

func clear_run() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	for t in towers:
		if is_instance_valid(t):
			t.queue_free()
	for p in projs:
		if is_instance_valid(p["node"]):
			(p["node"] as Node).queue_free()
	enemies.clear()
	towers.clear()
	projs.clear()
	floats.clear()
	spawnq.clear()
	fx.clear_all()
	boss = null
	sel_tower = null
	place_kind = -1
	hover_pad = -1
	_update_indicators()

func go_title() -> void:
	state = "title"
	paused = false
	load_map(map_i)
	_setup_demo()
	cam.reset_view(Vector3(0, 0, 0), 0.5, 0.75, 44.0)
	hud.show_title()

func _setup_demo() -> void:
	# attract mode: a few upgraded towers defending against random enemies
	var picks := [[0, 3], [1, 2], [2, 4], [4, 3], [6, 4], [7, 2], [3, 3], [8, 4], [9, 2], [5, 3]]
	var step := maxi(1, pads.size() / picks.size())
	for i in picks.size():
		var pi: int = (i * step + 2) % pads.size()
		if pads[pi]["tower"] != null:
			continue
		var t = _make_tower(picks[i][0], pi)
		t.level = picks[i][1]
		t.rebuild()
	refresh_buffs()
	wave = 8
	cash = 0
	lives = 999

func start_game(mi: int, md: String) -> void:
	mode = md
	load_map(mi)
	state = "play"
	cash = int(D.MAPS[mi]["cash"])
	lives = D.START_LIVES
	wave = 0
	speed = 1
	paused = false
	intermission = 25.0
	sim_time = 0.0
	stats = {"kills": 0, "earned": 0, "dmg": 0.0, "leaked": 0, "built": 0, "lt": {}}
	G.plays += 1
	cam.reset_view(Vector3(0, 0, 1.5), 0.0, 1.0, 45.0 if not is_portrait() else 62.0)
	hud.show_play()
	hud.banner("%s" % D.MAPS[mi]["name"], "Build towers on the glowing pads, then start wave 1!", Color(1, 0.9, 0.5))

func restart() -> void:
	start_game(map_i, mode)

func quit_to_title() -> void:
	if state == "play" and wave > 0:
		G.record(map_i, mode, wave - 1, false)
	go_title()

func can_call() -> bool:
	return state == "play" and spawnq.is_empty() and (mode == "endless" or wave < D.WAVES.size())

func call_next() -> void:
	if can_call():
		start_wave()

func start_wave() -> void:
	wave += 1
	if wave > 1:
		var bonus := D.wave_bonus(wave - 1)
		var farm := 0
		for t in towers:
			if t.id == "farm":
				var inc: int = t.s["income"]
				farm += inc
				add_float(t.global_position + Vector3(0, 2.2, 0), "+$%d" % inc, Color(1, 0.9, 0.3), 1.3)
				fx.burst(t.global_position + Vector3(0, 1.5, 0), Color(1, 0.85, 0.2), 6, 3.0, 0.6, 0.14)
		cash += bonus + farm
		stats["earned"] += bonus + farm
		hud.toast("Wave bonus +$%d%s" % [bonus, ("  ·  Farms +$%d" % farm) if farm > 0 else ""])
		if farm > 0:
			sfx("coin")
	spawnq.clear()
	var has_boss := false
	for gdef in D.wave_groups(wave):
		spawnq.append({"type": gdef[0], "left": int(gdef[1]), "interval": float(gdef[2]), "t": float(gdef[3])})
		if gdef[0] == "boss":
			has_boss = true
	intermission = -1.0
	if has_boss:
		hud.banner("WAVE %d" % wave, "THE IRON TYRANT APPROACHES", Color(1, 0.35, 0.3))
		sfx("boss")
	else:
		hud.banner("WAVE %d" % wave, _wave_hint(wave), Color(1, 1, 1))
		sfx("wave")

func _wave_hint(n: int) -> String:
	var types := {}
	for gd in D.wave_groups(n):
		types[gd[0]] = true
	for t in ["stormwing", "juggernaut", "shade", "wisp", "shellback", "mender", "splitter"]:
		if types.has(t):
			var dd: Dictionary = D.ENEMIES[t]
			return "%s: %s" % [dd["name"], D.ENEMY_INFO[t]]
	return "Hold the line!"

func victory() -> void:
	state = "over"
	var rec: bool = G.record(map_i, mode, wave, true)
	sfx("win")
	for i in 8:
		fx.burst(citadel.global_position + Vector3(randf_range(-4, 4), 6 + randf() * 3, randf_range(-4, 4)), Color.from_hsv(randf(), 0.7, 1.0), 16, 7.0, 1.3, 0.2, 0.4)
	hud.show_end(true, rec)

func defeat() -> void:
	state = "over"
	var rec: bool = G.record(map_i, mode, wave, false)
	sfx("lose")
	add_shake(0.8)
	for i in 5:
		fx.burst(citadel.global_position + Vector3(randf_range(-2, 2), 2 + randf() * 3, randf_range(-2, 2)), Color(1, 0.5, 0.2), 18, 6.0, 1.2, 0.3)
	hud.show_end(false, rec)

# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if state == "title":
		cam.g_yaw += delta * 0.06
		_demo(delta)
		sim_step(delta)
	elif state == "play" and not paused:
		var dt := delta * speed
		var n := int(ceil(dt / 0.034))
		for i in n:
			sim_step(dt / n)
			if state != "play":
				break
	if not paused:
		fx.update(delta * (speed if state == "play" else 1))
	_keys(delta)
	var i := 0
	while i < floats.size():
		var f: Dictionary = floats[i]
		f["t"] = float(f["t"]) + delta
		if float(f["t"]) >= float(f["life"]):
			floats.remove_at(i)
		else:
			i += 1
	if citadel:
		var cr := citadel.get_node_or_null("Crystal")
		if cr:
			cr.rotation.y += delta * 1.5
			cr.position.y = 7.0 + sin(Time.get_ticks_msec() / 500.0) * 0.2
	_update_indicators()

func _demo(delta: float) -> void:
	demo_t -= delta
	if demo_t <= 0.0 and enemies.size() < 14:
		demo_t = 1.1
		var pool := ["grunt", "dasher", "brute", "shellback", "wisp", "splitter", "stormwing", "mender", "grunt", "shade"]
		spawn(pool[randi() % pool.size()], 0.0)
	cash = 0

func sim_step(dt: float) -> void:
	sim_time += dt
	if state == "play":
		var i := 0
		while i < spawnq.size():
			var gq: Dictionary = spawnq[i]
			gq["t"] = float(gq["t"]) - dt
			while int(gq["left"]) > 0 and float(gq["t"]) <= 0.0:
				spawn(gq["type"], 0.0)
				gq["left"] = int(gq["left"]) - 1
				gq["t"] = float(gq["t"]) + float(gq["interval"])
			if int(gq["left"]) <= 0:
				spawnq.remove_at(i)
			else:
				i += 1
	for e in enemies.duplicate():
		if e.alive:
			e.update(dt, self)
	for t in towers:
		t.update(dt, self)
	_update_projs(dt)
	if state != "play":
		return
	if spawnq.is_empty() and enemies.is_empty():
		if mode == "normal" and wave >= D.WAVES.size():
			victory()
			return
		if intermission < 0.0:
			intermission = 6.0
	if intermission >= 0.0 and spawnq.is_empty() and (enemies.is_empty() or wave == 0):
		intermission -= dt
		if intermission <= 0.0:
			start_wave()

# ------------------------------------------------------------------ path

func path_pos(d: float) -> Vector3:
	d = clampf(d, 0.0, path_len)
	var i := 1
	while i < cum.size() - 1 and float(cum[i]) < d:
		i += 1
	var a: Vector3 = pts[i - 1]
	var b: Vector3 = pts[i]
	var seg: float = float(cum[i]) - float(cum[i - 1])
	return a.lerp(b, (d - float(cum[i - 1])) / maxf(seg, 0.001))

func path_dir(d: float) -> Vector3:
	d = clampf(d, 0.0, path_len)
	var i := 1
	while i < cum.size() - 1 and float(cum[i]) < d:
		i += 1
	return ((pts[i] as Vector3) - (pts[i - 1] as Vector3)).normalized()

func center(e) -> Vector3:
	return e.position + Vector3(0, 0.55 * float(e.size), 0)

# ------------------------------------------------------------------ enemies

func spawn(type: String, d0: float):
	var e = EnemyS.new()
	var mp: float = D.MAPS[map_i]["hpm"]
	var n := maxi(wave, 1)
	var mult: float = D.hp_mult_raw(n) * mp
	if type == "boss":
		mult = mp * D.hp_mult_raw(n) / D.hp_mult_raw(30)
	if state == "title":
		mult = 1.0
	e.setup(type, mult, 1.0 + 0.06 * (n - 1))
	e.d = d0
	ents.add_child(e)
	e.position = path_pos(d0) + Vector3(0, e.height(), 0)
	enemies.append(e)
	if type == "boss":
		boss = e
	return e

func spawn_near(src, type: String, n: int) -> void:
	for i in n:
		var e = spawn(type, maxf(0.0, src.d - 1.2 - i * 0.9))
		fx.burst(center(e), Color(0.8, 0.3, 1.0), 6, 3.0, 0.5, 0.15)

func hit(e, dmg: float, pierce: float, src, show := true) -> float:
	if not e.alive:
		return 0.0
	if e.shield_t > 0.0:
		if show and randf() < 0.3:
			add_float(center(e) + Vector3(0, 1.0, 0), "IMMUNE", Color(0.6, 0.9, 1.0), 0.6)
		return 0.0
	var eff := maxf(dmg - maxf(e.armor - pierce, 0.0), dmg * 0.25)
	e.hp -= eff
	if show:
		e.flash = 0.08
		if eff >= 25.0:
			add_float(center(e) + Vector3(0, 0.8, 0), "%d" % int(eff), Color(1, 1, 1), 0.6)
	if src != null and is_instance_valid(src):
		src.dmg_dealt += eff
	if state == "play":
		stats["dmg"] = float(stats["dmg"]) + eff
	if e.hp <= 0.0:
		kill(e, src)
	return eff

func kill(e, src) -> void:
	if not e.alive:
		return
	e.alive = false
	enemies.erase(e)
	var c := center(e)
	if state == "play":
		cash += e.bounty
		stats["kills"] += 1
		stats["earned"] += e.bounty
		add_float(c + Vector3(0, 0.6, 0), "+$%d" % e.bounty, Color(1, 0.85, 0.3), 0.9)
	if src != null and is_instance_valid(src):
		src.kills += 1
	var dd: Dictionary = D.ENEMIES[e.type]
	fx.burst(c, dd["color"], 10 if e.type != "boss" else 70, 5.0, 0.7, 0.16 * float(e.size) + 0.06)
	sfx("pop")
	if e.type == "splitter":
		for i in 3:
			spawn("dasher", maxf(0.0, e.d - i * 0.5))
	if e == boss:
		boss = null
		add_shake(1.2)
		sfx("boom")
		fx.ring(c, Color(1, 0.6, 0.2), 9.0, 1.0)
		for i in 6:
			fx.burst(c + Vector3(randf_range(-2, 2), randf_range(0, 3), randf_range(-2, 2)), Color(1, 0.5 + randf() * 0.4, 0.1), 14, 8.0, 1.2, 0.3)
		if state == "play":
			hud.banner("THE IRON TYRANT FALLS!", "+$%d" % e.bounty, Color(1, 0.85, 0.3))
	e.queue_free()

func leak(e) -> void:
	if not e.alive:
		return
	e.alive = false
	enemies.erase(e)
	if e == boss:
		boss = null
	e.queue_free()
	if state != "play":
		return
	lives -= e.leak
	stats["leaked"] += e.leak
	var lt: Dictionary = stats["lt"]
	lt[e.type] = int(lt.get(e.type, 0)) + e.leak
	add_shake(0.25 if e.leak < 20 else 0.9)
	sfx("leak")
	hud.flash_red()
	fx.burst(citadel.global_position + Vector3(0, 3, 0), Color(1, 0.3, 0.2), 8, 4.0, 0.6, 0.2)
	if lives <= 0:
		lives = 0
		defeat()

func mender_pulse(m) -> void:
	fx.ring(m.position + Vector3(0, 0.3, 0), Color(0.3, 1.0, 0.45), 4.0, 0.5)
	for e in enemies:
		if e != m and e.alive and e.type != "boss" and e.position.distance_to(m.position) < 4.0:
			e.hp = minf(e.maxhp, e.hp + e.maxhp * 0.06)
			fx.burst(center(e), Color(0.3, 1.0, 0.45), 2, 1.5, 0.4, 0.1)

func boss_phase(b, p: int) -> void:
	add_shake(0.7)
	sfx("boss")
	fx.ring(b.position + Vector3(0, 1, 0), Color(1, 0.5, 0.2), 7.0, 0.9)
	if p == 2:
		hud.banner("PHASE 2", "The Tyrant raises its shield and calls guards!", Color(1, 0.65, 0.25))
		spawn_near(b, "brute", 4)
		spawn_near(b, "mender", 2)
	else:
		hud.banner("PHASE 3", "ENRAGED! Faster, and EMP blasts stun towers!", Color(1, 0.25, 0.2))
		spawn_near(b, "stormwing", 3)

func emp(b) -> void:
	sfx("emp")
	fx.ring(b.position + Vector3(0, 0.5, 0), Color(0.4, 0.8, 1.0), 8.0, 0.8)
	var n := 0
	for t in towers:
		if t.position.distance_to(b.position) < 8.0:
			t.stun = 3.0
			n += 1
	if n > 0:
		hud.toast("EMP BLAST! %d towers stunned" % n)

# ------------------------------------------------------------------ combat helpers

func pick_target(t):
	var r: float = t.s["range"]
	var r2 := r * r
	var det: bool = t.s["detect"]
	var best = null
	var bs := -INF
	var tp: Vector3 = t.position
	var skyb: bool = t.id == "sky"
	for e in enemies:
		if not e.alive:
			continue
		if e.fly:
			if not t.air:
				continue
		elif not t.ground:
			continue
		if e.hidden and not det:
			continue
		var dx: float = e.position.x - tp.x
		var dz: float = e.position.z - tp.z
		var dd := dx * dx + dz * dz
		if dd > r2:
			continue
		var sc := 0.0
		match t.mode:
			0: sc = e.d
			1: sc = -e.d
			2: sc = e.hp
			3: sc = -e.hp
			_: sc = -dd
		if skyb and e.fly:
			sc += 100000.0
		if sc > bs:
			bs = sc
			best = e
	return best

func can_hit(t, e) -> bool:
	if not e.alive:
		return false
	if e.fly and not t.air:
		return false
	if not e.fly and not t.ground:
		return false
	if e.hidden and not bool(t.s["detect"]):
		return false
	return true

func splash(pos: Vector3, radius: float, dmg: float, pierce: float, src, air: bool, ground: bool) -> int:
	var n := 0
	for e in enemies.duplicate():
		if not e.alive:
			continue
		if e.fly and not air:
			continue
		if not e.fly and not ground:
			continue
		var dx: float = e.position.x - pos.x
		var dz: float = e.position.z - pos.z
		var rr: float = radius + float(e.size) * 0.3
		if dx * dx + dz * dz <= rr * rr:
			hit(e, dmg, pierce, src)
			n += 1
	return n

func launch(t, kind: String, from: Vector3, tg, flight: float, arc: float) -> void:
	var node: MeshInstance3D
	match kind:
		"shell": node = M.add(fx, M.sph_mesh(0.18, 8), from, Color(0.15, 0.15, 0.15))
		"mortar": node = M.add(fx, M.sph_mesh(0.26, 8), from, Color(0.2, 0.22, 0.18))
		"ice": node = M.add(fx, M.prism_mesh(Vector3(0.25, 0.5, 0.25)), from, Color(0.7, 0.95, 1.0), Vector3.ZERO, 1.5)
		_: node = M.add(fx, M.box_mesh(Vector3(0.12, 0.12, 0.45)), from, Color(0.95, 0.95, 0.95), Vector3.ZERO, 0.4)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var to: Vector3 = center(tg)
	if kind == "mortar":
		to = path_pos(tg.d + tg.cur_speed * flight) + Vector3(0, 0.2, 0)
	elif kind == "shell" or kind == "ice":
		to = center(tg) + path_dir(tg.d) * tg.cur_speed * flight
	var p := {"kind": kind, "node": node, "from": from, "to": to, "tg": tg, "t": 0.0, "dur": maxf(flight, 0.01), "arc": arc,
		"tower": t, "dmg": float(t.s.get("dmg", 0.0)), "splash": float(t.s.get("splash", 0.0)), "pierce": float(t.s.get("pierce", 0.0)),
		"slow": float(t.s.get("slow", 0.0)), "freeze": bool(t.s.get("freeze", false)) and t.frost_count % 4 == 0,
		"pos": from, "vel": Vector3(randf_range(-3, 3), 7.0, randf_range(-3, 3)), "smoke": 0.0}
	projs.append(p)

func _update_projs(dt: float) -> void:
	var i := 0
	while i < projs.size():
		var p: Dictionary = projs[i]
		var node: MeshInstance3D = p["node"]
		var done := false
		if p["kind"] == "missile":
			var tg = p["tg"]
			if is_instance_valid(tg) and tg.alive:
				p["to"] = center(tg)
			var aim: Vector3 = p["to"]
			var pos: Vector3 = p["pos"]
			var vel: Vector3 = p["vel"]
			vel = vel.lerp((aim - pos).normalized() * 20.0, minf(1.0, dt * 5.0))
			pos += vel * dt
			p["pos"] = pos
			p["vel"] = vel
			node.position = pos
			if vel.length() > 0.1:
				var up := Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.RIGHT
				node.basis = Basis.looking_at(vel.normalized(), up)
			p["smoke"] = float(p["smoke"]) - dt
			if float(p["smoke"]) <= 0.0:
				p["smoke"] = 0.05
				fx.puff(pos, Vector3(0, 0.5, 0), Color(0.85, 0.85, 0.85), 0.22, 0.4)
			p["t"] = float(p["t"]) + dt
			if pos.distance_to(aim) < 0.6 or float(p["t"]) > 3.0:
				done = true
		else:
			p["t"] = float(p["t"]) + dt
			var k := minf(1.0, float(p["t"]) / float(p["dur"]))
			var from: Vector3 = p["from"]
			var to: Vector3 = p["to"]
			var arc: float = p["arc"]
			node.position = from.lerp(to, k) + Vector3(0, arc * 4.0 * k * (1.0 - k), 0)
			if p["kind"] == "ice":
				node.rotation.y += dt * 12.0
			if k >= 1.0:
				done = true
		if done:
			_impact(p)
			node.queue_free()
			projs.remove_at(i)
		else:
			i += 1

func _impact(p: Dictionary) -> void:
	var t = p["tower"]
	if not is_instance_valid(t):
		t = null
	var at: Vector3 = p["to"] if p["kind"] != "missile" else p["pos"]
	var dmg: float = p["dmg"]
	match p["kind"]:
		"shell":
			splash(at, p["splash"], dmg, p["pierce"], t, false, true)
			fx.burst(at, Color(1.0, 0.6, 0.2), 8, 4.0, 0.45, 0.18)
			fx.burst(at, Color(0.5, 0.5, 0.5), 4, 2.0, 0.6, 0.22)
			fx.ring(Vector3(at.x, 0.2, at.z), Color(1.0, 0.7, 0.3), p["splash"], 0.3)
			add_shake(0.04)
		"mortar":
			splash(at, p["splash"], dmg, p["pierce"], t, false, true)
			fx.burst(at, Color(1.0, 0.55, 0.15), 14, 6.0, 0.6, 0.22)
			fx.burst(at, Color(0.45, 0.42, 0.4), 8, 3.0, 0.9, 0.3)
			fx.ring(Vector3(at.x, 0.2, at.z), Color(1.0, 0.6, 0.25), p["splash"], 0.4)
			add_shake(0.12)
			sfx("boom", 0.12)
		"ice":
			var slow: float = p["slow"]
			var rad: float = p["splash"]
			for e in enemies.duplicate():
				if not e.alive:
					continue
				var dx: float = e.position.x - at.x
				var dz: float = e.position.z - at.z
				var rr: float = rad + float(e.size) * 0.3
				if dx * dx + dz * dz <= rr * rr:
					hit(e, dmg, 0.0, t, false)
					if e.alive:
						e.slow = maxf(e.slow, slow)
						e.slow_t = 1.6
						if p["freeze"] and e.type != "boss":
							e.freeze_t = 0.8
			fx.burst(at, Color(0.75, 0.95, 1.0), 8, 3.0, 0.5, 0.14)
			fx.ring(Vector3(at.x, at.y, at.z), Color(0.7, 0.95, 1.0), rad, 0.3)
		"missile":
			var tg = p["tg"]
			if is_instance_valid(tg) and tg.alive and tg.position.distance_to(at) < 2.5:
				hit(tg, dmg * (2.0 if tg.fly else 0.5), 0.0, t)
			else:
				for e in enemies:
					if e.alive and center(e).distance_to(at) < 1.5:
						hit(e, dmg * (2.0 if e.fly else 0.5), 0.0, t)
						break
			fx.burst(at, Color(1.0, 0.5, 0.2), 8, 4.0, 0.4, 0.16)
			fx.flash(at, Color(1, 0.8, 0.4), 0.6)

func chain(t, tg) -> void:
	var hitl := [tg]
	var cur = tg
	var dmg: float = t.s["dmg"]
	var pierce: float = t.s.get("pierce", 0.0)
	var from: Vector3 = t.muzzle()
	var chains: int = t.s.get("chains", 3)
	for i in chains:
		var c := center(cur)
		fx.bolt(from, c, Color(0.55, 0.9, 1.0), 0.14)
		fx.burst(c, Color(0.7, 0.95, 1.0), 3, 3.0, 0.25, 0.1)
		hit(cur, dmg, pierce, t)
		from = c
		var nxt = null
		var bd := 3.8
		for e in enemies:
			if hitl.has(e) or not can_hit(t, e):
				continue
			var dd: float = e.position.distance_to(cur.position)
			if dd < bd:
				bd = dd
				nxt = e
		if nxt == null:
			break
		hitl.append(nxt)
		cur = nxt
		dmg *= 0.85

func flame(t, tg, mz: Vector3) -> void:
	var tc := center(tg)
	var s: Dictionary = t.s
	for e in enemies.duplicate():
		if not e.alive or e.fly:
			continue
		if e.position.distance_to(tg.position) <= float(s["splash"]) + float(e.size) * 0.3:
			hit(e, float(s["dmg"]), 0.0, t, false)
			if e.alive:
				e.burn = maxf(e.burn, float(s["burn"]))
				e.burn_t = 2.0
				e.burn_src = t
	var dir := (tc - mz)
	var len := dir.length()
	dir = dir / maxf(len, 0.01)
	for i in 2:
		var col := Color(1.0, randf_range(0.35, 0.8), 0.1)
		fx.puff(mz, dir * len * randf_range(2.2, 3.0) + Vector3(randf_range(-0.6, 0.6), randf_range(0, 0.8), randf_range(-0.6, 0.6)), col, randf_range(0.25, 0.4), 0.35)
	sfx("flame", 0.22)

# ------------------------------------------------------------------ towers

func _make_tower(k: int, pi: int):
	var t = TowerS.new()
	t.position = pads[pi]["pos"] + Vector3(0, 0.25, 0)
	ents.add_child(t)
	t.setup(k, pi)
	t.head.rotation.y = randf() * TAU
	pads[pi]["tower"] = t
	towers.append(t)
	return t

func count_kind(id: String) -> int:
	var n := 0
	for t in towers:
		if t.id == id:
			n += 1
	return n

func try_place(k: int, pi: int) -> bool:
	if pi < 0 or pi >= pads.size() or pads[pi]["tower"] != null:
		return false
	var data: Dictionary = D.TOWERS[k]
	var cost: int = data["cost"]
	if data["id"] == "farm" and count_kind("farm") >= D.FARM_LIMIT:
		hud.toast("Farm limit reached (%d)" % D.FARM_LIMIT)
		sfx("error")
		return false
	if data["id"] == "beacon" and count_kind("beacon") >= D.BEACON_LIMIT:
		hud.toast("Beacon limit reached (%d)" % D.BEACON_LIMIT)
		sfx("error")
		return false
	if cash < cost:
		hud.toast("Need $%d for %s" % [cost, data["name"]])
		sfx("error")
		return false
	cash -= cost
	var t = _make_tower(k, pi)
	stats["built"] = int(stats.get("built", 0)) + 1
	refresh_buffs()
	fx.burst(t.position + Vector3(0, 0.3, 0), Color(0.8, 0.75, 0.6), 12, 4.0, 0.5, 0.16)
	fx.ring(t.position + Vector3(0, 0.2, 0), data["color"], 1.8, 0.35)
	sfx("place")
	place_kind = -1
	hud.on_place_mode(-1)
	select_tower(t)
	return true

func upgrade(t) -> bool:
	if t == null:
		return false
	var cost: int = t.upgrade_cost()
	if cost < 0:
		return false
	if cash < cost:
		hud.toast("Need $%d to upgrade" % cost)
		sfx("error")
		return false
	cash -= cost
	t.invested += cost
	t.level += 1
	t.rebuild()
	refresh_buffs()
	fx.burst(t.position + Vector3(0, 1.0, 0), Color(1, 0.85, 0.3), 16, 5.0, 0.6, 0.14)
	fx.ring(t.position + Vector3(0, 0.3, 0), Color(1, 0.85, 0.3), 2.0, 0.4)
	sfx("upgrade")
	hud.on_select(t)
	return true

func sell(t) -> void:
	if t == null:
		return
	var v: int = t.sell_value()
	cash += v
	pads[t.pad]["tower"] = null
	towers.erase(t)
	add_float(t.position + Vector3(0, 1.5, 0), "+$%d" % v, Color(1, 0.85, 0.3), 1.0)
	fx.burst(t.position + Vector3(0, 0.6, 0), Color(0.7, 0.7, 0.7), 14, 4.0, 0.6, 0.18)
	t.queue_free()
	sel_tower = null
	refresh_buffs()
	sfx("sell")
	hud.on_select(null)

func cycle_mode(t) -> void:
	if t == null or t.is_support():
		return
	t.mode = (t.mode + 1) % D.TARGET_MODES.size()
	sfx("click")
	hud.on_select(t)

func refresh_buffs() -> void:
	var beacons := []
	for t in towers:
		t.buff = {"range": 0.0, "rate": 0.0, "dmg": 0.0, "detect": false}
		if t.id == "beacon":
			t.recompute()
			beacons.append(t)
	for t in towers:
		if t.is_support():
			if t.id != "beacon":
				t.recompute()
			continue
		for b in beacons:
			if b.position.distance_to(t.position) <= float(b.s["range"]):
				t.buff["range"] = maxf(t.buff["range"], float(b.s["brange"]))
				t.buff["rate"] = maxf(t.buff["rate"], float(b.s["brate"]))
				t.buff["dmg"] = maxf(t.buff["dmg"], float(b.s["bdmg"]))
				if bool(b.s["detect"]):
					t.buff["detect"] = true
		t.recompute()

func select_tower(t) -> void:
	sel_tower = t
	if t != null:
		place_kind = -1
		sfx("click")
	hud.on_select(t)

func set_place_kind(k: int) -> void:
	if state != "play":
		return
	if place_kind == k:
		place_kind = -1
	else:
		place_kind = k
		sel_tower = null
		hud.on_select(null)
	sfx("click")
	hud.on_place_mode(place_kind)

func set_speed(s: int) -> void:
	speed = s
	hud.refresh_speed()

func toggle_pause() -> void:
	if state != "play":
		return
	paused = not paused
	hud.show_pause(paused)

func _update_indicators() -> void:
	var show_t = sel_tower if (sel_tower != null and is_instance_valid(sel_tower)) else null
	var pos := Vector3.ZERO
	var r := 0.0
	if show_t != null:
		pos = show_t.position
		r = float(show_t.s.get("range", 0.0))
	elif place_kind >= 0 and hover_pad >= 0:
		pos = pads[hover_pad]["pos"]
		r = float(D.TOWERS[place_kind]["lv"][0].get("range", 0.0))
	range_disc.visible = r > 0.0
	range_ring.visible = r > 0.0
	if r > 0.0:
		range_disc.position = Vector3(pos.x, 0.32, pos.z)
		range_disc.scale = Vector3(r, 1, r)
		range_ring.position = Vector3(pos.x, 0.34, pos.z)
		range_ring.scale = Vector3(r, 1, r)
	sel_ring.visible = show_t != null
	if show_t != null:
		sel_ring.position = Vector3(pos.x, 0.3, pos.z)
		sel_ring.rotation.y += 0.02
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	for i in pads.size():
		var pd: Dictionary = pads[i]
		var mi: MeshInstance3D = pd["node"]
		var glow: bool = place_kind >= 0 and pd["tower"] == null
		mi.material_override = pad_glow if glow else pad_norm
		mi.visible = pd["tower"] == null
		if glow:
			mi.scale = Vector3.ONE * (1.0 + (0.12 * pulse if i == hover_pad else 0.0))
		else:
			mi.scale = Vector3.ONE

# ------------------------------------------------------------------ input

func ground_point(sp: Vector2, y := 0.3):
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	if n.y > -0.001:
		return null
	var k := (y - o.y) / n.y
	return o + n * k

func nearest_pad(p: Vector3, maxd: float, free_only: bool) -> int:
	var best := -1
	var bd := maxd
	for i in pads.size():
		if free_only and pads[i]["tower"] != null:
			continue
		var d: float = Vector2(p.x - pads[i]["pos"].x, p.z - pads[i]["pos"].z).length()
		if d < bd:
			bd = d
			best = i
	return best

func nearest_tower(p: Vector3, maxd: float):
	var best = null
	var bd := maxd
	for t in towers:
		var d: float = Vector2(p.x - t.position.x, p.z - t.position.z).length()
		if d < bd:
			bd = d
			best = t
	return best

func click(sp: Vector2) -> void:
	if state != "play":
		return
	var gp = ground_point(sp, 0.3)
	if gp == null:
		return
	var gp2 = ground_point(sp, 1.0)
	if place_kind >= 0:
		var pi := nearest_pad(gp, 1.6, true)
		if pi >= 0:
			try_place(place_kind, pi)
			return
		var tt = nearest_tower(gp2 if gp2 != null else gp, 1.3)
		if tt != null:
			select_tower(tt)
			return
		hud.toast("Tap a glowing pad to build")
		return
	var t = nearest_tower(gp2 if gp2 != null else gp, 1.5)
	if t == null:
		t = nearest_tower(gp, 1.3)
	if t != null:
		select_tower(t)
	else:
		if sel_tower != null:
			select_tower(null)
		elif nearest_pad(gp, 1.4, true) >= 0:
			hud.toast("Pick a tower from the bar, then tap a pad")

func hover(sp: Vector2) -> void:
	if place_kind < 0:
		hover_pad = -1
		return
	var gp = ground_point(sp, 0.3)
	hover_pad = nearest_pad(gp, 1.8, true) if gp != null else -1

func _unhandled_input(ev: InputEvent) -> void:
	if state == "over":
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam.zoom_by(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam.zoom_by(1.1)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				press_pos = mb.position
				moved = 0.0
				drag_btn = mb.button_index
				pressing = true
			else:
				if pressing and moved < 14.0:
					if mb.button_index == MOUSE_BUTTON_LEFT:
						click(mb.position)
					elif mb.button_index == MOUSE_BUTTON_RIGHT:
						if place_kind >= 0:
							set_place_kind(place_kind)
						elif sel_tower != null:
							select_tower(null)
				pressing = false
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if pressing:
			moved += mm.relative.length()
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if pressing and moved >= 6.0 and state == "play":
			if drag_btn == MOUSE_BUTTON_RIGHT:
				cam.pan(mm.relative)
			else:
				cam.orbit(mm.relative)
		elif not pressing:
			hover(mm.position)
	elif ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			if touches.is_empty():
				touch_on_ui = hud.blocks(st.position)
			touches[st.index] = st.position
		else:
			touches.erase(st.index)
		if touches.size() >= 2:
			moved = 999.0
			var k := touches.keys()
			pinch_d = (touches[k[0]] as Vector2).distance_to(touches[k[1]])
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		touches[sd.index] = sd.position
		if touch_on_ui or state != "play":
			return
		if touches.size() == 1:
			if moved >= 8.0:
				cam.orbit(sd.relative * 1.2)
		elif touches.size() >= 2:
			var k := touches.keys()
			var dnow := (touches[k[0]] as Vector2).distance_to(touches[k[1]])
			if pinch_d > 1.0 and dnow > 1.0:
				cam.zoom_by(pinch_d / dnow)
			pinch_d = dnow
			cam.pan(sd.relative * 0.5)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		_key(ev as InputEventKey)

func _key(k: InputEventKey) -> void:
	if state != "play":
		return
	match k.keycode:
		KEY_ESCAPE:
			if place_kind >= 0:
				set_place_kind(place_kind)
			elif sel_tower != null:
				select_tower(null)
			else:
				toggle_pause()
		KEY_P: toggle_pause()
		KEY_SPACE, KEY_ENTER: call_next()
		KEY_F: set_speed(speed % 3 + 1)
		KEY_U: upgrade(sel_tower)
		KEY_X, KEY_DELETE, KEY_BACKSPACE: sell(sel_tower)
		KEY_T: cycle_mode(sel_tower)
		KEY_M:
			G.sound_on = not G.sound_on
			G.save()
			hud.refresh_sound()
		_:
			var c := int(k.keycode)
			if c >= KEY_1 and c <= KEY_9:
				set_place_kind(c - KEY_1)
			elif c == KEY_0:
				set_place_kind(9)

func _keys(delta: float) -> void:
	if state != "play" or paused:
		return
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x += 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x -= 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y -= 1
	if v != Vector2.ZERO:
		cam.pan(v * delta * 500.0)
	if Input.is_key_pressed(KEY_Q):
		cam.orbit(Vector2(-delta * 300.0, 0))
	if Input.is_key_pressed(KEY_E):
		cam.orbit(Vector2(delta * 300.0, 0))
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_EQUAL):
		cam.zoom_by(1.0 - delta * 1.5)
	if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_MINUS):
		cam.zoom_by(1.0 + delta * 1.5)

# ------------------------------------------------------------------ misc

func add_float(p: Vector3, text: String, col: Color, life: float) -> void:
	if floats.size() > 50:
		floats.remove_at(0)
	floats.append({"p": p, "text": text, "col": col, "t": 0.0, "life": life})

func add_shake(a: float) -> void:
	cam.shake = minf(1.5, cam.shake + a)

func sfx(n: String, gap := 0.045) -> void:
	if state == "title":
		return
	Sfx.play(n, gap)
