extends Button

@export var panel:Panel
func _ready():
	pressed.connect(func():
		# On Pressed
		panel.visible = !panel.visible #Reverses its state
		)
