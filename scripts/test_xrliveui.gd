extends Control

@export var connect_button: Button
@export var options_root: Control
@export var address_input: LineEdit
@export var error_text: Label
@export var connecting_text: Control

func _ready() -> void:
	connecting_text.hide()
	error_text.hide()
	options_root.show()

	connect_button.pressed.connect(_on_connect_pressed)
	XRLiveGlobal.connected_to_server.connect(_on_connected)
	XRLiveGlobal.disconnected_from_server.connect(_on_disconnected)
	XRLiveGlobal.failed_to_connect.connect(_on_connection_failed)


func _on_connect_pressed() -> void:
	if address_input.text == "":
		_show_error("Address cannot be empty!")
		return
	options_root.hide()
	connecting_text.show()
	XRLiveGlobal.start_client(address_input.text)


func _on_connected() -> void:
	hide()


func _on_connection_failed(reason: String) -> void:
	options_root.show()
	connecting_text.hide()
	_show_error(reason)
	show()


func _on_disconnected() -> void:
	options_root.show()
	connecting_text.hide()
	_show_error("Disconnected from server")
	show()


func _show_error(error: String) -> void:
	error_text.text = error
	error_text.show()
