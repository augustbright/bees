extends Area3D

const Bee = preload("res://bee.gd")

var nectar = 0:
	set(value):
		nectar = value
		$NectarLabel.text = 'Nectar: ' + str(nectar)

var bees = 0:
	set(value):
		bees = value
		$BeesLabel.text = 'Bees: ' + str(bees)

func publish(info: Dictionary):
	print('publish info: ', info)

func receive_nectar(amount):
	self.nectar += clamp(amount, 0, amount)

func receive_bee(bee: Bee):
	bees += 1

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
