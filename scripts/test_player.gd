# TODO: nuke this entire script
extends CharacterBody3D

class_name TestPlayer

const SPEED = 5.0
const RUBBER_BAND_DIST = 0.75

@export var input: PlayerInput

@export_category("Synched Properties")
@export var expected_position: Vector3

# Set by the authority, synchronized on spawn.
@export var player := 1 :
	set(id):
		player = id
		# Give authority over the player input to the appropriate peer.
		if is_inside_tree():
			input.set_multiplayer_authority(id)


func _enter_tree() -> void:
	input.set_multiplayer_authority(player)


func _physics_process(_delta: float) -> void:
	# Handle movement.
	var direction := (transform.basis * Vector3(input.direction.x, 0, input.direction.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	if multiplayer.is_server():
		expected_position = position
	elif multiplayer.multiplayer_peer.get_unique_id() != player:
		position = expected_position
	elif (expected_position - position).length_squared() > RUBBER_BAND_DIST * RUBBER_BAND_DIST:
		position = expected_position
