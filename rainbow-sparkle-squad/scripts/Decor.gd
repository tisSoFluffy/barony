class_name Decor
extends Node3D

## Non-interactive set dressing: one generated model, placed and scaled.
##
## The playground is built from code (see Game.gd), so scenery is data too - a
## model path plus where to stand it. Most props are pure visual; the big ones
## (tree trunks, the fountain) get a plain cylinder collider so the unicorn
## bumps them instead of walking through, set with `solid`.
##
## `sway` gives plants a slow idle rock; `bob` lets the clouds drift up and
## down. Both are procedural - there are no rigs or animation clips anywhere in
## this project.

var model_path := ""
var height := 1.0
var by_width := false        # scale to the widest horizontal axis, not height
var yaw := 0.0
var solid := false
var solid_radius := 0.5
var solid_height := 2.0
## Which physics layer the collider sits on. Indoor props want layer 2, the
## layer FollowCamera's obstruction ray skips - a solid wardrobe on the default
## layer shoves the camera into the player's back exactly as a wall would, and
## the Haunted House is full of them. See FollowCamera.SEE_OVER_LAYER_BIT.
var solid_layer := 1
var sway := 0.0              # radians of tilt amplitude
var bob := 0.0               # metres of vertical drift
var bob_hz := 0.12
# When opaque, repaint every surface this flat colour instead of its baked
# texture - the clouds come off TRELLIS with a speckled UV-seam crackle, and a
# plain matte white reads far cleaner for something that is pure white anyway.
var repaint := Color(0, 0, 0, 0)
## Multiplied into the albedo, KEEPING the texture - unlike `repaint`, which
## throws it away. Components may exceed 1.0 to brighten as well as darken,
## which is the point: the meadow sun blows pale props out to white and crushes
## dark ones to silhouettes, and the two need opposite corrections.
var tint := Color.WHITE

var _visual: Node3D
var _base_y := 0.0
var _phase := 0.0


func _ready() -> void:
	_visual = Models.spawn_wide(model_path, height) if by_width \
		else Models.spawn(model_path, height)
	_visual.rotation.y += yaw
	add_child(_visual)

	if tint != Color.WHITE:
		Models.tint_albedo(_visual, tint)

	if repaint.a > 0.0:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = repaint
		mat.roughness = 1.0
		for node in _visual.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for s in mi.get_surface_override_material_count():
				mi.set_surface_override_material(s, mat)

	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = solid_layer
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = solid_radius
		shape.height = solid_height
		col.shape = shape
		col.position.y = solid_height * 0.5
		body.add_child(col)
		add_child(body)

	_base_y = position.y
	_phase = randf() * TAU
	set_process(sway > 0.0 or bob > 0.0)


func _process(delta: float) -> void:
	_phase += delta
	if sway > 0.0:
		# Two out-of-phase axes so it circles a little rather than rocking flat.
		_visual.rotation.x = sin(_phase * 0.9) * sway
		_visual.rotation.z = sin(_phase * 1.3 + 1.0) * sway * 0.6
	if bob > 0.0:
		position.y = _base_y + sin(_phase * TAU * bob_hz) * bob
