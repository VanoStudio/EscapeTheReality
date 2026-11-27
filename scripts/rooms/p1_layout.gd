class_name ParkourLayout
extends RefCounted

# Data menara parkour P1 (dipisah supaya bisa dites tanpa autoload).
# Koordinat dunia: x 0..1000, y 140..1150 (y = permukaan pulau).
# Semua lompatan dicek (tests/m5_test.gd) dengan dua profil:
#   normal  : lompat 345, jalan 120  -> sisa jangkauan >= 20 px
#   kaki berat (tidak makan): lompat 0.9x, jalan 0.88x -> sisa >= 6 px

# ---------------------------------------------------------------- fisika & rasa
const WALK := 120.0
const JUMP := -345.0
const GRAVITY := 820.0
const COYOTE := 0.15
const JUMP_BUFFER := 0.15
const APEX_GRAVITY := 0.6     # gravitasi di puncak lompatan saat tombol ditahan
const MAX_FALL := 520.0

# ---------------------------------------------------------------- energi (bar 0..100)
const ENERGY_ATE := 100        # masuk parkour setelah makan di Mbok Luna
const ENERGY_HEAVY := 75       # masuk parkour tanpa makan (+ kaki berat)
const DMG_TRAUMA := 15
const DMG_VOID := 10           # jatuh ke kehampaan -> kembali ke pijakan aman terakhir
const LAND_SAFE_DROP := 110.0  # jatuh lebih dari ini (~2.5x tinggi badan) = sakit
const DMG_LAND_MIN := 5
const DMG_LAND_MAX := 10
const HEAL_PAPER := 25
const HEAL_LANTERN := 10       # lentera menyala pertama kali
const HEAL_FOOD := 10          # bekal Mbok Luna di jalur sulit
const INVULN_SEC := 1.5
const ASSIST_AFTER := 3        # gagal (jatuh/kena trauma) di tingkat yang sama -> bantuan Bayangan

# [jenis, varian, x, y(permukaan), opsi]
const LEVEL := [
	# Tingkat 1: kanan -> kiri (pengenalan: satu zona trauma diam)
	["static", "G", 900, 1080],
	["static", "M", 720, 1075],
	["static", "L", 555, 1065],
	["static", "S", 410, 1045],
	["static", "M", 295, 1035],
	["static", "L", 130, 1040],
	# naik di kiri
	["static", "M", 230, 1000],
	["static", "S", 140, 960],
	["static", "M", 60, 920],
	["static", "L", 150, 880],
	# Tingkat 2: kiri -> kanan (runtuh + bergerak, lalu satu trauma naik-turun)
	["crumble", "M", 300, 880],
	["moving", "S", 412, 870, {"patrol": Vector2(90, 0), "speed": 0.16}],
	["static", "S", 605, 860],
	["static", "L", 750, 860],
	["static", "M", 915, 850],
	# naik di kanan
	["static", "S", 850, 810],
	["static", "M", 930, 770],
	["static", "S", 850, 730],
	["static", "L", 880, 690],
	# Tingkat 3: kanan -> kiri (batu menyatu #1)
	["static", "M", 715, 690],
	["movable", "L", 557, 770, {"target": Vector2(557, 690), "bounds": Rect2(470, 640, 180, 150)}],
	["static", "M", 400, 690],
	["static", "S", 290, 670],
	["static", "M", 180, 660],
	# naik di kiri
	["static", "S", 100, 620],
	["static", "M", 190, 580],
	["static", "S", 100, 540],
	["static", "L", 160, 500],
	# Tingkat 4: kiri -> kanan (dua batu menyatu)
	["static", "M", 310, 500],
	["movable", "M", 430, 565, {"target": Vector2(405, 470), "bounds": Rect2(360, 440, 90, 140)}],
	["movable", "M", 535, 330, {"target": Vector2(520, 440), "bounds": Rect2(470, 310, 100, 150)}],
	["static", "M", 640, 420],
	["static", "L", 800, 400],
	# puncak
	["static", "S", 935, 360],
	["static", "M", 860, 322],
	# puncak lebar, portal di ujung kiri: pemain menyeberangi puncak dulu sebelum finale
	["static", "G", 700, 285],
]

