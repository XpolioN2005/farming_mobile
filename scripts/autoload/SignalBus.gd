extends Node

@warning_ignore_start("unused_signal")

signal worker_state_changed(worker, old_state, new_state)
signal worker_arrived(worker, position)

# Harvest / store
signal worker_harvest_started(worker, duration)
signal worker_harvest_finished(worker)
signal worker_harvest_picked(worker, item)
signal worker_store_started(worker, duration)
signal worker_store_finished(worker)
signal worker_store_delivered(worker)

# Inventory
signal worker_inventory_changed(worker, inventory)
signal worker_inventory_full(worker, item)

# Delivery
signal worker_delivered_item(worker, item, target)

# Gossip / drag
signal worker_gossip_started(worker, target_worker)
signal worker_gossip_finished(worker, target_worker)
signal worker_drag_started(worker)
signal worker_drag_stopped(worker)

signal worker_num_chnaged(num)
