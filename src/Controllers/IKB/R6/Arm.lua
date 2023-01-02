local RunService = game:GetService("RunService")

local CORRECTION_ANGLES = CFrame.Angles(math.pi / 2, 0, 0)

-- Equivalent to Vector3.new(0, 0, -1) but faster
local VECTOR3_NEGATIVE_ZAXIS = Vector3.zAxis * -1

type IKArmType = {
	-- Runtime
	_Torso: BasePart,
	_Arm: BasePart,
	_Shoulder: Motor6D,

	-- Constants
	_ArmLength: number,
	_ShoulderC0Cache: CFrame,
	_OriginalShoulderC0: CFrame,
	_OriginalShoulderC1: CFrame,
	_TransformResetLoop: RBXScriptConnection
}

local IKArm = {}
IKArm.__index = IKArm

function IKArm.new(character, side)
	local self = setmetatable({}, IKArm)
	
	local torso = character.Torso
	local arm = character[side.. " Arm"]
	local shoulder = torso[side.. " Shoulder"]
	
	--[[
		Save original C's; why? because we want
		to be able to reset them back to how they were before.
	]]
	local originalShoulderC0 = shoulder.C0
	local originalShoulderC1 = shoulder.C1
	
	--[[
		Clean up rotations by omitting them; why?
		because othewise our rotations will become offsetted by the original rotations!
	]]
	--shoulder.C0 = CFrame.new(shoulder.C0.Position)
	--shoulder.C1 = CFrame.new(shoulder.C1.Position)
	
	--[[
		Keep resetting transform; why?
		because otherwise the arms will be going crazy!
	]]
	--[[
	self._TransformResetLoop = RunService.Stepped:Connect(function()
		-- CFrame.identity is basically CFrame.new() but constant; therefore faster!
		shoulder.Transform = CFrame.identity
	end)
	--]]
	self._Torso = torso
	self._Arm = arm
	self._Shoulder = shoulder
	
	-- TODO: Explain why we're subtracting 0.5 from arm size on Y-axis
	self._ArmLength = arm.Size.Y - 0.5
	
	self._ShoulderC0Cache = CFrame.new(shoulder.C0.Position)
	self._ShoulderC1Cache = CFrame.new(shoulder.C1.Position)
	self._OriginalShoulderC0 = originalShoulderC0
	self._OriginalShoulderC1 = originalShoulderC1
	
	return self
end


function IKArm:ResetTransform()
	self._Shoulder.Transform = CFrame.new(self._Shoulder.Transform.Position)
end


function IKArm:Solve(targetPosition: Vector3, correctionAngle: Vector3)
	correctionAngle = correctionAngle or CORRECTION_ANGLES

	local shoulderCFrame = self._Torso.CFrame * self._ShoulderC0Cache
	local localized = shoulderCFrame:PointToObjectSpace(targetPosition)
	
	local planeBaseline = shoulderCFrame * CFrame.fromAxisAngle(
		VECTOR3_NEGATIVE_ZAXIS:Cross(localized.Unit), -- Axis
		math.acos(-localized.Unit.Z) -- Angle
	)

	local planeCFrame
		if localized.Magnitude < self._ArmLength then
			planeCFrame = planeBaseline * CFrame.new(Vector3.zAxis * (self._ArmLength - localized.Magnitude))
		else
			planeCFrame = planeBaseline
		end
	
	self._Shoulder.Transform = self._Torso.CFrame:ToObjectSpace(planeCFrame * correctionAngle)
	self._Shoulder.C1 = self._OriginalShoulderC1
end

function IKArm:Destroy()
	self._Shoulder.C0 = self._OriginalShoulderC0
	self._Shoulder.C1 = self._OriginalShoulderC1
	
	--self._TransformResetLoop:Disconnect()
end

return IKArm