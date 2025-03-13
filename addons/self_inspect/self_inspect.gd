@tool
extends EditorPlugin

var dock: Node

func _enter_tree() -> void:
	dock = preload("res://addons/self_inspect/custom_tree_inspector.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)

func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.free()
