@tool
@icon("res://addons/OSIK/OSIKicon.svg")
extends SkeletonModifier3D
class_name OSIK

##Code Version 1.0.5.7 ##

@export var tipBoneLenght:float = 0.1:
	set(newVal):
		if newVal <0.0001:
			newVal = 0.0001
		tipBoneLenght = newVal
		_creat_IK_Look_Spots(boneList)
@export var loops:int = 1:
	set(newVal):
		if newVal <1:
			loops=1
		else :
			loops = newVal
@export var CloseEnoughValue:float = 0.01:
	set(NewValue):
		if NewValue < 0.01:
			CloseEnoughValue = 0.01
		else:
			CloseEnoughValue = NewValue
@export var targetNode:Node3D
@export var poleNode:Node3D
@export var copyTargetRotation:bool = false
@export var GlobalTargetRotation:bool = false
@export var LockToRestRoll:bool = false
@export_enum(" ") var targetBone:String:
	set(NewVal):
		targetBone = NewVal
		if loaded and NewVal!=null and NewVal != "":
			boneList = _creat_bone_list()
			_creat_bone_constraints_resorces()
			_creat_IK_Look_Spots(boneList)
			_creat_bone_current_pose_list()
@export var IKLength :int = 1:
	set (NewVal):
		if NewVal <=0:
			IKLength = 1
		else:
			IKLength = NewVal
		if loaded and targetBone != "" :
			boneList = _creat_bone_list()
			_creat_bone_constraints_resorces()
			_creat_IK_Look_Spots(boneList)
			_creat_bone_current_pose_list()
@export_range(0.01,99.0,0.01) var slerpSpeed:float = 5:
	set(newVal):
		if newVal < 0.01:
			slerpSpeed = 0.01
		else:
			slerpSpeed = newVal
		if slerpSpeed > 45 and WarrningTimmerslerpSpeed > 4:
			WarrningTimmerslerpSpeed =0
			push_warning("DANGER ZONE! slerp Speed set to " + str(slerpSpeed) + " High speeds can cause errors and odd behavior")
@export var Limits:Array[OSIK_Constraints]:
	set(NewVal):
		if NewVal.size() != Limits.size() and !LimitsSizeEdit and loaded:
			if WarrningTimmer >= 4:
				WarrningTimmer = 0
				push_warning("Adjust the IK Length field to change the size. This field is locked and can only be modified through this control.")
			return
		else:
			Limits = NewVal

@onready var skeleton: Skeleton3D = get_skeleton()
@onready var SkelPrevPos:Vector3 = skeleton.global_position
@onready var allOSIK : Array [OSIK] = return_sibling_OSIK_array()
@onready var global_scale:Vector3 = self.global_transform.basis.get_scale()

var LimitsSizeEdit:bool = false
var boneList:Array
var loaded = false
var IK_Look_Spots: Array [Array]
var boneCurrentPoseArray :Array
var target_PrevLocation: Vector3
var poleNode_PrevLocation: Vector3
var tipPoint: Vector3
var updateChainRequired: bool = false
var WarrningTimmer:float = 5.0
var WarrningTimmerslerpSpeed:float = 5.0
var editorFocus:bool = true
var boneCache : Dictionary

func _ready():
	get_skeleton().child_order_changed.connect(update_OSIK_Array)
	if targetBone != null and targetBone != "":
		boneList = _creat_bone_list()
	loaded = true
	_creat_IK_Look_Spots(boneList)
	_creat_bone_current_pose_list()

func _process(delta: float) -> void:
	if global_scale != self.global_transform.basis.get_scale() and loaded:
		global_scale = self.global_transform.basis.get_scale()
		update_bone_sizes()

	if Engine.is_editor_hint():
		if WarrningTimmer < 5:
			WarrningTimmer += delta
		if WarrningTimmerslerpSpeed <5:
			WarrningTimmerslerpSpeed += delta

