extends Node

# AssetRegistry: Menyediakan referensi terpusat aset visual dan fallback placeholder

const ROOM_BACKGROUNDS = {
	"R1": "res://assets/processed/rooms/bg_r1.png",
	"R2": "res://assets/processed/rooms/bg_r2.png",
	"F1": "res://assets/processed/rooms/bg_f1.png",
	"F2": "res://assets/processed/rooms/bg_f2.png",
	"F3": "res://assets/processed/rooms/bg_f3.png",
	"F4": "res://assets/processed/rooms/bg_f4.png",
	"F5": "res://assets/processed/rooms/bg_f5.png"
}

const PORTRAITS = {
	"kakak_biasa": "res://assets/processed/portraits/portrait_kakak_biasa.png",
	"kakak_kesal": "res://assets/processed/portraits/portrait_kakak_kesal.png",
	"kakak_sedih": "res://assets/processed/portraits/portrait_kakak_sedih.png",
	"kakak_lega": "res://assets/processed/portraits/portrait_kakak_lega.png",
	"kakak_rumah": "res://assets/processed/portraits/portrait_kakak_rumah.png",
	"adik_biasa": "res://assets/processed/portraits/portrait_adik_biasa.png",
	"adik_kaget": "res://assets/processed/portraits/portrait_adik_kaget.png",
	"penjual": "res://assets/processed/portraits/portrait_penjual.png"
}

const WATCHES = {
	"teal": "res://assets/processed/props/pocket_watch_teal.png",
	"orange": "res://assets/processed/props/pocket_watch_orange.png",
	"red": "res://assets/processed/props/pocket_watch_red.png"
}

const COMIC_PANELS = {
	"open_1": "res://assets/processed/comic/comic_open_1.png",
	"open_2": "res://assets/processed/comic/comic_open_2.png",
	"open_3": "res://assets/processed/comic/comic_open_3.png",
	"open_4": "res://assets/processed/comic/comic_open_4.png",
	"open_5": "res://assets/processed/comic/comic_open_5.png",
	"open_6": "res://assets/processed/comic/comic_open_6.png",
	"end_1": "res://assets/processed/comic/comic_end_1.png",
	"end_2": "res://assets/processed/comic/comic_end_2.png"
}

const SCRAPS = {
	"scrap_1": "res://assets/processed/props/scrap_1.png",
	"scrap_2": "res://assets/processed/props/scrap_2.png",
	"scrap_3": "res://assets/processed/props/scrap_3.png",
	"frame_empty": "res://assets/processed/props/frame_empty.png",
	"photo_completed": "res://assets/processed/props/photo_completed.png"
}

func get_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_room_bg(room_id: String) -> Texture2D:
	var path = ROOM_BACKGROUNDS.get(room_id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_portrait(key: String) -> Texture2D:
	var path = PORTRAITS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
