@tool
extends SceneTree

func _init() -> void:
	print("Building SpriteFrames for Kirana...")
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	
	var anims = {
		"idle": {
			"path": "res://assets/processed/characters/kirana_fantasi/spritesheets_strip_12x1/idle_12f.png",
			"fps": 10.0,
			"loop": true
		},
		"walk": {
			"path": "res://assets/processed/characters/kirana_fantasi/spritesheets_strip_12x1/walk_12f.png",
			"fps": 12.0,
			"loop": true
		},
		"jump": {
			"path": "res://assets/processed/characters/kirana_fantasi/spritesheets_strip_12x1/jump_12f.png",
			"fps": 12.0,
			"loop": false
		},
		"fall": {
			"path": "res://assets/processed/characters/kirana_fantasi/spritesheets_strip_12x1/fall_12f.png",
			"fps": 12.0,
			"loop": true
		}
	}
	
	for anim_name in anims.keys():
		var info = anims[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, info["fps"])
		sf.set_animation_loop(anim_name, info["loop"])
		
		var tex = load(info["path"])
		if not tex:
			printerr("Failed to load: ", info["path"])
			continue
			
		for i in range(12):
			var atlas = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * 256, 0, 256, 256)
			sf.add_frame(anim_name, atlas)
			
	# Add idle_rumah and walk_rumah using kirana_rumah.png
	var tex_rumah = load("res://assets/processed/characters/kirana_rumah.png")
	if tex_rumah:
		sf.add_animation("idle_rumah")
		sf.set_animation_speed("idle_rumah", 6.0)
		sf.set_animation_loop("idle_rumah", true)
		sf.add_frame("idle_rumah", tex_rumah)
		
		sf.add_animation("walk_rumah")
		sf.set_animation_speed("walk_rumah", 8.0)
		sf.set_animation_loop("walk_rumah", true)
		sf.add_frame("walk_rumah", tex_rumah)
			
	var save_path = "res://assets/processed/characters/kirana_fantasi/kirana_fantasy_frames.tres"
	var err = ResourceSaver.save(sf, save_path)
	if err == OK:
		print("Successfully saved SpriteFrames with Rumah and Fantasy animations!")
	else:
		printerr("Failed to save SpriteFrames: ", err)
		
	quit(0)
