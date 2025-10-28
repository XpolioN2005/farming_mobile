extends CharacterBody2D
class_name BaseWorker

"""
BaseWorker

A simple autonomous worker NPC with states: IDLE, WANDER, GO_TO_WORK, WORKING, GOSSIP, DRAGGING.

- Emits signals through a project-wide SignalBus:
  "worker_state_changed", "worker_arrived", "worker_work_started",
  "worker_work_finished", "worker_gossip_started", "worker_gossip_finished",
  "worker_drag_started", "worker_drag_stopped"
- Add this node to the "worker" group (done in _ready).
"""

enum State { IDLE, WANDER, GO_TO_WORK, WORKING, GOSSIP, DRAGGING }

# Tunables (exported)
@export_range(0.0, 2000.0, 1.0) var speed: float = 120.0
@export_range(0.0, 2000.0, 1.0) var wander_radius: float = 240.0
@export_range(0.0, 10.0, 0.1) var wander_retarget_time: float = 2.0
@export_range(0.0, 64.0, 0.5) var arrive_threshold: float = 16.0
@export var idle_time_range: Vector2 = Vector2(1.0, 3.0)

@export_range(0.0, 120.0, 0.1) var work_duration: float = 5.0
@export_range(0.0, 120.0, 0.1) var gossip_duration: float = 3.0
@export_range(0.0, 2000.0, 1.0) var gossip_radius: float = 200.0
@export_range(0.0, 1.0, 0.01) var gossip_chance: float = 0.25
@export_range(0.1, 10.0, 0.1) var gossip_check_interval: float = 2.0
@export_range(0.0, 60.0, 0.1) var gossip_cooldown: float = 6.0

# Backing state + property (Godot 4 style)
var _state_internal: State = State.IDLE
var state: State:
	get:
		return _state_internal
	set(value):
		if value == _state_internal:
			return
		var old_state = _state_internal
		_state_internal = value
		SignalBus.emit_signal("worker_state_changed", self, old_state, value)

var prev_state: State = State.IDLE

# Timers / targets
var idle_timer: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var origin: Vector2 = Vector2.ZERO

var work_position: Vector2 = Vector2.ZERO
var work_timer: float = 0.0

# Gossip state
var gossip_target: BaseWorker = null
var gossip_timer: float = 0.0
var is_gossiping: bool = false
var can_gossip: bool = true
var _gossip_check_timer: float = 0.0
var _gossip_cooldown_timer: float = 0.0

# Drag
var drag_offset: Vector2 = Vector2.ZERO

# Nodes
@onready var _sprite_node: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("worker")
	velocity = Vector2.ZERO
	origin = global_position

	if _sprite_node and _sprite_node.material and _sprite_node.material is ShaderMaterial:
		_sprite_node.material = _sprite_node.material.duplicate()
		_sprite_node.material.set_shader_parameter("outline_enabled", false)

	state = State.IDLE
	_enter_idle()
	_gossip_check_timer = gossip_check_interval

func _physics_process(delta: float) -> void:
	_gossip_check_timer -= delta
	if _gossip_check_timer <= 0.0:
		_gossip_check_timer = gossip_check_interval
		_try_autogossip()

	if not can_gossip:
		_gossip_cooldown_timer -= delta
		if _gossip_cooldown_timer <= 0.0:
			can_gossip = true
			_gossip_cooldown_timer = 0.0

	match state:
		State.DRAGGING:
			_state_dragging()
		State.IDLE:
			_state_idle(delta)
		State.WANDER:
			_state_wander(delta)
		State.GO_TO_WORK:
			_state_go_to_work(delta)
		State.WORKING:
			_state_working(delta)
		State.GOSSIP:
			_state_gossip(delta)

	_update_facing()

	if state not in [State.DRAGGING, State.IDLE, State.WORKING]:
		if velocity != Vector2.ZERO:
			if velocity.length() > speed:
				velocity = velocity.normalized() * speed
			move_and_slide()

# State implementations
func _state_dragging() -> void:
	global_position = get_global_mouse_position() - drag_offset
	velocity = Vector2.ZERO

func _state_idle(delta: float) -> void:
	idle_timer -= delta
	velocity = Vector2.ZERO
	if idle_timer <= 0.0:
		state = State.WANDER
		_pick_new_wander_target()

func _state_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0 or global_position.distance_to(wander_target) < arrive_threshold:
		_enter_idle()
		return
	velocity = (wander_target - global_position).normalized() * speed

func _state_go_to_work(_delta: float) -> void:
	var to = work_position - global_position
	if to.length() <= arrive_threshold:
		_enter_working()
		SignalBus.emit_signal("worker_arrived", self, work_position)
		return
	velocity = to.normalized() * speed

