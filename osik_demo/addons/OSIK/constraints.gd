@tool
extends Resource
class_name OSIK_Constraints

@export var boneName:String: 
	set(Newvalue):
		if NameChangeOpen:
			boneName = Newvalue
			NameChangeOpen = false

@export_category("X limits")
@export var limitX:bool
@export_range(0.00,180,0.01) var xPositiveLimit = 0.0
@export_range(0.00,180,0.01) var xNegativeLimit = 0.0

@export_category("Y limits")
@export var limitY:bool
@export_range(0.00,180,0.01) var yPositiveLimit = 0.0
@export_range(0.00,180,0.01) var yNegativeLimit = 0.0

var NameChangeOpen:bool = true

func _ready():
	NameChangeOpen = false

func change_bone_name(newName:String):
	NameChangeOpen = true
	boneName = newName
