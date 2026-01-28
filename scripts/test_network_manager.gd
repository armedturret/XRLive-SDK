extends Node

class_name TestNetworkManager

# TODO: this should probably be seperated into its own gui node
# we'll want to decouple ui/business logic for people to add to their ui
@export var net_ui: Control
@export var host_button: Button
@export var connect_button: Button
@export var address_input: LineEdit

# TODO: these should be spawned automatically and abstracted out
@export var levelRoot: Node

func _ready() -> void:
	get_tree().paused = true
	# disables transmitting packets directly between peers
	multiplayer.server_relay = false
	connect_button.pressed.connect(_on_connect_pressed)


func _on_connect_pressed() -> void:
	# TODO: Move OS alerts into an in-game error box
	if address_input.text == "":
		OS.alert("Need to specify a host address")
		return

	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address_input.text, 3700)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer client.")
		return
	multiplayer.multiplayer_peer = peer
	start_game()


func start_game() -> void:
	net_ui.hide()
	get_tree().paused = false
	if multiplayer.is_server():
		change_level.call_deferred(load("res://scenes/test_level.tscn"))


func change_level(scene: PackedScene) -> void:
	if not multiplayer.is_server():
		OS.alert("Need to be server to change scenes.")
		return
	for c: Node in levelRoot.get_children():
		levelRoot.remove_child(c)
		c.queue_free()
	levelRoot.add_child(scene.instantiate())


# TODO: remove ALL this, should be 0 input logic in the net man
func _input(event: InputEvent) -> void:
	if not multiplayer.is_server():
		return
	if event.is_action("ui_accept") and Input.is_action_just_pressed("ui_accept"):
		change_level.call_deferred(load("res://scenes/test_level.tscn"))
