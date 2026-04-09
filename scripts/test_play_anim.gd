extends Node3D

@export
var anim_player: AnimationPlayer
@export
var xrlive_body_modifier: XRLiveBodyModifier

var client_playing_id: int = 1

func _enter_tree() -> void:
	XRLiveGlobal.other_peer_connected.connect(_on_peer_connected)


func _exit_tree() -> void:
	XRLiveGlobal.other_peer_connected.disconnect(_on_peer_connected)


func _on_peer_connected(id: int) -> void:
	# really hacky method to get an animation playing on the first client
	# we want to run this on a client to simulate movement on their end
	if multiplayer.is_server() && client_playing_id == 1:
		client_playing_id = id
		rpc_id(id, "_play_anim")
		xrlive_body_modifier.player = client_playing_id


@rpc("authority", "call_remote", "reliable")
func _play_anim() -> void:
	anim_player.current_animation = "mixamo_com"
	anim_player.play()
