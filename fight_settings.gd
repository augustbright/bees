extends  Node
var acceleration = 0
var dump = 0
var max_speed = 0
var threshold = 0

func _init(
	acceleration: float, dump: float,
	max_speed: float,
	threshold: float
):
	self.acceleration = acceleration
	self.dump = dump
	self.max_speed = max_speed
	self.threshold = threshold
	
func has_reached_3(current_position: Vector3, destination: Vector3):
	return current_position.distance_to(destination) < threshold

func has_reached_2(current_position: Vector3, destination: Vector3):
	var current_position_2 = Vector2(current_position.x, current_position.z)
	var destination_2 = Vector2(destination.x, destination.z)
	
	return current_position_2.distance_to(destination_2) < threshold
