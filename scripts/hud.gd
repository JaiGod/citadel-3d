extends CanvasLayer
## All UI, built in code: top bar, tower bar, tower panel, banners, overlay (HP bars, numbers)
## and the title / map select / help / pause / end screens. Rebuilt when orientation changes.

const D = preload("res://scripts/data.gd")

var main
var portrait := false
var screen := "title"
var root: Control
var th: Theme
var top: PanelContainer
var lbl_lives: Label
var lbl_cash: Label
var lbl_wave: Label
var btn_speed: Button
var btn_sound: Button
var btn_pause: Button
var wave_btn: Button
var bar: PanelContainer
var tower_btns: Array = []
var info: PanelContainer
var info_title: Label
var info_body: Label
var info_pips: Control
var btn_up: Button
var btn_sell: Button
var btn_mode: Button
var btn_close: Button
var banner_box: VBoxContainer
var banner_l1: Label
var banner_l2: Label
var banner_t := 0.0
var toast_l: Label
var toast_t := 0.0
var overlay: Control
var red: ColorRect
var red_t := 0.0
var scr_title: Control
var scr_maps: Control
var scr_help: Control
var scr_pause: Control
var scr_end: Control
var end_won := false
var end_rec := false
var info_refresh := 0.0
var help_from := "title"

func _ready() -> void:
	layer = 5
	_build()

func layout(p: bool) -> void:
	if p == portrait and root != null:
		return
	portrait = p
	_build()

# ------------------------------------------------------------------ helpers

func _sb(bg: Color, border: Color, bw: int, rad: int, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s

func _mk_theme() -> void:
	th = Theme.new()
	th.default_font_size = 18
	th.set_stylebox("normal", "Button", _sb(Color(0.17, 0.22, 0.36), Color(0.42, 0.58, 0.95), 2, 10))
	th.set_stylebox("hover", "Button", _sb(Color(0.24, 0.31, 0.5), Color(0.6, 0.75, 1.0), 2, 10))
	th.set_stylebox("pressed", "Button", _sb(Color(0.1, 0.13, 0.22), Color(1.0, 0.85, 0.35), 2, 10))
	th.set_stylebox("disabled", "Button", _sb(Color(0.14, 0.15, 0.19), Color(0.3, 0.32, 0.38), 2, 10))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(1, 1, 1))
	th.set_color("font_hover_color", "Button", Color(1, 0.95, 0.75))
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.62))
	th.set_stylebox("panel", "PanelContainer", _sb(Color(0.06, 0.08, 0.14, 0.9), Color(0.32, 0.45, 0.78, 0.95), 2, 12, 12))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 4)
	th.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.6))
	th.set_constant("outline_size", "Button", 3)

func _lbl(text: String, size := 18, col := Color(1, 1, 1), align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _btn(text: String, cb: Callable, minsz := Vector2(0, 44), size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsz
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

func _accent(b: Button, c: Color) -> void:
	b.add_theme_stylebox_override("normal", _sb(c.darkened(0.35), c.lightened(0.2), 2, 10))
	b.add_theme_stylebox_override("hover", _sb(c.darkened(0.15), c.lightened(0.45), 2, 10))
	b.add_theme_stylebox_override("pressed", _sb(c.darkened(0.55), Color(1, 1, 1), 2, 10))

func _icon(kind: String, sz := 26.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): _draw_icon(c, kind, Vector2(sz, sz) * 0.5, sz * 0.5))
	return c

func _draw_icon(c: Control, kind: String, o: Vector2, r: float) -> void:
	match kind:
		"heart":
			var col := Color(1, 0.3, 0.35)
			c.draw_circle(o + Vector2(-r * 0.42, -r * 0.2), r * 0.48, col)
			c.draw_circle(o + Vector2(r * 0.42, -r * 0.2), r * 0.48, col)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 0.88, -r * 0.05), o + Vector2(r * 0.88, -r * 0.05), o + Vector2(0, r * 0.85)]), col)
		"coin":
			c.draw_circle(o, r * 0.85, Color(0.85, 0.6, 0.1))
			c.draw_circle(o, r * 0.65, Color(1, 0.82, 0.25))
			c.draw_rect(Rect2(o + Vector2(-r * 0.12, -r * 0.4), Vector2(r * 0.24, r * 0.8)), Color(0.85, 0.6, 0.1))
		"wave":
			c.draw_line(o + Vector2(-r * 0.6, r * 0.85), o + Vector2(-r * 0.6, -r * 0.85), Color(0.9, 0.9, 0.9), 3)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 0.55, -r * 0.85), o + Vector2(r * 0.8, -r * 0.45), o + Vector2(-r * 0.55, -r * 0.05)]), Color(1, 0.4, 0.3))
		_:
			var i := D.tower_index(kind)
			if i >= 0:
				_draw_tower_icon(c, kind, D.TOWERS[i]["color"], o, r)