func _creat_IK_Look_Spots(aBoneList:Array):
	if !aBoneList.is_empty():
		IK_Look_Spots.resize(aBoneList.size())
		for i in aBoneList.size():
			IK_Look_Spots[i]= [[],[]]
			var bone_idx: int = skeleton.find_bone(aBoneList[i])
			IK_Look_Spots[i][0] = (skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx))
			IK_Look_Spots[i][1] = get_bone_length(skeleton,bone_idx)

func update_bone_sizes():
	if !IK_Look_Spots.is_empty():
		for i in IK_Look_Spots.size():
			var bone_idx: int = skeleton.find_bone(boneList[i])
			IK_Look_Spots[i][1] = get_bone_length(skeleton,bone_idx)
		_creat_bone_current_pose_list()

func get_bone_length(skeleton_node: Skeleton3D, bone_index: int) -> float:
	# Get the global pose of the current bone
	var bone_pose: Transform3D = skeleton_node.get_bone_global_pose(bone_index)
	var bone_origin: Vector3 = bone_pose.origin
	
	if bone_index < 0:
		push_error("Error the index is les the 0, returning a 1 as the legnth however this would be an error")
		return 1
	# Get the global pose of the parent bone
	if bone_index+1 < skeleton_node.get_bone_count():
		var child_bone_global_pose: Transform3D = skeleton_node.get_bone_global_pose(bone_index+1)
		var child_origin: Vector3 = child_bone_global_pose.origin

		# The length is the distance between the two origins, * the scale to put the ground work in for scaling
		var bone_length: float = bone_origin.distance_to(child_origin) * global_scale.y
		return bone_length
	else:
		push_warning("tip length used, as bone has no child")
		return tipBoneLenght * global_scale.y

func _creat_bone_current_pose_list():
	var startingIndex:int = skeleton.find_bone(targetBone)
	if !boneCurrentPoseArray.is_empty():
		boneCurrentPoseArray.clear()
	boneCurrentPoseArray.resize(boneList.size())
	for i in boneList.size():
		boneCurrentPoseArray[i] = skeleton.get_bone_global_pose(startingIndex-i)

func _creat_bone_list():
	if targetBone!=null and targetBone!="":
		var list:Array = []
		var startingIndex:int = skeleton.find_bone(targetBone)
		if IKLength > startingIndex+1:
			IKLength = startingIndex+1
		for i in IKLength:
			list.append(skeleton.get_bone_name(startingIndex-i))
		return list

func _creat_bone_constraints_resorces():
	if targetBone!=null and targetBone!="":
		LimitsSizeEdit = true
		if !Limits.is_empty() and Limits!= null and Limits[0]!=null and Limits[0].boneName == boneList[0]:
			if Limits.size() == IKLength:
				notify_property_list_changed()
				LimitsSizeEdit = false
				return
			elif Limits.size() > IKLength:
				Limits.resize(IKLength)
				notify_property_list_changed()
				LimitsSizeEdit = false
				return
			else:
				Limits.resize(IKLength)
			for i in Limits.size():
				if Limits[i] == null:
					Limits[i] = OSIK_Constraints.new()
				if Limits[i].boneName == null or Limits[i].boneName == '':
					Limits[i].change_bone_name(boneList[i])
		elif Limits == null:
			Limits = []
			Limits.resize(boneList.size())
			for i in Limits.size()-1:
				Limits[i] = OSIK_Constraints.new()
				Limits[i].change_bone_name(boneList[i])
		else:
			Limits.clear()
			Limits.resize(boneList.size())
			for bone in boneList.size():
				if Limits[bone] == null:
					Limits[bone] = OSIK_Constraints.new()
				Limits[bone].change_bone_name(boneList[bone])
		LimitsSizeEdit = false
		notify_property_list_changed()

## this Validate_property creates the Enum list for the Skeleton
func _validate_property(property: Dictionary) -> void:
	if property.name == "targetBone":
		if skeleton:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skeleton.get_concatenated_bone_names()

