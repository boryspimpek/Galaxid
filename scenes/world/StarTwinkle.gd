extends GPUParticles2D

# Ile cykli jasność-ciemność przez całe życie cząstki.
# Przy lifetime=192s → 60 cykli = mruganie co ~3s.
const TWINKLE_CYCLES := 60

func _ready() -> void:
	var steps := 256
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	offs.resize(steps + 1)
	cols.resize(steps + 1)

	for i in range(steps + 1):
		var t := float(i) / steps
		var a := 0.08 + 0.92 * pow(sin(t * PI * TWINKLE_CYCLES) * 0.5 + 0.5, 1)
		offs[i] = t
		cols[i] = Color(1.0, 1.0, 1.0, a)

	var grad := Gradient.new()
	grad.offsets = offs
	grad.colors = cols

	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 512

	(process_material as ParticleProcessMaterial).color_ramp = tex
