
extends Camera2D

class_name TouchCamera

@export var zoom_speed: float = 0.1
@export var pan_speed: float = 1.0
@export var rotation_speed: float = 1.0

@export var can_pan: bool
@export var can_zoom: bool

var touch_points: Dictionary = {}
var start_distance
var start_zoom

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMouseButton:
		handle_mouse_scroll(event)

		
func handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touch_points[event.index] = event.position
	else:
		touch_points.erase(event.index)
	
	if touch_points.size() == 2:
		var touch_point_positions = touch_points.values()
		start_distance = touch_point_positions[0].distance_to(touch_point_positions[1])
		start_zoom = zoom
	elif touch_points.size() < 2:
		start_distance = 0
		
func handle_drag(event: InputEventScreenDrag) -> void:
	touch_points[event.index] = event.position
	
	if touch_points.size() == 1:
		if can_pan:
			offset -= event.relative.rotated(rotation) * pan_speed /zoom.x
			
	elif touch_points.size() == 2:
		var touch_point_positions = touch_points.values()
		var current_dist = touch_point_positions[0].distance_to(touch_point_positions[1])
		var zoom_factor = start_distance / current_dist
		
		if can_zoom:
			zoom = start_zoom / zoom_factor
		limit_zoom(zoom)
	
func handle_mouse_scroll(event: InputEventMouseButton) -> void:
	if not can_zoom:
		return

	var factor
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		factor = 1.0 - zoom_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		factor = 1.0 + zoom_speed
	else:
		return

	zoom *= factor
	limit_zoom(zoom)


func limit_zoom(new_zoom) -> void:
	if new_zoom.x < 1:
		zoom.x = 1
	if new_zoom.y < 1:
		zoom.y = 1
	if new_zoom.x > 10:
		zoom.x = 10
	if new_zoom.y > 10:
		zoom.y = 10
	