func _state_working(delta: float) -> void:
	work_timer -= delta
	velocity = Vector2.ZERO
	if work_timer <= 0.0:
		_enter_idle()
		SignalBus.emit_signal("worker_work_finished", self)

func _state_gossip(delta: float) -> void:
	if not is_instance_valid(gossip_target):
		_finish_gossip()
		return
	var to = gossip_target.global_position - global_position
	if to.length() > arrive_threshold:
		velocity = to.normalized() * speed
	else:
		gossip_timer -= delta
		velocity = Vector2.ZERO
		if gossip_timer <= 0.0:
			_finish_gossip()

# Transitions / helpers
func _enter_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	velocity = Vector2.ZERO

func _pick_new_wander_target() -> void:
	wander_timer = wander_retarget_time
	var angle = randf() * TAU
	var r = randf() * wander_radius
	wander_target = origin + Vector2(cos(angle), sin(angle)) * r

func start_work_at(pos: Vector2, duration: float = -1.0) -> void:
	work_position = pos
	state = State.GO_TO_WORK
	work_timer = duration if duration > 0.0 else work_duration

func _enter_working() -> void:
	state = State.WORKING
	if work_timer <= 0.0:
		work_timer = work_duration
	SignalBus.emit_signal("worker_work_started", self, work_timer)

# Gossip
func start_gossip_with(target: BaseWorker, duration: float = -1.0) -> bool:
	if not _can_start_gossip(target):
		return false
	_begin_gossip(target, duration)
	target._begin_gossip(self, duration)
	SignalBus.emit_signal("worker_gossip_started", self, target)
	return true

func _can_start_gossip(target: BaseWorker) -> bool:
	if state == State.DRAGGING or is_gossiping or not can_gossip:
		return false
	if not is_instance_valid(target):
		return false
	if target.state == State.DRAGGING or target.is_gossiping or not target.can_gossip:
		return false
	return true

func _begin_gossip(target: BaseWorker, duration: float = -1.0) -> void:
	gossip_target = target
	state = State.GOSSIP
	is_gossiping = true
	gossip_timer = duration if duration > 0.0 else gossip_duration

func _finish_gossip() -> void:
	var prev_target = gossip_target
	is_gossiping = false
	SignalBus.emit_signal("worker_gossip_finished", self, prev_target)
	gossip_target = null
	_enter_idle()
	can_gossip = false
	_gossip_cooldown_timer = gossip_cooldown

func _try_autogossip() -> void:
	if state in [State.DRAGGING, State.WORKING, State.GOSSIP]:
		return
	if not can_gossip or is_gossiping:
		return
	if randf() >= gossip_chance:
		return
	var workers = get_tree().get_nodes_in_group("worker")
	var candidates: Array = []
	for w in workers:
		if w == self: continue
		if not is_instance_valid(w): continue
		if global_position.distance_to(w.global_position) <= gossip_radius:
			candidates.append(w)
	if candidates.size() == 0:
		return
	var idx = randi() % candidates.size()
	start_gossip_with(candidates[idx])

func _update_facing() -> void:
	if _sprite_node:
		_sprite_node.flip_h = velocity.x < 0.0

# Drag handlers
func _on_button_button_down() -> void:
	z_index = 1
	scale *= 1.2
	prev_state = state

	# stop gossip on both sides if involved
	if is_gossiping and is_instance_valid(gossip_target):
		gossip_target._finish_gossip()
	# stop any other worker currently gossiping with us
	var workers = get_tree().get_nodes_in_group("worker")
	for w in workers:
		if w == self: continue
		if is_instance_valid(w) and is_instance_valid(w.gossip_target) and w.gossip_target == self:
			w._finish_gossip()

	state = State.DRAGGING
	drag_offset = get_global_mouse_position() - global_position
	can_gossip = false
	is_gossiping = false
	gossip_target = null
	SignalBus.emit_signal("worker_drag_started", self)
	velocity = Vector2.ZERO

	var mat = _sprite_node.material
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("outline_enabled", true)

func _on_button_button_up() -> void:
	z_index = 0
	scale = Vector2(1.0,1.0)
	state = prev_state if prev_state != State.DRAGGING else State.IDLE
	prev_state = state
	SignalBus.emit_signal("worker_drag_stopped", self)

	var mat = _sprite_node.material
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("outline_enabled", false)

# Public API
func api_set_state(new_state: State) -> void:
	state = new_state

func api_start_work_at(pos: Vector2, duration: float = -1.0) -> void:
	start_work_at(pos, duration)

func api_force_gossip(target: BaseWorker) -> void:
	start_gossip_with(target, gossip_duration)

func api_force_idle() -> void:
	_enter_idle()

func api_stop_all() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	is_gossiping = false
	gossip_target = null
	can_gossip = true
	_gossip_check_timer = gossip_check_interval
	_gossip_cooldown_timer = 0.0
