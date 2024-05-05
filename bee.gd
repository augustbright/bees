extends CharacterBody3D

const NectarSource = preload("res://nectar_source.gd")
const Hive = preload("res://hive.gd")

var anchor_position: Vector3

var arrived = true
const arrived_threshold = 1
const TRAVEL_MAX_SPEED = 7
const max_speed = 7
const TRAVEL_HEIGHT = 1

var fly_destination: Vector3
var fly_velocity = Vector3.ZERO
const fly_acceleration = 30
const DEFAULT_DUMP = 30
const destination_threshold = 1
const fly_segment_length = 3
const max_deviation = 1

var hung = false
const hang_threshold = 0.2
const HANG_MAX_SPEED = 3
const HANG_ATTEMPT_TIME = 3

var spin_count = 0
const SPIN_THRESHOLD = 0.2
const SPIN_REQUIRED = 10
const spin_radius = 0.5
const SPIN_MAX_SPEED = 5

var eight_count = 0
const EIGHT_THRESHOLD = 0.2
const EIGHT_REQUIRED = 10
const EIGHT_MAX_SPEED = 5
const EIGHT_DUMP = 100
const EIGHT_HEIGHT = 2
const EIGHT_RADIUS = 0.5

enum AnchorMode {
	HANG, ORIENT, EXPLORE
}
var anchor_mode: AnchorMode

var vision_nectar: Array[NectarSource]
var memory_nectar := {}
var unvisited_nectar := {}
var visited_nectar := {}

var explore_destination = Vector3.ZERO
var EXPLORE_SEGMENT_LENGTH = 3
var EXPLORE_RADIUS = 100

var NECTAR_CAPACITY = 50
var nectar = 0
var nectar_source: NectarSource = null
var nectar_landed = false
const PICK_NECTAR_TIME = 3
var pick_nectar_timeout = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	set_anchor_mode(AnchorMode.HANG)
	set_anchor(position)
	set_fly_destination(position)

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
	if arrived:
		process_anchor(delta)
	else:
		arrived = process_arrive(delta, anchor_position)
	
	velocity = fly_velocity
	move_and_slide()

func process_anchor(delta):
	if anchor_mode == AnchorMode.HANG:		
		process_hang(delta)
	if anchor_mode == AnchorMode.ORIENT:
		process_orient(delta)
	if anchor_mode == AnchorMode.EXPLORE:
		process_explore(delta)

func process_hang(delta):	
	if hung: return
	hung = land_on_point(delta, anchor_position)

func land_on_point(delta, point: Vector3):
	if position.distance_to(point) < hang_threshold:		
		fly_velocity = Vector3.ZERO
		return true
	
	if fly_velocity.dot(fly_destination - position) < 0 or position.distance_to(fly_destination) < hang_threshold:
		var remaining = point - fly_destination
		var half_remaining = remaining / 2
		var deviation = Vector3.FORWARD.rotated(Vector3.UP, randf() * PI * 2) * half_remaining.length()		
		set_fly_destination(fly_destination + half_remaining + deviation)
	
	process_fly_to_destination(delta, HANG_MAX_SPEED)
	return false

func process_orient(delta):
	if spin_count < SPIN_REQUIRED:
		process_spin(delta)
	else:
		process_eight(delta)

func process_spin(delta):
	if position.distance_to(fly_destination) < SPIN_THRESHOLD:
		var new_destination = anchor_position + (fly_destination - anchor_position).rotated(Vector3.UP, PI / 4).normalized() * spin_radius		
		set_fly_destination(new_destination)
		spin_count += 1
	
	process_fly_to_destination(delta, SPIN_MAX_SPEED)

func process_eight(delta):
	if position.distance_to(fly_destination) < EIGHT_THRESHOLD:
		var eight_origin = anchor_position + Vector3.UP * EIGHT_HEIGHT
		if fly_destination.y < eight_origin.y:
			if fly_destination.x < eight_origin.x:
				set_fly_destination(eight_origin + Vector3(EIGHT_RADIUS, EIGHT_RADIUS, randf_range(-0.3, 0.3)))
			else:
				set_fly_destination(eight_origin + Vector3(-EIGHT_RADIUS, -EIGHT_RADIUS, randf_range(-0.3, 0.3)))
		else:
			if fly_destination.x < eight_origin.x:
				set_fly_destination(eight_origin + Vector3(EIGHT_RADIUS, -EIGHT_RADIUS, randf_range(-0.3, 0.3)))
			else:
				set_fly_destination(eight_origin + Vector3(-EIGHT_RADIUS, EIGHT_RADIUS, randf_range(-0.3, 0.3)))

	process_fly_to_destination(delta, EIGHT_MAX_SPEED, EIGHT_DUMP)

