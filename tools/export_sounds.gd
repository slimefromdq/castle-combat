extends SceneTree
## Writes every SoundBank sound to a .wav file, to listen to them outside the game:
##   godot --headless --path . -s tools/export_sounds.gd -- <output folder>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://sounds"
	DirAccess.make_dir_recursive_absolute(dir)
	for name: StringName in SoundBank.RECIPES:
		SoundBank.get_stream(name).save_to_wav(dir.path_join(String(name) + ".wav"))
	print("wrote %d sounds to %s" % [SoundBank.RECIPES.size(), dir])
	quit()
