@tool
extends EditorPlugin
## Export-only: runtime parsers need the source bytes as well as imported meshes.
class RawModelExport extends EditorExportPlugin:
	const SOURCES := [
		"res://prototypes/tinkercad/3rd map/Amazing Densor-Uusam/tinker.obj",
		"res://prototypes/tinkercad/3rd map/Amazing Densor-Uusam/obj.mtl",
		"res://prototypes/tinkercad/tinker.obj",
		"res://prototypes/tinkercad/obj.mtl",
	]
	func _get_name() -> String:
		return "BalanceRawModels"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		for path: String in SOURCES:
			var bytes := FileAccess.get_file_as_bytes(path)
			if bytes.is_empty():
				push_error("Missing runtime model source: " + path)
			else:
				add_file(path, bytes, false)

var _exporter: RawModelExport

func _enter_tree() -> void:
	_exporter = RawModelExport.new()
	add_export_plugin(_exporter)

func _exit_tree() -> void:
	remove_export_plugin(_exporter)