func _draw_tower_icon(c: Control, id: String, col: Color, o: Vector2, r: float) -> void:
	var dk := col.darkened(0.5)
	var base := Rect2(o + Vector2(-r * 0.7, r * 0.45), Vector2(r * 1.4, r * 0.4))
	c.draw_rect(base, Color(0.55, 0.57, 0.62))
	match id:
		"scout":
			c.draw_rect(Rect2(o + Vector2(-r * 0.4, -r * 0.15), Vector2(r * 0.8, r * 0.6)), col)
			c.draw_line(o + Vector2(r * 0.3, r * 0.05), o + Vector2(r * 0.95, -r * 0.35), Color(0.15, 0.15, 0.15), 3)
		"cannon":
			c.draw_circle(o + Vector2(0, r * 0.1), r * 0.42, col)
			c.draw_line(o, o + Vector2(r * 0.9, -r * 0.5), Color(0.15, 0.15, 0.15), 6)
		"volt":
			c.draw_polyline(PackedVector2Array([o + Vector2(r * 0.2, -r * 0.9), o + Vector2(-r * 0.25, -r * 0.05), o + Vector2(r * 0.2, -r * 0.05), o + Vector2(-r * 0.2, r * 0.45)]), col, 4)
		"frost":
			for k in 3:
				var a := PI * k / 3.0
				var v := Vector2(cos(a), sin(a)) * r * 0.65
				c.draw_line(o + Vector2(0, -r * 0.1) - v, o + Vector2(0, -r * 0.1) + v, col, 3)
		"sky":
			for k in 2:
				var x := (-0.3 + k * 0.6) * r
				c.draw_rect(Rect2(o + Vector2(x - r * 0.12, -r * 0.3), Vector2(r * 0.24, r * 0.7)), Color(0.95, 0.95, 0.95))
				c.draw_colored_polygon(PackedVector2Array([o + Vector2(x - r * 0.12, -r * 0.3), o + Vector2(x + r * 0.12, -r * 0.3), o + Vector2(x, -r * 0.7)]), col)
		"flame":
			c.draw_circle(o + Vector2(0, r * 0.1), r * 0.38, col)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 0.36, r * 0.0), o + Vector2(r * 0.36, r * 0.0), o + Vector2(r * 0.05, -r * 0.85)]), col)
			c.draw_circle(o + Vector2(0, r * 0.15), r * 0.18, Color(1, 0.9, 0.4))
		"rail":
			c.draw_rect(Rect2(o + Vector2(-r * 0.35, -r * 0.05), Vector2(r * 0.6, r * 0.5)), Color(0.4, 0.43, 0.48))
			c.draw_line(o + Vector2(0, r * 0.1), o + Vector2(r * 0.95, -r * 0.6), Color(0.15, 0.15, 0.15), 3)
			c.draw_circle(o + Vector2(r * 0.45, -r * 0.2), r * 0.12, col)
			c.draw_circle(o + Vector2(r * 0.75, -r * 0.42), r * 0.12, col)
		"mortar":
			c.draw_rect(Rect2(o + Vector2(-r * 0.5, r * 0.1), Vector2(r * 1.0, r * 0.35)), col)
			c.draw_line(o + Vector2(0, r * 0.15), o + Vector2(r * 0.3, -r * 0.7), Color(0.15, 0.15, 0.15), 8)
		"farm":
			c.draw_rect(Rect2(o + Vector2(-r * 0.35, -r * 0.1), Vector2(r * 0.7, r * 0.55)), Color(0.92, 0.88, 0.78))
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 0.45, -r * 0.1), o + Vector2(r * 0.45, -r * 0.1), o + Vector2(0, -r * 0.5)]), Color(0.75, 0.25, 0.2))
			c.draw_line(o + Vector2(-r * 0.5, -r * 0.9), o + Vector2(r * 0.5, r * 0.1), col, 3)
			c.draw_line(o + Vector2(r * 0.5, -r * 0.9), o + Vector2(-r * 0.5, r * 0.1), col, 3)
		"beacon":
			c.draw_rect(Rect2(o + Vector2(-r * 0.12, -r * 0.1), Vector2(r * 0.24, r * 0.6)), Color(0.85, 0.85, 0.9))
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r * 0.95), o + Vector2(r * 0.3, -r * 0.55), o + Vector2(0, -r * 0.15), o + Vector2(-r * 0.3, -r * 0.55)]), col)
			c.draw_arc(o + Vector2(0, -r * 0.55), r * 0.55, 0, TAU, 24, col.lightened(0.3), 2)
		_:
			c.draw_circle(o, r * 0.5, col)
	c.draw_rect(base, dk, false, 1.0)

func _full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

