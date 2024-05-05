extends CharacterBody3D

const NectarSource = preload("res://nectar_source.gd")
const Hive = preload("res://hive.gd")
const FlightSettings = preload('res://fight_settings.gd')

var hive: Hive = null
var anchor: Vector3:
	set(position):
		anchor = position
		$Anchor.position = anchor
		arrived_to_anchor = false
		#hung = false
		#nectar_landed = false
		target_nectar_source = null
		spin_count = 0

####	TRAVELING FLIGHT
var arrived_to_anchor = false
#var hung = false

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
const SPIN_REQUIRED = 10
const SPIN_RADIUS = 1

var eight_count = 0
const EIGHT_REQUIRED = 10
const EIGHT_HEIGHT = 2
const EIGHT_RADIUS = 0.5

enum AnchorMode { HANG, ORIENT, EXPLORE }
var anchor_mode: AnchorMode:
	set(mode):
		anchor_mode = mode
		match anchor_mode:
			AnchorMode.HANG:
				#hung = false
				$Anchor/Label.text = 'Hang'
			AnchorMode.EXPLORE:
				$Anchor/Label.text = 'Explore'
			AnchorMode.ORIENT:
				spin_count = 0
				eight_count = 0
				$Anchor/Label.text = 'Orient'

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
#var nectar_landed = false
const PICK_NECTAR_TIME = 3
var pick_nectar_timeout = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	anchor_mode = AnchorMode.HANG
	anchor = position
	current_destination = position

func _process(delta):
	var mesh = $Vision/DebugMesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if vision_nectar.size() > 0:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for nectar in vision_nectar:
			mesh.surface_add_vertex(position)
			mesh.surface_add_vertex(nectar.position)
		mesh.surface_end()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if has_to_go_home():
		process_go_home(delta)
	elif has_to_process_anchor():
		process_anchor(delta)
	elif has_to_go_to_anchor():
		if process_travel(delta, anchor):
			arrived_to_anchor = true

	velocity = fly_velocity
	move_and_slide()

func has_to_go_home():
	return hive != null and nectar >= NECTAR_CAPACITY
	
func has_to_process_anchor():
	return arrived_to_anchor

func has_to_go_to_anchor():
	return not arrived_to_anchor

func process_go_home(delta):
	if process_travel(delta, hive.position):
		if process_land_on_point(delta, hive.position):
			if enter_hive():
				queue_free()

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
	
func process_anchor(delta):
	match anchor_mode:
		AnchorMode.HANG:
			if process_land_on_point(delta, anchor):
				return false
		AnchorMode.ORIENT:
			if process_orient(delta, anchor):
				anchor_mode = AnchorMode.HANG
		AnchorMode.EXPLORE:
			if process_explore(delta):
				anchor_mode = AnchorMode.HANG

func process_land_on_point(delta, point: Vector3):
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

func process_explore(delta):
	if process_search_nectar_target(delta):
		if process_land_on_point(delta, target_nectar_source.position):
			visited_nectar[target_nectar_source.position] = target_nectar_source.amount
			unvisited_nectar.erase(target_nectar_source.position)
			pick_nectar_timeout = PICK_NECTAR_TIME
			if process_gather_nectar(delta):
				target_nectar_source = null

func process_search_nectar_target(delta):
	if target_nectar_source != null:
		return true

	if process_look_for_unvisited_nectar():
		return true

	if process_return_to_unvisited_nectar(delta):
		return false

	return process_search_nectar_sources(delta)

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

func process_search_nectar_sources(delta):
	if process_travel(delta, current_travel_destination):
		choose_next_search_point()

	return false

func choose_next_search_point():
	if anchor.distance_to(position) > EXPLORE_RADIUS:
		current_travel_destination = anchor
	else:
		current_travel_destination = position + (Vector3.FORWARD * EXPLORE_SEGMENT_LENGTH).rotated(Vector3.UP, randf() * PI * 2)	

func process_gather_nectar(delta):
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
