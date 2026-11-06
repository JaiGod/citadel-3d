extends Camera3D
## Orbit / zoom / pan camera around a ground target. Smoothly eases toward goal values.

var target := Vector3.ZERO
var yaw := 0.6
var pitch := 0.95
var dist := 38.0
var g_target := Vector3.ZERO
var g_yaw := 0.6
var g_pitch := 0.95
var g_dist := 38.0
var bounds := Rect2(-20, -14, 40, 28)
var shake := 0.0
var min_dist := 10.0
var max_dist := 60.0

func reset_view(t: Vector3, y: float, p: float, d: float, snap := true) -> void:
	g_target = t
	g_yaw = y
	g_pitch = p
	g_dist = d
	if snap:
		target = t
		yaw = y
		pitch = p
		dist = d
	_apply()

func orbit(rel: Vector2) -> void:
	g_yaw -= rel.x * 0.006
	g_pitch = clampf(g_pitch + rel.y * 0.004, 0.45, 1.45)

func zoom_by(f: float) -> void:
	g_dist = clampf(g_dist * f, min_dist, max_dist)

func pan(rel: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	g_target += (-right * rel.x + fwd * rel.y) * dist * 0.0022
	g_target.x = clampf(g_target.x, bounds.position.x, bounds.end.x)
	g_target.z = clampf(g_target.z, bounds.position.y, bounds.end.y)

func _process(delta: float) -> void:
	var k := minf(1.0, delta * 10.0)
	target = target.lerp(g_target, k)
	yaw = lerp_angle(yaw, g_yaw, k)
	pitch = lerpf(pitch, g_pitch, k)
	dist = lerpf(dist, g_dist, k)
	shake = maxf(0.0, shake - delta * 2.5)
	_apply()

func _apply() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var j := Vector3.ZERO
	if shake > 0.0:
		j = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.6
	position = target + off + j
	look_at(target + j * 0.5, Vector3.UP)
