extends Node3D

# This class operates asynchronously from the main autoload and tracks new markers
# DO NOT ADD MULTIPLAYER CHILDREN TO THESE MARKERS
# Godot depends on matching node paths to send rpcs, not possible with dynamic
# markers

signal added_qr_anchor(anchor: XRNode3D, text: String)
signal removed_qr_anchor(anchor: XRNode3D)

var marker_tracker_scene: PackedScene = preload("res://addons/xrlive_sdk/scenes/xrlive_qr_anchor.tscn")

var _managed_nodes: Dictionary[XRTracker, XRAnchor3D]

func get_tracker_by_qr(qr_text: String) -> XRAnchor3D:
	for anchor: XRAnchor3D in _managed_nodes.values():
		if anchor.has_meta("qr_text") and anchor.get_meta("qr_text", "") == qr_text:
			return anchor
	return null


func _enter_tree() -> void:
	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_removed.connect(_on_tracker_removed)

	# Need to add existing trackers
	var trackers : Dictionary = XRServer.get_trackers(XRServer.TRACKER_ANY)
	for tracker_name in trackers:
		var tracker: XRTracker = trackers[tracker_name]
		if tracker and tracker is OpenXRSpatialEntityTracker:
			_add_tracker(tracker)


func _exit_tree():
	XRServer.tracker_added.disconnect(_on_tracker_added)
	XRServer.tracker_removed.disconnect(_on_tracker_removed)

	# Clean up trackers.
	for tracker in _managed_nodes:
		removed_qr_anchor.emit(_managed_nodes[tracker])
		XRLiveGlobal.xr_origin.remove_child(_managed_nodes[tracker])
		_managed_nodes[tracker].queue_free()

	_managed_nodes.clear()


func _add_tracker(tracker: OpenXRSpatialEntityTracker):
	if _managed_nodes.has(tracker):
		return

	print("Tracker added: ", tracker.name)
	if tracker is OpenXRMarkerTracker and tracker.marker_type == OpenXRSpatialComponentMarkerList.MARKER_TYPE_QRCODE:
		var data = tracker.get_marker_data()
		print("Tracker data: ", data)
		if typeof(data) != TYPE_STRING:
			return

		var new_anchor : XRAnchor3D = marker_tracker_scene.instantiate()
		new_anchor.tracker = tracker.name
		new_anchor.pose = "default"
		new_anchor.set_meta("qr_text", data as String)
		_managed_nodes[tracker] = new_anchor
		XRLiveGlobal.xr_origin.add_child(new_anchor)
		added_qr_anchor.emit(new_anchor, data as String)


func _on_tracker_added(tracker_name: StringName, type: int):
	if type == XRServer.TRACKER_ANCHOR:
		var tracker: XRTracker = XRServer.get_tracker(tracker_name)
		if tracker and tracker is OpenXRSpatialEntityTracker:
			_add_tracker(tracker)


func _on_tracker_removed(tracker_name: StringName, type: int):
	if type == XRServer.TRACKER_ANCHOR:
		print("Tracker removed: ", tracker_name)
		var tracker: XRTracker = XRServer.get_tracker(tracker_name)
		if _managed_nodes.has(tracker):
			removed_qr_anchor.emit(_managed_nodes[tracker])
			# remove from children, delete, and untrack
			XRLiveGlobal.xr_origin.remove_child(_managed_nodes[tracker])
			_managed_nodes[tracker].queue_free()
			_managed_nodes.erase(tracker)
