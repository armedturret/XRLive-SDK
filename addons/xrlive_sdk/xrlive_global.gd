extends Node

# These signals are all client only
signal disconnected_from_server
signal connected_to_server
signal failed_to_connect(reason: String)

var _constants = preload("res://addons/xrlive_sdk/xrlive_constants.gd")

var _level_root: Node
var _levels: Array[String]

func _ready() -> void:
	# Should NOT be able to pause a network manager
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Client only
	multiplayer.server_disconnected.connect(_on_disconnected_from_server)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failure)


func _on_disconnected_from_server() -> void:
	disconnected_from_server.emit()


func _on_connected_to_server() -> void:
	connected_to_server.emit()


func _on_connection_failure() -> void:
	failed_to_connect.emit("Failed to establish connection.")


# Init with the list of levels
func init(levels: Array[String], default_scene_index: int) -> void:
	if _level_root != null:
		push_error("Can only have one XRLiveInitializer")
		return

	_level_root = Node.new()
	_level_root.name = _constants.XRLIVE_LEVEL_ROOT_NAME
	get_tree().root.add_child(_level_root)
	var level_spawner := MultiplayerSpawner.new()
	level_spawner.name = _constants.XRLIVE_LEVEL_SPAWNER_NAME
	for path: String in levels:
		level_spawner.add_spawnable_scene(path)
	get_tree().root.add_child(level_spawner)
	level_spawner.spawn_path = _level_root.get_path()
	multiplayer.server_relay = false

	_levels = levels

	# Only start the server here, need input from client for address
	if DisplayServer.get_name() == "headless":
		start_server(default_scene_index)


func change_level(scene_path: String) -> void:
	if not multiplayer.is_server():
		push_error("Must be server to change scenes")
		return
	if _level_root == null:
		push_error("Must place an XRLiveInitializer in a scene first!")
		return
	var level := load(scene_path) as PackedScene
	for c: Node in _level_root.get_children():
		_level_root.remove_child(c)
		c.queue_free()
	_level_root.add_child(level.instantiate())
	print("Level should be added!")


func start_server(default_scene_index: int) -> void:
	print("Server started!")
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(_constants.XRLIVE_PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		push_error("Failed to start multiplayer server.")
		return
	multiplayer.multiplayer_peer = peer
	change_level.call_deferred(_levels[default_scene_index])


func start_client(address: String) -> void:
	if address == "":
		push_error("Need to specify an adrdess.")
		return

	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address, 3700)

	# reduce the timeout since the default is crazy long
	var packet_peer := peer.get_peer(1)
	packet_peer.set_timeout(0, 0, _constants.XRLIVE_TIMEOUT_SECONDS * 1000)


	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		push_error("Failed to start multiplayer client.")
		return
	multiplayer.multiplayer_peer = peer
