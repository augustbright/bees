extends Node3D

@export var space_click_effect: PackedScene

const RAY_LENGTH = 1000.0
const CAM_SPEED = 5

# Called when the node enters the scene tree for the first time.
func _ready():
	set_anchor_mode(0)
	$Bee.hive = $Hive

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var cam_velocity = Vector3.ZERO
	if Input.is_action_pressed("camera_forward"):
		cam_velocity.z -= 1
	if Input.is_action_pressed("camera_backward"):
		cam_velocity.z += 1
	if Input.is_action_pressed("camera_left"):
		cam_velocity.x -= 1
	if Input.is_action_pressed("camera_right"):
		cam_velocity.x += 1
	if Input.is_action_pressed("camera_up"):
		cam_velocity.y += 1	
	if Input.is_action_pressed("camera_down"):
		cam_velocity.y -= 1
	
	cam_velocity = cam_velocity.normalized() * CAM_SPEED * delta
	$Camera3D.position += cam_velocity

func _physics_process(delta):
	if Input.is_action_just_pressed("click") and cursor_on_scene():
		var space_state = get_world_3d().direct_space_state
		var intersection = raycast()
		
		if intersection:
			var effect = space_click_effect.instantiate() as GPUParticles3D
			effect.position = intersection.position
			effect.emitting = true
			add_child(effect)
			
			$Bee.anchor = intersection.position

func raycast():
	var space_state = get_world_3d().direct_space_state

	var ray_origin = $Camera3D.project_ray_origin(get_viewport().get_mouse_position())
	var ray_end = $Camera3D.project_ray_normal(get_viewport().get_mouse_position()) * RAY_LENGTH
	var ray_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	return space_state.intersect_ray(ray_query)
	
func cursor_on_scene():
	var gui_nodes = get_tree().get_nodes_in_group('GUI')
	return not gui_nodes.any(has_cursor)

func has_cursor(control: Control):
	return control.get_global_rect().has_point(get_viewport().get_mouse_position())

func _on_anchor_mode_selector_item_selected(index):
	set_anchor_mode(index)

func set_anchor_mode(index):
	$Bee.anchor_mode = index
	$Control/AnchorModeSelector.select(index)