##This little nugget will stop the OSIK nodes from becoming possessed by demons when you Alt-Tab out in the editor.
func _notification(what):
	if Engine.is_editor_hint():
		match what:
			MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
				editorFocus = true
			MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
				editorFocus = false

## this one will run of using the positions
func _process_modification_with_delta(delta: float) -> void:
	if editorFocus:
		#restore_pose()
		restore_pose_self()
		if !updateChainRequired:
			updateChainRequired = return_true_if_update_required()
		if is_inside_tree() and targetNode !=null and is_instance_valid(targetNode) and targetBone!=null and targetBone !="" :
			var currentIteration:int = 0
			var MaxIterations:int  = loops
			if !skeleton:
				return # Never happen, but for the safety.
			var LatIndex:int = skeleton.find_bone(boneList[-1])
			
			#befor starting the iK system we need to make sure the root bone, or last bone in the chain fron the target bone is set to the position relative to its corect position
			boneCurrentPoseArray[-1] = skeleton.get_bone_global_pose(LatIndex)
			# This will make it so that the chain only updates if there are changes
			if updateChainRequired:
				updateChainRequired = false
				#print("Update was called")
				
				## This next block of code will make the entire IK chain follow the direction of the pole node. This forces the solution to bend in the direction of the pole reference.
				if poleNode!=null:
					IK_Look_Spots[-1][0].origin = (skeleton.global_transform * skeleton.get_bone_global_pose(LatIndex)).origin
					var directToPole = (poleNode.global_position - IK_Look_Spots[-1][0].origin).normalized()
					for i in IK_Look_Spots.size():
						if i != 0:
							# We run it in reverse so that it goes from the root bone to the tip, and we don’t affect the root bone since it needs to stay in place. [-1][0].origin is the position that we don’t want to change, or where i = 0.
							var invertI:int = IK_Look_Spots.size()-1-i
							IK_Look_Spots[invertI][0].origin = IK_Look_Spots[invertI+1][0].origin + (directToPole*IK_Look_Spots[invertI+1][1])
				while currentIteration < MaxIterations:
					var start = (skeleton.global_transform * skeleton.get_bone_global_pose(LatIndex)).origin
					## BACKWARD
					# I know most people would call this the forward pass, but since it reaches back from the target to the root bone, it made more sense to me to call it the backward pass.
					var directToTargetFromLast =  (targetNode.global_position - IK_Look_Spots[0][0].origin).normalized()
					IK_Look_Spots[0][0].origin = targetNode.global_position -(directToTargetFromLast*IK_Look_Spots[0][1])
					#$"../MeshInstance3D2".global_position = IK_Look_Spots[1][0].origin
					for i in IK_Look_Spots.size():
						if i != IK_Look_Spots.size()-1:
							var IK_DirectionBackward = (IK_Look_Spots[i+1][0].origin - IK_Look_Spots[i][0].origin).normalized()
							IK_Look_Spots[i+1][0].origin = IK_Look_Spots[i][0].origin + IK_DirectionBackward*IK_Look_Spots[i+1][1]
					
					## This is forward
					# I know this would normally be called the backward pass since it’s the second stage, but because it reaches forward toward the target, it made more sense to me to call it the forward pass.
					IK_Look_Spots[-1][0].origin = start
					for i in IK_Look_Spots.size():
						var inversI = IK_Look_Spots.size()-i # You could write it as (i + 1) * -1 and filter out cases where i * -1 >= IK_Look_Spots.size(), but the inverse approach works fine for me.
						if inversI != IK_Look_Spots.size():
							var IK_DirectionForward = (IK_Look_Spots[inversI][0].origin - IK_Look_Spots[inversI-1][0].origin).normalized()
							var ParrentAngleForward:Vector3
							if inversI != IK_Look_Spots.size()-1:
								ParrentAngleForward = (IK_Look_Spots[inversI+1][0].origin - IK_Look_Spots[inversI][0].origin).normalized()
							else:
								var bone_idx: int = skeleton.find_bone(boneList[inversI])
								ParrentAngleForward = ((skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx-1)).origin -IK_Look_Spots[inversI][0].origin).normalized()
								
							IK_DirectionForward = clamp_directional_angle(ParrentAngleForward,IK_DirectionForward,Limits[inversI])
							IK_Look_Spots[inversI-1][0].origin = IK_Look_Spots[inversI][0].origin - IK_DirectionForward*IK_Look_Spots[inversI][1]

					# Creat 1 more point to tell if the tip of the last bone ould be with in the range at the end
					var ParrentAngle:Vector3
					var directToTarget =  (targetNode.global_position - IK_Look_Spots[0][0].origin).normalized()
					if IKLength!=1:
						# this clamps the tip if need
						ParrentAngle =  IK_Look_Spots[0][0].origin - IK_Look_Spots[1][0].origin
						directToTarget = clamp_directional_angle(ParrentAngle,directToTarget,Limits[0])
					elif skeleton.find_bone(targetBone)!=0:
						# this will clamp the angle on the tip if the IK is only 1 long and not the last bone
						ParrentAngle = (IK_Look_Spots[0][0].origin-(skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(targetBone)-1)).origin).normalized()
						directToTarget = clamp_directional_angle(ParrentAngle,directToTarget,Limits[0])
					var LastBoneTip:Vector3 =  IK_Look_Spots[0][0].origin+(directToTarget*IK_Look_Spots[0][1])
					tipPoint = LastBoneTip
					if targetNode.global_position.distance_to(LastBoneTip) < CloseEnoughValue: # this will have the IK stop once its closeenough to the target after the forward pass
						break
					currentIteration +=1
							
			##The code below uses the position pointers created above to align each bone to the correct position along the IK chain.
			## it also will slerp the basis towards the end goal
			#$"../MeshInstance3D2".global_position = IK_Look_Spots[1][0].origin
			for bone in boneList.size():
				var bone_idx: int = skeleton.find_bone(boneList[boneList.size()-bone-1])
				var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
				pose.basis = pose.basis.orthonormalized()
				var looked_at: Transform3D 
				if bone == boneList.size()-1:
					if tipPoint != Vector3(0,0,0):
						if LockToRestRoll:
							looked_at  = _y_look_at_rel_to_globalTransform(pose.orthonormalized(), tipPoint, skeleton.global_transform *skeleton.get_bone_global_rest(bone_idx))
						else:
							looked_at = _y_look_at(pose.orthonormalized(), tipPoint)
					else:
						if LockToRestRoll:
							looked_at  = _y_look_at_rel_to_globalTransform(pose.orthonormalized(), targetNode.global_position, skeleton.global_transform *skeleton.get_bone_global_rest(bone_idx))
						else:
							looked_at = _y_look_at(pose.orthonormalized(), targetNode.global_position)
				else:
					if LockToRestRoll:
						looked_at  = _y_look_at_rel_to_globalTransform(pose.orthonormalized(), IK_Look_Spots[boneList.size()-bone-2][0].origin, skeleton.global_transform *skeleton.get_bone_global_rest(bone_idx))
					else:
						looked_at = _y_look_at(pose.orthonormalized(),IK_Look_Spots[boneList.size()-bone-2][0].origin)
				# The code below converts the look-at location from global to local space so it can be correctly applied to the skeleton.
				var new_global_pose = Transform3D(looked_at.basis.orthonormalized(), looked_at.origin)
				var local_pose = skeleton.global_transform.affine_inverse().orthonormalized() * new_global_pose
				boneCurrentPoseArray[boneList.size()-bone-1].basis = boneCurrentPoseArray[boneList.size()-bone-1].basis.orthonormalized().slerp(local_pose.basis.orthonormalized(),slerpSpeed*1*delta).orthonormalized()
				if bone != boneList.size()-1:
					# Sets the new origin for the next bone based on the current bone’s basis Y direction.
					boneCurrentPoseArray[boneList.size()-bone-2].origin = (boneCurrentPoseArray[boneList.size()-bone-1].origin+ (boneCurrentPoseArray[boneList.size()-bone-1].basis.orthonormalized().y.normalized() *(IK_Look_Spots[boneList.size()-bone-1][1]))/global_scale)
				skeleton.set_bone_global_pose(bone_idx, boneCurrentPoseArray[boneList.size()-bone-1])
			## This next section will allow you to Keep rotation on the next bone after the chain relative to the roation of the IK if required, good for use with hands or feet
				if copyTargetRotation and skeleton.find_bone(targetBone) != skeleton.get_bone_count()-1:
					if GlobalTargetRotation:
						skeleton.set_bone_global_pose(skeleton.find_bone(targetBone)+1,Transform3D(targetNode.global_basis,skeleton.get_bone_global_pose(skeleton.find_bone(targetBone)+1).origin))
					else:
						skeleton.set_bone_global_pose(skeleton.find_bone(targetBone)+1,Transform3D(targetNode.basis,skeleton.get_bone_global_pose(skeleton.find_bone(targetBone)+1).origin))
			## Bake poses from last OSIK, use this for OSIK's to load there pose's from to stop jitters
			if !allOSIK.is_empty():
				if allOSIK[-1] == self:
					bake_bone_pose()

