extends Node
# ShadowFactory.gd
# Autoload: procedural blob shadow (radial-gradient quad) for billboards.
# No asset files — texture is a GradientTexture2D built once and shared.

const Y_OFFSET := 0.02  # above floor, avoids z-fighting

static var _shadow_tex: GradientTexture2D
static var _shadow_mat: StandardMaterial3D


static func _texture() -> GradientTexture2D:
	if _shadow_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.55))
		grad.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_shadow_tex = tex
	return _shadow_tex


static func _material() -> StandardMaterial3D:
	if _shadow_mat == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _texture()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = -1  # draw below sprites
		_shadow_mat = mat
	return _shadow_mat


# Returns a flat MeshInstance3D quad, ready to add_child under a sprite owner
# (position it at the owner's feet, y = Y_OFFSET). `diameter` in world meters.
static func make_shadow(diameter: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()  # FACE_Y default — lies flat, facing up
	mesh.size = Vector2(diameter, diameter)
	mi.mesh = mesh
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = Y_OFFSET
	return mi
