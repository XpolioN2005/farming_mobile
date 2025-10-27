extends Camera2D
class_name TouchCamera

# --- CONFIGURATION ---

@export var can_pan: bool = true
@export var can_zoom: bool = true

@export var pan_speed: float = 1.0
@export var zoom_speed: float = 0.1

@export var min_zoom: float = 1.0
@export var max_zoom: float = 10.0

@export var pan_smooth: float = 0.15
@export var zoom_smooth: float = 0.1

# Enable built-in camera limits
@export var use_limits: bool = true

# --- INTERNAL STATE ---
var touch_points: Dictionary = {}
var start_distance: float
var start_zoom: Vector2
var target_zoom: Vector2
var target_position: Vector2


func _ready() -> void:
	target_zoom = zoom
	target_position = position


func _process(_delta: float) -> void:
	zoom = lerp(zoom, target_zoom, zoom_smooth)
	position = lerp(position, target_position, pan_smooth)

	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMouseButton:
		handle_mouse_scroll(event)


# --- TOUCH HANDLING ---

func handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touch_points[event.index] = event.position
	else:
		touch_points.erase(event.index)

	if touch_points.size() == 2:
		var pts = touch_points.values()
		start_distance = pts[0].distance_to(pts[1])
		start_zoom = zoom


func handle_drag(event: InputEventScreenDrag) -> void:
	touch_points[event.index] = event.position

	if touch_points.size() == 1 and can_pan:
		target_position -= event.relative.rotated(rotation) * pan_speed / zoom.x
	elif touch_points.size() == 2 and can_zoom:
		var pts = touch_points.values()
		var current_dist = pts[0].distance_to(pts[1])
		var zoom_factor = start_distance / current_dist
		target_zoom = start_zoom / zoom_factor
		limit_zoom()


# --- MOUSE HANDLING ---

func handle_mouse_scroll(event: InputEventMouseButton) -> void:
	if not can_zoom:
		return

	var factor := 1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		factor = 1.0 - zoom_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		factor = 1.0 + zoom_speed
	else:
		return

	target_zoom *= factor
	limit_zoom()


# --- LIMITS ---

func limit_zoom() -> void:
	var avg_zoom = (target_zoom.x + target_zoom.y) * 0.5
	avg_zoom = clamp(avg_zoom, min_zoom, max_zoom)
	target_zoom = Vector2(avg_zoom, avg_zoom)