const PAPERS := [Vector2(85, 1012), Vector2(925, 822), Vector2(175, 632), Vector2(835, 372)]
# Awal tiap tingkat (juga titik masuk saat kembali dari Mbok Luna).
const TIER_STARTS := [Vector2(930, 1080), Vector2(130, 880), Vector2(900, 690), Vector2(130, 500)]
# Checkpoint berurutan sesuai progres (lentera awal tingkat, lentera tengah tingkat, lokasi pecahan).
# Checkpoint hanya maju, tidak pernah mundur walau Kirana jatuh ke tingkat bawah.
const CHECKPOINTS := [
	Vector2(930, 1080), Vector2(295, 1035), Vector2(90, 1040),
	Vector2(130, 880), Vector2(750, 860), Vector2(925, 850),
	Vector2(900, 690), Vector2(400, 690), Vector2(175, 660),
	Vector2(130, 500), Vector2(640, 420), Vector2(835, 400),
]
const PAPER_CHECKPOINT := [2, 5, 8, 11]   # indeks checkpoint milik tiap pecahan
const LANTERNS := [Vector2(930, 1080), Vector2(295, 1035), Vector2(130, 880), Vector2(750, 860),
	Vector2(900, 690), Vector2(400, 690), Vector2(130, 500), Vector2(640, 420)]
const DEEP_FALL := 140.0       # jatuh lebih dari ini di bawah checkpoint = ditarik kembali
const DMG_RECALL := 5          # tahan R: kembali ke checkpoint
const RECALL_HOLD := 0.7
# [posisi, ukuran, patroli, kecepatan]
const TRAUMAS := [
	[Vector2(555, 1065), Vector2(30, 24), Vector2.ZERO, 0.0],
	[Vector2(652, 845), Vector2(24, 24), Vector2(0, -60), 0.25],
	[Vector2(430, 655), Vector2(26, 22), Vector2(-90, 0), 0.22],
	[Vector2(400, 420), Vector2(26, 22), Vector2(140, 0), 0.22],
	[Vector2(770, 400), Vector2(24, 22), Vector2.ZERO, 0.0],
]
# Bekal Mbok Luna: melayang tinggi di atas pulau (bonus pemain jago; kaki berat sulit meraihnya).
const FOODS := [
	Vector2(720, 1013), Vector2(410, 983),
	Vector2(300, 818), Vector2(750, 798),
	Vector2(715, 628), Vector2(290, 608),
	Vector2(310, 438), Vector2(640, 358),
]
# Pijakan bantuan Bayangan per tingkat (muncul setelah ASSIST_AFTER kali gagal).
const ASSISTS := [
	[Vector2(640, 1088), Vector2(352, 1062)],
	[Vector2(355, 896), Vector2(680, 880)],
	[Vector2(790, 706), Vector2(345, 700)],
	[Vector2(582, 452), Vector2(722, 432)],
]
# Gerbang gema K1-K7 (percakapan dunia lain). wall = kaki dinding, trigger = area pemicu (dunia).
const ECHO_GATES := [
	{"id": "K1", "wall": Vector2(720, 1075), "h": 110.0, "trigger": Rect2(736, 1035, 22, 40)},
	{"id": "K2", "wall": Vector2(150, 1040), "h": 70.0, "trigger": Rect2(166, 1005, 36, 35)},
	{"id": "K3", "wall": Vector2(760, 860), "h": 110.0, "trigger": Rect2(686, 820, 50, 40)},
	{"id": "K4", "wall": Vector2(905, 850), "h": 70.0, "trigger": Rect2(878, 815, 18, 35)},
	{"id": "K5", "wall": Vector2(840, 690), "h": 110.0, "trigger": Rect2(852, 650, 40, 40)},
	{"id": "K6", "wall": Vector2(380, 690), "h": 110.0, "trigger": Rect2(400, 650, 36, 40)},
	{"id": "K7", "wall": Vector2(325, 500), "h": 110.0, "trigger": Rect2(276, 460, 30, 40)},
]
# Energi saat menjawab gerbang gema: hanya Jujur yang membuka gerbang.
const ECHO_ENERGY := {"jujur": 10, "pendam": -5, "sindir": -10, "ledak": -15}
const FINAL_PORTAL := Vector2(640, 285)
# Pemicu finale hanya tepat di depan portal (bukan seluruh puncak).
const FINALE_ZONE := Rect2(735, 235, 50, 50)
# Panggung finale: Kirana berhenti di sini, bayangan Adik berdiri di antara Kirana dan portal.
const FINALE_KIRANA_X := 760.0
const FINALE_SHADOW_X := 690.0

static func tier_of(y: float) -> int:
	if y > 960.0:
		return 0
	if y > 760.0:
		return 1
	if y > 560.0:
		return 2
	return 3
