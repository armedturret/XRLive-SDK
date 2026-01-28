extends Node

var _constants = preload("res://addons/xrlive_sdk/xrlive_constants.gd")

var _level_root: Node
var _levels: Array[String]

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


func start_server(default_scene_index: int) -> void:
	print("Server started!")
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(_constants.XRLIVE_PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		push_error("Failed to start multiplayer server.")
		return
	multiplayer.multiplayer_peer = peer
	change_level(_levels[default_scene_index])


func start_client(address: String) -> void:
	pass
