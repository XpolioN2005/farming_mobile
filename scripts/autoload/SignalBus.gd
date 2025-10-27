extends Node

signal worker_state_changed(worker, old_state, new_state)
signal worker_arrived(worker, position)
signal worker_work_started(worker, duration)
signal worker_work_finished(worker)
signal worker_gossip_started(worker, target_worker)
signal worker_gossip_finished(worker, target_worker)
signal worker_drag_started(worker)
signal worker_drag_stopped(worker)