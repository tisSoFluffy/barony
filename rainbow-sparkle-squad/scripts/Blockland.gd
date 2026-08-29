class_name Blockland
extends Node3D

## Blockland: a plaza where the ten Numberblocks stand, and the counting game
## they are there for.
##
## It is built far off to one side of the meadow rather than in a scene of its
## own, and the doors teleport between the two. Keeping one scene means the
## player, camera, HUD and audio are never torn down and rebuilt, so there is
## no reload hitch and nothing to re-wire on the way back.
##
## The game: the blocks stand in a shuffled arc, and you have to touch them in
## order, one to ten. A right answer lights the block and says its number. A
## wrong one shakes it and puts the whole row out again, which is the point -
## you have to know what comes next, not just barge around.

signal progress(next_number: int, total: int)
signal mistake(expected: int, got: int)
signal completed

const TOTAL := 10
const RADIUS := 8.5
const ARC := 3.5                  # radians the ten blocks are spread over

var _blocks: Array[Numberblock] = []
var _next := 1
var _done := false
var _voice: AudioStreamPlayer


func _ready() -> void:
	_build_ground()
	_build_ring()
	_build_blocks()

	_voice = AudioStreamPlayer.new()
	_voice.name = "BlockVoice"
	_voice.volume_db = 2.0
	add_child(_voice)


# -- the plaza -----------------------------------------------------------

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "BlocklandGround"

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var mat := StandardMaterial3D.new()
	# Warm sand, and darker than it looks like it should be: the generator-free
	# blocks are lit by the same bright meadow sun and filmic tonemap, which
	# lifts a pale ground to flat white and swallows Ten whole.
	mat.albedo_color = Color("#b9a373")
	mat.roughness = 0.95
	plane.material = mat
	mesh.mesh = plane
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1.0, 40)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)
	add_child(body)


## A low kerb of coloured cubes around the plaza - the ten Numberblock colours,
## repeating, so the place reads as theirs before you have touched anything.
func _build_ring() -> void:
	var ring := Node3D.new()
	ring.name = "Kerb"
	add_child(ring)

	var count := 44
	for i in count:
		var a: float = TAU * float(i) / float(count)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		# Deliberately smaller than a Numberblock cube - the kerb is a border,
		# and must never out-scale the characters it frames.
		mesh.size = Vector3(0.62, 0.3, 0.62)
		mi.mesh = mesh

		var mat := StandardMaterial3D.new()
		var n: int = (i % TOTAL) + 1
		mat.albedo_color = Numberblock.SEVEN[i % Numberblock.SEVEN.size()] \
			if n == 7 else Numberblock.COLOURS.get(n, Color.WHITE)
		mat.roughness = 0.7
		mi.material_override = mat

		mi.position = Vector3(cos(a) * 13.5, 0.15, sin(a) * 13.5)
		mi.rotation.y = -a
		ring.add_child(mi)


## The ten blocks around an arc, in shuffled order, each turned to face the
## middle of the plaza where the player arrives.
func _build_blocks() -> void:
	var order: Array[int] = []
	for n in range(1, TOTAL + 1):
		order.append(n)
	order.shuffle()

	for i in order.size():
		var block := Numberblock.new()
		block.number = order[i]
		block.name = "Numberblock%d" % order[i]

		var a: float = -ARC * 0.5 + ARC * (float(i) / float(order.size() - 1))
		var pos := Vector3(sin(a) * RADIUS, 0.0, -cos(a) * RADIUS)
		block.position = pos
		# -Z is the block's face. Rotating by atan2(x, z) turns -Z to point back
		# down the position vector, i.e. inward at the player - no extra half
		# turn, which would face them all out of the plaza.
		block.rotation.y = atan2(pos.x, pos.z)

		block.touched.connect(_on_block_touched)
		add_child(block)
		_blocks.append(block)


# -- the counting game ---------------------------------------------------

## There is deliberately no debounce here. `body_entered` only fires when the
## player actually crosses into a block, so it cannot double-fire on its own,
## and a timed cooldown would silently swallow a real touch: walk briskly from
## one block to the next and the second one is eaten, with no further entry
## event ever coming to make up for it. `is_lit` is the only guard needed.
func _on_block_touched(block: Numberblock) -> void:
	if _done or block.is_lit():
		return

	if block.number == _next:
		block.cheer()
		Voices.say(_voice, block.number)
		_next += 1
		if _next > TOTAL:
			_finish()
		else:
			progress.emit(_next, TOTAL)
	else:
		block.buzz()
		mistake.emit(_next, block.number)
		_reset()


func _reset() -> void:
	for b in _blocks:
		b.set_lit(false)
	_next = 1
	progress.emit(_next, TOTAL)


func _finish() -> void:
	_done = true
	completed.emit()
	# A wave down the line: each block pops a beat after the one before it.
	var by_number := _blocks.duplicate()
	by_number.sort_custom(func(a: Numberblock, b: Numberblock) -> bool:
		return a.number < b.number)
	for i in by_number.size():
		await get_tree().create_timer(0.09).timeout
		if is_instance_valid(by_number[i]):
			by_number[i].cheer()


## Start over - called when the player walks back in through the door, so the
## puzzle is always fresh rather than sitting solved.
func restart() -> void:
	_done = false
	_reset()


func next_number() -> int:
	return _next


func is_complete() -> bool:
	return _done
