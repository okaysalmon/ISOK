@tool
extends EditorPlugin


func _enable_plugin() -> void:
	push_warning("Enabling or disabling OSIK plugin won’t do anything — it only serves to add the files to your project. To remove it completely, you’ll need to delete the OSIK folder from the addons directory, as the OS_IK file is what enables the creation of OSIK nodes.")
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	push_warning("Enabling or disabling OSIK plugin won’t do anything — it only serves to add the files to your project. To remove it completely, you’ll need to delete the OSIK folder from the addons directory, as the OS_IK file is what enables the creation of OSIK nodes.")
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
