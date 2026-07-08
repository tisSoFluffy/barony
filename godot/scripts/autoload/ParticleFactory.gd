extends Node
## Factory for HD 2D particle effects.
## All methods return a ready-to-place GPUParticles3D (not yet in the scene).
## Caller sets global_position, add_child(), then emitting = true.

# ── Hit sparks — burst on enemy damage ────────────────────────────────────────
func hit_sparks(tint: Color = Color(1.0, 0.45, 0.08)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount        = 12
	p.lifetime      = 0.45
	p.one_shot      = true
	p.explosiveness = 0.95
	p.emitting      = false
	p.top_level     = true
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))

	var mat := ParticleProcessMaterial.new()
	mat.direction            = Vector3(0.0, 1.0, 0.0)
	mat.spread               = 120.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity              = Vector3(0.0, -7.0, 0.0)
	mat.scale_min            = 0.04
	mat.scale_max            = 0.10
	mat.color                = tint
	mat.color_ramp           = _fade_ramp(tint, Color(tint.r * 0.4, 0.0, 0.0, 0.0))
	p.process_material = mat
	p.draw_pass_1 = _small_sphere(0.05)
	return p


# ── Death burst — larger, darker red ─────────────────────────────────────────
func death_burst() -> GPUParticles3D:
	var p := hit_sparks(Color(0.85, 0.08, 0.04))
	p.amount   = 22
	p.lifetime = 0.75
	return p


# ── Torch embers — continuous upward drift ────────────────────────────────────
func torch_embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount     = 18
	p.lifetime   = 1.4
	p.one_shot   = false
	p.emitting   = true
	p.preprocess = 0.5
	p.visibility_aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 4, 1))

	var mat := ParticleProcessMaterial.new()
	mat.direction            = Vector3(0.0, 1.0, 0.0)
	mat.spread               = 18.0
	mat.initial_velocity_min = 0.25
	mat.initial_velocity_max = 0.65
	mat.gravity              = Vector3(0.0, -0.15, 0.0)
	mat.scale_min            = 0.02
	mat.scale_max            = 0.05
	mat.color_ramp           = _ember_ramp()
	p.process_material = mat
	p.draw_pass_1 = _small_sphere(0.03)
	return p


# ── Dust motes — slow drifting warm specks in torch light pools ─────────────
func dust_motes() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount     = 8
	p.lifetime   = 6.0
	p.one_shot   = false
	p.emitting   = true
	p.preprocess = 3.0
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape        = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 2.0
	mat.direction             = Vector3(0.0, 1.0, 0.0)
	mat.spread                = 60.0
	mat.initial_velocity_min  = 0.03
	mat.initial_velocity_max  = 0.10
	mat.gravity               = Vector3(0.0, 0.03, 0.0)
	mat.damping_min           = 0.05
	mat.damping_max           = 0.15
	mat.turbulence_enabled    = true
	mat.turbulence_noise_strength = 0.6
	mat.turbulence_noise_scale    = 1.5
	mat.scale_min             = 0.008
	mat.scale_max             = 0.02
	mat.color                 = Color(1.0, 0.92, 0.75, 0.35)
	p.process_material = mat
	p.draw_pass_1 = _small_sphere(0.015)

	var mat_override := StandardMaterial3D.new()
	mat_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_override.blend_mode   = BaseMaterial3D.BLEND_MODE_ADD
	mat_override.vertex_color_use_as_albedo = true
	mat_override.albedo_color = Color(1.0, 0.92, 0.75, 0.35)
	p.draw_pass_1.surface_set_material(0, mat_override)
	return p


# ── Helpers ───────────────────────────────────────────────────────────────────

func _small_sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius          = r
	m.height          = r * 2.0
	m.radial_segments = 4
	m.rings           = 2
	return m


func _fade_ramp(from_col: Color, to_col: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, from_col)
	g.set_color(1, to_col)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _ember_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.20, 1.0))
	g.set_color(1, Color(0.25, 0.06, 0.01, 0.0))
	g.add_point(0.45, Color(0.95, 0.40, 0.08, 0.7))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
