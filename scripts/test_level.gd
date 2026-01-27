extends Node3D

const SPAWN_RANDOM := 3.0

@export var player_root: Node3D

func _ready() -> void:
    # We only need to spawn players on the server.
    if not multiplayer.is_server():
        return

    multiplayer.peer_connected.connect(add_player)
    multiplayer.peer_disconnected.connect(del_player)

    # Spawn already connected players.
    for id in multiplayer.get_peers():
        add_player(id)

    # Only spawn host player if not server
    if DisplayServer.get_name() != "headless":
       add_player(1)


func _exit_tree() -> void:
    if not multiplayer.is_server():
        return
    multiplayer.peer_connected.disconnect(add_player)
    multiplayer.peer_disconnected.disconnect(del_player)


func add_player(id: int) -> void:
    var character := preload("res://scenes/test_player.tscn").instantiate()
    # Set player id.
    character.player = id
    # Randomize character position.
    var pos := Vector2.from_angle(randf() * 2 * PI)
    character.position = Vector3(pos.x * SPAWN_RANDOM * randf(), 0, pos.y * SPAWN_RANDOM * randf())
    character.name = str(id)
    player_root.add_child(character, true)


func del_player(id: int) -> void:
    # TODO: using node names is not a great idea, store as internal var
    if not player_root.has_node(str(id)):
        return
    player_root.get_node(str(id)).queue_free()
