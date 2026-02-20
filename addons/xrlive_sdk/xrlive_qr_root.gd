extends Node3D

class_name XRLiveQRRoot

# class that tracks an anchor tracking a QR code
# unlike the anchor, this persists, letting it function with multiplayer

# Target qr code to anchor to
@export var root_qr_text: String

# QR code to try to face
@export var forward_qr_text: String

var _root_anchor: XRAnchor3D
var _forward_anchor: XRAnchor3D

func _enter_tree() -> void:
	XRLiveSpatialEntitiesManager.added_qr_anchor.connect(_on_anchor_added)
	XRLiveSpatialEntitiesManager.removed_qr_anchor.connect(_on_anchor_removed)

	# check if the anchor was created before joining the server
	var anchor : XRAnchor3D = XRLiveSpatialEntitiesManager.get_tracker_by_qr(root_qr_text)
	if anchor:
		_root_anchor = anchor

	var fw_anchor : XRAnchor3D = XRLiveSpatialEntitiesManager.get_tracker_by_qr(forward_qr_text)
	if fw_anchor:
		_forward_anchor = fw_anchor


func _exit_tree() -> void:
	XRLiveSpatialEntitiesManager.added_qr_anchor.disconnect(_on_anchor_added)
	XRLiveSpatialEntitiesManager.removed_qr_anchor.disconnect(_on_anchor_removed)


func _process(_delta: float) -> void:
	if _root_anchor:
		global_position = _root_anchor.global_position
	if _forward_anchor:
		look_at(_forward_anchor.global_position)


func _on_anchor_added(anchor: XRNode3D, text: String) -> void:
	if text == root_qr_text:
		_root_anchor = anchor
	if text == forward_qr_text:
		_forward_anchor = anchor


func _on_anchor_removed(anchor: XRNode3D) -> void:
	if _root_anchor == anchor:
		_root_anchor = null
	elif _forward_anchor == anchor:
		_forward_anchor = null
