extends Node

class_name XRLiveInitializer

@export var levels: Array[String]
@export var default_scene_idx: int

var _constants = preload("res://addons/xrlive_sdk/xrlive_constants.gd")

func _ready() -> void:
	XRLiveGlobal.init.call_deferred(levels, default_scene_idx)
