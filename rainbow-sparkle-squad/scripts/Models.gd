class_name Models
extends RefCounted

## Loading helper for the generated GLBs.
##
## tools/import_assets.py normalises every export the same way: longest axis
## about 1.0, centred on XZ, sitting on y = 0. So placing one is just a uniform
## scale to the size we want, and callers never have to know the raw dimensions.
##
## The generator reconstructs the concept image facing the camera, which is +Z;
## Godot treats -Z as forward, so models arrive backwards and need a half turn.
const MODEL_YAW := PI


## Instance `path`, scaled so its tallest axis is `target_height` metres.
## Returns a Node3D whose origin is on the ground, centred under the model.
static func spawn(path: String, target_height: float, face_forward := true) -> Node3D:
	var holder := Node3D.new()
	var packed := load(path)
	if packed == null:
		push_error("Models.spawn: could not load %s" % path)
		return holder

	var inst: Node3D = packed.instantiate()
	holder.add_child(inst)

	var size := _aabb_of(inst).size
	var tallest: float = maxf(size.y, 0.001)
	inst.scale = Vector3.ONE * (target_height / tallest)
	if face_forward:
		inst.rotation.y = MODEL_YAW
	holder.name = path.get_file().get_basename()
	return holder


## Same, but scaled by the longest horizontal axis instead of by height - the
## right choice for wide set dressing like the gate and the rainbow arches,
## where the footprint is what has to line up, not the height.
static func spawn_wide(path: String, target_width: float, face_forward := true) -> Node3D:
	var holder := Node3D.new()
	var packed := load(path)
	if packed == null:
		push_error("Models.spawn_wide: could not load %s" % path)
		return holder

	var inst: Node3D = packed.instantiate()
	holder.add_child(inst)

	var size := _aabb_of(inst).size
	var widest: float = maxf(maxf(size.x, size.z), 0.001)
	inst.scale = Vector3.ONE * (target_width / widest)
	if face_forward:
		inst.rotation.y = MODEL_YAW
	holder.name = path.get_file().get_basename()
	return holder


## Multiply down the albedo of everything under `node`.
##
## The generator bakes its own studio lighting into the albedo, so a pale asset
## arrives already near-white and then blows out completely under the meadow's
## sun, losing every feature. Tinting the material pulls it back into the
## scene's exposure without touching the texture. Set-dressing is far enough
## away not to care; the characters you look at up close do.
static func tint_albedo(node: Node3D, tint: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for s in mesh_node.mesh.get_surface_count():
			var base := mesh_node.mesh.surface_get_material(s) as StandardMaterial3D
			if base == null:
				continue
			var tinted: StandardMaterial3D = base.duplicate()
			tinted.albedo_color = tint
			tinted.roughness = 1.0
			mesh_node.set_surface_override_material(s, tinted)


## Union of every MeshInstance3D AABB under `node`, in `node`'s own space.
## Uses local transforms throughout, because this runs on a freshly
## instantiated subtree that is not in the scene tree yet.
static func _aabb_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in _walk(node):
		var mesh_node := child as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var box: AABB = _relative_transform(node, mesh_node) * mesh_node.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var cur := node
	while cur != null and cur != root:
		xform = cur.transform * xform
		cur = cur.get_parent() as Node3D
	return xform


static func _walk(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_walk(child))
	return out
