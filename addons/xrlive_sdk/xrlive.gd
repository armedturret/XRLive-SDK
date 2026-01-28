@tool
extends EditorPlugin

var _constants = preload("res://addons/xrlive_sdk/xrlive_constants.gd")

func _enable_plugin() -> void:
	if not Engine.has_singleton(_constants.XRLIVE_AUTOLOAD):
		add_autoload_singleton(_constants.XRLIVE_AUTOLOAD, "res://addons/xrlive_sdk/xrlive_global.gd")


func _disable_plugin() -> void:
	if Engine.has_singleton(_constants.XRLIVE_AUTOLOAD):
		remove_autoload_singleton(_constants.XRLIVE_AUTOLOAD)


func _enter_tree() -> void:
	add_autoload_singleton(_constants.XRLIVE_AUTOLOAD, "res://addons/xrlive_sdk/xrlive_global.gd")


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
