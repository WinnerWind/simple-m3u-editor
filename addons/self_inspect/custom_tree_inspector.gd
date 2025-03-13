@tool
extends Tree

func set_all_visible(item: TreeItem) -> void:
	if not item:
		return
	item.visible = true
	set_all_visible(item.get_parent())

func build_tree(node: Node, parent_item: TreeItem) -> void:
	if not parent_item:
		parent_item = create_item()
		
	if node.get_class().contains("Tree"):
		set_all_visible(parent_item)
	else:
		parent_item.visible = false
		
	parent_item.set_text(0, node.get_class())
	parent_item.set_metadata(0, node)
	for child in node.get_children(false):
		var child_item = create_item(parent_item)
		build_tree(child, child_item)

func _on_reload() -> void:
	var root = EditorInterface.get_base_control()
	clear()
	build_tree(root, null)


func _on_item_selected() -> void:
	var tree_item = get_selected()
	var node = tree_item.get_metadata(0)
	EditorInterface.inspect_object(node)