## This Funciton is from the Documentation on how to use SkeletonModifier3D, and was what made me go, HAY! i can use this to make an IK system
func _y_look_at(from: Transform3D, target: Vector3) -> Transform3D:
	var t_v: Vector3 = target - from.origin
	var v_y: Vector3 = t_v.normalized()
	
	##Creating a fixed Roll direction can be done with the below
	#var global_down = Vector3.RIGHT
	#var v_z: Vector3 = global_down.cross(v_y).normalized()
	## This will keep making relative rolls, which can over twist 
	var v_z: Vector3 = from.basis.orthonormalized().x.cross(v_y)
	v_z = v_z.normalized()
	
	var v_x: Vector3 = v_y.cross(v_z)
	
	from.basis = Basis(v_x, v_y, v_z)
	
	return from


func _y_look_at_rel_to_globalTransform(from: Transform3D, target: Vector3, globalTransform:Transform3D) -> Transform3D:
	var t_v: Vector3 = target - from.origin
	var v_y: Vector3 = t_v.normalized()
	
	##Creating a fixed Roll relative to the rest pose's roll
	var rest_z = globalTransform.basis.x.normalized()
	var v_z: Vector3 = rest_z.cross(v_y).normalized()
	var v_x: Vector3 = v_y.cross(v_z).normalized()
	
	from.basis = Basis(v_x, v_y, v_z)
	
	return from


