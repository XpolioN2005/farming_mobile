extends CharacterBody2D
class_name BaseWorker

enum State { IDLE, WANDER, GO_TO_WORK, WORKING, GOSSIP, DRAGGING }

# --- CONFIG ---
# movement
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

# --- STATE ---
var state: State = State.IDLE
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

# --- PHYSICS PROCESS ---
func _physics_process(delta: float) -> void:
	# gossip timers
	_gossip_check_timer -= delta
	if _gossip_check_timer <= 0.0:
		_gossip_check_timer = gossip_check_interval
		_try_autogossip()

	if not can_gossip:
		_gossip_cooldown_timer -= delta
		if _gossip_cooldown_timer <= 0.0:
			can_gossip = true
			_gossip_cooldown_timer = 0.0

	# state update
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

# --- STATES ---
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
		return
	velocity = to.normalized() * speed

func _state_working(delta: float) -> void:
	work_timer -= delta
	velocity = Vector2.ZERO
	if work_timer <= 0.0:
		_enter_idle()

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
	work_timer = work_timer if work_timer > 0.0 else work_duration

# start gossip if both self and target can gossip and not dragging
func start_gossip_with(target: BaseWorker, duration: float = -1.0) -> bool:
	print("try")
	if not _can_start_gossip(target):
		return false

	# start gossip for both workers safely
	_begin_gossip(target, duration)
	target._begin_gossip(self, duration)
	return true

func _can_start_gossip(target: BaseWorker) -> bool:
	# both self and target must be able to gossip
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
	work_timer = duration if duration > 0.0 else gossip_duration


func _finish_gossip() -> void:
	is_gossiping = false
	gossip_target = null
	_enter_idle()
	can_gossip = false
	_gossip_cooldown_timer = gossip_cooldown

# automatic gossip check
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
		if w == self:
			continue
		if not is_instance_valid(w):
			continue
		if global_position.distance_to(w.global_position) <= gossip_radius:
			candidates.append(w)
	if candidates.size() == 0:
		return
	var idx = randi() % candidates.size()
	start_gossip_with(candidates[idx])

# update sprite facing by x velocity only
func _update_facing() -> void:
	if _sprite_node:
		_sprite_node.flip_h = velocity.x < 0.0

# --- DRAG ---
func _on_button_button_down() -> void:
	prev_state = state
	state = State.DRAGGING
	drag_offset = get_global_mouse_position() - global_position
	can_gossip = false

func _on_button_button_up() -> void:
	state = prev_state if prev_state != State.DRAGGING else State.IDLE
	prev_state = state
	# gossip cooldown governs re-enable
