extends RefCounted
## Static game data: towers, enemies, maps and the 30 hand-made waves.

const TARGET_MODES := ["First", "Last", "Strongest", "Weakest", "Closest"]
const FARM_LIMIT := 6
const BEACON_LIMIT := 3
const START_LIVES := 150
const SELL_RATE := 0.6

# lv: stats per level 0..4 (4 upgrades). up: cost of upgrades 1..4.
const TOWERS := [
	{"id": "scout", "name": "Scout Post", "cost": 250, "color": Color(0.36, 0.72, 0.36), "air": true, "ground": true,
	 "desc": "Cheap rapid-fire rifle. Sees stealth from level 2.",
	 "up": [200, 450, 1000, 2500],
	 "lv": [{"dmg": 4, "rate": 2.4, "range": 9.0},
			{"dmg": 5, "rate": 3.0, "range": 9.5},
			{"dmg": 7, "rate": 3.4, "range": 10.0, "detect": true},
			{"dmg": 11, "rate": 4.4, "range": 11.0, "detect": true},
			{"dmg": 18, "rate": 6.0, "range": 12.0, "detect": true}]},
	{"id": "cannon", "name": "Bastion Cannon", "cost": 450, "color": Color(0.85, 0.55, 0.22), "air": false, "ground": true,
	 "desc": "Explosive splash shells. Ground only. Cracks armor at level 2.",
	 "up": [350, 800, 1800, 4200],
	 "lv": [{"dmg": 14, "rate": 0.6, "range": 8.0, "splash": 1.8},
			{"dmg": 20, "rate": 0.65, "range": 8.5, "splash": 1.9},
			{"dmg": 30, "rate": 0.7, "range": 9.0, "splash": 2.0, "pierce": 3},
			{"dmg": 48, "rate": 0.8, "range": 9.5, "splash": 2.4, "pierce": 4},
			{"dmg": 85, "rate": 0.9, "range": 10.0, "splash": 3.0, "pierce": 6}]},
	{"id": "volt", "name": "Volt Coil", "cost": 600, "color": Color(0.3, 0.8, 1.0), "air": true, "ground": true,
	 "desc": "Lightning that chains between enemies and ignores some armor.",
	 "up": [500, 1100, 2400, 5200],
	 "lv": [{"dmg": 8, "rate": 0.8, "range": 7.0, "chains": 3, "pierce": 2},
			{"dmg": 11, "rate": 0.9, "range": 7.5, "chains": 3, "pierce": 2},
			{"dmg": 15, "rate": 1.0, "range": 8.0, "chains": 4, "pierce": 3},
			{"dmg": 24, "rate": 1.1, "range": 8.5, "chains": 5, "pierce": 4},
			{"dmg": 40, "rate": 1.3, "range": 9.0, "chains": 7, "pierce": 6}]},
	{"id": "frost", "name": "Frost Spire", "cost": 400, "color": Color(0.6, 0.85, 1.0), "air": true, "ground": true,
	 "desc": "Ice shards slow everything in a small area. Level 4 freezes solid.",
	 "up": [300, 700, 1500, 3400],
	 "lv": [{"dmg": 2, "rate": 1.0, "range": 7.0, "splash": 1.6, "slow": 0.3},
			{"dmg": 3, "rate": 1.0, "range": 7.5, "splash": 1.7, "slow": 0.35},
			{"dmg": 5, "rate": 1.1, "range": 8.0, "splash": 1.9, "slow": 0.4},
			{"dmg": 8, "rate": 1.2, "range": 8.5, "splash": 2.1, "slow": 0.5},
			{"dmg": 14, "rate": 1.3, "range": 9.0, "splash": 2.4, "slow": 0.6, "freeze": true}]},
	{"id": "sky", "name": "Skyhunter", "cost": 700, "color": Color(0.9, 0.3, 0.35), "air": true, "ground": true,
	 "desc": "Homing missiles. Double damage to flyers, half to ground.",
	 "up": [550, 1200, 2600, 5500],
	 "lv": [{"dmg": 22, "rate": 0.9, "range": 11.0, "missiles": 1},
			{"dmg": 30, "rate": 0.95, "range": 11.5, "missiles": 1},
			{"dmg": 42, "rate": 1.0, "range": 12.0, "missiles": 2},
			{"dmg": 60, "rate": 1.05, "range": 13.0, "missiles": 2, "detect": true},
			{"dmg": 100, "rate": 1.1, "range": 14.0, "missiles": 3, "detect": true}]},
	{"id": "flame", "name": "Ember Thrower", "cost": 500, "color": Color(1.0, 0.45, 0.1), "air": false, "ground": true,
	 "desc": "Short-range fire stream that burns crowds. Weak against armor.",
	 "up": [400, 900, 2000, 4500],
	 "lv": [{"dmg": 3, "rate": 6.0, "range": 5.0, "splash": 1.4, "burn": 3},
			{"dmg": 4, "rate": 6.0, "range": 5.5, "splash": 1.5, "burn": 4},
			{"dmg": 6, "rate": 6.5, "range": 6.0, "splash": 1.6, "burn": 6},
			{"dmg": 9, "rate": 7.0, "range": 6.0, "splash": 1.8, "burn": 10},
			{"dmg": 15, "rate": 7.5, "range": 6.5, "splash": 2.0, "burn": 18}]},
	{"id": "rail", "name": "Lancer Rail", "cost": 900, "color": Color(0.7, 0.45, 1.0), "air": true, "ground": true,
	 "desc": "Long-range railgun. Pierces all armor and always sees stealth.",
	 "up": [700, 1500, 3200, 7000],
	 "lv": [{"dmg": 60, "rate": 0.35, "range": 16.0, "detect": true, "pierce": 99},
			{"dmg": 85, "rate": 0.38, "range": 17.0, "detect": true, "pierce": 99},
			{"dmg": 120, "rate": 0.42, "range": 18.0, "detect": true, "pierce": 99},
			{"dmg": 190, "rate": 0.48, "range": 20.0, "detect": true, "pierce": 99},
			{"dmg": 340, "rate": 0.55, "range": 22.0, "detect": true, "pierce": 99}]},
	{"id": "mortar", "name": "Mortar Pit", "cost": 650, "color": Color(0.55, 0.6, 0.4), "air": false, "ground": true,
	 "desc": "Huge range, big blast radius, slow lobbed shells. Ground only.",
	 "up": [500, 1100, 2500, 5500],
	 "lv": [{"dmg": 24, "rate": 0.33, "range": 18.0, "splash": 2.6, "pierce": 2},
			{"dmg": 32, "rate": 0.33, "range": 19.0, "splash": 2.7, "pierce": 2},
			{"dmg": 46, "rate": 0.35, "range": 20.0, "splash": 3.0, "pierce": 3},
			{"dmg": 72, "rate": 0.38, "range": 21.0, "splash": 3.2, "pierce": 4},
			{"dmg": 130, "rate": 0.45, "range": 22.0, "splash": 3.6, "pierce": 6}]},
	{"id": "farm", "name": "Harvest Mill", "cost": 250, "color": Color(0.95, 0.8, 0.3), "air": false, "ground": false,
	 "desc": "Farm: pays out cash at the start of every wave. Max 6.",
	 "up": [200, 550, 1100, 2200],
	 "lv": [{"income": 50, "range": 0.0}, {"income": 100, "range": 0.0}, {"income": 200, "range": 0.0},
			{"income": 400, "range": 0.0}, {"income": 750, "range": 0.0}]},
	{"id": "beacon", "name": "Beacon Relay", "cost": 800, "color": Color(1.0, 0.4, 0.8), "air": false, "ground": false,
	 "desc": "Support: boosts range and fire rate of nearby towers. Level 2 grants stealth sight. Max 3.",
	 "up": [600, 1300, 2600, 5000],
	 "lv": [{"range": 6.0, "brange": 0.10, "brate": 0.10, "bdmg": 0.0},
			{"range": 6.0, "brange": 0.15, "brate": 0.15, "bdmg": 0.0},
			{"range": 6.5, "brange": 0.15, "brate": 0.15, "bdmg": 0.0, "detect": true},
			{"range": 7.0, "brange": 0.20, "brate": 0.20, "bdmg": 0.05, "detect": true},
			{"range": 7.5, "brange": 0.25, "brate": 0.30, "bdmg": 0.15, "detect": true}]},
]

