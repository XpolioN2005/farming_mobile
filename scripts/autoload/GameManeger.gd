extends Node

var plot_node: Node
var plots: Array[Vector2] = []
var ready_plots: = []

var worker_number: int = 5

func add_worker(num: int) -> void:
	worker_number += num
	SignalBus.emit_signal("worker_num_changed", worker_number)

func subtract_worker(num: int) -> void:
	worker_number = max(0, worker_number - num)
	SignalBus.emit_signal("worker_num_changed", worker_number)
