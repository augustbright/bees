extends CharacterBody3D

const NectarSource = preload("res://nectar_source.gd")
const Hive = preload("res://hive.gd")
const FlightSettings = preload('res://fight_settings.gd')

var hive: Hive = null

var current_destination: Vector3:
	set(value):
		current_destination = value
		$FlyDestination.position = value

var current_travel_destination = Vector3.ZERO

var fly_velocity = Vector3.ZERO

var TRAVEL_FLIGHT_SETTINGS = FlightSettings.new(30, 30, 7, 1)
var ACCURATE_FLIGHT_SETTINGS = FlightSettings.new(30, 30, 3, 0.2)
var LANDING_FLIGHT_SETTINGS = FlightSettings.new(30, 30, 3, 0.2)
var SPIN_FLIGHT_SETTINGS = FlightSettings.new(30, 30, 5, 0.2)
var EIGHT_FLIGHT_SETTINGS = FlightSettings.new(30, 100, 5, 0.2)

const TRAVEL_SEGMENT_LENGTH = 3
const TRAVEL_HEIGHT = 1
const TRAVEL_DEVIATION = 1

####	ORIENTATION FLIGHT
var spin_count = 0
const SPIN_REQUIRED = 3
const SPIN_RADIUS = 1

var eight_count = 0
const EIGHT_REQUIRED = 3
const EIGHT_HEIGHT = 2
const EIGHT_RADIUS = 0.5

####	NECTAR EXPLORING
var vision_nectar: Array[NectarSource]
var memory_nectar := {}
var unvisited_nectar := {}
var visited_nectar := {}

var EXPLORE_SEGMENT_LENGTH = 3
var EXPLORE_RADIUS = 100

####	NECTAR GATHERING
var NECTAR_CAPACITY = 3
var nectar = 0:
	set(value):
		nectar = value
		$NectarLabel.text = str(nectar)
		if nectar > 0:
			$NectarLabel.show()
		else:
			$NectarLabel.hide()

var target_nectar_source: NectarSource = null
var is_sitting_on_source = false
const PICK_NECTAR_TIME = 3
var pick_nectar_timeout = 0

var task_queue: Array[Dictionary] = []

func task_orientation_flight(position: Vector3):
	task_queue.clear()
	spin_count = 0
	eight_count = 0
	task_queue.push_back({
		'type': 'orientation',
		'position': position
	})

func task_explore(position: Vector3):
	task_queue.clear()
	task_queue.push_back({
		'type': 'explore',
		'position': position
	})

func task_sit(position: Vector3):
	task_queue.clear()
	task_queue.push_back({
		'type': 'sit',
		'position': position
	})
	
func task_gather_nectar(position: Vector3):
	task_queue.clear()
	task_queue.push_back({
		'type': 'gather_nectar',
		'position': position
	})

# Called when the node enters the scene tree for the first time.
func _ready():
	current_destination = position

func _process(delta):
	var mesh = $DebugMesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if vision_nectar.size() > 0:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for nectar in vision_nectar:
			mesh.surface_add_vertex(global_position)
			mesh.surface_add_vertex(nectar.global_position)
		mesh.surface_end()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if process_task_queue(delta) and process_go_home(delta):
		queue_free()

	velocity = fly_velocity
	move_and_slide()

func process_task_queue(delta):
	if task_queue.size() == 0:
		return true

	var task = task_queue[0]
	match task['type']:
		'orientation':
			if process_orient(delta, task['position']):
				task_queue.pop_front()
		'explore':
			if process_explore(delta, task['position']):
				task_queue.pop_front()
		'sit':
			if process_sit(delta, task['position']):
				task_queue.pop_front()
		'gather_nectar':
			if process_gather_nectar(delta, task['position']):
				task_queue.pop_front()
		_: task_queue.pop_front()
	return false

func process_gather_nectar(delta, origin):
	if nectar >= NECTAR_CAPACITY:
		return true

	return process_orient(delta, origin) and process_explore(delta, origin) and false

func process_go_home(delta):
	return process_land_on_point(delta, hive.position) and enter_hive()

func enter_hive():
	give_nectar_to_hive(hive, self.nectar)
	hive.publish({
		'type': 'memory_nectar',
		'payload': memory_nectar
	})
	hive.receive_bee(self)
	return true

func give_nectar_to_hive(hive: Hive, amount = 1):
	var available = clamp(amount, 0, self.nectar)
	self.nectar -= available
	hive.receive_nectar(available)

func process_sit(delta, origin):
	return process_land_on_point(delta, origin) and false

func process_land_on_point(delta, point: Vector3):
	if is_sitting_on_source: return true

	if process_travel(delta, point):
		if process_fly_to_destination(delta, point, LANDING_FLIGHT_SETTINGS):
			fly_velocity = Vector3.ZERO
			return true	
		
		if fly_velocity.dot(current_destination - position) < 0 or position.distance_to(current_destination) < LANDING_FLIGHT_SETTINGS.threshold:
			var remaining = point - current_destination
			var half_remaining = remaining / 2
			var deviation = Vector3.FORWARD.rotated(Vector3.UP, randf() * PI * 2) * half_remaining.length()		
			
			current_destination = current_destination + half_remaining + deviation

	return false

func process_orient(delta, origin):
	return process_spin(delta, origin) and process_eight(delta, origin)

func process_spin(delta, origin):
	if spin_count >= SPIN_REQUIRED:
		return true
	if process_travel(delta, origin):
		if process_fly_to_destination(delta, current_destination, SPIN_FLIGHT_SETTINGS):
			if origin == current_destination:
				current_destination = origin + Vector3.FORWARD
			current_destination = origin + (current_destination - origin).rotated(Vector3.UP, PI / 4).normalized() * SPIN_RADIUS
			spin_count += 1

	return false

