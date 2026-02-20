extends MeshInstance3D

@export
var angular_speed_deg: float = 45.0

func _process(delta: float) -> void:
	if XRLiveGlobal.is_server:
		rotate_y(deg_to_rad(angular_speed_deg) * delta)
