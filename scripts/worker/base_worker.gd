extends CharacterBody2D

var is_dragging : bool = false
var of : Vector2 = Vector2.ZERO

func _process(_delta):
	if is_dragging:
		position = get_global_mouse_position()- of

func _on_button_button_up() -> void:
	is_dragging = false


func _on_button_button_down() -> void:
	is_dragging = true
	of = get_global_mouse_position()-global_position
