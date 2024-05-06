extends Area3D

@export var amount = 5
var place = 2

# Called when the node enters the scene tree for the first time.
func _ready():
	_set_amount(amount)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func take(amount = 1):
	var available = clamp(amount, 0, self.amount)
	_set_amount(self.amount - available)
	return available

func _set_amount(amount):
	self.amount = amount
	$Label3D.text = str(amount)
