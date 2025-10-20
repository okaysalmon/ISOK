@tool
@icon("res://OSIK/OSIKicon.svg")
extends SkeletonModifier3D
class_name OSIK

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
			

var LimitsSizeEdit:bool = false
var boneList:Array
var loaded = false
var IK_Look_Spots: Array [Array]
var boneCurrentPoseArray :Array

var target_PrevLocation: Vector3
var tipPoint: Vector3

var WarrningTimmer:float = 5.0
var WarrningTimmerslerpSpeed:float = 5.0

@onready var global_scale:Vector3 = self.global_transform.basis.get_scale():
	set(newVal):
		global_scale = newVal
		#if global_scale != Vector3(1,1,1): ## this error no longer needed as scaling fixed
			#push_error("Scale isn’t set to Vector3(1, 1, 1). Scaling isn’t supported yet and might cause some funky stuff to happen.")


func _ready():
	loaded = true
	boneList = _creat_bone_list()
	target_PrevLocation = targetNode.global_position
	_creat_IK_Look_Spots(boneList)
	_creat_bone_current_pose_list()

func _process(delta: float) -> void:
	if global_scale != self.global_transform.basis.get_scale():
		global_scale = self.global_transform.basis.get_scale()
		update_bone_sizes()
		#print(global_scale)
		
		
	
	if Engine.is_editor_hint():
		if WarrningTimmer < 5:
			WarrningTimmer += delta
		if WarrningTimmerslerpSpeed <5:
			WarrningTimmerslerpSpeed += delta

func _creat_IK_Look_Spots(aBoneList:Array):
	IK_Look_Spots.resize(aBoneList.size())
	var skeleton: Skeleton3D = get_skeleton()
	for i in aBoneList.size():
		IK_Look_Spots[i]= [[],[]]
		var bone_idx: int = skeleton.find_bone(aBoneList[i])
		IK_Look_Spots[i][0] = (skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx))
		IK_Look_Spots[i][1] = get_bone_length(skeleton,bone_idx)

func update_bone_sizes():
	var skeleton: Skeleton3D = get_skeleton()
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
	var skeleton: Skeleton3D = get_skeleton()
	var startingIndex:int = skeleton.find_bone(targetBone)
	if !boneCurrentPoseArray.is_empty():
		boneCurrentPoseArray.clear()
	boneCurrentPoseArray.resize(boneList.size())
	for i in boneList.size():
		boneCurrentPoseArray[i] = skeleton.get_bone_global_pose(startingIndex-i)

func _creat_bone_list():
	var skeleton: Skeleton3D = get_skeleton()
	var list:Array = []
	var startingIndex:int = skeleton.find_bone(targetBone)
	if IKLength > startingIndex+1:
		IKLength = startingIndex+1
	for i in IKLength:
		list.append(skeleton.get_bone_name(startingIndex-i))
	return list

func _creat_bone_constraints_resorces():
	if targetNode !=null and is_instance_valid(targetNode):
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
		var skeleton: Skeleton3D = get_skeleton()
		if skeleton:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skeleton.get_concatenated_bone_names()

## this one will run of using the positions
func _process_modification_with_delta(delta: float) -> void:
	if is_inside_tree() and targetNode !=null and is_instance_valid(targetNode) and targetBone!=null and targetBone !="" :
		var currentIteration:int = 0
		var MaxIterations:int  = loops
		var skeleton: Skeleton3D = get_skeleton()
		if !skeleton:
			return # Never happen, but for the safety.
		var LatIndex:int = skeleton.find_bone(boneList[-1])
		if target_PrevLocation != targetNode.global_position or target_PrevLocation == null:
			target_PrevLocation = targetNode.global_position
			while currentIteration < MaxIterations:
				#if IKLength ==1 and skeleton.find_bone(targetBone)==0:
				#	break
				var start = (skeleton.global_transform * skeleton.get_bone_global_pose(LatIndex)).origin
				## BACKWARD
				# I know most people would call this the forward pass, but since it reaches back from the target to the root bone, it made more sense to me to call it the backward pass.
				var directToTargetFromLast =  (targetNode.global_position - IK_Look_Spots[0][0].origin).normalized()
				IK_Look_Spots[0][0].origin = targetNode.global_position -(directToTargetFromLast*IK_Look_Spots[0][1])
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
							ParrentAngleForward = (IK_Look_Spots[inversI][0].origin-(skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx+1)).origin).normalized()
							
						IK_DirectionForward = clamp_directional_angle(ParrentAngleForward,IK_DirectionForward,Limits[inversI])
						IK_Look_Spots[inversI-1][0].origin = IK_Look_Spots[inversI][0].origin - IK_DirectionForward*IK_Look_Spots[inversI-1][1]

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
				var LastBoneTip =  IK_Look_Spots[0][0].origin+(directToTarget*IK_Look_Spots[0][1])
				tipPoint = LastBoneTip
				if targetNode.global_position.distance_to(LastBoneTip) < CloseEnoughValue: # this will have the IK stop once its closeenough to the target after the forward pass
					break
				currentIteration +=1
					
		##The code below uses the position pointers created above to align each bone to the correct position along the IK chain.
		## it also will slerp the basis towards the end goal
		for bone in boneList.size():
			var bone_idx: int = skeleton.find_bone(boneList[boneList.size()-bone-1])
			var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
			pose.basis = pose.basis.orthonormalized()
			var looked_at: Transform3D 
			if bone == boneList.size()-1:
				if tipPoint != Vector3(0,0,0):
					looked_at = _y_look_at(pose.orthonormalized(), tipPoint)
				else:
					looked_at = _y_look_at(pose.orthonormalized(), targetNode.global_position)
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



## This Funciton is from the Documentation on how to use SkeletonModifier3D, and was what made me go, HAY! i can use this to make an IK system
func _y_look_at(from: Transform3D, target: Vector3) -> Transform3D:
	var t_v: Vector3 = target - from.origin
	var v_y: Vector3 = t_v.normalized()
	var v_z: Vector3 = from.basis.orthonormalized().x.cross(v_y)
	v_z = v_z.normalized()
	var v_x: Vector3 = v_y.cross(v_z)
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

	var final_dir = newtransform.basis.orthonormalized() * clamped_local
	return final_dir.normalized()
