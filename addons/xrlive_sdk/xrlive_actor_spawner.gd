extends MultiplayerSpawner

class_name XRLiveActorSpawner

@export_file_path("*.tscn")
var actor_scene: String

var _actor_packedscene: PackedScene

func _enter_tree() -> void:
	super.clear_spawnable_scenes()
	super.add_spawnable_scene(actor_scene)
	_actor_packedscene = load(actor_scene) as PackedScene

	# check if this client is trying to be an actor
	if XRLiveGlobal.settings.is_actor and not multiplayer.is_server():
		rpc_id(1, request_actor_spawn.get_method())


@rpc("any_peer", "call_remote", "reliable")
func request_actor_spawn() -> void:
	if multiplayer.is_server():
		var new_actor := _actor_packedscene.instantiate()
		var actor := new_actor as XRLiveActor
		get_node(spawn_path).add_child(new_actor)
		actor.xrlive_body_mod.player = multiplayer.get_remote_sender_id()
