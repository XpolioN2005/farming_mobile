extends Node2D

@onready var progrss_bar = $CanvasLayer/HBoxContainer/MarginContainer/HSlider
@onready var lable = $CanvasLayer/HBoxContainer/MarginContainer2/Label

func _ready():
	progrss_bar.value = GameManeger.worker_number
func _process(_delta):
	lable.text = str(progrss_bar.value)

func _on_button_pressed() -> void:
	GameManeger.worker_number = progrss_bar.value
	get_tree().reload_current_scene()