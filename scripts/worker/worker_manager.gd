extends Node

@export var worker_scene: PackedScene
@export var crop_scene: PackedScene

var workers: Array[BaseWorker] = []

var last_work : Dictionary = {}

func _ready() -> void:
	SignalBus.connect("worker_harvest_finished", Callable(self, "_on_worker_harvest_finished"))
	_spawn_workers()


func _spawn_workers() -> void:
	if worker_scene == null:
		push_error("WorkerManager: worker_scene not assigned.")
		return

	for i in range(GameManeger.worker_number):
		var worker: BaseWorker = worker_scene.instantiate()
		add_child(worker)
		workers.append(worker)


# kind 0 - 5
func place_seed(kind: int) -> void:

	var worker = workers[randi() % workers.size()]
	var plot_index = randi() % GameManeger.plots.size()
	var pos = GameManeger.plots[plot_index]
	
	GameManeger.plots.remove_at(plot_index)

	worker.start_harvest_at(pos)
	 
	var crop = crop_scene.instantiate()
	crop.crop_type = kind

	worker.give_item(crop)
	worker.add_child(crop)
	
	last_work[worker.get_instance_id()] = {
		"state": "placed_seed",
		"plot": pos,
	}


func _on_worker_harvest_finished(worker: Node) -> void:
	if worker == null:
		return

	var id = worker.get_instance_id()
	if not last_work.has(id):
		push_error("WorkerManager: no last_work recorded for worker %s" % str(worker.name))
		return

	var info = last_work[id]
	match info.get("state", ""):
		"placed_seed":
			info["state"] = "waiting_for_harvest"
			last_work[id] = info
		"got_crop":
			info["state"] = "stored"
			last_work[id] = info
		"stored":
			last_work.erase(id)
		_:
			push_error("WorkerManager: unexpected last_work state '%s' for worker %s" % [str(info.get("state", "")), str(worker.name)])
			last_work.erase(id)
