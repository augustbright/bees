extends Area3D

const Bee = preload("res://bee.gd")
@export var bee_scene: PackedScene

var memory_nectar := {}

var nectar = 0:
	set(value):
		nectar = value
		$NectarLabel.text = 'Nectar: ' + str(nectar)

var bees = 10:
	set(value):
		bees = value
		$BeesLabel.text = 'Bees: ' + str(bees)

func publish(info: Dictionary):
	match info['type']:
		'memory_nectar':
			var snapped_memory := {}
			for position: Vector3 in info['payload']:
				var snapped_position = position.snapped(Vector3(3, 3, 3))
				var amount = info['payload'][position]

				if snapped_memory.has(snapped_position):
					snapped_memory[snapped_position] += amount
				else:
					snapped_memory[snapped_position] = amount

			for position in snapped_memory:
				memory_nectar[position] = snapped_memory[position]

func receive_nectar(amount):
	self.nectar += clamp(amount, 0, amount)

func receive_bee(bee: Bee):
	bees += 1
	
func emit_bee():
	if bees > 0:
		var bee = bee_scene.instantiate() as Bee
		bee.position = position
		bee.memory_nectar = memory_nectar
		bee.unvisited_nectar = memory_nectar
		bee.hive = self
		bee.task_gather_nectar(position)
		get_parent().add_child(bee)
		bees -= 1

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
