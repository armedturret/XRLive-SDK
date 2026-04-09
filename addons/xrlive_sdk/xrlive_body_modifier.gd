extends SkeletonModifier3D

class_name XRLiveBodyModifier

@export var player := 1

var _bone_pose_positions : PackedVector3Array
var _bone_pose_rotations : PackedVector4Array

var _last_tick_recieved: int

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if !skeleton:
		return
	if not multiplayer.is_server() and multiplayer.get_unique_id() == player:
		# save all the bone positions + rotations on the local client
		_bone_pose_positions.resize(skeleton.get_bone_count())
		_bone_pose_rotations.resize(skeleton.get_bone_count())
		for i in range(skeleton.get_bone_count()):
			_bone_pose_positions[i] = skeleton.get_bone_pose_position(i)
			_bone_pose_rotations[i] = _quat_to_vec4(skeleton.get_bone_pose_rotation(i))

		# send updated position to server
		rpc_id(1,
		_update_bones_server.get_method(),
		 _bone_pose_positions,
		_bone_pose_rotations,
		Time.get_ticks_msec())
	else:
		# any of the other clients should restore bone positions
		for i in range(skeleton.get_bone_count()):
			skeleton.set_bone_pose_position(i, _bone_pose_positions[i])
			skeleton.set_bone_pose_rotation(i, _vec4_to_quat(_bone_pose_rotations[i]))


func _skeleton_changed(old_skeleton: Skeleton3D, new_skeleton: Skeleton3D) -> void:
	# save a default skeleton
	_bone_pose_positions.resize(new_skeleton.get_bone_count())
	_bone_pose_rotations.resize(new_skeleton.get_bone_count())
	for i in range(new_skeleton.get_bone_count()):
		_bone_pose_positions[i] = new_skeleton.get_bone_pose_position(i)
		_bone_pose_rotations[i] = _quat_to_vec4(new_skeleton.get_bone_pose_rotation(i))

func _vec4_to_quat(vec4: Vector4) -> Quaternion:
	return Quaternion(vec4.x, vec4.y, vec4.z, vec4.w)


func _quat_to_vec4(quat: Quaternion) -> Vector4:
	return Vector4(quat.x, quat.y, quat.z, quat.w)


# CLIENT -> SERVER call to update bones
@rpc("any_peer", "call_remote", "unreliable")
func _update_bones_server(bone_pos: PackedVector3Array,
	bone_rot: PackedVector4Array,
	sent_time: int) -> void:

	# TODO: send deltas only? might reduce bandwith usage
	if not multiplayer.is_server():
		return

	# only the designated player can update the model
	if multiplayer.get_remote_sender_id() != player:
		return

	# this is an unreliable function, so we could recieve data out of order
	if sent_time < _last_tick_recieved:
		return
	else:
		_last_tick_recieved = sent_time
		_bone_pose_positions = bone_pos
		_bone_pose_rotations = bone_rot

		# avoid resending to the designated owner
		for id: int in multiplayer.get_peers():
			if id != player:
				rpc_id(id, _update_bones_clients.get_method(), bone_pos, bone_rot, sent_time)


@rpc("authority", "call_remote", "unreliable")
func _update_bones_clients(bone_pos: PackedVector3Array,
	bone_rot: PackedVector4Array,
	sent_time: int) -> void:

	if multiplayer.get_unique_id() == player:
		return

	# this is an unreliable function, so we could recieve data out of order
	if sent_time < _last_tick_recieved:
		return
	else:
		_last_tick_recieved = sent_time
		_bone_pose_positions = bone_pos
		_bone_pose_rotations = bone_rot
