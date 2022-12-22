local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Player = require(Project.Player)

local PlayerIKController = {}

--Script in Starter Player Scripts
--Made by dthecoolest, 18/08/2021
--Please give credit

-- Modified by Vlazed to fit FE Player Template package directory 

local player = Player.getPlayer()
local Players = game:GetService("Players")

local CCDIKController = require(Project.Controllers.CCDIKController)

local RunService = game:GetService("RunService")

--Creates fake Upper hip motors and upper leg part
local function createFakeLegs(character, Torso, RealLeftLeg, RealRightLeg)
	--create LLEg First

	local FakeUpperLLeg = Instance.new("Part")
	FakeUpperLLeg.Transparency = 0
	FakeUpperLLeg.Size = Vector3.new(0.1,0.1,0.1)
	FakeUpperLLeg.CanCollide = false
	FakeUpperLLeg.CanQuery = false
	FakeUpperLLeg.CanTouch = false
	FakeUpperLLeg.Name = "FakeUpperLLeg"

	local LeftHip = Instance.new("Motor6D")
	LeftHip.Name = "Fake Left Hip"
	LeftHip.C1 = CFrame.new(0, 0.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	LeftHip.C0 = CFrame.new(-0.5, -0.95, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	LeftHip.Part0 = Torso
	LeftHip.Part1 = FakeUpperLLeg

	local LeftLeg = Instance.new("Motor6D")
	LeftLeg.Name = "Fake Left Leg"
	LeftLeg.C1 = CFrame.new(0, 0.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	LeftLeg.C0 = CFrame.new(0, -0.15, 0)
	LeftLeg.Part0 = FakeUpperLLeg
	LeftLeg.Part1 = RealLeftLeg

	--Start parenting
	FakeUpperLLeg.Parent = character
	LeftHip.Parent = Torso
	LeftLeg.Parent = Torso

	--Begin right leg
	local FakeUpperRLeg = Instance.new("Part")
	FakeUpperRLeg.Transparency = 0
	FakeUpperRLeg.Size = Vector3.new(0.1,0.1,0.1)
	FakeUpperRLeg.CanCollide = false
	FakeUpperRLeg.CanQuery = false
	FakeUpperRLeg.CanTouch = false
	FakeUpperRLeg.Name = "FakeUpperRLeg"
	FakeUpperRLeg.Parent = character

	local RightHip = Instance.new("Motor6D")
	RightHip.Name = "Fake Right Hip"
	RightHip.C1 = CFrame.new(0, 0.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	RightHip.C0 = CFrame.new(0.5, -0.95, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	RightHip.Part0 = Torso
	RightHip.Part1 = FakeUpperRLeg

	local RightLeg = Instance.new("Motor6D")
	RightLeg.Name = "Fake Right Leg"
	RightLeg.C1 = CFrame.new(0, 0.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	RightLeg.C0 = CFrame.new(0, -0.15, 0)
	RightLeg.Part0 = FakeUpperRLeg
	RightLeg.Part1 = RealRightLeg

	--Start parenting
	FakeUpperRLeg.Parent = character
	RightHip.Parent = Torso
	RightLeg.Parent = Torso
	--return Motor6Ds packaged form
	return {LeftHip,LeftLeg},{RightHip, RightLeg}, FakeUpperLLeg,FakeUpperRLeg

end

local function giveCharacterIK(character)

	local Torso = character:WaitForChild("Torso")

	local RealRightLeg : BasePart = character:WaitForChild("Right Leg")
	local RealLeftLeg : BasePart = character:WaitForChild("Left Leg")

	local EndEffector = Instance.new("Attachment")
	EndEffector.Name = "EndEffector"
	EndEffector.Position = Vector3.new(0, -0.9, 0)
	EndEffector.Parent = RealRightLeg

	local cloneEndEffect = EndEffector:Clone()
	cloneEndEffect.Parent = RealLeftLeg

	local LeftLegData, RightLegData, FakeUpperLLeg, FakeUpperRLeg = createFakeLegs(character,Torso,RealLeftLeg,RealRightLeg)

	--Create hinge constraint for CCDIK
	local function createHingeConstraints()
		local LKneeAttachment = Instance.new("Attachment")
		LKneeAttachment.Position = Vector3.new(0, -0.35, 0)
		LKneeAttachment.Parent = FakeUpperLLeg

		local LKneeAttachment1 = Instance.new("Attachment")
		LKneeAttachment1.Position = Vector3.new(0, 0.4, 0)
		LKneeAttachment1.Parent = RealLeftLeg

		local kneeConstraint = Instance.new("HingeConstraint")
		kneeConstraint.Attachment0 = LKneeAttachment
		kneeConstraint.Attachment1 = LKneeAttachment1
		kneeConstraint.LimitsEnabled = true
		kneeConstraint.LowerAngle = -145
		kneeConstraint.UpperAngle = -15
		kneeConstraint.Parent = FakeUpperLLeg

		--Repeat for right leg
		local RKneeAttachment = Instance.new("Attachment")
		RKneeAttachment.Position = Vector3.new(0, -0.35, 0)
		RKneeAttachment.Parent = FakeUpperRLeg

		local RKneeAttachment1 = Instance.new("Attachment")
		RKneeAttachment1.Position = Vector3.new(0, 0.4, 0)
		RKneeAttachment1.Parent = RealRightLeg

		local kneeConstraintRight = Instance.new("HingeConstraint")
		kneeConstraintRight.Attachment0 = RKneeAttachment
		kneeConstraintRight.Attachment1 = RKneeAttachment1
		kneeConstraintRight.LimitsEnabled = true
		kneeConstraintRight.LowerAngle = -145
		kneeConstraintRight.UpperAngle = -15
		kneeConstraintRight.Parent = FakeUpperRLeg
	end	
	createHingeConstraints()
	
	local function createBallSocketConstraints()
		
		local RightHipAttachment = Instance.new("Attachment")
		RightHipAttachment.Position = Vector3.new(0.5, -0.95, 0)
		RightHipAttachment.Parent = Torso
		
		local RightHipAttachment1 = Instance.new("Attachment")
		RightHipAttachment1.Position = Vector3.new(0, 0.3, 0)
		RightHipAttachment1.Parent = FakeUpperRLeg
		
		local hipConstraint = Instance.new("BallSocketConstraint")
		hipConstraint.Name = "RightBallSocketConstraint"
		hipConstraint.LimitsEnabled = true
		hipConstraint.TwistLimitsEnabled = true
		hipConstraint.UpperAngle = 5
		hipConstraint.Attachment0 = RightHipAttachment
		hipConstraint.Attachment1 = RightHipAttachment1
		hipConstraint.Parent = Torso
		
		local LeftHipAttachment = Instance.new("Attachment")
		LeftHipAttachment.Position = Vector3.new(-0.5, -0.95, 0)
		LeftHipAttachment.Parent = Torso
		
		local LeftHipAttachment1 = Instance.new("Attachment")
		LeftHipAttachment1.Position = Vector3.new(0, 0.3, 0)
		LeftHipAttachment1.Parent = FakeUpperLLeg
		
		local hipConstraintLeft = hipConstraint:Clone()
		hipConstraintLeft.Attachment0 = LeftHipAttachment
		hipConstraintLeft.Attachment1 = LeftHipAttachment1
		hipConstraintLeft.Name = "LeftBallSocketConstraint"
		hipConstraintLeft.Parent = Torso
	end
	createBallSocketConstraints()
	--Disable the original Hip motor6ds

	local rightLegController = CCDIKController.new(RightLegData)
	--rightLegController:InitDragDebug()
	rightLegController.UseLastMotor = true
	rightLegController:GetConstraints()
	rightLegController:GetConstraintsFromMotor(RightLegData[1],"RightBallSocketConstraint")
	
	local leftLegController = CCDIKController.new(LeftLegData)
	--leftLegController:InitDragDebug()
	leftLegController.UseLastMotor = true
	leftLegController:GetConstraints()
	leftLegController:GetConstraintsFromMotor(LeftLegData[1],"LeftBallSocketConstraint")
	
	local leftStepAttach = Instance.new("Attachment")
	leftStepAttach.Name = "LeftStepAttach"
	leftStepAttach.Position = Vector3.new(-0.5, -2.8, 0.1)
	leftStepAttach.Parent = Torso

	local rightStepAttach = Instance.new("Attachment")
	rightStepAttach.Name = "rightStepAttach"
	rightStepAttach.Position = Vector3.new(0.5, -2.8, 0.1)
	rightStepAttach.Parent = Torso

	local rightHipAttach = Instance.new("Attachment")
	rightHipAttach.Name = "RightHipAttach"
	rightHipAttach.Position = Vector3.new(0.5, -0.9, 0)
	rightHipAttach.Parent = Torso

	local leftHipAttach = Instance.new("Attachment")
	leftHipAttach.Name = "LeftHipAttach"
	leftHipAttach.Position = Vector3.new(-0.5, -0.9, 0)
	leftHipAttach.Parent = Torso
	
	local r6Legs = {
		["rightLeg"] = {
			["CurrentCycle"] = 0,
			["CCDIKController"] =rightLegController,
			["HipAttachment"]= rightHipAttach,
			["FootAttachment"] = rightStepAttach,
		},

		["leftLeg"] = {
			["CurrentCycle"] = math.pi,
			["CCDIKController"] =leftLegController,
			["HipAttachment"]= leftHipAttach,
			["FootAttachment"] = leftStepAttach,
		}
	}

	return r6Legs, FakeUpperLLeg, FakeUpperRLeg
end

function PlayerIKController.givePlayerIK() 
	return giveCharacterIK(Player.getNexoCharacter())
end

return PlayerIKController