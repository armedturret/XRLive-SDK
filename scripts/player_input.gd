extends MultiplayerSynchronizer

class_name PlayerInput

@export var direction := Vector2()

func _ready() -> void:
	# Process for local player only
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())


func _process(_delta: float) -> void:
	# TODO: Figure out how to wrap XR inputs
	# TODO: Make conformant with event-based input
	direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