func clamp_directional_angle(reference: Vector3, target: Vector3, OSLimits: OSIK_Constraints) -> Vector3:
	var LimitX = OSLimits.limitX
	var LimitY = OSLimits.limitY
	# this is a saftey to make sure the Ref and the tgt are normalized, they already should be but just incase
	var ref_dir = reference.normalized()
	var tgt_dir = target.normalized()
	# if both limits are off retune the target
	if !OSLimits.limitX and !OSLimits.limitY:
		return target
	# Builds a basis (local coordinate system) from the reference direction
	var up = Vector3.UP
	if abs(ref_dir.dot(up)) > 0.99:
		up = Vector3.FORWARD  # Avoid gimbal lock when looking straight up/down
	var right = ref_dir.cross(up).normalized()
	var local_up = right.cross(ref_dir).normalized()
	
	var newbasis = Basis(right, local_up, ref_dir)  # X = right, Y = up, Z = forward
	var newtransform = Transform3D(newbasis.orthonormalized(), Vector3.ZERO)

	# Transforms target into reference's local space
	var local_target = newtransform.basis.inverse() * tgt_dir.normalized()

	# Extracts yaw and pitch from local target
	var yaw_rad = atan2(local_target.x, local_target.z)
	var pitch_rad = atan2(local_target.y, local_target.z)

	## The below clamps the angles based on the restrictions given from the OSLimits
	# I think I’ve used the correct naming conventions for yaw (x) and pitch (y), and I believe roll is (z). I’m not affecting roll with the code below, though, I’m not entirely sure how I would. This part fried my brain enough already.
	# If the restrictions are turned off (as they are by default), it will just pass the original x, z and y, z information for yaw and pitch.
	
	var clamped_yaw
	var clamped_pitch
	if LimitX:
		clamped_yaw = clamp(rad_to_deg(yaw_rad), -OSLimits.xNegativeLimit, OSLimits.xPositiveLimit)
	else:
		clamped_yaw = rad_to_deg(yaw_rad)
	if LimitY:
		clamped_pitch = clamp(rad_to_deg(pitch_rad), -OSLimits.yNegativeLimit, OSLimits.yPositiveLimit)
	else:
		clamped_pitch = rad_to_deg(pitch_rad)
	# after clamping the direction needs to be reconstructed from the clamped angles
	var clamped_local = Vector3(
		sin(deg_to_rad(clamped_yaw)),
		sin(deg_to_rad(clamped_pitch)),
		cos(deg_to_rad(clamped_yaw)) * cos(deg_to_rad(clamped_pitch))
	).normalized()

	# Then transform back to world space, this is usually the point where you scoop your brain up off the floor after dealing with all that relative vector math.
	var final_dir = newtransform.basis.orthonormalized() * clamped_local
	return final_dir.normalized()

