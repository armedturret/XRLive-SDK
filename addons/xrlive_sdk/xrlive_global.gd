extends Node

# These signals are all client only
signal disconnected_from_server
# Called when a client is starting, but hasn't failed/succeeded yet
signal connection_started
signal connected_to_server
signal failed_to_connect(reason: String)

# This is only called from a server (duh)
signal server_initialized

# Called on both client and server
signal other_peer_connected(id: int)
signal other_peer_disconnected(id: int)

var settings: XRLiveSettings
var xr_interface: XRInterface
var is_server: bool
var xr_origin: XROrigin3D

var _constants = preload("res://addons/xrlive_sdk/xrlive_constants.gd")

var _level_root: Node3D
var _levels: Array[String]

var _input_thread: Thread

func _ready() -> void:
	# Should NOT be able to pause a network manager
	process_mode = Node.PROCESS_MODE_ALWAYS

	settings = XRLiveSettings.new()
	settings.port = _constants.XRLIVE_DEFAULT_PORT
	_parse_launch_file()
	_parse_launch_arguments()

	# Should we launch in AR?
	is_server = DisplayServer.get_name() == "headless"
	if !is_server:
		xr_interface = XRServer.find_interface("OpenXR")
		if xr_interface and xr_interface.is_initialized():
			print("OpenXR initialized successfully")

			# Turn off v-sync!
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

			get_viewport().use_xr = true
			if not OpenXRSpatialEntityExtension.supports_capability(OpenXRSpatialEntityExtension.CAPABILITY_MARKER_TRACKING_QR_CODE):
				push_error("This device does not support qr code tracking")
		else:
			print("OpenXR not initialized, please check if your headset is connected")


func _enter_tree() -> void:
	# these callbacks are only ever called on the client
	multiplayer.server_disconnected.connect(_on_disconnected_from_server)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failure)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if is_server:
		print("Type 'quit' to quit!")
		_input_thread = Thread.new()
		_input_thread.start(_async_read_input)


func _exit_tree() -> void:
	multiplayer.server_disconnected.disconnect(_on_disconnected_from_server)
	multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	multiplayer.connection_failed.disconnect(_on_connection_failure)
	multiplayer.peer_connected.disconnect(_on_peer_connected)
	multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

	if _input_thread:
		_input_thread.wait_to_finish()


# CLIENT ONLY
func _on_disconnected_from_server() -> void:
	print("Disconnected from server!")
	disconnected_from_server.emit()

	for c: Node in _level_root.get_children():
		_level_root.remove_child(c)
		c.queue_free()

	# retry connecting
	if settings.address != "":
		start_client(settings.address, settings.port)


# CLIENT ONLY
func _on_connected_to_server() -> void:
	print("Connected to server!")
	connected_to_server.emit()


# CLIENT ONLY
func _on_connection_failure() -> void:
	failed_to_connect.emit("Failed to establish connection.")

	# retry connection
	if settings.address != "":
		start_client(settings.address, settings.port)


# CLIENT + SERVER
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		print("Client peer connected: ", id)
	else:
		print("Other peer connected: ", id)
	other_peer_connected.emit(id)


# CLIENT + SERVER
func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		print("Client peer disconnected: ", id)
	else:
		print("Other peer disconnected: ", id)
	other_peer_disconnected.emit(id)


# Init with the list of levels
func init(levels: Array[String],
		default_scene_index: int,
		xr_origin: XROrigin3D) -> void:
	if _level_root != null:
		push_error("Can only have one XRLiveInitializer")
		return

	if xr_origin == null:
		push_error("Need to set xr_origin in XRLiveInitializer")
		return

	if len(levels) == 0:
		push_error("Must add at least one scene to XRLiveInitializer")
		return

	# Setup tree
	self.xr_origin = xr_origin
	_level_root = Node3D.new()
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
	if is_server:
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
		return
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
	# --actor - spawns a controllable model for this client
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
		elif args[i] == "--actor":
			settings.is_actor = true

	if should_quit:
		get_tree().quit(1)


# This function is blocking, only called in thread
func _async_read_input() -> void:
	var input : String = ""
	while input != "quit":
		input = OS.read_string_from_stdin().strip_edges().to_lower()
		match input:
			"quit":
				pass
			"stats":
				print("Uptime (ms): %s" %
					Time.get_ticks_msec())
			"":
				pass
			_:
				print("String \'%s\' unrecognized command" % input)
	get_tree().quit()