func process_explore(delta):
	if nectar_source == null:
		var unvisited = vision_nectar.filter(func (source): return not visited_nectar.has(source.position))
		if unvisited.size() > 0:
			nectar_source = unvisited[0]
		elif unvisited_nectar.size() > 0:
			explore_destination = unvisited_nectar.keys()[0]

		if process_arrive(delta, explore_destination):
			if anchor_position.distance_to(position) > EXPLORE_RADIUS:
				explore_destination = anchor_position
			else:
				explore_destination = position + (Vector3.FORWARD * EXPLORE_SEGMENT_LENGTH).rotated(Vector3.UP, randf() * PI * 2)

	if nectar_source and not nectar_landed:
		nectar_landed = land_on_point(delta, nectar_source.position)
		if nectar_landed:
			visited_nectar[nectar_source.position] = nectar_source.amount
			unvisited_nectar.erase(nectar_source.position)
			pick_nectar_timeout = PICK_NECTAR_TIME

	if nectar_source and nectar_landed:
		process_gather_nectar(delta)

func process_gather_nectar(delta):
	pick_nectar_timeout -= delta
	if pick_nectar_timeout <= 0:
		_add_nectar(nectar_source.take(1))
		nectar_landed = false
		nectar_source = null

func process_arrive(delta, final: Vector3):
	var position_2d = Vector2(position.x, position.z)
	var final_2d = Vector2(final.x, final.z)
	var fly_destination_2d = Vector2(fly_destination.x, fly_destination.z)
	
	if position_2d.distance_to(final_2d) < arrived_threshold:		
		return	true

	var close_enugh = position_2d.distance_to(fly_destination_2d) < destination_threshold
	var left_behind = position_2d.distance_to(final_2d) <= fly_destination_2d.distance_to(final_2d)
	if close_enugh or left_behind:
		set_fly_destination(next_travel_destination(final))
	
	process_fly_to_destination(delta, TRAVEL_MAX_SPEED)

func next_travel_destination(final: Vector3):
	var remaining = final - position
	var remaining_distance = remaining.length()
	var next = remaining.normalized() * fly_segment_length
	if next.length() > remaining_distance:
		next = remaining
	
	var deviation = Vector3.FORWARD.rotated(Vector3.UP, randf() * PI * 2) * max_deviation	
	
	next = position + next + deviation
	var surface_height = Vector3.UP * _get_height(next)
	var travel_height = Vector3.UP * TRAVEL_HEIGHT
	next.y = 0
	next = next + surface_height + travel_height
	
	return next

func process_fly_to_destination(delta, max_speed, dump = DEFAULT_DUMP):
	if fly_destination != position:
		look_at(fly_destination)
	var force = (fly_destination - position).normalized() * fly_acceleration * delta
	#var force = Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * fly_acceleration * delta
	fly_velocity += force

	if dump:
		var dot = fly_velocity.dot(fly_destination - position)
		if dot < 0:
			fly_velocity -= fly_velocity.normalized() * dump * delta

	if fly_velocity.length() > max_speed:
		fly_velocity -= fly_velocity.normalized() * dump * delta	

func _add_nectar(amount):
	self.nectar += amount

func set_fly_destination(destination: Vector3):
	fly_destination = destination
	$FlyDestination.position = fly_destination

func set_anchor(position: Vector3):
	anchor_position = position
	$Anchor.position = anchor_position	
	arrived = false
	hung = false
	nectar_landed = false
	nectar_source = null
	explore_destination = anchor_position
	spin_count = 0

func set_anchor_mode(mode: AnchorMode):
	anchor_mode = mode
	if mode == AnchorMode.HANG:	
		hung = false
		$Anchor/Label.text = 'Hang'
	elif mode == AnchorMode.EXPLORE:
		$Anchor/Label.text = 'Explore'
	elif mode == AnchorMode.ORIENT:
		spin_count = 0
		$Anchor/Label.text = 'Orient'

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