## This next line isnt yet used, but will use it to bake poses from last OSIK back to the first in a future version
func bake_bone_pose():
	for bone in skeleton.get_bone_count():
		boneCache[bone] = skeleton.get_bone_pose(bone)

## Prevents the node form shaking in editor and creates smother IK movment 
func restore_pose_self():
	var cache = allOSIK[-1].boneCache as Dictionary
	if not cache.is_empty():
		for bone in skeleton.get_bone_count():
			if boneList.has(skeleton.get_bone_name(bone)):
				skeleton.set_bone_pose(bone,cache[bone])
	pass

## Originally, I used this to feed the last pose back to the first node. It had the issue of making the influence slider on each OSIK useless unless its value was higher than the first in the chain, if this function was used.
func restore_pose():
	if !allOSIK.is_empty():
		var whiteList = []
		for node in allOSIK:
			whiteList.append_array(node.boneList)
		if allOSIK[0] == self:
			var cache = allOSIK[-1].boneCache as Dictionary
			if not cache.is_empty():
				for bone in skeleton.get_bone_count():
					if whiteList.has(skeleton.get_bone_name(bone)):
						skeleton.set_bone_pose(bone,cache[bone])

# Going to change this to a full list that allso connects all to a siginal, moved, if one of the children are moved then all will rework there lists, the first and last will then connect to bakeing and remaking the poses to prevent flicker
func return_sibling_OSIK_array()->Array[OSIK]:
	var OSIKnodes:Array[OSIK] =[]
	for child in skeleton.get_children():
		if child is OSIK: 
			OSIKnodes.append(child)
	return OSIKnodes
	

func update_OSIK_Array():
	allOSIK.clear()
	allOSIK = return_sibling_OSIK_array()

##This checks whether an update is needed for this node. If it is, it notifies the other OSIK nodes that they need to check their solutions as well, since their start points may have been moved.
func return_true_if_update_required()->bool:
	if targetNode != null:
		if target_PrevLocation == null or target_PrevLocation != targetNode.global_position:
			target_PrevLocation = targetNode.global_position
			set_all_OSIK_for_update_required()
			return true
	if poleNode != null:
		if poleNode_PrevLocation == null or poleNode.global_position != poleNode_PrevLocation:
			poleNode_PrevLocation = poleNode.global_position
			set_all_OSIK_for_update_required()
			return true
	if skeleton.global_position != SkelPrevPos:
		SkelPrevPos = skeleton.global_position
		set_all_OSIK_for_update_required()
		return true
	return false

func set_all_OSIK_for_update_required():
	for node in allOSIK:
		node.updateChainRequired = true
