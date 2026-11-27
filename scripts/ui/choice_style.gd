class_name ChoiceStyle
extends Resource

# Gaya kotak pilihan jawaban. Semua angka bisa diatur dari Inspector Godot:
# buka data/choice_style.tres, ubah nilainya, jalankan game. Tidak perlu menyentuh kode.

@export_group("Tata letak")
@export var card_width: float = 660.0
@export var min_height: float = 70.0
@export var gap: float = 14.0
@export var right_margin: float = 90.0        # jarak kotak dari tepi kanan layar
@export var bottom_above_dialog: float = 352.0 # jarak kotak terbawah dari tepi bawah layar
@export var padding := Vector2(34.0, 14.0)    # jarak teks dari tepi kotak (kiri/kanan, atas/bawah)
@export var chamfer: float = 16.0             # sudut terpotong di kiri & kanan

@export_group("Warna")
@export var fill := Color(0.97, 0.94, 0.87)
@export var fill_hover := Color(1.0, 0.97, 0.9)
@export var border_outer := Color(0.62, 0.45, 0.22)
@export var border_inner := Color(0.85, 0.68, 0.38)
@export var border_hover := Color(0.95, 0.72, 0.3)
@export var glow := Color(1.0, 0.78, 0.4, 0.45)
@export var shadow := Color(0.0, 0.0, 0.0, 0.35)
@export var text_color := Color(0.24, 0.17, 0.12)
@export var text_hover := Color(0.45, 0.16, 0.08)

@export_group("Garis & teks")
@export var border_width: float = 3.0
@export var inner_inset: float = 5.0
@export var inner_width: float = 1.5
@export var font_size: int = 28
@export var font_path: String = "res://assets/processed/fonts/comic_dialog_bold.ttf"
@export var show_numbers: bool = false

@export_group("Gerak")
@export var hover_shift: float = 12.0          # kotak bergeser ke kiri saat dipilih
@export var appear_stagger: float = 0.06       # jeda muncul antar kotak
@export var anim_speed: float = 7.0

static func load_default() -> ChoiceStyle:
	var path := "res://data/choice_style.tres"
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is ChoiceStyle:
			return s
	return ChoiceStyle.new()
