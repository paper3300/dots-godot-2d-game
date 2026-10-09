extends SceneTree
func _initialize() -> void:
	var f := FileAccess.open("res://builds/ENGINE-LICENSES.txt",FileAccess.WRITE)
	f.store_string("GODOT ENGINE\n============\n"+Engine.get_license_text()+"\n\n")
	f.store_string("THIRD-PARTY COPYRIGHT INFORMATION\n=================================\n")
	for component in Engine.get_copyright_info():
		f.store_string(JSON.stringify(component,"  ")+"\n\n")
	f.store_string("THIRD-PARTY LICENSE TEXTS\n========================\n")
	var licenses: Dictionary=Engine.get_license_info()
	for license_name in licenses:
		f.store_string(str(license_name)+"\n"+str(licenses[license_name])+"\n\n")
	f.close()
	print("Engine and third-party licenses written.")
	quit()
