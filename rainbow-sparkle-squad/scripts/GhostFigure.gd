class_name GhostFigure
extends Area3D

## One ghost, wearing one feeling.
##
## The other islands' characters are either built in code (Numberblocks,
## ShapeFigures, LetterFigures) or roam the biome (RoamingAnimal). A ghost is
## neither: the thing being taught here is its FACE, so it has to hold still
## enough to be read, and it has to be generated because a face is exactly the
## kind of organic shape code cannot make.
##
## So the five ghosts share one body and differ only in expression. That is the
## whole reason the lesson is honest: if the bodies differed too, a child could
## answer "who looks sad" by shape and never look at the face at all.
##
## Ghosts FLOAT rather than stand. It is free characterisation, and it also
## keeps the face at roughly eye height for a small player instead of down at
## knee level where the ring would hide it.

signal touched(figure: GhostFigure)

const BOB_HZ := 0.45
const BOB_HEIGHT := 0.13
const SWAY_HZ := 0.31
## How far off the ground it idles. Enough to read as floating, low enough that
## the face still sits around the height of a Shape Cove figure's - the whole
## island is looking UP at these, and a ghost hovering at head height puts its
## expression somewhere a small player has to back away from to see.
const HOVER := 0.4

## Set before the node enters the tree.
var emotion := "happy"
var height := 1.7
## Multiplied into the albedo. The models are deliberately all near-white -
## they are ghosts - and a near-white asset renders as a featureless blob under
## the meadow sun with the face washed clean off it (trap 4). A different pale
## wash each keeps them apart at a distance without making COLOUR the answer:
## the tints are close enough that no child could rank them by feeling.
var tint := Color.WHITE

## Set by HauntedHouse, which gets it from Game.gd - the same way Bunny is
## handed the player so she can be spooked.
##
## The ghosts TURN TO WATCH the player, which is not decoration. They were
## first laid out facing the middle of their ring, exactly like the Shape Cove
## figures; but a shape is legible from any angle and a face is not, and the
## door is OUTSIDE the ring, so walking in showed a child five blank white
## backs and the whole lesson was on the far side of them. Facing outward only
## moves the problem to anyone standing in the middle. Tracking solves it from
## everywhere, and a ghost that slowly turns to follow you is the most
## in-character way this island could have fixed it.
var player: Node3D

const TURN_SPEED := 1.6            # radians/sec, slow enough to read as a haunt

var _visual: Node3D
var _mats: Array[StandardMaterial3D] = []
var _label: Label3D
var _phase := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _lit := false


func _ready() -> void:
	_visual = Models.spawn("res://assets/models/%s.glb" % _model_name(), height)
	_visual.name = "Visual"
	add_child(_visual)
	_take_materials()
	_apply_tint()

	# Roomier than the body on purpose: a three-year-old aims approximately, and
	# brushing a ghost's hem should count as reaching it. Same reasoning as the
	# Area3D on RoamingAnimal.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(height * 1.35, maxf(height * 1.4, 2.0), height * 1.35)
	shape.shape = box
	shape.position.y = height * 0.55
	add_child(shape)

	_build_label()

	_phase = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)


func _model_name() -> String:
	return "ghost_%s" % emotion


## Duplicate every surface material once, up front, and keep the handles.
##
## Both the tint and the lit glow have to write to these, and `Models.tint_albedo`
## re-duplicates from the mesh's own material every time it is called - so
## calling it after set_lit would quietly throw the emission away. Taking the
## copies once here means tint and glow compose instead of clobbering.
func _take_materials() -> void:
	for child in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for s in mesh_node.mesh.get_surface_count():
			var base := mesh_node.mesh.surface_get_material(s) as StandardMaterial3D
			if base == null:
				continue
			var copy: StandardMaterial3D = base.duplicate()
			copy.roughness = 1.0
			mesh_node.set_surface_override_material(s, copy)
			_mats.append(copy)


func _apply_tint() -> void:
	for m in _mats:
		m.albedo_color = tint


func _build_label() -> void:
	_label = Label3D.new()
	_label.text = emotion.capitalize()
	_label.font_size = 130
	_label.outline_size = 38
	_label.modulate = Color("#efe6ff")
	_label.outline_modulate = Color(0.16, 0.11, 0.22, 0.95)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0022
	_label.position.y = height + 0.55
	add_child(_label)


# -- life ----------------------------------------------------------------

func _process(delta: float) -> void:
	_phase += delta
	_face_player(delta)
	_squash_vel += (-150.0 * _squash - 13.0 * _squash_vel) * delta
	_squash += _squash_vel * delta
	_squash = clampf(_squash, -0.5, 0.5)

	_visual.scale = Vector3(1.0 - _squash * 0.45, 1.0 + _squash, 1.0 - _squash * 0.45)
	_visual.position.y = HOVER + sin(_phase * TAU * BOB_HZ) * BOB_HEIGHT
	# A slow lean, not a spin: the face has to stay pointed at the ring or the
	# expression - the entire lesson - turns away from the player.
	_visual.rotation.z = sin(_phase * TAU * SWAY_HZ) * 0.05


## Turn to look at the player.
##
## The face is -Z (Models.spawn already applied the half turn), and the yaw that
## aims -Z along a direction d is `atan2(-d.x, -d.z)` - the NEGATED components,
## same as RoamingAnimal._face. Feeding it the un-negated vector is trap 5
## wearing a different hat: it compiles, it turns smoothly, and every ghost
## presents its back to the thing it is supposed to be looking at.
##
## ShapeCove's `atan2(pos.x, pos.z)` is not a counter-example - `pos` there
## runs from the ring's centre OUT to the figure, so it is already the negation
## of "towards the middle".
##
## Standing almost on top of a ghost gives a near-zero direction and a yaw that
## snaps about wildly, so inside half a metre it just holds still.
func _face_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 0.5:
		return
	var want := atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, want, minf(TURN_SPEED * delta, 1.0))


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		touched.emit(self)


func cheer() -> void:
	_squash = 0.42
	_squash_vel = 0.0
	set_lit(true)


func buzz() -> void:
	_squash = -0.3
	_squash_vel = 0.0
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_visual, "rotation:z", 0.13, 0.05)
		tween.tween_property(_visual, "rotation:z", -0.13, 0.05)
	tween.tween_property(_visual, "rotation:z", 0.0, 0.05)


## A nudge for a player who has guessed wrong twice - the answer bobs on the
## spot without being given away by a glow.
func hint() -> void:
	_squash = 0.26
	_squash_vel = 0.0


func set_lit(on: bool) -> void:
	_lit = on
	for m in _mats:
		m.emission_enabled = on
		if on:
			m.emission = Color("#fff2c4")
			m.emission_energy_multiplier = 0.55


func is_lit() -> bool:
	return _lit
