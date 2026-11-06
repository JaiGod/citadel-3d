extends Node3D
## A placed tower: model, cached stats (with beacon buffs), targeting and firing.

const D = preload("res://scripts/data.gd")
const M = preload("res://scripts/models.gd")

var kind := 0
var id := "scout"
var level := 0
var pad := -1
var cd := 0.2
var mode := 0
var invested := 0
var model: Node3D
var head: Node3D
var head_y := 0.4
var muzzles: Array = []
var barrels: Array = []
var barrel_base: Array = []
var spinner: Node3D = null
var s := {}
var buff := {"range": 0.0, "rate": 0.0, "dmg": 0.0, "detect": false}
var stun := 0.0
var kills := 0
var dmg_dealt := 0.0
var recoil := 0.0
var shot_i := 0
var frost_count := 0
var pop := 0.0
var air := true
var ground := true

func setup(k: int, pad_i: int) -> void:
	kind = k
	var data: Dictionary = D.TOWERS[k]
	id = data["id"]
	air = data["air"]
	ground = data["ground"]
	pad = pad_i
	invested = int(data["cost"])
	mode = 0
	model = Node3D.new()
	add_child(model)
	rebuild()

func rebuild() -> void:
	M.build_tower(self)
	barrel_base = []
	for b in barrels:
		barrel_base.append(b.position)
	recompute()
	pop = 1.0

func recompute() -> void:
	var base: Dictionary = D.TOWERS[kind]["lv"][level]
	s = base.duplicate()
	s["range"] = float(base.get("range", 0.0)) * (1.0 + float(buff["range"]))
	if base.has("rate"):
		s["rate"] = float(base["rate"]) * (1.0 + float(buff["rate"]))
	if base.has("dmg"):
		s["dmg"] = float(base["dmg"]) * (1.0 + float(buff["dmg"]))
	s["detect"] = bool(base.get("detect", false)) or bool(buff["detect"])

func upgrade_cost() -> int:
	if level >= 4:
		return -1
	return int(D.TOWERS[kind]["up"][level])

func sell_value() -> int:
	return int(invested * D.SELL_RATE)

func is_support() -> bool:
	return id == "farm" or id == "beacon"

func muzzle() -> Vector3:
	if muzzles.is_empty():
		return global_position + Vector3(0, head_y + 0.5, 0)
	var mk: Node3D = muzzles[shot_i % muzzles.size()]
	return mk.global_position

func update(dt: float, g) -> void:
	if pop > 0.0:
		pop = maxf(0.0, pop - dt * 4.0)
		var k := 1.0 + sin(pop * PI) * 0.25
		model.scale = Vector3(k, 1.0 / k, k) if pop > 0.0 else Vector3.ONE
	if spinner:
		var sp := 1.5
		match id:
			"volt": sp = 2.0 + level
			"farm": sp = 1.2 + level * 0.5
			"beacon": sp = 1.0
		spinner.rotation.y += dt * sp if id != "farm" else 0.0
		if id == "farm":
			spinner.rotation.z += dt * sp
	if recoil > 0.0:
		recoil = maxf(0.0, recoil - dt * 6.0)
		for i in barrels.size():
			var b: Node3D = barrels[i]
			var bb: Vector3 = barrel_base[i]
			b.position = bb + Vector3(0, 0, recoil * 0.18)
	if stun > 0.0:
		stun -= dt
		if randf() < dt * 6.0:
			g.fx.burst(global_position + Vector3(0, head_y + 0.6, 0), Color(0.5, 0.8, 1.0), 2, 2.0, 0.3, 0.1)
		return
	if is_support():
		return
	cd -= dt
	var tg = g.pick_target(self)
	if tg == null:
		if cd < 0.0:
			cd = 0.0
		return
	if head and id != "volt" and id != "frost":
		var dir: Vector3 = tg.global_position - global_position
		head.rotation.y = lerp_angle(head.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, dt * 14.0))
	if cd <= 0.0:
		cd = 1.0 / float(s["rate"])
		fire(tg, g)

func fire(tg, g) -> void:
	recoil = 1.0
	var mz := muzzle()
	shot_i += 1
	var dmg: float = s.get("dmg", 0.0)
	var tc: Vector3 = g.center(tg)
	match id:
		"scout":
			g.hit(tg, dmg, 0.0, self)
			g.fx.beam(mz, tc, Color(1.0, 0.95, 0.55), 0.05, 0.07)
			g.fx.flash(mz, Color(1.0, 0.9, 0.5), 0.18)
			g.sfx("rifle")
		"rail":
			g.hit(tg, dmg, 99.0, self)
			g.fx.beam(mz, tc, Color(0.85, 0.6, 1.0), 0.16, 0.25)
			g.fx.beam(mz, tc, Color(1, 1, 1), 0.06, 0.18)
			g.fx.flash(mz, Color(0.8, 0.5, 1.0), 0.35)
			g.fx.burst(tc, Color(0.85, 0.6, 1.0), 6, 4.0, 0.35, 0.12)
			g.add_shake(0.08)
			g.sfx("rail")
		"cannon":
			g.launch(self, "shell", mz, tg, 0.35, 1.0)
			g.fx.flash(mz, Color(1.0, 0.7, 0.3), 0.3)
			g.fx.burst(mz, Color(0.7, 0.7, 0.7), 3, 1.5, 0.4, 0.15)
			g.sfx("cannon")
		"mortar":
			g.launch(self, "mortar", mz, tg, 1.2, 6.0)
			g.fx.burst(mz, Color(0.75, 0.75, 0.7), 5, 2.0, 0.5, 0.18)
			g.sfx("mortar")
		"frost":
			frost_count += 1
			g.launch(self, "ice", mz, tg, 0.3, 0.5)
			g.sfx("frost")
		"sky":
			var n: int = s.get("missiles", 1)
			for i in n:
				g.launch(self, "missile", muzzle(), tg, 0.0, 0.0)
				shot_i += 1
			g.sfx("missile")
		"volt":
			g.chain(self, tg)
			g.sfx("zap")
		"flame":
			g.flame(self, tg, mz)
