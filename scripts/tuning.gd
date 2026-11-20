class_name Tuning
extends Resource

@export_group("Stability")
@export var stability_initial: int = 60
@export var stability_min: int = 0
@export var stability_max: int = 100
@export var stability_loop_reset: int = 40

@export_group("Effects per Choice Type")
@export var delta_jujur: int = 15
@export var delta_pendam: int = 5
@export var delta_sindir: int = -10
@export var delta_ledak: int = -20

@export_group("Pendam Mechanics")
@export var pendam_bomb_multiplier: int = 12

@export_group("Tier Thresholds")
@export var tier_tenang_min: int = 60
@export var tier_kesel_min: int = 30
@export var tier_hampir_meledak_min: int = 1

@export_group("Timers per Tier")
@export var timer_tenang: float = 0.0
@export var timer_kesel: float = 30.0
@export var timer_hampir_meledak: float = 15.0

@export_group("Visuals per Tier")
@export var opacity_jujur_kesel: float = 0.75
@export var opacity_jujur_hampir_meledak: float = 0.55
@export var tint_kesel_orange_alpha: float = 0.15
@export var tint_hampir_meledak_red_alpha: float = 0.30
@export var rewind_duration: float = 1.5

@export_group("Platforming Physics")
@export var walk_speed: float = 80.0
@export var jump_velocity: float = -230.0
@export var gravity: float = 600.0
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.1
