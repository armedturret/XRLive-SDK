extends Node

class_name NetworkManager

# this should probably be seperated into its own gui node
# we'll want to decouple ui/business logic for people to add to their owns scenes
@export var net_ui: Control
@export var host_button: Button
@export var connect_button: Button
@export var address_input: LineEdit
@export var port_input: LineEdit

func _ready() -> void:
	get_tree().paused = true
	# disables transmitting packets directly between peers
	multiplayer.server_relay = false
	host_button.pressed.connect(_on_host_pressed)
	connect_button.pressed.connect(_on_connect_pressed)


func _on_host_pressed() -> void:
	# TODO: Move OS alerts into an in-game error box
	if port_input.text == "" || !port_input.text.is_valid_int():
		OS.alert("Need to specify a valid port.")
		return

	var peer := ENetMultiplayerPeer.new()
	peer.create_server(port_input.text.to_int())
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer server.")
		return
	multiplayer.multiplayer_peer = peer
	start_game()


func _on_connect_pressed() -> void:
	# TODO: Move OS alerts into an in-game error box
	if address_input.text == "":
		OS.alert("Need to specify a host address")
		return

	if port_input.text == "" || !port_input.text.is_valid_int():
		OS.alert("Need to specify a valid port.")
		return

	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address_input.text, port_input.text.to_int())
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer client.")
		return
	multiplayer.multiplayer_peer = peer
	start_game()


func start_game() -> void:
	net_ui.hide()
	get_tree().paused = false
