class_name R1Room
extends LayeredRoom
## R1 (ruang tamu): LayeredRoom + cahaya hangat lampu + debu.
## Lapisan di assets/processed/rooms/r1_layers/ (lihat layered_room.gd).

@export var lamp_position: Vector2 = Vector2(148, 117)

func _build_extras() -> void:
	_build_light()
	_build_dust()

func _build_light() -> void:
	var cm := CanvasModulate.new()
	cm.name = "RoomTint"
	cm.color = Color(0.62, 0.58, 0.68)
	add_child(cm)

	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var lamp := PointLight2D.new()
	lamp.name = "LampLight"
	lamp.texture = tex
	lamp.texture_scale = 1.1  # radius ~140 px canvas
	lamp.color = Color(1.0, 0.78, 0.45)
	lamp.energy = 1.3
	lamp.position = lamp_position
	lamp.shadow_enabled = false
	add_child(lamp)

func _build_dust() -> void:
	var d := CPUParticles2D.new()
	d.name = "Dust"
	d.amount = 24
	d.lifetime = 7.0
	d.preprocess = 7.0
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	d.emission_rect_extents = Vector2(240, 120)
	d.position = Vector2(240, 135)
	d.direction = Vector2(0.3, -1)
	d.spread = 60.0
	d.gravity = Vector2.ZERO
	d.initial_velocity_min = 1.0
	d.initial_velocity_max = 4.0
	d.scale_amount_min = 0.6
	d.scale_amount_max = 1.4
	d.color = Color(1.0, 0.9, 0.7, 0.35)
	d.z_index = 4
	add_child(d)
