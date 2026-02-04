extends Node

# These signals are all client only
signal disconnected_from_server
# Called when a client is starting, but hasn't failed/succeeded yet
signal connection_started
signal connected_to_server
signal failed_to_connect(reason: String)
signal server_initialized

var settings: XRLiveSettings

var _constants = preload("res://addons/xrlive_sdk/xrlive_constants.gd")

var _level_root: Node
var _levels: Array[String]

func _ready() -> void:
	# Should NOT be able to pause a network manager
	process_mode = Node.PROCESS_MODE_ALWAYS

	# These callbacks are only ever called on client
	multiplayer.server_disconnected.connect(_on_disconnected_from_server)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failure)

	settings = XRLiveSettings.new()
	settings.port = _constants.XRLIVE_DEFAULT_PORT
	_parse_launch_file()
	_parse_launch_arguments()


func _on_disconnected_from_server() -> void:
	disconnected_from_server.emit()


func _on_connected_to_server() -> void:
	print("Connected to server!")
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

	# Start server, or, if addresss specified, join immediately
	if DisplayServer.get_name() == "headless":
		start_server(default_scene_index)
	elif settings.address != "":
		start_client(settings.address, settings.port)


func change_level(scene_path: String) -> void:
	if not multiplayer.is_server():
		push_error("Must be server to change scenes")
		return
	if _level_root == null:
		push_error("Must place a XRLiveInitializer in a scene first!")
		return
	var level := load(scene_path) as PackedScene
	for c: Node in _level_root.get_children():
		_level_root.remove_child(c)
		c.queue_free()
	_level_root.add_child(level.instantiate())


func start_server(default_scene_index: int) -> void:
	print("Starting server on port %s" % settings.port)

	if _level_root == null:
		push_error("Must place a XRLiveInitializer in a scene first!")
		return

	var peer := ENetMultiplayerPeer.new()
	peer.create_server(settings.port, _constants.XRLIVE_MAX_CLIENTS)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		push_error("Failed to start multiplayer server.")
		get_tree().quit(1)
	multiplayer.multiplayer_peer = peer
	change_level.call_deferred(_levels[default_scene_index])
	print("Server started!")
	server_initialized.emit()


func start_client(address: String, port: int) -> void:
	print("Connecting to %s:%s" % [address, port])
	if _level_root == null:
		push_error("Must place a XRLiveInitializer in a scene first!")
		return
	elif address == "":
		push_error("Need to specify an adrdess.")
		return

	connection_started.emit()

	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address, settings.port)

	# reduce the timeout since the default is crazy long
	var packet_peer := peer.get_peer(1)
	packet_peer.set_timeout(0, 0, _constants.XRLIVE_TIMEOUT_SECONDS * 1000)

	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		push_error("Failed to start multiplayer client.")
		return
	multiplayer.multiplayer_peer = peer


func _parse_launch_file() -> void:
	# reads the config file located in the executable directory (if there is one)
	# just passes them as if passed via command line
	if OS.has_feature("editor"):
		return

	var path : String = OS.get_executable_path().get_base_dir()
	path += _constants.XRLIVE_ARG_FILE_PATH

	if FileAccess.file_exists(path):
		print("Found %s! Parsing..." % path)
		var file := FileAccess.open(path, FileAccess.READ)
		var contents := file.get_as_text()
		var args := contents.strip_edges().split(" ", false)
		_parse_args(args)


func _parse_launch_arguments() -> void:
	# command line args take higher precendence than config file
	var args := OS.get_cmdline_args()
	_parse_args(args)


func _parse_args(args: PackedStringArray) -> void:
	# options:
	# --port [PORT] - set client/server port
	# --address [ADDRESS] - connects client to address (if not headless)
	var should_quit: bool = false

	for i : int in range(len(args)):
		if args[i] == "--port":
			if i == len(args) - 1:
				push_error("No port specified")
				should_quit = true
				continue
			elif not args[i + 1].is_valid_int():
				push_error("Not a valid port")
				should_quit = true
				continue
			settings.port = args[i + 1].to_int()
			i += 1
		elif args[i] == "--address":
			if i == len(args) - 1:
				push_error("No address specified")
				should_quit = true
				continue
			settings.address = args[i + 1]
			i += 1

	if should_quit:
		get_tree().quit(1)
