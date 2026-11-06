extends Node
## Captures README screenshots (needs a display, e.g. xvfb-run). SHOTS=<dir>, PORTRAIT=1 for the phone layout.
const D = preload("res://scripts/data.gd")
var main
var out := "user://"
var portrait := false

func _ready() -> void:
	out = OS.get_environment("SHOTS") if OS.get_environment("SHOTS") != "" else "user://"
	portrait = OS.get_environment("PORTRAIT") == "1"
	_run.call_deferred()

func f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func sim(sec: float) -> void:
	var n := int(sec / 0.05)
	for i in n:
		main.sim_step(0.05)
		if i % 10 == 0:
			main.fx.update(0.05 * 10)

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var w := 900 if not portrait else 420
	var j: Image = img.duplicate()
	j.resize(w, int(float(w) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	j.save_jpg(out + "/" + name + ".jpg", 0.72)
	print("[shot] ", name)

func _build_base(levels: Array) -> void:
	main.cash = 9999999
	var kinds := [0, 1, 2, 4, 6, 7, 3, 8, 9, 5, 0, 2, 6, 1]
	var step := maxi(1, main.pads.size() / kinds.size())
	for i in kinds.size():
		var pi: int = (i * step + 1) % main.pads.size()
		if main.pads[pi]["tower"] != null:
			continue
		main.try_place(kinds[i], pi)
		var t = main.pads[pi]["tower"]
		for u in int(levels[i % levels.size()]):
			main.upgrade(t)
	main.select_tower(null)

func _run() -> void:
	get_window().size = Vector2i(390, 844) if portrait else Vector2i(1280, 720)
	G.sound_on = false
	G.delete_save()
	G.best = {"0:normal": 30, "1:normal": 22, "0:endless": 41}
	G.wins = {"0:normal": 2}
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await f(30)
	sim(6.0)
	await f(30)
	if portrait:
		main.start_game(0, "normal")
		_build_base([1, 0, 2])
		main.wave = 15
		main.start_wave()
		sim(6.0)
		main.cash = 1830
		main.select_tower(main.towers[1])
		await f(30)
		await snap("mobile")
		get_tree().quit()
		return
	await snap("title")
	main.hud.show_maps()
	await f(20)
	await snap("maps")
	main.start_game(0, "normal")
	_build_base([1, 0, 2, 1])
	main.wave = 18
	main.start_wave()
	sim(7.0)
	main.cash = 2475
	main.lives = 137
	main.cam.reset_view(Vector3(-3, 0, 0), 0.35, 0.85, 36.0)
	await f(30)
	await snap("battle")
	# upgrade showcase: one tower type at levels 0..4, close-up with the panel open
	main.start_game(1, "normal")
	main.cash = 9999999
	var row := []
	for pi in main.pads.size():
		var p: Vector3 = main.pads[pi]["pos"]
		if p.z > 9.0 and p.x < -6.0:
			row.append(pi)
	row = row.slice(0, 5)
	for i in row.size():
		main.try_place(1, row[i])
		var t = main.pads[row[i]]["tower"]
		for u in mini(i * 2, 4):
			main.upgrade(t)
	main.hud.banner_t = 0.0
	if row.size() > 0:
		var c: Vector3 = main.pads[row[0]]["pos"]
		main.cam.reset_view(c + Vector3(4, 0, -1), 0.5, 0.6, 16.0)
		main.select_tower(main.pads[row[row.size() - 1]]["tower"])
	main.cash = 3120
	await f(30)
	await snap("upgrades")
	# boss
	main.start_game(2, "normal")
	main.cash = 9999999
	_build_base([1, 0])
	main.wave = 29
	main.start_wave()
	main.lives = 999
	sim(3.0)
	if main.boss != null:
		main.boss.d = 30.0
		while main.boss.phase < 2:
			main.hit(main.boss, 200.0, 99.0, null)
			main.sim_step(0.05)
		sim(1.2)
		main.cam.reset_view(main.boss.position, 0.6, 0.8, 28.0)
	main.cash = 6840
	main.lives = 96
	main.hud.banner("PHASE 2", "The Tyrant raises its shield and calls guards!", Color(1, 0.65, 0.25))
	await f(30)
	await snap("boss")
	get_tree().quit()
