extends SceneTree

func _initialize() -> void:
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var license_file := FileAccess.open(output.path_join("Godot.txt"), FileAccess.WRITE)
	license_file.store_string(Engine.get_license_text())
	license_file.close()
	var dependencies := FileAccess.open(output.path_join("Godot-third-party.json"), FileAccess.WRITE)
	dependencies.store_string(JSON.stringify({"copyright": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "\t"))
	dependencies.close()
	quit()