const ENEMIES := {
	"grunt": {"name": "Grunt", "hp": 14, "spd": 2.0, "bounty": 4, "leak": 1, "color": Color(0.85, 0.3, 0.3), "size": 0.8},
	"dasher": {"name": "Dasher", "hp": 9, "spd": 3.8, "bounty": 4, "leak": 1, "color": Color(1.0, 0.85, 0.25), "size": 0.6},
	"brute": {"name": "Brute", "hp": 70, "spd": 1.4, "bounty": 12, "leak": 4, "color": Color(0.55, 0.3, 0.75), "size": 1.2},
	"shellback": {"name": "Shellback", "hp": 40, "spd": 1.6, "bounty": 10, "leak": 3, "armor": 3, "color": Color(0.2, 0.65, 0.6), "size": 0.95},
	"wisp": {"name": "Wisp", "hp": 22, "spd": 2.6, "bounty": 7, "leak": 2, "fly": true, "color": Color(0.5, 0.95, 1.0), "size": 0.7},
	"shade": {"name": "Shade", "hp": 30, "spd": 2.4, "bounty": 9, "leak": 2, "hidden": true, "color": Color(0.45, 0.25, 0.7), "size": 0.8},
	"splitter": {"name": "Splitter", "hp": 50, "spd": 1.8, "bounty": 8, "leak": 3, "color": Color(1.0, 0.55, 0.2), "size": 1.0},
	"mender": {"name": "Mender", "hp": 45, "spd": 1.7, "bounty": 12, "leak": 3, "color": Color(0.9, 0.95, 0.85), "size": 0.9},
	"juggernaut": {"name": "Juggernaut", "hp": 550, "spd": 0.9, "bounty": 120, "leak": 15, "armor": 6, "color": Color(0.5, 0.55, 0.62), "size": 1.6},
	"stormwing": {"name": "Stormwing", "hp": 110, "spd": 2.0, "bounty": 25, "leak": 6, "armor": 3, "fly": true, "color": Color(0.3, 0.45, 0.95), "size": 1.1},
	"boss": {"name": "The Iron Tyrant", "hp": 12000, "spd": 0.7, "bounty": 2000, "leak": 150, "armor": 10, "color": Color(0.35, 0.33, 0.38), "size": 2.4},
}

