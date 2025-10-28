extends Node

@export var worker_scene: PackedScene
@export var crop_scene: PackedScene

var workers: Array[BaseWorker] = []
var last_work: Dictionary = {}
var worker_busy: Dictionary = {}

func _ready() -> void:
	SignalBus.connect("worker_harvest_finished", Callable(self, "_on_worker_harvest_finished"))
	SignalBus.connect("worker_store_finished", Callable(self, "_on_worker_store_finished"))
	_spawn_workers()

func _spawn_workers() -> void:
	if worker_scene == null:
		push_error("WorkerManager: worker_scene not assigned.")
		return
	for i in range(GameManeger.worker_number):
		var worker: BaseWorker = worker_scene.instantiate()
		add_child(worker)
		workers.append(worker)
		worker_busy[worker.get_instance_id()] = false
	print("WorkerManager: spawned %d workers" % workers.size())

func _process(_delta: float) -> void:
	for worker in workers:
		if not is_instance_valid(worker):
			continue
		if worker_busy.get(worker.get_instance_id(), false):
			continue
		if not worker.can_work():
			continue

		if not GameManeger.ready_plots.is_empty():
			print("WorkerManager: _process -> assigning get_crop_for to", worker.name)
			get_crop_for(worker)
		elif not GameManeger.plots.is_empty():
			print("WorkerManager: _process -> assigning place_seed_for to", worker.name)
			place_seed_for(worker)

# --- Work assignment ---

func place_seed_for(worker: BaseWorker, kind: int = 0) -> void:
	if worker == null or GameManeger.plots.is_empty():
		return

	var id = worker.get_instance_id()
	var plot_index = randi() % GameManeger.plots.size()
	var pos = GameManeger.plots[plot_index]
	GameManeger.plots.remove_at(plot_index)

	worker_busy[id] = true
	print("WorkerManager: place_seed_for -> worker %s (id=%d) assigned plot %s" % [str(worker.name), id, str(pos)])
	worker.start_harvest_at(pos)

	var crop = crop_scene.instantiate()
	crop.crop_type = kind
	worker.give_item(crop)
	worker.get_node("inv").add_child(crop)

	last_work[id] = {
		"state": "placed_seed",
		"plot": pos
	}

func get_crop_for(worker: BaseWorker) -> void:
	if worker == null or GameManeger.ready_plots.is_empty():
		return

	var id = worker.get_instance_id()
	var plot_index = randi() % GameManeger.ready_plots.size()
	var crop = GameManeger.ready_plots[plot_index]
	GameManeger.ready_plots.remove_at(plot_index)

	var pos = crop.global_position

	worker_busy[id] = true
	print("WorkerManager: get_crop_for -> worker %s (id=%d) assigned crop at %s" % [str(worker.name), id, str(pos)])
	worker.start_harvest_at(pos)

	last_work[id] = {
		"state": "got_crop",
		"plot": pos,
		"crop": crop
	}

func store(worker: BaseWorker) -> void:
	if worker == null:
		return
	var id = worker.get_instance_id()
	worker_busy[id] = true
	print("WorkerManager: store -> worker %s (id=%d) started storing" % [str(worker.name), id])
	worker.start_store_at(Vector2i.ZERO)
	last_work[id] = {"state": "stored"}

# --- Signals ---

func _on_worker_harvest_finished(worker: BaseWorker, pos) -> void:
	if worker == null:
		return

	var id = worker.get_instance_id()
	if not last_work.has(id):
		print("WorkerManager: _on_worker_harvest_finished -> no last_work for worker", worker.name, id)
		worker_busy[id] = false
		return

	var info = last_work[id]
	match info.get("state", ""):
		"placed_seed":
			var crop = worker.take_first_item()
			if is_instance_valid(crop):
				crop.reparent(GameManeger.plot_node)
				crop.global_position = pos
				crop._next_state()
				crop._timer.start()
				print("WorkerManager: placed seed node reparented to plot_node for worker %s (id=%d)" % [str(worker.name), id])
			worker_busy[id] = false
			last_work.erase(id)

		"got_crop":
			var crop = info.get("crop")
			if is_instance_valid(crop):
				crop.harvest()
				crop.reparent(worker.get_node("inv"))
				crop.global_position = worker.get_node("inv").global_position
				worker.give_item(crop)
				print("WorkerManager: got_crop -> worker %s (id=%d) picked up crop" % [str(worker.name), id])
				store(worker)
			else:
				print("WorkerManager: got_crop -> crop not valid for worker", worker.name, id)
				worker_busy[id] = false
				last_work.erase(id)

		_:
			print("WorkerManager: _on_worker_harvest_finished -> unexpected state '%s' for worker %s" % [str(info.get("state", "")), str(worker.name)])
			worker_busy[id] = false
			last_work.erase(id)

func _on_worker_store_finished(worker: BaseWorker, _pos) -> void:
	if worker == null:
		return

	var id = worker.get_instance_id()
	if not last_work.has(id):
		print("WorkerManager: _on_worker_store_finished -> no last_work for worker", worker.name, id)
		worker_busy[id] = false
		return

	var info = last_work[id]
	match info.get("state", ""):
		"stored":
			var crop = worker.take_first_item()
			if is_instance_valid(crop):
				crop.queue_free()
				print("WorkerManager: store_finished -> freed crop from worker %s (id=%d)" % [str(worker.name), id])
			worker_busy[id] = false
			last_work.erase(id)
		_:
			print("WorkerManager: _on_worker_store_finished -> unexpected store state '%s' for worker %s" % [str(info.get("state", "")), str(worker.name)])
			worker_busy[id] = false
