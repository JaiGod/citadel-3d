extends Node3D
## One enemy walking (or flying) along the map path. Driven by main.sim_step().

const D = preload("res://scripts/data.gd")
const M = preload("res://scripts/models.gd")

var type := "grunt"
var hp := 10.0
var maxhp := 10.0
var armor := 0.0
var spd := 2.0
var bounty := 4
var leak := 1
var fly := false
var hidden := false
var d := 0.0            # distance travelled along the path
var alive := true
var model: Node3D
var slow := 0.0
var slow_t := 0.0
var freeze_t := 0.0
var burn := 0.0
var burn_t := 0.0
var burn_src = null
var flash := 0.0
var phase := 1
var pause_t := 0.0
var shield_t := 0.0
var ability_t := 6.0
var heal_t := 2.0
var bob := 0.0
var lane := 0.0
var cur_speed := 0.0
var size := 1.0

func setup(t: String, mult: float, bounty_mult: float) -> void:
	type = t
	var dd: Dictionary = D.ENEMIES[t]
	size = float(dd["size"])
	maxhp = float(dd["hp"]) * mult
	hp = maxhp
	armor = float(dd.get("armor", 0))
	spd = float(dd["spd"])
	bounty = int(round(float(dd["bounty"]) * bounty_mult))
	leak = int(dd["leak"])
	fly = bool(dd.get("fly", false))
	hidden = bool(dd.get("hidden", false))
	bob = randf() * TAU
	lane = randf_range(-0.35, 0.35) if t != "boss" else 0.0
	model = Node3D.new()
	add_child(model)
	M.build_enemy(self)

func height() -> float:
	return 2.8 if fly else 0.0

func update(dt: float, g) -> void:
	if not alive:
		return
	bob += dt * (6.0 if not fly else 3.0)
	if flash > 0.0:
		flash -= dt
	if shield_t > 0.0:
		shield_t -= dt
	if slow_t > 0.0:
		slow_t -= dt
		if slow_t <= 0.0:
			slow = 0.0
	if burn_t > 0.0:
		burn_t -= dt
		g.hit(self, burn * dt, 0.0, burn_src, false)
		if not alive:
			return
		if randf() < dt * 8.0:
			g.fx.burst(global_position + Vector3(0, 0.6 + height(), 0), Color(1, 0.5, 0.1), 1, 1.5, 0.4, 0.15)
	if type == "mender":
		heal_t -= dt
		if heal_t <= 0.0:
			heal_t = 2.0
			g.mender_pulse(self)
	if type == "boss":
		_boss_logic(dt, g)
	cur_speed = 0.0
	if freeze_t > 0.0:
		freeze_t -= dt
	elif pause_t > 0.0:
		pause_t -= dt
	else:
		var sm := slow * (0.5 if type == "boss" or type == "juggernaut" else 1.0)
		cur_speed = spd * (1.0 - sm)
		d += cur_speed * dt
	if d >= g.path_len:
		g.leak(self)
		return
	var p: Vector3 = g.path_pos(d)
	var dir: Vector3 = g.path_dir(d)
	var side := Vector3(-dir.z, 0, dir.x)
	var y: float = height() + (absf(sin(bob)) * 0.12 if not fly else sin(bob) * 0.25)
	position = p + side * lane + Vector3(0, y, 0)
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, dt * 10.0))
	var sc := 1.0 + (0.18 if flash > 0.0 else 0.0)
	if freeze_t > 0.0:
		sc *= 0.92
	model.scale = Vector3(sc, sc * (1.0 - (0.08 if flash > 0.0 else 0.0)), sc)

func _boss_logic(dt: float, g) -> void:
	var f := hp / maxhp
	if phase == 1 and f <= 0.66:
		phase = 2
		pause_t = 2.5
		shield_t = 2.5
		armor += 4.0
		ability_t = 3.0
		M.build_enemy(self)
		g.boss_phase(self, 2)
	elif phase == 2 and f <= 0.33:
		phase = 3
		pause_t = 2.0
		shield_t = 2.0
		spd *= 1.7
		ability_t = 3.0
		M.build_enemy(self)
		g.boss_phase(self, 3)
	ability_t -= dt
	if ability_t <= 0.0:
		if phase == 2:
			ability_t = 8.0
			g.spawn_near(self, "shellback", 2)
		elif phase == 3:
			ability_t = 9.0
			g.emp(self)
		else:
			ability_t = 10.0
			g.spawn_near(self, "grunt", 3)