func process_eight(delta, origin):
	if eight_count >= EIGHT_REQUIRED:
		return true

	if process_fly_to_destination(delta, current_destination, EIGHT_FLIGHT_SETTINGS):
		var eight_origin = origin + Vector3.UP * EIGHT_HEIGHT
		if current_destination.y < eight_origin.y:
			if current_destination.x < eight_origin.x:
				current_destination = eight_origin + Vector3(EIGHT_RADIUS, EIGHT_RADIUS, randf_range(-0.3, 0.3))
			else:
				current_destination = eight_origin + Vector3(-EIGHT_RADIUS, -EIGHT_RADIUS, randf_range(-0.3, 0.3))
		else:
			if current_destination.x < eight_origin.x:
				current_destination = eight_origin + Vector3(EIGHT_RADIUS, -EIGHT_RADIUS, randf_range(-0.3, 0.3))
			else:
				current_destination = eight_origin + Vector3(-EIGHT_RADIUS, EIGHT_RADIUS, randf_range(-0.3, 0.3))
				eight_count += 1

func process_explore(delta, origin):
	if process_search_nectar_target(delta, origin):
		if process_land_on_point(delta, target_nectar_source.position):
			if !is_sitting_on_source and target_nectar_source.place <= 0:
				visited_nectar[target_nectar_source.position] = target_nectar_source.amount
				unvisited_nectar.erase(target_nectar_source.position)
				target_nectar_source = null
				return false

			if pick_nectar_timeout <= 0:
				visited_nectar[target_nectar_source.position] = target_nectar_source.amount
				unvisited_nectar.erase(target_nectar_source.position)
				pick_nectar_timeout = PICK_NECTAR_TIME
				target_nectar_source.place -= 1
				is_sitting_on_source = true

			if process_pick_nectar(delta):
				target_nectar_source.place += 1
				target_nectar_source = null
				is_sitting_on_source = false

func process_search_nectar_target(delta, origin):
	if target_nectar_source != null:
		return true

	if process_look_for_unvisited_nectar():
		return true

	if unvisited_nectar.size() >= 0:
		if process_return_to_unvisited_nectar(delta):
			return false
	else:
		return process_search_nectar_sources(delta, origin)

func process_look_for_unvisited_nectar():
	var unvisited = vision_nectar.filter(func (source): return not visited_nectar.has(source.position))
	if unvisited.size() > 0:
		target_nectar_source = unvisited[0]
		return true
	return false

func process_return_to_unvisited_nectar(delta):
	if unvisited_nectar.size() <= 0:
		return false
	
	return process_travel(delta, unvisited_nectar.keys()[0])

func process_search_nectar_sources(delta, origin):
	if process_travel(delta, current_travel_destination):
		choose_next_search_point(origin)

	return false

func choose_next_search_point(origin):
	if origin.distance_to(position) > EXPLORE_RADIUS:
		current_travel_destination = origin
	else:
		current_travel_destination = position + (Vector3.FORWARD * EXPLORE_SEGMENT_LENGTH).rotated(Vector3.UP, randf() * PI * 2)

func process_pick_nectar(delta):
	pick_nectar_timeout -= delta
	if pick_nectar_timeout <= 0:
		self.nectar += target_nectar_source.take(1)
		return true
	return false

func process_travel(delta, final: Vector3):
	if TRAVEL_FLIGHT_SETTINGS.has_reached_2(position, final):
		return	true

	var has_reached = TRAVEL_FLIGHT_SETTINGS.has_reached_2(position, current_destination)
	var left_behind = _has_left_behind_2(final)

	if has_reached or left_behind:
		current_destination = next_travel_destination(final)

	if process_fly_to_destination(delta, current_destination, TRAVEL_FLIGHT_SETTINGS):
		current_destination = next_travel_destination(final)
	
func _has_left_behind_2(final: Vector3):
	var current_destination_2d = Vector2(current_destination.x, current_destination.z)
	var position_2d = Vector2(position.x, position.z)
	var final_2d = Vector2(final.x, final.z)
	
	return position_2d.distance_to(final_2d) <= current_destination_2d.distance_to(final_2d)

func next_travel_destination(final: Vector3):
	var remaining = final - position
	var remaining_distance = remaining.length()
	var next = remaining.normalized() * TRAVEL_SEGMENT_LENGTH
	if next.length() > remaining_distance:
		next = remaining
	
	var deviation = Vector3.FORWARD.rotated(Vector3.UP, randf() * PI * 2) * TRAVEL_DEVIATION	
	
	next = position + next + deviation
	var surface_height = Vector3.UP * _get_height(next)
	var travel_height = Vector3.UP * TRAVEL_HEIGHT
	next.y = 0
	next = next + surface_height + travel_height
	
	return next

func process_fly_to_destination(delta, destination: Vector3, settings: FlightSettings):
	if settings.has_reached_3(position, destination):
		return true

	if destination != position:
		look_at(destination)
	var force = (destination - position).normalized() * settings.acceleration * delta
	fly_velocity += force

	if settings.dump > 0:
		var dot = fly_velocity.dot(destination - position)
		if dot < 0:
			fly_velocity -= fly_velocity.normalized() * settings.dump * delta

	if fly_velocity.length() > settings.max_speed:
		fly_velocity -= fly_velocity.normalized() * settings.dump * delta

	return false

func _get_height(position):
	return 0

func _on_vision_area_entered(area: NectarSource):
	if area.is_in_group("nectar"):
		vision_nectar.append(area)
		memory_nectar[area.position] = area.amount
		if not visited_nectar.has(area.position):
			unvisited_nectar[area.position] = area.amount

func _on_vision_area_exited(area):
	if area.is_in_group("nectar"):
		vision_nectar.erase(area)