const ENEMY_INFO := {
	"grunt": "Basic walker.", "dasher": "Very fast, fragile.", "brute": "Slow and tough.",
	"shellback": "Armored: flat damage reduction.", "wisp": "Flying: only anti-air towers hit it.",
	"shade": "Stealth: needs detection.", "splitter": "Bursts into 3 Dashers.",
	"mender": "Heals nearby enemies.", "juggernaut": "Heavily armored mini-boss.",
	"stormwing": "Armored flyer.", "boss": "3-phase boss: shields, summons, EMP.",
}

const MAPS := [
	{"name": "Greenvale Crossing", "diff": "Easy", "hpm": 0.85, "cash": 650,
	 "ground": Color(0.42, 0.68, 0.3), "ground2": Color(0.36, 0.6, 0.26), "path": Color(0.86, 0.74, 0.5),
	 "edge": Color(0.45, 0.32, 0.2), "sky": Color(0.55, 0.78, 0.95), "deco": "forest",
	 "pts": [Vector2(-21, -9), Vector2(-9, -9), Vector2(-9, 5), Vector2(1, 5), Vector2(1, -7), Vector2(11, -7), Vector2(11, 7), Vector2(21, 7)]},
	{"name": "Frostline Pass", "diff": "Normal", "hpm": 1.3, "cash": 600,
	 "ground": Color(0.88, 0.92, 0.97), "ground2": Color(0.8, 0.86, 0.94), "path": Color(0.6, 0.7, 0.82),
	 "edge": Color(0.45, 0.5, 0.6), "sky": Color(0.7, 0.8, 0.92), "deco": "snow",
	 "pts": [Vector2(-21, 10), Vector2(-13, 10), Vector2(-13, -9), Vector2(-5, -9), Vector2(-5, 8), Vector2(4, 8), Vector2(4, -9), Vector2(12, -9), Vector2(12, 3), Vector2(21, 3)]},
	{"name": "Cinder Forge", "diff": "Hard", "hpm": 1.15, "cash": 550,
	 "ground": Color(0.25, 0.21, 0.22), "ground2": Color(0.3, 0.24, 0.24), "path": Color(0.5, 0.36, 0.3),
	 "edge": Color(0.15, 0.12, 0.12), "sky": Color(0.25, 0.14, 0.14), "deco": "lava",
	 "pts": [Vector2(-21, 0), Vector2(-11, 0), Vector2(-11, -8), Vector2(0, -8), Vector2(0, 8), Vector2(10, 8), Vector2(10, -1), Vector2(21, -1)]},
]

