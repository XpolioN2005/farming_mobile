extends CharacterBody2D
class_name BaseWorker

enum State { IDLE, WANDER, GO_TO_WORK, WORKING, GOSSIP, DRAGGING }

# --- CONFIG ---
var speed: float = 120.0
var wander_radius: float = 240.0
var wander_retarget_time: float = 2.0
var arrive_threshold: float = 16.0
var idle_time_range: Vector2 = Vector2(1.0, 3.0)

# work / gossip
var work_duration: float = 5.0
var gossip_duration: float = 3.0
var gossip_radius: float = 200.0
var gossip_chance: float = 0.25
var gossip_check_interval: float = 2.0
var gossip_cooldown: float = 6.0

# --- STATE (safe setget backing) ---
var _state_internal: State = State.IDLE
var state: State setget _set_state, _get_state

func _get_state() -> State:
	return _state_internal

func _set_state(new_state: State) -> void:
	if new_state == _state_internal:
		return
	var old_state = _state_internal
	_state_internal = new_state
	# emit through SignalBus with self as reference
	SignalBus.emit_signal("worker_state_changed", self, old_state, new_state)

var prev_state: State = State.IDLE

# --- TIMERS / TARGETS ---
var idle_timer: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var origin: Vector2 = Vector2.ZERO
var work_position: Vector2 = Vector2.ZERO
var work_timer: float = 0.0
var gossip_target: BaseWorker = null
var drag_offset: Vector2 = Vector2.ZERO

# gossip flags / timers
var is_gossiping: bool = false
var can_gossip: bool = true
var _gossip_check_timer: float = 0.0
var _gossip_cooldown_timer: float = 0.0

# --- NODES ---
@onready var _sprite_node: AnimatedSprite2D = $AnimatedSprite2D

# --- READY ---
func _ready() -> void:
	add_to_group("worker")
	velocity = Vector2.ZERO
	origin = global_position
	_enter_idle()

# --- PHYSICS ---
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
		State.DRAGGING: _state_dragging()
		State.IDLE: _state_idle(delta)
		State.WANDER: _state_wander(delta)
		State.GO_TO_WORK: _state_go_to_work(delta)
		State.WORKING: _state_working(delta)
		State.GOSSIP: _state_gossip(delta)

	_update_facing()

	if state not in [State.DRAGGING, State.IDLE, State.WORKING] and velocity != Vector2.ZERO:
		velocity = velocity.limit_length(speed)
		move_and_slide()

# --- STATE LOGIC ---
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
		work_timer -= delta
		velocity = Vector2.ZERO
		if work_timer <= 0.0:
			_finish_gossip()

# --- HELPERS ---
func _enter_idle() -> void:
	_set_state_internal(State.IDLE)
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	velocity = Vector2.ZERO

# internal helper to avoid going through public setter (prevents double-emits)
func _set_state_internal(new_state: State) -> void:
	if new_state == _state_internal:
		return
	var old_state = _state_internal
	_state_internal = new_state
	SignalBus.emit_signal("worker_state_changed", self, old_state, new_state)

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
	_set_state_internal(State.WORKING)
	if work_timer <= 0.0:
		work_timer = work_duration
	SignalBus.emit_signal("worker_work_started", self, work_timer)

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
	_set_state_internal(State.GOSSIP)
	is_gossiping = true
	work_timer = duration if duration > 0.0 else gossip_duration

func _finish_gossip() -> void:
	# keep local reference so we can emit who we were gossiping with
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
	var candidates := []
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

# --- DRAG ---
func _on_button_button_down() -> void:
	prev_state = state
	state = State.DRAGGING
	drag_offset = get_global_mouse_position() - global_position
	can_gossip = false
	SignalBus.emit_signal("worker_drag_started", self)

func _on_button_button_up() -> void:
	state = prev_state if prev_state != State.DRAGGING else State.IDLE
	prev_state = state
	SignalBus.emit_signal("worker_drag_stopped", self)

# --- PUBLIC APIS for manager ---
func api_set_state(new_state: State) -> void:
	state = new_state

func api_start_work_at(pos: Vector2, duration: float = -1.0) -> void:
	start_work_at(pos, duration)

func api_force_gossip(target: BaseWorker) -> void:
	start_gossip_with(target, gossip_duration)

func api_force_idle() -> void:
	_enter_idle()

func api_stop_all() -> void:
	_set_state_internal(State.IDLE)
	velocity = Vector2.ZERO
	is_gossiping = false
	gossip_target = null
