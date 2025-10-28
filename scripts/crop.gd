extends Node2D

class_name Crop

enum CropState { BAG, HARVESTED, SEEDED, GROWTH1, HARVESTABLE }

# CONFIG
@export var cols: int = 11
@export var rows: int = 3
@export var cell_size: Vector2i = Vector2i(16, 32)
@export var test_interval_seconds: float = 5.0
@export var auto_cycle: bool = false

@onready var sprite: Sprite2D = $sprite

# INTERNALS
var state: int = CropState.BAG
var _timer: Timer
var crop_type: int = 0 # 0 to 5

var sprite_per_crop: Array = [
	[0, 1, 2, 3, 4],      # turnip
	[6, 7, 8, 9, 10],     # onion
	[11, 12, 13, 14, 15], # potato
	[17, 18, 19, 20, 21], # carrot
	[22, 23, 24, 25, 26], # radish
	[28, 29, 30, 31, 32]  # spinach
]


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = test_interval_seconds
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_update_sprite()

	if auto_cycle:
		_timer.start()


func _on_timer_timeout() -> void:
	if state < CropState.HARVESTABLE:
		_next_state()
	else:
		_timer.stop() # stop once fully grown


func _next_state() -> void:
	# advance state only within growable range
	if state == CropState.BAG:
		state = CropState.SEEDED
	elif state == CropState.SEEDED:
		state = CropState.GROWTH1
	elif state == CropState.GROWTH1:
		state = CropState.HARVESTABLE
	else:
		return

	_update_sprite()
	print("State:", CropState.keys()[state])


func _update_sprite() -> void:
	var frames = sprite_per_crop[crop_type]
	var frame_index = frames[min(state, frames.size() - 1)]
	var col = frame_index % cols
	var row = frame_index / cols
	sprite.region_rect = Rect2(col * cell_size.x, row * cell_size.y, cell_size.x, cell_size.y)


# --- PUBLIC API ---

func harvest() -> void:
	"""
	Force the crop into the HARVESTED state.
	Use this when the player harvests it.
	"""
	state = CropState.HARVESTED
	_update_sprite()
	print("Crop harvested!")