# [type, count, interval, delay]
const WAVES := [
	[["grunt", 6, 1.3, 0.0]],
	[["grunt", 10, 1.0, 0.0]],
	[["grunt", 8, 0.9, 0.0], ["dasher", 4, 0.8, 5.0]],
	[["dasher", 10, 0.6, 0.0], ["grunt", 8, 0.8, 3.0]],
	[["brute", 3, 2.5, 0.0], ["grunt", 10, 0.7, 2.0]],
	[["wisp", 6, 1.2, 0.0], ["grunt", 10, 0.6, 4.0]],
	[["shellback", 5, 1.6, 0.0], ["dasher", 10, 0.5, 4.0]],
	[["shade", 6, 1.4, 0.0], ["grunt", 14, 0.5, 2.0]],
	[["splitter", 6, 1.5, 0.0], ["wisp", 8, 0.9, 5.0]],
	[["brute", 6, 1.4, 0.0], ["juggernaut", 1, 1.0, 8.0], ["grunt", 15, 0.4, 2.0]],
	[["mender", 4, 2.0, 0.0], ["shellback", 8, 1.0, 1.0], ["dasher", 12, 0.4, 6.0]],
	[["shade", 10, 0.9, 0.0], ["wisp", 10, 0.8, 3.0]],
	[["stormwing", 4, 2.0, 0.0], ["brute", 8, 1.1, 3.0]],
	[["splitter", 10, 1.0, 0.0], ["mender", 4, 1.8, 4.0], ["shade", 8, 0.8, 6.0]],
	[["juggernaut", 2, 6.0, 0.0], ["shellback", 12, 0.8, 2.0], ["wisp", 12, 0.6, 8.0]],
	[["dasher", 30, 0.25, 0.0], ["brute", 10, 0.9, 4.0]],
	[["stormwing", 8, 1.2, 0.0], ["shade", 14, 0.6, 2.0]],
	[["mender", 8, 1.2, 0.0], ["shellback", 16, 0.6, 1.0], ["splitter", 10, 0.8, 6.0]],
	[["brute", 16, 0.7, 0.0], ["wisp", 20, 0.4, 3.0], ["shade", 12, 0.6, 6.0]],
	[["juggernaut", 3, 4.0, 0.0], ["mender", 6, 1.5, 2.0], ["stormwing", 10, 1.0, 6.0]],
	[["splitter", 18, 0.6, 0.0], ["shade", 18, 0.5, 4.0]],
	[["shellback", 24, 0.45, 0.0], ["mender", 8, 1.2, 3.0], ["wisp", 20, 0.4, 6.0]],
	[["stormwing", 14, 0.8, 0.0], ["brute", 20, 0.5, 2.0]],
	[["juggernaut", 4, 3.0, 0.0], ["shade", 24, 0.4, 3.0], ["splitter", 14, 0.7, 6.0]],
	[["dasher", 50, 0.15, 0.0], ["stormwing", 16, 0.7, 3.0], ["mender", 10, 1.0, 5.0]],
	[["brute", 30, 0.4, 0.0], ["shellback", 24, 0.4, 4.0], ["shade", 20, 0.4, 8.0]],
	[["juggernaut", 6, 2.5, 0.0], ["stormwing", 20, 0.6, 4.0], ["mender", 12, 0.9, 6.0]],
	[["splitter", 30, 0.4, 0.0], ["wisp", 40, 0.25, 3.0], ["shade", 30, 0.3, 6.0]],
	[["juggernaut", 6, 2.5, 0.0], ["brute", 30, 0.35, 2.0], ["stormwing", 24, 0.5, 6.0], ["mender", 14, 0.8, 8.0]],
	[["boss", 1, 1.0, 0.0], ["shellback", 20, 0.8, 4.0], ["shade", 20, 0.8, 10.0], ["stormwing", 12, 1.4, 16.0]],
]

const ENDLESS_POOL := ["grunt", "dasher", "brute", "shellback", "wisp", "shade", "splitter", "mender", "stormwing", "juggernaut"]

static func hp_mult_raw(n: int) -> float:
	var k := float(n - 1)
	var m := 1.0 + 0.08 * k + 0.004 * k * k
	if n > 30:
		m *= pow(1.12, n - 30)
	return m

static func wave_groups(n: int) -> Array:
	if n <= WAVES.size():
		return WAVES[n - 1]
	var r := RandomNumberGenerator.new()
	r.seed = n * 7919
	var out := []
	var groups := 3 + mini(n / 10, 4)
	for i in groups:
		var t: String = ENDLESS_POOL[r.randi() % ENDLESS_POOL.size()]
		var c := 10 + n / 2
		if t == "juggernaut":
			c = maxi(2, c / 6)
		elif t == "stormwing" or t == "brute":
			c = c / 2
		out.append([t, c, r.randf_range(0.25, 0.8), i * 3.0])
	if n % 10 == 0:
		out.append(["boss", 1 + (n - 30) / 20, 6.0, 0.0])
	return out

static func wave_bonus(n: int) -> int:
	return 100 + 25 * n

static func tower_index(id: String) -> int:
	for i in TOWERS.size():
		if TOWERS[i]["id"] == id:
			return i
	return -1
