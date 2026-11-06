extends Node
## Headless smoke test: UI flows, a bot that plays all 3 maps, boss phases, endless, upgrades, targeting.
## Run: godot --headless --path . res://tests/Smoke.tscn   (prints SMOKE OK)

const D = preload("res://scripts/data.gd")
var main
var fails := 0
var pad_rank: Array = []
var plan := ["scout", "scout", "farm", "farm", "cannon", "volt", "sky", "farm", "rail", "frost", "mortar", "beacon", "rail", "mortar", "volt", "sky", "rail"]
var plan_i := 0

func ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	G.delete_save()
	G.sound_on = false
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await f(3)
	ok(main.state == "title", "starts on title")
	for i in 300:
		main.sim_step(0.05)
	ok(main.towers.size() >= 8, "demo towers placed")
	main.hud.show_maps()
	await f(2)
	main.hud.show_help("title")
	main.hud._close_help()
	main.hud.layout(true)
	await f(2)
	main.hud.layout(false)
	await f(2)
	# every tower: place, upgrade to max, cycle targeting, sell
	main.start_game(0, "normal")
	main.cash = 999999
	for k in D.TOWERS.size():
		var pi := _free_pad()
		ok(main.try_place(k, pi), "place tower %d" % k)
		var t = main.pads[pi]["tower"]
		ok(t != null, "tower exists %d" % k)
		for u in 4:
			ok(main.upgrade(t), "upgrade %s to %d" % [t.id, u + 1])
		ok(t.level == 4, "max level")
		ok(not main.upgrade(t), "no upgrade past max")
		for m in 5:
			main.cycle_mode(t)
		main.select_tower(t)
	var nb := 0
	for t in main.towers:
		if t.buff["rate"] > 0.0:
			nb += 1
	print("buffed towers near beacon: ", nb)
	var t0 = main.towers[0]
	main.sell(t0)
	ok(not main.towers.has(t0), "sold")
	main.hud.layout(true)
	main.select_tower(main.towers[0])
	await f(2)
	main.hud.layout(false)
	main.toggle_pause()
	ok(main.paused, "paused")
	main.toggle_pause()
	# fast-forward all waves with maxed towers to exercise everything incl. boss
	main.cash = 999999
	var guard := 0
	while main.state == "play" and guard < 200000:
		guard += 1
		if main.can_call() and main.enemies.size() < 30:
			main.call_next()
		main.sim_step(0.05)
		if main.boss != null:
			main.lives = 150
	print("maxed run: state=", main.state, " wave=", main.wave, " lives=", main.lives)
	ok(main.state == "over" and main.wave == 30, "maxed run reaches wave 30")
	# boss phase test
	main.start_game(1, "normal")
	main.wave = 29
	main.start_wave()
	var phases := {}
	guard = 0
	while guard < 40000 and main.state == "play":
		guard += 1
		main.sim_step(0.05)
		if main.boss != null:
			phases[main.boss.phase] = true
			if guard % 20 == 0:
				main.hit(main.boss, 300.0, 99.0, null)
	print("boss phases seen: ", phases.keys(), " state=", main.state)
	ok(phases.has(3), "boss reaches phase 3")
	# endless
	main.start_game(2, "endless")
	main.cash = 999999
	main.wave = 39
	main.start_wave()
	ok(main.spawnq.size() >= 3, "endless wave groups")
	for i in 400:
		main.sim_step(0.05)
	ok(main.wave >= 40, "endless wave 40")
	main.quit_to_title()
	ok(G.get_best(2, "endless") >= 39, "endless best recorded")
	# bot plays each map normally
	for mi in 3:
		var res = await _bot(mi)
		print("  leaks by type: ", main.stats["lt"], "  towers: ", main.towers.map(func(x): return "%s%d" % [x.id, x.level]))
		print("BOT map %d (%s): state=%s wave=%d lives=%d cash=%d towers=%d kills=%d" % [mi, D.MAPS[mi]["name"], main.state, main.wave, main.lives, main.cash, main.towers.size(), main.stats["kills"]])
	main.go_title()
	await f(2)
	if fails == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FAILED: ", fails)
	get_tree().quit()

func _free_pad() -> int:
	for i in main.pads.size():
		if main.pads[i]["tower"] == null:
			return i
	return -1

func _rank_pads() -> void:
	pad_rank = []
	for i in main.pads.size():
		var p: Vector3 = main.pads[i]["pos"]
		var c := 0
		var d := 0.0
		while d < main.path_len:
			if p.distance_to(main.path_pos(d)) < 8.0:
				c += 1
			d += 1.0
		pad_rank.append([c, i])
	pad_rank.sort_custom(func(a, b): return a[0] > b[0])

func _best_pad(farm: bool) -> int:
	if farm:
		for k in range(pad_rank.size() - 1, -1, -1):
			if main.pads[pad_rank[k][1]]["tower"] == null:
				return pad_rank[k][1]
	for r in pad_rank:
		if main.pads[r[1]]["tower"] == null:
			return r[1]
	return -1

func _bot(mi: int) -> bool:
	main.start_game(mi, "normal")
	_rank_pads()
	plan_i = 0
	var t := 0.0
	var steps := 0
	while main.state == "play" and steps < 400000:
		steps += 1
		t += 0.05
		if t >= 0.5:
			t = 0.0
			_bot_act()
		if main.wave == 0 and main.towers.size() >= 2:
			main.call_next()
		main.sim_step(0.05)
	return main.state == "over"

func _bot_act() -> void:
	if main.wave >= 6:
		var det := false
		for tw in main.towers:
			if tw.s["detect"]:
				det = true
		if not det:
			for tw in main.towers:
				if tw.id == "scout" and tw.level < 2:
					if main.cash >= tw.upgrade_cost():
						main.upgrade(tw)
					return
	for n in 4:
		if plan_i < plan.size():
			var id: String = plan[plan_i]
			var k := D.tower_index(id)
			var cost: int = D.TOWERS[k]["cost"]
			if main.cash >= cost:
				var pi := _best_pad(id == "farm")
				if pi >= 0 and main.try_place(k, pi):
					plan_i += 1
					continue
				plan_i += 1
				continue
			# farms: upgrade early
		var best = null
		var bc := 1e9
		for tw in main.towers:
			var c: int = tw.upgrade_cost()
			if c < 0:
				continue
			var score := float(c) * (0.4 if tw.id == "farm" and main.wave < 16 else 1.0)
			if tw.id == "farm" and main.wave >= 22:
				score *= 10.0
			if score < bc:
				bc = score
				best = tw
		if best != null and main.cash >= best.upgrade_cost() and (plan_i >= plan.size() or best.upgrade_cost() < D.TOWERS[D.tower_index(plan[plan_i])]["cost"]):
			main.upgrade(best)
		else:
			return
