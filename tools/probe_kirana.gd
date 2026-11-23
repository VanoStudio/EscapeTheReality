extends Node
# Probe: ukur bbox sprite fantasi + cek akses file input. Output lewat printerr (stderr, ekor log).

func _load_png(path: String) -> Image:
	var b := FileAccess.get_file_as_bytes(path)
	if b.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(b) != OK:
		return null
	return img

func _ready() -> void:
	var out := "PROBE>>\n"
	var base := "res://assets/processed/characters/kirana_fantasi/individual_frames/"
	for a in ["idle", "walk"]:
		for i in [1, 4, 7, 10]:
			var img := _load_png(base + "%s/frame_%02d.png" % [a, i])
			if img == null:
				out += "gagal %s %d\n" % [a, i]
				continue
			out += "%s %d size=%s used=%s\n" % [a, i, str(img.get_size()), str(img.get_used_rect())]
	var cands := [
		"res://assets/raw/characters/kirana-rumah-chibi-konsep-2.png",
		"/home/kantor/kantor-ai/outputs/k-261123-e2843f/kirana-rumah-chibi-konsep-2.png",
		"res://outputs/k-261123-e2843f/kirana-rumah-chibi-konsep-2.png",
		"res://../../../outputs/k-261123-e2843f/kirana-rumah-chibi-konsep-2.png",
		"res://../../../../outputs/k-261123-e2843f/kirana-rumah-chibi-konsep-2.png",
		"res://../../../../../outputs/k-261123-e2843f/kirana-rumah-chibi-konsep-2.png",
	]
	for c in cands:
		out += "%s exists=%s\n" % [c, str(FileAccess.file_exists(c))]
	out += "project dir=" + ProjectSettings.globalize_path("res://") + "\n"
	var d := DirAccess.open("res://assets/raw/characters/")
	if d:
		out += str(d.get_files()) + "\n"
	printerr(out)
	get_tree().quit()