func _center_panel(w: float) -> Array:
	var cc := CenterContainer.new()
	_full(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	return [cc, vb]

# ------------------------------------------------------------------ build

func _build() -> void:
	if root != null:
		root.queue_free()
	tower_btns.clear()
	_mk_theme()
	root = Control.new()
	root.theme = th
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_full(root)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	_full(overlay)
	overlay.draw.connect(_draw_overlay)
	red = ColorRect.new()
	red.color = Color(1, 0.1, 0.1, 0.0)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(red)
	_full(red)
	_build_top()
	_build_bar()
	_build_info()
	_build_banner()
	_build_title()
	_build_maps()
	_build_help()
	_build_pause()
	_build_end()
	_apply_screen()

func _build_top() -> void:
	top = PanelContainer.new()
	root.add_child(top)
	top.anchor_left = 0
	top.anchor_right = 1
	top.anchor_top = 0
	top.anchor_bottom = 0
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	top.offset_bottom = 58
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8 if portrait else 14)
	top.add_child(hb)
	var fs := 20 if portrait else 22
	hb.add_child(_icon("heart"))
	lbl_lives = _lbl("150", fs)
	hb.add_child(lbl_lives)
	hb.add_child(_icon("coin"))
	lbl_cash = _lbl("$0", fs, Color(1, 0.88, 0.4))
	lbl_cash.custom_minimum_size = Vector2(64 if portrait else 110, 0)
	hb.add_child(lbl_cash)
	hb.add_child(_icon("wave"))
	lbl_wave = _lbl("0/30", fs)
	hb.add_child(lbl_wave)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sp)
	var bw := 48 if portrait else 64
	btn_speed = _btn("1x", func(): main.set_speed(main.speed % 3 + 1), Vector2(bw, 40))
	hb.add_child(btn_speed)
	btn_sound = _btn("SND", func():
		G.sound_on = not G.sound_on
		G.save()
		refresh_sound(), Vector2(bw, 40), 15)
	hb.add_child(btn_sound)
	btn_pause = _btn("II", func(): main.toggle_pause(), Vector2(bw - 8, 40))
	hb.add_child(btn_pause)
	wave_btn = _btn("START WAVE 1", func(): main.call_next(), Vector2(250 if not portrait else 230, 46), 18)
	_accent(wave_btn, Color(0.25, 0.7, 0.35))
	root.add_child(wave_btn)
	wave_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wave_btn.offset_right = -10
	wave_btn.offset_left = -10 - (250 if not portrait else 230)
	wave_btn.offset_top = 70
	wave_btn.offset_bottom = 116
	toast_l = _lbl("", 20, Color(1, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(toast_l)
	toast_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_l.offset_left = -300
	toast_l.offset_right = 300
	toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_bar() -> void:
	bar = PanelContainer.new()
	root.add_child(bar)
	bar.anchor_left = 0
	bar.anchor_right = 1
	bar.anchor_top = 1
	bar.anchor_bottom = 1
	bar.offset_left = 6
	bar.offset_right = -6
	bar.offset_bottom = -6
	bar.offset_top = -6
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var gc := GridContainer.new()
	gc.columns = 5 if portrait else 10
	gc.add_theme_constant_override("h_separation", 6)
	gc.add_theme_constant_override("v_separation", 6)
	bar.add_child(gc)
	var bsz := Vector2(88, 84) if portrait else Vector2(116, 92)
	for i in D.TOWERS.size():
		var td: Dictionary = D.TOWERS[i]
		var b := Button.new()
		b.custom_minimum_size = bsz
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func(): main.set_place_kind(idx))
		gc.add_child(b)
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		b.add_child(vb)
		_full(vb)
		vb.offset_top = 4
		var ic := _icon(td["id"], 34.0 if portrait else 38.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(ic)
		var nm := _lbl(String(td["name"]).split(" ")[0] if portrait else String(td["name"]), 13 if portrait else 14, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
		nm.clip_text = true
		vb.add_child(nm)
		var cl := _lbl("$%d" % int(td["cost"]), 15, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
		vb.add_child(cl)
		var hk := _lbl(str((i + 1) % 10), 12, Color(0.7, 0.75, 0.9))
		hk.position = Vector2(6, 2)
		b.add_child(hk)
		tower_btns.append(b)

func _build_info() -> void:
	info = PanelContainer.new()
	root.add_child(info)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	info.add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	info_title = _lbl("", 22, Color(1, 0.9, 0.5))
	info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_title)
	btn_close = _btn("X", func():
		if main.place_kind >= 0:
			main.set_place_kind(main.place_kind)
		else:
			main.select_tower(null), Vector2(40, 36))
	hb.add_child(btn_close)
	info_pips = Control.new()
	info_pips.custom_minimum_size = Vector2(0, 18)
	info_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_pips.draw.connect(_draw_pips)
	vb.add_child(info_pips)
	info_body = _lbl("", 16, Color(0.88, 0.9, 0.96))
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info_body)
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 8)
	vb.add_child(hb2)
	btn_up = _btn("UPGRADE", func(): main.upgrade(main.sel_tower), Vector2(0, 46), 17)
	btn_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accent(btn_up, Color(0.3, 0.7, 0.35))
	hb2.add_child(btn_up)
	btn_sell = _btn("SELL", func(): main.sell(main.sel_tower), Vector2(0, 46), 17)
	btn_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accent(btn_sell, Color(0.75, 0.3, 0.3))
	hb2.add_child(btn_sell)
	btn_mode = _btn("TARGET: First", func(): main.cycle_mode(main.sel_tower), Vector2(0, 40), 16)
	vb.add_child(btn_mode)
	info.visible = false
	_place_info()

func _place_info() -> void:
	info.anchor_top = 1
	info.anchor_bottom = 1
	info.anchor_right = 1
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if portrait:
		info.anchor_left = 0
		info.offset_left = 8
		info.offset_right = -8
		info.offset_bottom = -196
	else:
		info.anchor_left = 1
		info.offset_right = -10
		info.offset_left = -340
		info.offset_bottom = -118
		info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.offset_top = info.offset_bottom

func _build_banner() -> void:
	banner_box = VBoxContainer.new()
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_box)
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.offset_left = -400
	banner_box.offset_right = 400
	banner_box.offset_top = 130 if portrait else 120
	banner_l1 = _lbl("", 44 if portrait else 56, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	banner_l1.add_theme_constant_override("outline_size", 12)
	banner_box.add_child(banner_l1)
	banner_l2 = _lbl("", 18 if portrait else 22, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	banner_l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_l2.custom_minimum_size = Vector2(460 if portrait else 760, 0)
	banner_l2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner_box.add_child(banner_l2)
	banner_box.modulate.a = 0.0

func _build_title() -> void:
	scr_title = Control.new()
	root.add_child(scr_title)
	_full(scr_title)
	scr_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.08, 0.75))
	grad.set_color(1, Color(0.02, 0.03, 0.08, 0.1))
	grad.add_point(0.5, Color(0.02, 0.03, 0.08, 0.05))
	grad.add_point(0.85, Color(0.02, 0.03, 0.08, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr_title.add_child(tr)
	_full(tr)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_theme_constant_override("separation", 12)
	scr_title.add_child(vb)
	vb.set_anchors_preset(Control.PRESET_CENTER_TOP)
	vb.offset_left = -240
	vb.offset_right = 240
	vb.offset_top = 70 if portrait else 46
	var logo := _lbl("CITADEL", 78 if portrait else 96, Color(1, 0.84, 0.32), HORIZONTAL_ALIGNMENT_CENTER)
	var ls := LabelSettings.new()
	ls.font_size = 78 if portrait else 96
	ls.font_color = Color(1, 0.84, 0.32)
	ls.outline_size = 14
	ls.outline_color = Color(0.25, 0.12, 0.02)
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.6)
	ls.shadow_offset = Vector2(5, 6)
	logo.label_settings = ls
	vb.add_child(logo)
	var l3 := _lbl("3 D", 40 if portrait else 46, Color(0.55, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	var ls2 := LabelSettings.new()
	ls2.font_size = 40 if portrait else 46
	ls2.font_color = Color(0.55, 0.85, 1.0)
	ls2.outline_size = 10
	ls2.outline_color = Color(0.03, 0.12, 0.3)
	l3.label_settings = ls2
	vb.add_child(l3)
	vb.add_child(_lbl("L O W - P O L Y   T O W E R   D E F E N S E", 15 if portrait else 18, Color(0.92, 0.94, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18 if portrait else 10)
	vb.add_child(gap)
	var bp := _btn("PLAY", func(): show_maps(), Vector2(300, 66), 28)
	_accent(bp, Color(0.95, 0.65, 0.15))
	bp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(bp)
	var bh := _btn("HOW TO PLAY", func(): show_help("title"), Vector2(300, 48), 18)
	bh.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(bh)
	var bs := _btn("SOUND: ON" if G.sound_on else "SOUND: OFF", func(): pass, Vector2(300, 48), 18)
	bs.pressed.connect(func():
		G.sound_on = not G.sound_on
		G.save()
		bs.text = "SOUND: ON" if G.sound_on else "SOUND: OFF")
	bs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(bs)
	var foot := _lbl("10 towers · 10 enemies + a 3-phase boss · 30 waves · 3 maps · endless\nMade by Jaineil Rana (JaKing) · part of JaiGod", 14 if portrait else 15, Color(0.85, 0.88, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	scr_title.add_child(foot)
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_left = -300
	foot.offset_right = 300
	foot.offset_top = -64
	foot.offset_bottom = -14
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_maps() -> void:
	scr_maps = Control.new()
	root.add_child(scr_maps)
	_full(scr_maps)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.08, 0.55)
	scr_maps.add_child(bg)
	_full(bg)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr_maps.add_child(sc)
	_full(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	cc.add_child(vb)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	vb.add_child(gap)
	vb.add_child(_lbl("CHOOSE YOUR BATTLEFIELD", 28 if portrait else 34, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
	var box: BoxContainer
	if portrait:
		box = VBoxContainer.new()
	else:
		box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	vb.add_child(box)
	var dcol := [Color(0.4, 0.85, 0.4), Color(0.4, 0.7, 1.0), Color(1.0, 0.4, 0.3)]
	for i in D.MAPS.size():
		var mp: Dictionary = D.MAPS[i]
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(440 if portrait else 340, 0)
		box.add_child(pc)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		pc.add_child(cv)
		var prev := Control.new()
		prev.custom_minimum_size = Vector2(0, 92 if portrait else 130)
		prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mi := i
		prev.draw.connect(func(): _draw_map_preview(prev, mi))
		cv.add_child(prev)
		cv.add_child(_lbl(mp["name"], 22, Color(1, 1, 1)))
		var hb := HBoxContainer.new()
		cv.add_child(hb)
		hb.add_child(_lbl(mp["diff"], 17, dcol[i]))
		hb.add_child(_lbl("  ·  enemy HP x%.2f  ·  start $%d" % [float(mp["hpm"]), int(mp["cash"])], 15, Color(0.8, 0.83, 0.9)))
		var bn := G.get_best(i, "normal")
		var wn := G.get_wins(i, "normal")
		var be := G.get_best(i, "endless")
		var rec := "Best: wave %d/30%s   ·   Endless best: %d" % [bn, ("  (won x%d)" % wn) if wn > 0 else "", be]
		cv.add_child(_lbl(rec, 14, Color(1, 0.88, 0.5)))
		var hb2 := HBoxContainer.new()
		hb2.add_theme_constant_override("separation", 8)
		cv.add_child(hb2)
		var b1 := _btn("PLAY 30 WAVES", func(): main.start_game(mi, "normal"), Vector2(0, 48), 17)
		b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_accent(b1, Color(0.95, 0.65, 0.15))
		hb2.add_child(b1)
		var b2 := _btn("ENDLESS", func(): main.start_game(mi, "endless"), Vector2(0, 48), 17)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_accent(b2, Color(0.6, 0.35, 0.9))
		hb2.add_child(b2)
	var back := _btn("BACK", func(): show_title(), Vector2(200, 46))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 6)
	vb.add_child(gap2)

func _draw_map_preview(c: Control, mi: int) -> void:
	var mp: Dictionary = D.MAPS[mi]
	var sz := c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), mp["ground"])
	c.draw_rect(Rect2(Vector2.ZERO, sz), mp["edge"], false, 3.0)
	var pts := PackedVector2Array()
	for v in mp["pts"]:
		pts.append(Vector2((v.x + 23.0) / 46.0 * sz.x, (v.y + 15.5) / 31.0 * sz.y))
	c.draw_polyline(pts, (mp["path"] as Color).darkened(0.25), sz.y * 0.1 + 2)
	c.draw_polyline(pts, mp["path"], sz.y * 0.075)
	c.draw_circle(pts[0], sz.y * 0.07, Color(0.75, 0.3, 1.0))
	c.draw_rect(Rect2(pts[pts.size() - 1] - Vector2(sz.y * 0.08, sz.y * 0.08), Vector2(sz.y * 0.16, sz.y * 0.16)), Color(0.9, 0.88, 0.82))

func _build_help() -> void:
	scr_help = Control.new()
	root.add_child(scr_help)
	_full(scr_help)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	scr_help.add_child(bg)
	_full(bg)
	var r := _center_panel(470 if portrait else 760)
	scr_help.add_child(r[0])
	var vb: VBoxContainer = r[1]
	vb.add_child(_lbl("HOW TO PLAY", 28, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = false
	rt.custom_minimum_size = Vector2(0, 470 if portrait else 380)
	rt.add_theme_font_size_override("normal_font_size", 16 if portrait else 17)
	rt.add_theme_font_size_override("bold_font_size", 16 if portrait else 17)
	rt.text = "[b][color=#ffd560]Goal:[/color][/b] stop enemies walking the path from the purple portal to your Citadel. Each one that gets through costs lives. Survive 30 waves (or as long as you can in Endless).\n\n" + \
		"[b][color=#ffd560]Build:[/color][/b] pick a tower in the bottom bar (or keys 1-0), then tap a glowing pad. Tap a tower to upgrade it (4 levels, the model changes each time), sell it, or change its targeting: First, Last, Strongest, Weakest, Closest.\n\n" + \
		"[b][color=#ffd560]Enemies:[/color][/b] [color=#9ef]Flying[/color] foes only take hits from anti-air towers (Scout, Volt, Frost, Skyhunter, Rail). [color=#c9f]Stealth[/color] Shades need detection: Scout lv2, Skyhunter lv3, Lancer Rail, or a Beacon lv2 nearby. [color=#9dd]Armored[/color] foes shrug off small hits; use Rail, Cannon, Mortar or Volt. Every 10 waves brings a heavy hitter; wave 30 is the 3-phase Iron Tyrant.\n\n" + \
		"[b][color=#ffd560]Economy:[/color][/b] kills pay cash and each new wave pays a bonus. Harvest Mills (farms) pay out at the start of every wave, so build them early.\n\n" + \
		"[b][color=#ffd560]Camera:[/color][/b] drag to orbit, right-drag (or two fingers) to pan, wheel or pinch to zoom. Keys: WASD/arrows pan, Q/E rotate, Z/C zoom.\n\n" + \
		"[b][color=#ffd560]Keys:[/color][/b] Space = next wave, F = speed 1x/2x/3x, U = upgrade, X = sell, T = targeting, M = sound, Esc/P = pause."
	vb.add_child(rt)
	var b := _btn("GOT IT", func(): _close_help(), Vector2(220, 48), 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(b)

func _build_pause() -> void:
	scr_pause = Control.new()
	root.add_child(scr_pause)
	_full(scr_pause)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	scr_pause.add_child(bg)
	_full(bg)
	var r := _center_panel(340)
	scr_pause.add_child(r[0])
	var vb: VBoxContainer = r[1]
	vb.add_child(_lbl("PAUSED", 34, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
	var b1 := _btn("RESUME", func(): main.toggle_pause(), Vector2(0, 50), 20)
	_accent(b1, Color(0.3, 0.7, 0.35))
	vb.add_child(b1)
	vb.add_child(_btn("HOW TO PLAY", func(): show_help("pause"), Vector2(0, 46)))
	vb.add_child(_btn("RESTART MAP", func(): main.restart(), Vector2(0, 46)))
	vb.add_child(_btn("MAIN MENU", func(): main.quit_to_title(), Vector2(0, 46)))

func _build_end() -> void:
	scr_end = Control.new()
	root.add_child(scr_end)
	_full(scr_end)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	scr_end.add_child(bg)
	_full(bg)
	var r := _center_panel(440 if portrait else 520)
	scr_end.add_child(r[0])
	var vb: VBoxContainer = r[1]
	var l1 := _lbl("VICTORY!" if end_won else "CITADEL FALLEN", 46, Color(1, 0.85, 0.3) if end_won else Color(1, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	l1.add_theme_constant_override("outline_size", 10)
	l1.name = "Head"
	vb.add_child(l1)
	var body := _lbl("", 18, Color(0.92, 0.94, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(body)
	var b1 := _btn("PLAY AGAIN", func(): main.restart(), Vector2(0, 52), 20)
	_accent(b1, Color(0.95, 0.65, 0.15))
	vb.add_child(b1)
	vb.add_child(_btn("CHOOSE MAP", func():
		main.go_title()
		show_maps(), Vector2(0, 46)))
	vb.add_child(_btn("MAIN MENU", func(): main.go_title(), Vector2(0, 46)))

# ------------------------------------------------------------------ screens

func _apply_screen() -> void:
	var play := screen == "play" or screen == "pause" or screen == "over" or screen == "help_play"
	top.visible = play
	bar.visible = play and screen != "over"
	wave_btn.visible = play and screen != "over"
	scr_title.visible = screen == "title"
	scr_maps.visible = screen == "maps"
	scr_help.visible = screen == "help" or screen == "help_play"
	scr_pause.visible = screen == "pause"
	scr_end.visible = screen == "over"
	if not play:
		info.visible = false
	if screen == "over":
		_fill_end()
	if play and main:
		on_select(main.sel_tower if main.place_kind < 0 else null)
		if main.place_kind >= 0:
			on_place_mode(main.place_kind)
	refresh_speed()
	refresh_sound()

func show_title() -> void:
	screen = "title"
	_apply_screen()

func show_maps() -> void:
	# rebuild so best scores are fresh
	screen = "maps"
	_build()

func show_help(from: String) -> void:
	help_from = from
	screen = "help" if from == "title" else "help_play"
	_apply_screen()

func _close_help() -> void:
	screen = "title" if help_from == "title" else "pause"
	_apply_screen()

func show_play() -> void:
	screen = "play"
	banner_t = 0.0
	_apply_screen()

func show_pause(p: bool) -> void:
	screen = "pause" if p else "play"
	_apply_screen()

func show_end(won: bool, rec: bool) -> void:
	end_won = won
	end_rec = rec
	screen = "over"
	_build()

func _fill_end() -> void:
	var head: Label = scr_end.find_child("Head", true, false)
	var body: Label = scr_end.find_child("Body", true, false)
	if head == null or main == null or main.stats.is_empty():
		return
	head.text = "VICTORY!" if end_won else "CITADEL FALLEN"
	head.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if end_won else Color(1, 0.4, 0.35))
	var mp: Dictionary = D.MAPS[main.map_i]
	var s: Dictionary = main.stats
	var txt := "%s  ·  %s\n" % [mp["name"], "Endless" if main.mode == "endless" else "30 waves"]
	txt += ("All 30 waves cleared! The Iron Tyrant is scrap metal." if end_won else "Reached wave %d." % main.wave) + "\n\n"
	txt += "Enemies defeated: %d\nDamage dealt: %d\nCash earned: $%d\nTowers built: %d\nLives left: %d" % [int(s["kills"]), int(s["dmg"]), int(s["earned"]), int(s.get("built", 0)), main.lives]
	if end_rec:
		txt += "\n\nNEW PERSONAL BEST!"
	body.text = txt

# ------------------------------------------------------------------ in-game updates

func banner(l1: String, l2: String, col: Color) -> void:
	banner_l1.text = l1
	banner_l1.add_theme_color_override("font_color", col)
	banner_l2.text = l2
	banner_t = 3.2

func toast(t: String) -> void:
	toast_l.text = t
	toast_t = 2.4

func flash_red() -> void:
	red_t = 0.35

func refresh_speed() -> void:
	if btn_speed and main:
		btn_speed.text = "%dx" % main.speed
		var c: Color = [Color(0.3, 0.45, 0.8), Color(0.85, 0.6, 0.2), Color(0.9, 0.3, 0.3)][main.speed - 1]
		_accent(btn_speed, c)

func refresh_sound() -> void:
	if btn_sound:
		btn_sound.text = "SND" if G.sound_on else "MUTE"
		btn_sound.modulate = Color(1, 1, 1) if G.sound_on else Color(0.6, 0.6, 0.6)

func on_place_mode(k: int) -> void:
	for i in tower_btns.size():
		var b: Button = tower_btns[i]
		if i == k:
			b.add_theme_stylebox_override("normal", _sb(Color(0.3, 0.38, 0.15), Color(1, 0.85, 0.3), 3, 10))
		else:
			b.remove_theme_stylebox_override("normal")
	if k < 0:
		if main.sel_tower == null:
			info.visible = false
		return
	var td: Dictionary = D.TOWERS[k]
	var l0: Dictionary = td["lv"][0]
	info.visible = screen == "play"
	info_title.text = "%s  $%d" % [td["name"], int(td["cost"])]
	info_body.text = "%s\n%s\nTap a glowing pad to build." % [td["desc"], _stat_line(td, l0)]
	info_pips.visible = false
	btn_up.visible = false
	btn_sell.visible = false
	btn_mode.visible = false

func _stat_line(td: Dictionary, s: Dictionary) -> String:
	var id: String = td["id"]
	if id == "farm":
		return "Income: $%d per wave" % int(s["income"])
	if id == "beacon":
		var t := "Aura %.1f: +%d%% range, +%d%% fire rate" % [float(s["range"]), int(float(s["brange"]) * 100), int(float(s["brate"]) * 100)]
		if float(s.get("bdmg", 0.0)) > 0.0:
			t += ", +%d%% dmg" % int(float(s["bdmg"]) * 100)
		if s.get("detect", false):
			t += ", stealth sight"
		return t
	var t2 := "DMG %d  ·  %.1f/s  ·  RNG %.1f" % [int(round(float(s["dmg"]))), float(s["rate"]), float(s["range"])]
	if s.has("splash"):
		t2 += "  ·  AoE %.1f" % float(s["splash"])
	if s.has("chains"):
		t2 += "  ·  x%d chain" % int(s["chains"])
	if s.has("slow"):
		t2 += "  ·  slow %d%%" % int(float(s["slow"]) * 100)
	if s.has("missiles") and int(s["missiles"]) > 1:
		t2 += "  ·  x%d missiles" % int(s["missiles"])
	if s.has("burn"):
		t2 += "  ·  burn %d/s" % int(s["burn"])
	var tags := []
	if td["air"]:
		tags.append("hits air")
	else:
		tags.append("ground only")
	if s.get("detect", false):
		tags.append("sees stealth")
	if float(s.get("pierce", 0.0)) >= 99.0:
		tags.append("ignores armor")
	elif float(s.get("pierce", 0.0)) > 0.0:
		tags.append("pierce %d" % int(s["pierce"]))
	return t2 + "\n" + ", ".join(tags)

func on_select(t) -> void:
	if t == null or not is_instance_valid(t):
		if main == null or main.place_kind < 0:
			info.visible = false
		return
	var td: Dictionary = D.TOWERS[t.kind]
	info.visible = screen == "play" or screen == "pause"
	info_pips.visible = true
	info_pips.queue_redraw()
	info_title.text = "%s  Lv %d" % [td["name"], t.level]
	var txt := _stat_line(td, t.s)
	if not t.is_support():
		txt += "\nKills %d  ·  Damage %d" % [t.kills, int(t.dmg_dealt)]
	if t.level < 4:
		var nxt: Dictionary = td["lv"][t.level + 1]
		txt += "\n[next] " + _stat_line(td, nxt).split("\n")[0]
	if t.stun > 0.0:
		txt += "\nSTUNNED!"
	info_body.text = txt
	var uc: int = t.upgrade_cost()
	btn_up.visible = true
	btn_sell.visible = true
	btn_up.text = "MAX LEVEL" if uc < 0 else "UPGRADE $%d" % uc
	btn_up.disabled = uc < 0 or main.cash < uc
	btn_sell.text = "SELL $%d" % t.sell_value()
	btn_mode.visible = not t.is_support()
	btn_mode.text = "TARGET: %s" % D.TARGET_MODES[t.mode]

func _draw_pips() -> void:
	var t = main.sel_tower if main else null
	if t == null or not is_instance_valid(t):
		return
	for i in 5:
		var p := Vector2(10 + i * 26, 9)
		info_pips.draw_circle(p, 8, Color(0.2, 0.22, 0.3))
		if i <= t.level:
			info_pips.draw_circle(p, 6, Color(1, 0.82, 0.25) if i == 4 else Color(0.45, 0.85, 1.0))

func blocks(p: Vector2) -> bool:
	for c in [top, bar, info, wave_btn, scr_pause, scr_end, scr_help, scr_maps]:
		var cc: Control = c
		if cc != null and cc.visible and cc.get_global_rect().has_point(p):
			return true
	return false

func _process(delta: float) -> void:
	if main == null:
		return
	if banner_t > 0.0:
		banner_t -= delta
	banner_box.modulate.a = clampf(banner_t / 0.5, 0.0, 1.0) * clampf((3.2 - banner_t) / 0.2 + 0.2, 0.0, 1.0)
	if toast_t > 0.0:
		toast_t -= delta
	toast_l.modulate.a = clampf(toast_t / 0.4, 0.0, 1.0)
	toast_l.offset_bottom = -(bar.size.y + 18 if bar.visible else 18) - (info.size.y + 8 if info.visible and portrait else 0)
	toast_l.offset_top = toast_l.offset_bottom - 56
	if info.visible and bar.visible:
		var ob := -(bar.size.y + 14.0)
		if absf(info.offset_bottom - ob) > 0.5:
			info.offset_bottom = ob
			info.offset_top = ob
	if red_t > 0.0:
		red_t -= delta
	red.color.a = maxf(0.0, red_t) * 0.6
	overlay.queue_redraw()
	if screen != "play" and screen != "pause":
		return
	lbl_lives.text = str(main.lives)
	lbl_cash.text = "$%d" % main.cash
	lbl_wave.text = ("%d/30" % main.wave) if main.mode == "normal" else ("%d  (endless)" % main.wave if not portrait else "%d E" % main.wave)
	for i in tower_btns.size():
		var b: Button = tower_btns[i]
		var cost: int = D.TOWERS[i]["cost"]
		b.modulate = Color(1, 1, 1) if main.cash >= cost else Color(0.6, 0.6, 0.65)
	if main.can_call():
		wave_btn.disabled = false
		if main.wave == 0:
			wave_btn.text = "START WAVE 1  (%d)" % int(ceil(main.intermission))
		elif main.enemies.is_empty() and main.intermission >= 0.0:
			wave_btn.text = "NEXT WAVE  (%d)" % int(ceil(main.intermission))
		else:
			wave_btn.text = "CALL WAVE %d EARLY" % (main.wave + 1)
	else:
		wave_btn.disabled = true
		wave_btn.text = "WAVE %d IN PROGRESS" % main.wave if main.wave < 30 or main.mode == "endless" else "FINAL WAVE"
	info_refresh -= delta
	if info_refresh <= 0.0 and main.sel_tower != null and is_instance_valid(main.sel_tower) and info.visible:
		info_refresh = 0.25
		on_select(main.sel_tower)

func _draw_overlay() -> void:
	if main == null or main.cam == null:
		return
	var cam: Camera3D = main.cam
	for e in main.enemies:
		if not e.alive or e == main.boss:
			continue
		if e.hp >= e.maxhp and not e.hidden:
			continue
		var wp: Vector3 = e.position + Vector3(0, 1.1 * float(e.size) + 0.5, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var w := 34.0 * clampf(float(e.size), 0.8, 1.6)
		var f: float = clampf(e.hp / e.maxhp, 0.0, 1.0)
		overlay.draw_rect(Rect2(sp + Vector2(-w * 0.5 - 1, -1), Vector2(w + 2, 7)), Color(0, 0, 0, 0.7))
		var col := Color(0.3, 0.95, 0.35).lerp(Color(1, 0.3, 0.2), 1.0 - f)
		if e.armor > 0.0:
			col = Color(0.75, 0.8, 0.9) if f > 0.5 else col
		overlay.draw_rect(Rect2(sp + Vector2(-w * 0.5, 0), Vector2(w * f, 5)), col)
		if e.hidden:
			overlay.draw_string(ThemeDB.fallback_font, sp + Vector2(-w * 0.5, -4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.6, 1.0))
	var font := ThemeDB.fallback_font
	for fl in main.floats:
		var p: Vector3 = fl["p"]
		var t: float = fl["t"]
		var wp2 := p + Vector3(0, t * 1.4, 0)
		if cam.is_position_behind(wp2):
			continue
		var sp2 := cam.unproject_position(wp2)
		var a := clampf((float(fl["life"]) - t) / 0.3, 0.0, 1.0)
		var col2: Color = fl["col"]
		col2.a = a
		var txt: String = fl["text"]
		var fs := 18
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		overlay.draw_string_outline(font, sp2 - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, a * 0.8))
		overlay.draw_string(font, sp2 - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col2)
	var b = main.boss
	if b != null and is_instance_valid(b) and b.alive and (screen == "play" or screen == "pause"):
		var vs := overlay.size
		var bw := minf(vs.x - 40.0, 560.0)
		var y := 124.0 if not portrait else 128.0
		var x0 := (vs.x - bw) * 0.5
		if not portrait:
			x0 = minf(x0, vs.x - 280.0 - bw)
			x0 = maxf(x0, 20.0)
		var f2: float = clampf(b.hp / b.maxhp, 0.0, 1.0)
		var nm := "THE IRON TYRANT  ·  PHASE %d%s" % [b.phase, "  ·  SHIELDED" if b.shield_t > 0.0 else ""]
		overlay.draw_string_outline(font, Vector2(x0, y - 8), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.9))
		overlay.draw_string(font, Vector2(x0, y - 8), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.75, 0.4))
		overlay.draw_rect(Rect2(x0 - 2, y - 2, bw + 4, 18), Color(0, 0, 0, 0.75))
		var pc: Color = [Color(0.4, 0.75, 1.0), Color(1.0, 0.6, 0.2), Color(1.0, 0.25, 0.2)][clampi(b.phase - 1, 0, 2)]
		overlay.draw_rect(Rect2(x0, y, bw * f2, 14), pc)
		for k in [0.33, 0.66]:
			overlay.draw_rect(Rect2(x0 + bw * k - 1, y, 2, 14), Color(1, 1, 1, 0.8))
