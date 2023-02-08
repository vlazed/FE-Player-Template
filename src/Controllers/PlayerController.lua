local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local RunService = game:GetService("RunService")

local ActionHandler = require(Project.Controllers.ActionHandler)
local Animation = require(Project.Controllers.Animations.Animation)
local AnimationController = require(Project.Controllers.AnimationController)
local ControllerSettings = require(Project.Controllers.ControllerSettings)
local EmoteController = require(Project.Controllers.EmoteController)
local VRController = require(Project.Controllers.VRController)

local R6Reanim = require(Project.Controllers.Reanimation.R6Nexo)
local R15Reanim = require(Project.Controllers.Reanimation.R15NexoKuraga)

local Network = require(Project.Util.Network)
local SendNotification = require(Project.Util.SendNotification)
local FastTween = require(Project.Util.FastTween)
local Thread = require(Project.Util.Thread)
local Signal = require(Project.Packages.Signal)
local Spring = require(Project.Util.Spring)

-- TODO: Determine CFrame-based implementation for R6 IK Foot Placement 
--local R6IKController = require(Project.Controllers.R6IKController)

local Player = require(Project.Player)

local PlayerController = {}

local FALLEN_PARTS_THRESHOLD = 0.25
local EPSILON = 1e-4
local DEBUG = false


PlayerController.MoveVector = Player.getHumanoidRootPart().CFrame.LookVector
PlayerController.TiltVector = Vector3.new(0, 1, 0)
local tiltSpring = Spring.new(2, PlayerController.TiltVector)
local moveSpring = Spring.new(2, PlayerController.MoveVector)

PlayerController.AttackPosition = Vector3.new()

local Mouse = Player.getMouse()

local IKArmController
local IKLegController

if Player:GetRigType() == Enum.HumanoidRigType.R6 then
	IKArmController = require(Project.Controllers.IKB.R6.Arm)
	IKLegController = require(Project.Controllers.IKB.R6.Leg)
else
	IKArmController = require(Project.Controllers.IKB.R15.AL)
	IKLegController = require(Project.Controllers.IKB.R15.AL)
end

PlayerController.LeftArm = nil 
PlayerController.RightArm = nil
PlayerController.LeftLeg = nil 
PlayerController.RightLeg = nil

PlayerController.ResetTransform = false
PlayerController.ToggleFling = false
PlayerController.LimbFling = false
PlayerController.LerpEnabled = false

local HRPFlingButton = Enum.KeyCode.Equals
local LimbFlingButton = Enum.KeyCode.RightBracket

local debounce = false

local fallingSpeed = 0
local currentFlipDelay = 0

local previousCFrame = CFrame.identity

PlayerController.Buoyancy = nil

-- Controller Locomotion Scalars
PlayerController.DefaultSettings = ControllerSettings:GetSettings()

PlayerController.Settings = {
	IdleSpeed = PlayerController.DefaultSettings.IdleSpeed,
	WalkSpeed = PlayerController.DefaultSettings.WalkSpeed,
	RunSpeed = PlayerController.DefaultSettings.RunSpeed,
	SprintSpeed = PlayerController.DefaultSettings.SprintSpeed,
	JumpPower = PlayerController.DefaultSettings.JumpPower,
	RunJumpPower = PlayerController.DefaultSettings.RunJumpPower,
	SprintJumpPower = PlayerController.DefaultSettings.SprintJumpPower,
	IdleTweenTime = PlayerController.DefaultSettings.IdleTweenTime,
	WalkTweenTime = PlayerController.DefaultSettings.WalkTweenTime,
	RunTweenTime = PlayerController.DefaultSettings.RunTweenTime,
	SprintTweenTime = PlayerController.DefaultSettings.SprintTweenTime,

	-- Controls for reactive locomotion
	IdleTiltRate = 10,
	FallTiltRate = 3,
	JumpTiltRate = 3,
	WalkTiltRate = 2,
	RunTiltRate = 4,
	SprintTiltRate = 8,

	-- Controls for strength to influence character's tilt
	WalkTiltMagnitude = 0.25,
	RunTiltMagnitude = 4,
	SprintTiltMagnitude = 4,
	JumpTiltMagnitude = 0.1,

	MoveRate = 2,
}

PlayerController.Modules = {}

PlayerController.Animation = Animation.new("Blank", {}, 30, false)

-- Animation Controller Layers
PlayerController.LayerA = {}
PlayerController.LayerB = {}
PlayerController.DanceLayer = {}
PlayerController.VRLayer = {}
PlayerController.Initialized = false

local massPollRate = 1
local massExecuteTime = tick() + 1/massPollRate

local updateModuleRate = 1
local moduleExecuteTime = tick() + 1/updateModuleRate

local previousVelocity = Vector3.new()

local connection
local nexoConnections
local respawnConnection
local animationConnection

local lostOwnershipLocation = Instance.new("Part")
lostOwnershipLocation.Size = Vector3.new(0.1, 2048, 0.1)
lostOwnershipLocation.Transparency = 0.8
lostOwnershipLocation.Material = Enum.Material.Neon
lostOwnershipLocation.Anchored = true
lostOwnershipLocation.CanCollide = false
lostOwnershipLocation.Parent = workspace

local lostPart = false
local ground

-- https://raw.githubusercontent.com/CenteredSniper/Kenzen/master/ZendeyReanimate.lua
local function setPhysicsOptimizations()
	if RunService:IsStudio() then return end

	settings()["Physics"].PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
	settings()["Physics"].AllowSleep = false
	settings()["Physics"].ForceCSGv2 = false
	settings()["Physics"].DisableCSGv2 = true
	settings()["Physics"].UseCSGv2 = false
	settings()["Physics"].ThrottleAdjustTime = math.huge - math.huge

	sethiddenproperty(workspace,"PhysicsSteppingMethod",Enum.PhysicsSteppingMethod.Fixed)
	--sethiddenproperty(workspace,"PhysicsSimulationRate",Enum.PhysicsSimulationRate.Fixed240Hz)
	sethiddenproperty(workspace, "SignalBehavior", "Immediate")

	workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Disabled
	workspace.Retargeting = "Disabled"
end


local function acceleration(v1, v2, dt)
	dt = dt or 0.01
	return (v2-v1).Magnitude/dt
end

--[[
	Some scripts are able to bypass the noclip anti-fling by attempting to apply a higher angular velocity
	while "stealing" network ownership. This is a compensation rather than an anti-fling.
--]]
local function detectFling(threshold: number, dt)
	threshold = threshold or 1000

	local currentVelocity = Vector3.new()
	local currentAcceleration = 0

	local nhrp = Player.getNexoHumanoidRootPart()
	if nhrp then
		currentVelocity = nhrp.AssemblyLinearVelocity + nhrp.AssemblyLinearVelocity
		currentAcceleration = acceleration(previousVelocity, currentVelocity, dt)
		previousVelocity = currentVelocity
	end

	--print(currentAcceleration)

	if 
		currentAcceleration > threshold and 
		not (
			Player.Sprinting:GetState() or 
			Player.Running:GetState() or 
			Player.Landing or 
			Player.Flipping
		)
	then
		print("Detected Fling")
		nhrp.CFrame = previousCFrame + Vector3.yAxis * 5
		Player.SetCFrame = false
		task.delay(1, function() Player.SetCFrame = true end)
	end
end

local function initializeControls()
	local hrp = Player.getNexoHumanoidRootPart()
	
	local floatAttachment = hrp:FindFirstChild("Floater") or Instance.new("Attachment")
	if floatAttachment.Name ~= "Floater" then
		floatAttachment.Name = "Floater"
		floatAttachment.Parent = hrp
	end
	
	local float = hrp:FindFirstChild("Float") or Instance.new("AlignPosition")
	if float.Name ~= "Float" then
		float.Name = "Float"
		float.Mode = Enum.PositionAlignmentMode.OneAttachment
		float.Attachment0 = Player.getNexoCharacterRootAttachment()
		float.ApplyAtCenterOfMass = true
		float.Enabled = Player.Flying
		float.Parent = hrp
	end
	
	local alignRot = hrp:FindFirstChild("FaceForward") or Instance.new("AlignOrientation")
	if alignRot.Name ~= "FaceForward" then
		alignRot.Name = "FaceForward"
		alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignRot.Attachment0 = Player.getNexoCharacterRootAttachment()
		alignRot.PrimaryAxisOnly = false
		alignRot.RigidityEnabled = false
		alignRot.MaxTorque = 100000
		alignRot.AlignType = Enum.AlignType.Perpendicular
		alignRot.Enabled = false
		alignRot.Parent = hrp		
	end

	local buoyancyForce = hrp:FindFirstChild("Archimedes") or Instance.new("VectorForce")
	if buoyancyForce.Name ~= "Archimedes" then
		buoyancyForce.Name = "Archimedes"
		buoyancyForce.Force = Vector3.new(0,1,0) * Player.Mass * workspace.Gravity
		buoyancyForce.Attachment0 = Player.getNexoCharacterRootAttachment()
		buoyancyForce.ApplyAtCenterOfMass = true
		buoyancyForce.RelativeTo = Enum.ActuatorRelativeTo.World
		buoyancyForce.Parent = Player.getNexoHumanoidRootPart()
		PlayerController.Buoyancy = buoyancyForce	
	end
end

-- TODO: Use Maid or Trove to automate cleanup of animation connections at respawn
function PlayerController:_InitializeStates()	
	Player:GetStateClass("Idling").OnTrue:Connect(self.OnIdle)
	Player:GetStateClass("Falling").OnTrue:Connect(self.OnFall)
	Player:GetStateClass("Jumping").OnTrue:Connect(self.OnJump)
	Player:GetStateClass("Walking").OnTrue:Connect(self.OnWalk)

	Player.Crouching.OnTrue:Connect(self.OnCrouch)
	Player.Crouching.OnFalse:Connect(self.StoppedCrouch)

	Player:GetStateClass("Walking").OnFalse:Connect(self.StoppedState)

	Player:GetAnimation("Roll"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("Slide"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("FrontFlip"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("BackFlip"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("RightFlip"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("LeftFlip"):ConnectStop(self.OnStopAnimation)

	Player:GetAnimation("LandSoft"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("LandHard"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("SprintStop"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("RunStop"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("WalkStop"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("FlyRunStop"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("FlyWalkStop"):ConnectStop(self.OnStopAnimation)
	
	Player.FightMode.OnFalse:Connect(self.StoppedState)
	Player.Attacking.OnFalse:Connect(self.StoppedState)
	Player.Sprinting.OnFalse:Connect(self.StoppedState)
	Player.Running.OnFalse:Connect(self.StoppedState)

	Player.Climbing.OnTrue:Connect(self.OnClimb)
	Player.Climbing.OnFalse:Connect(self.StoppedState)

	Player:getNexoHumanoid():SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	Player:getHumanoid():SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	Player:getNexoHumanoid():SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	Player:getHumanoid():SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end


function PlayerController:SetSettings(setting)
	for name,setting in pairs(setting) do
		self.Settings[name] = setting
	end
end


function PlayerController:SetAnimation(animTable)
	self.Animation = animTable
end


function PlayerController:Sprint()
	local runInfo = {self.Settings.RunTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.In}
	local sprintInfo = {self.Settings.SprintTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.In}
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	if Player.Running:GetState() then
		FastTween(humA, runInfo, {WalkSpeed = self.Settings.RunSpeed})
		FastTween(humB, runInfo, {WalkSpeed = self.Settings.RunSpeed})
		humA.JumpPower = self.Settings.RunJumpPower
		humB.JumpPower = self.Settings.RunJumpPower
	elseif Player.Sprinting:GetState() then
		FastTween(humA, sprintInfo, {WalkSpeed = self.Settings.SprintSpeed})
		FastTween(humB, sprintInfo, {WalkSpeed = self.Settings.SprintSpeed})
		humA.JumpPower = self.Settings.SprintJumpPower
		humB.JumpPower = self.Settings.SprintJumpPower
	end

	if Player.Flying then
		tiltSpring.f = self.Settings.RunTiltRate / 2 * Player:GetAnimationSpeed()
	elseif Player.Swimming then
		tiltSpring.f = self.Settings.RunTiltRate * 2.5 * Player:GetAnimationSpeed()
	else
		if Player.Running:GetState() then
			if Player.Flying then
				Player:GetAnimation("FlyRun"):AdjustWeight(1, 1)
				Player:GetAnimation("FlyRun"):Play()
				Player:GetAnimation("FlyRun").Framerate = 30 / (humA.WalkSpeed / 64)
			else
				Player:GetAnimation("Run"):AdjustWeight(1, 1)
				Player:GetAnimation("Run"):Play()
				Player:GetAnimation("Run").Framerate = 30 / (humA.WalkSpeed / 64)
				tiltSpring.f = self.Settings.RunTiltRate * Player:GetAnimationSpeed()
			end
		elseif Player.Sprinting:GetState() then
			if Player.Flying then
				Player:GetAnimation("FlySprint"):AdjustWeight(1, 1)
				Player:GetAnimation("FlySprint"):Play()
				Player:GetAnimation("FlySprint").Framerate = 60	
			else
				Player:GetAnimation("Sprint"):AdjustWeight(1, 1)
				Player:GetAnimation("Sprint"):Play()
				Player:GetAnimation("Sprint").Framerate = 60
				tiltSpring.f = self.Settings.SprintTiltRate * Player:GetAnimationSpeed()
			end
		end
	end
end


function PlayerController:Walk()
	local tweenInfo = {self.Settings.WalkTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.In}
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	humA.JumpPower = self.Settings.JumpPower
	humB.JumpPower = self.Settings.JumpPower
	FastTween(humA, tweenInfo, {WalkSpeed = self.Settings.WalkSpeed})
	FastTween(humB, tweenInfo, {WalkSpeed = self.Settings.WalkSpeed})

	if Player.Flying then
		tiltSpring.f = self.Settings.WalkTiltRate / 2 * Player:GetAnimationSpeed()
	elseif Player.Swimming then
		tiltSpring.f = self.Settings.WalkTiltRate * 5 * Player:GetAnimationSpeed()
	else
		tiltSpring.f = self.Settings.WalkTiltRate * Player:GetAnimationSpeed()
	end
end


function PlayerController:Fall()

	--print("Fall")
	if Player.Flying then
		tiltSpring.f = self.Settings.FallTiltRate / 3 * Player:GetAnimationSpeed()
	else
		tiltSpring.f = self.Settings.FallTiltRate * Player:GetAnimationSpeed()
	end
end


function PlayerController:Jump(char)
	local Settings = ControllerSettings:GetSettings()

	char = char or Player.getNexoCharacter()

	if ground then
		char.Humanoid.Jump = true
	elseif Player.Dodging and not Player:GetState("Jumping") then
		char.Humanoid:ChangeState(3)
		task.wait(Settings.DT)
		char.Humanoid:ChangeState(5)
	end

	if Player.Flying then
		tiltSpring.f = self.Settings.JumpTiltRate / 3 * Player:GetAnimationSpeed()
	elseif Player.Swimming then
		tiltSpring.f = self.Settings.JumpTiltRate / 3 * Player:GetAnimationSpeed()
	else
		tiltSpring.f = self.Settings.JumpTiltRate * Player:GetAnimationSpeed()
	end
end


function PlayerController:Idle()
	local tweenInfo = {self.Settings.IdleTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.In}

	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	humA.JumpPower = self.Settings.JumpPower
	humB.JumpPower = self.Settings.JumpPower
	FastTween(humA, tweenInfo, {WalkSpeed = self.Settings.IdleSpeed})
	FastTween(humB, tweenInfo, {WalkSpeed = self.Settings.IdleSpeed})

	if Player.Landing then
		humA.WalkSpeed = self.Settings.IdleSpeed
		humB.WalkSpeed = self.Settings.IdleSpeed
	end
	
	-- TODO: Change transition functions by shifting weight of animations
	if Player.Flying then
		--Player.Transition(2)
	elseif Player.Swimming then
		tiltSpring.f = self.Settings.IdleTiltRate * Player:GetAnimationSpeed()
	else
		--Player.Transition(1)
	end
end


function PlayerController:HoldTool(tool)
	local char = Player.getCharacter()
	local handle = tool:FindFirstChild("Handle")
	local rightGrip = CFrame.new(-Vector3.yAxis) * CFrame.fromOrientation(-90, 0, 0)
	if handle then
		handle.Velocity = Vector3.new(17.5, 17.5, 17.5)
		handle.CFrame = char["Right Arm"].CFrame * rightGrip * tool.Grip:Inverse()
	end
end


function PlayerController:Fly()
	local Settings = ControllerSettings:GetSettings()
	local Camera = workspace.CurrentCamera

	local humanoid = Player.getNexoHumanoid()
	local hrp = Player.getNexoHumanoidRootPart()
	local float = hrp:FindFirstChild("Float")
	local alignRot = hrp:FindFirstChild("FaceForward")
	
	float.Enabled = Player.Flying
	alignRot.Enabled = Player.Flying
	
	local walkSpeed = humanoid.WalkSpeed
	local moveDirection = humanoid.MoveDirection
	
	local ascent = (ActionHandler.IsKeyDown(Settings.ascendButton) - ActionHandler.IsKeyDown(Settings.crouchButton)) * Settings.AscentSpeed * Vector3.new(0,1,0)

	alignRot.CFrame = CFrame.fromMatrix(hrp.CFrame.Position, Camera.CFrame.XVector, Camera.CFrame.YVector)
	float.Position = hrp.Position + moveDirection * walkSpeed + ascent * humanoid.JumpPower / 50
end


function PlayerController:SetLostNetworkPosition(position)
	if lostPart then return end 

	lostPart = true
	lostOwnershipLocation.Position = position
	lostOwnershipLocation.Transparency = 0
end


function PlayerController:ToggleDebug()
	DEBUG = not DEBUG
end


function PlayerController:DodgeMove(direction)
	local hrp = Player.getNexoHumanoidRootPart()
	hrp.CFrame = hrp.CFrame + direction / Player:GetAnimationSpeed()
end


function PlayerController:Slide()
	if Player.DodgeMoving then
		self:DodgeMove(self.MoveVector*0.1)
		return
	end

	local slide = Player:GetAnimation("Slide")
	local slideDelay = slide.Properties.DodgeTime or 1
	self.LayerA:LoadAnimation(slide)
	if not slide:IsPlaying() then
		slide:Play()
		Player.DodgeMoving = true
		task.delay(slideDelay, function() Player.DodgeMoving = false Player.Transition(2) end)
	end
end


function PlayerController:Invisible()
	if not Player.Invisible then 
		self.LayerA.Playing = true 
		self.LayerB.Playing = true 
		self.DanceLayer.Playing = true 
		return 
	end

	for i,v in ipairs(Player.getCharacter():GetDescendants()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			v.CFrame = CFrame.new(0,1000,0)
		end
	end
end


function PlayerController:DodgeGround()
	if Player.Dancing or Player.Swimming then return end

	if Player.DodgeMoving then
		self:DodgeMove(self.MoveVector * 0.3)
		return
	end

	local roll = Player:GetAnimation("Roll")
	local rollDelay = roll.Properties.DodgeTime or 1.35
	self.LayerA:LoadAnimation(roll)
	if not roll:IsPlaying() then
		roll:Play()
		Player.DodgeMoving = true
		task.delay(rollDelay, function() Player.DodgeMoving = false end)
	end
end


-- Flip Implementation: Use feFlip to rotate character latitudinally or longitudinally, then animate character twist motion
function PlayerController:DodgeAir(char)
	if Player.Dancing or Player.Swimming or Player.Flipping then return end
	local torso = char.HumanoidRootPart

	local flip

	local rightVector = torso.CFrame.RightVector
	local lookVector = torso.CFrame.lookVector
	local c0 = rightVector:Dot(self.MoveVector) + EPSILON / 2
	local c1 = lookVector:Dot(self.MoveVector) + EPSILON / 2

	if math.abs(c0) < EPSILON then
		if c1 >= 0 then
			flip = Player:GetAnimation("FrontFlip")
		else
			flip = Player:GetAnimation("BackFlip")
		end
	else
		if c0 >= 0 then
			flip = Player:GetAnimation("RightFlip")
		else
			flip = Player:GetAnimation("LeftFlip")
		end
	end

	--print(flip)
	currentFlipDelay = flip.Properties.DodgeTime or flip.TimeLength
	self.LayerA:LoadAnimation(flip)
	
	if not flip:IsPlaying() then
		flip:Play()
		Player.Flipping = true
		Player.DodgeMoving = true
		self.LayerA.XDirection = math.round(c1)
		self.LayerA.ZDirection = math.round(c0)
		self:Jump()
		torso:ApplyImpulse(Player:GetWeight()*(Vector3.new(0,0.5,0) + self.MoveVector).Unit / 4)
		task.delay(currentFlipDelay, function() 
			Player.DodgeMoving = false
			Player.Flipping = false
		end)
	end

end


function PlayerController:LeanCharacter(char)

	local Settings = ControllerSettings:GetSettings()

	if char.Humanoid.MoveDirection.Magnitude > 0 and not Player.Dodging then
		self.MoveVector = char.Humanoid.MoveDirection
	end

	local sprintConstant = Player.Sprinting:GetState() and self.Settings.SprintTiltMagnitude or 1 
	local runConstant = Player.Running:GetState() and self.Settings.RunTiltMagnitude or 1
	local walkConstant = Player:GetState("Walking") and self.Settings.WalkTiltMagnitude or 1
	local jumpConstant = Player:GetState("Jumping") and self.Settings.JumpTiltMagnitude or 1
	local flyConstant = Player.Flying and 2 or 1

	self.TiltVector = Vector3.new(0,1,0) + char.Humanoid.MoveDirection * flyConstant * walkConstant * sprintConstant * jumpConstant * runConstant

	moveSpring.f = self.Settings.MoveRate * Player:GetAnimationSpeed()

	local tilt = tiltSpring:Update(Settings.DT, self.TiltVector)
	local move = moveSpring:Update(Settings.DT, self.MoveVector)

	AnimationController.TiltVector = tilt
	AnimationController.MoveVector = move
	
end


function PlayerController:Climb()
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()
	Player:GetAnimation("Climb").Speed = humB.WalkSpeed / 16
end


function PlayerController:ProcessStates(char, nexoChar)

	local nexoHum = Player.getNexoHumanoid()
	local hum = Player.getHumanoid()
	local height = nexoChar.HumanoidRootPart.CFrame.Position.Y 
	local tool = char:FindFirstChildOfClass("Tool")

	local hrp = nexoChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local threshold = 5000

	ground = Player:OnGround()

	local position = Network:CheckNetworkOwnershipOf(char)
	if typeof(position) == "Vector3" then
		self:SetLostNetworkPosition(position)
	else
		lostPart = false
		lostOwnershipLocation.Transparency = 1
	end

	local fallenPercent = math.abs((height - workspace.FallenPartsDestroyHeight) / workspace.FallenPartsDestroyHeight)
	if fallenPercent < FALLEN_PARTS_THRESHOLD then
		hrp.AssemblyLinearVelocity = Vector3.new()
		hrp.CFrame = previousCFrame + Vector3.new(0, 5, 0)
	end

	if Player.Dancing then
		threshold *= 2
		if not self.Animation:IsPlaying() then
			self.Animation:Play()
		end
	end

	if 
		hum:GetState() == Enum.HumanoidStateType.Climbing 
		or nexoHum:GetState() == Enum.HumanoidStateType.Climbing 
	then
		self:Climb()
		Player.Climbing:SetState(true)
	else
		Player.Climbing:SetState(false)
	end

	if Player:GetState("Jumping") and not Player.Dodging then
		Player:GetStateClass("Jumping"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Jumping", true)
		threshold *= 4
		self:Jump(nexoChar)
	elseif not (ground or Player.Flying) then
		Player:GetStateClass("Falling"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Falling", true)
		fallingSpeed = hrp.AssemblyLinearVelocity.Y
		threshold *= 1.75
		self:Fall()
	elseif Player.Running:GetState() or Player.Sprinting:GetState() then
		Player.Running:SetPreviousState(Player:GetEnabledLocomotionState())
		Player.Sprinting:SetPreviousState(Player:GetEnabledLocomotionState())
		self:Sprint()
		threshold *= 10
	elseif char.Humanoid.MoveDirection.Magnitude > 0 and not (Player:GetState("Jumping") or Player:GetState("Falling"))  then
		Player:GetStateClass("Walking"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Walking", true)
		self:Walk()
		threshold *= 1.2
	else
		Player:GetStateClass("Idling"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Idling", true)
		--hrp.AssemblyLinearVelocity = Vector3.new()
		self:Idle()
	end

	if tool then
		Player:GetAnimation("ToolHold"):Play()
		self:HoldTool(tool)
	else
		Player:GetAnimation("ToolHold"):Stop()
	end

	if not (Player:GetState("Falling") or Player:GetState("Jumping") or Player.Flying or Player.Swimming) and Player.SetCFrame then
		--print("Setting CFrame")
		previousCFrame = hrp.CFrame
	end

	if Player.Dodging then
		if Player:GetState("Falling") or Player:GetState("Jumping") then
			nexoHum.PlatformStand = true
			self:DodgeAir(nexoChar)
		elseif Player.Running:GetState() or Player.Sprinting:GetState() then
			nexoHum.PlatformStand = false
			self:Slide()
		else
			nexoHum.PlatformStand = false
			self:DodgeGround()
		end
	else
		nexoHum.PlatformStand = false
	end

	if 
		hum:GetState() == Enum.HumanoidStateType.Swimming 
		or nexoHum:GetState() == Enum.HumanoidStateType.Swimming 
	then
		Player.Swimming = true
	else
		Player.Swimming = false
	end

	local ascent = ActionHandler.IsKeyDownBool(Enum.KeyCode.Space) and 1.5 or 1
	self.Buoyancy.Enabled = Player.Swimming
	self.Buoyancy.Force = Vector3.new(0,1,0) * Player:GetWeight() * ascent

	hum.AutoRotate = false
	nexoHum.AutoRotate = false
	nexoHum:Move(self.MoveVector)

	if Player.Flying then
		threshold *= 12
	end

	if tick() >= massExecuteTime then
		Player:UpdateMass()
		massExecuteTime = tick() + 1 / massPollRate
	end
	if tick() >= moduleExecuteTime then
		self.LayerA:UpdateModule(Player:GetAnimationModule())
		moduleExecuteTime = tick() + 1 / updateModuleRate
	end
	detectFling(threshold)
end


function PlayerController:ProcessInputs()
	local Settings = ControllerSettings:GetSettings()

	if not debounce then
		if ActionHandler.IsKeyDownBool(HRPFlingButton) then
			self.ToggleFling = not self.ToggleFling
			SendNotification("ToggleFling", tostring(self.ToggleFling), "Close")
			debounce = true
			task.delay(0.2, function() debounce = false end)
		elseif ActionHandler.IsKeyDownBool(LimbFlingButton) then
				self.LimbFling = not self.LimbFling
				SendNotification("LimbFling", tostring(self.LimbFling), "Close")
				debounce = true
				task.delay(0.2, function() debounce = false end)
		elseif ActionHandler.IsKeyDownBool(Enum.KeyCode.BackSlash) then
			self.LerpEnabled = not self.LerpEnabled
			debounce = true
			--print("LerpEnabled:", self.LerpEnabled)
			task.delay(0.2, function() debounce = false end)
		elseif ActionHandler.IsKeyDownBool(Settings.debugButton) then
			self:ToggleDebug()
			task.delay(0.2, function() debounce = false end)
		end
	end
end


function PlayerController:StopAllModules()
	for i, module in pairs(self.Modules) do
		module:Stop()
	end
end


function PlayerController:RunUpdateTable()
	for i, module in pairs(self.Modules) do
		module:Update()
	end
end


function PlayerController:ProcessAfterStates()
	self:Invisible()
end


function PlayerController:Animate()
	local char = Player.getCharacter()
	
	self:LeanCharacter(char)

	self.LayerA:Animate()
	self.DanceLayer:Animate()

	self.LayerA.looking = Player.Looking

	self.LayerB:Animate()

	self.VRLayer:Update()
end


function PlayerController:Update()
	if Player:GetState("Respawning") then 
		self:Respawn()
		return 
	end

    local char = Player.getCharacter()
	local nexoChar = Player.getNexoCharacter()

	self:Fly()

	self:ProcessInputs()

	self:ProcessStates(char, nexoChar)

	if self.ResetTransform then
		self.RightArm:ResetTransform()
		self.LeftArm:ResetTransform()
	end

	--self.RightArm:Destroy()
	--self.LeftArm:Destroy()

--	self.ResetTransform = true

	if EmoteController.PointRight then
		self.RightArm:Solve(Mouse.Hit.Position, CFrame.Angles(0, 0, math.pi / 2))
	end
	if EmoteController.PointLeft then
		self.LeftArm:Solve(Mouse.Hit.Position, CFrame.Angles(0, 0, -math.pi / 2))
	end
--	self.RightArm:Solve(self.AttackPosition)
--	self.LeftArm:Solve(self.AttackPosition)

	EmoteController:Update()
	ActionHandler:Update()

	self:RunUpdateTable()
	
	self:ProcessAfterStates()

	Network:Debug(DEBUG)
end    


function PlayerController:OnCrouch()
	local motionName = Player:GetEnabledLocomotionState():GetName()
	if motionName == "Idling" then
		Player:GetAnimation("Idle"):Stop()
		Player:GetAnimation("FightIdle"):Stop()
		Player:GetAnimation("CrouchIdle"):Play()
	elseif motionName == "Walking" or Player.Running:GetState() or Player.Sprinting:GetState() then 
		Player:GetAnimation("Run"):Pause()
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Sprint"):Pause()
		Player:GetAnimation("CrouchWalk"):Play()
	end
end


function PlayerController:StoppedCrouch()
	local motionName = Player:GetEnabledLocomotionState():GetName()
	Player:GetAnimation("CrouchIdle"):Stop()

	if motionName == "Idling" then
		Player:GetAnimation("Idle"):Play()
	elseif motionName == "Walking"  then 
		Player:GetAnimation("CrouchWalk"):Stop()
		Player:GetAnimation("Walk"):Play()
	elseif Player.Running:GetState() or Player.Sprinting:GetState() then
		if Player.Running:GetState() then 
			Player:GetAnimation("Run"):Play() 
		else 
			Player:GetAnimation("Sprint"):Play()
		end
	end
end


function PlayerController:OnClimb()
	Player:GetAnimation("Climb"):Play()
end


function PlayerController:OnIdle()
	--print("Idling")
	--print(fallingSpeed)
	if Player.Dancing then return end
	if Player.Flying then
		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyIdle"):Play()
	else
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyIdle"):Stop()
		Player:GetAnimation("FlyFall"):Stop()
		Player:GetAnimation("FlyJump"):Stop()

		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Jump"):Stop()
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Walk").Weight = 0

		if Player.FightMode:GetState() then
			Player:GetAnimation("Idle"):Stop()
			Player:GetAnimation("FightIdle"):Play()
		else
			Player:GetAnimation("Idle"):Play()
			Player:GetAnimation("Idle"):AdjustWeight(1, 1)
			Player:GetAnimation("FightIdle"):Stop()
		end
		
		if Player:GetStateClass("Idling").PreviousState:GetName() == "Falling" then
			
			if math.abs(fallingSpeed) > 150 then
				Player.Landing = true
				Player:GetAnimation("LandHard"):Play()
				--print("Landed HARD")
			else
				Player.Landing = true
				Player:GetAnimation("LandSoft"):Play()
				--print("Landed")
			end
		end	
	end
end


function PlayerController.OnStopAnimation(animation: Animation)
	if animation.Name == "Roll" or animation.Name:find("Flip") or animation.Name == "Slide" then
		--print("Flipped")
		Player.Dodging = false
		Player.Flipping = false
	elseif animation.Name:find("Land") then
		Player.Landing = false
	elseif animation.Name:find("Stop") then
		Player.Slowing = false
	end
end


local function delayStopAnim(anim: Animation)
	if Player:GetEnabledLocomotionState():GetName() == "Idling" then
		Player.Slowing = true
		anim:Play()
	end
end


function PlayerController:ResetLocomotionScalars()
	for name, _ in pairs(self.Settings) do
		self.Settings[name] = self.DefaultSettings[name]
	end
end


function PlayerController.StoppedState(state)
	if state:GetName() == "Sprinting" then
		--print("Skidded HARD")
		Player:GetAnimation("FlySprint"):Stop()
		Player:GetAnimation("Sprint").Weight = 0
		Player:GetAnimation("Sprint"):Stop()
		Player:GetAnimation("Sprint").Weight = 0
		if Player.Flying then
			task.delay(0.05, delayStopAnim, Player:GetAnimation("FlyRunStop"))
		else
			task.delay(0.05, delayStopAnim, Player:GetAnimation("SprintStop"))
		end
	elseif state:GetName() == "Running" then
		--print("Skidded")
		Player:GetAnimation("FlyRun"):Stop()
		Player:GetAnimation("FlyRun").Weight = 0
		Player:GetAnimation("Run"):Stop()
		Player:GetAnimation("Run").Weight = 0
		if Player.Flying then
			task.delay(0.05, delayStopAnim, Player:GetAnimation("FlyRunStop"))
		else
			task.delay(0.05, delayStopAnim, Player:GetAnimation("SprintStop"))
		end
	elseif state:GetName() == "Walking" then
		--print("Skidded")
		Player:GetAnimation("FlyWalk"):Stop()
		Player:GetAnimation("Walk"):Stop()
		Player:GetAnimation("CrouchWalk"):Stop()
		if not Player.Crouching:GetState() then
			if Player.Flying then
				task.delay(0.05, delayStopAnim, Player:GetAnimation("FlyWalkStop"))
			else
				task.delay(0.05, delayStopAnim, Player:GetAnimation("WalkStop"))
			end
		end
	elseif state:GetName() == "FightMode" then
		Player:GetAnimation("FightIdle"):Stop()
		Player:GetAnimation("Idle"):Play()
	elseif state:GetName() == "Attacking" then
		if Player.FightMode:GetState() then
			Player:GetAnimation("FightIdle"):Play()		
			Player:GetAnimation("Idle"):Stop()
		else
			Player:GetAnimation("FightIdle"):Stop()
			Player:GetAnimation("Idle"):Play()
		end
	elseif state:GetName() == "Climbing" then
		Player:GetAnimation("Climb"):Pause()
	end
end


function PlayerController:OnWalk()
	if Player.Flying then
		Player:GetAnimation("Fall"):Stop()
		Player:GetAnimation("Jump"):Stop()

		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyWalk"):Play()
	elseif Player.Crouching:GetState() then
		Player:GetAnimation("CrouchFall"):Pause()
		Player:GetAnimation("CrouchJump"):Stop()
		Player:GetAnimation("CrouchWalk"):Play()		
	else
		Player:GetAnimation("Walk"):AdjustWeight(1, 1)
		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Jump"):Stop()
		Player:GetAnimation("Walk"):Play()
	end
end


function PlayerController:OnJump()
	if Player.Flying then
		--print("FlyJump")
		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyJump"):Play()
	else
		--print("Jump")
		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Jump"):Play()
	end
end


function PlayerController:OnFall()
	if Player.Flying then
		--print("FlyFall")
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyFall"):Play()
	else
		--print("Fall")
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Fall"):Play()
	end
end


function PlayerController:Init(canClickFling)
	if self.Initialized then return end
	local Settings = ControllerSettings:GetSettings()

    canClickFling = canClickFling or false

	print("Loading Player")
	setPhysicsOptimizations()
	Player:HookFramerate()
	if Player.getHumanoid().RigType == Enum.HumanoidRigType.R15 then
		nexoConnections = R15Reanim(canClickFling, self)
	else
		nexoConnections = R6Reanim(canClickFling, self)
		--R6Legs, LeftLeg, RightLeg = R6IKController.givePlayerIK()
		--AnimationController.R6Legs = R6Legs
	end
	self.LayerA = AnimationController.new(Player.AnimationModule)
	self.LayerB = AnimationController.new()
	self.DanceLayer = AnimationController.new(false)
	self.VRLayer = VRController.new()
	PlayerController.Initialized = false

	self.RightArm = IKArmController.new(Player.getNexoCharacter(), "Right", "Arm")
	self.LeftArm = IKArmController.new(Player.getNexoCharacter(), "Left", "Arm")
	self.LeftLeg = IKLegController.new(Player.getNexoCharacter(), "Left", "Leg")
	self.RightLeg = IKLegController.new(Player.getNexoCharacter(), "Right", "Leg")

	coroutine.resume(Network["PartOwnership"]["Enable"])
	
	initializeControls()
	previousCFrame = Player.getNexoHumanoidRootPart().CFrame

    connection = Thread.DelayRepeat(Settings.DT, self.Update, self)
	animationConnection = RunService.Heartbeat:Connect(function() self:Animate() end)
	ActionHandler:Init()
	EmoteController:Init()

	self:_InitializeStates()

	self.VRLayer:EnableVR()

	self.Initialized = true
end


function PlayerController:CleanConnections()

end


function PlayerController:Respawn()
	print("Respawning")
    local char = game:GetService("Players").LocalPlayer.Character

	local oldCFrame = previousCFrame

	SendNotification("Respawning")

	if connection then
		connection:Disconnect()
	end

	if animationConnection then
		animationConnection:Disconnect()
	end

	for i, conn in pairs(nexoConnections)do 
		conn:Disconnect()
	end 

	table.clear(nexoConnections)

	Network:RemoveParts()
	coroutine.resume(Network["PartOwnership"]["Disable"])

	if char:FindFirstChildOfClass("Humanoid") then
		char:FindFirstChildOfClass("Humanoid"):ChangeState(15) 
	end

	ActionHandler:Stop()
	EmoteController:Stop()
	self.LayerA:Destroy()
	self.LayerB:Destroy()
	self.DanceLayer:Destroy()
	self.VRLayer:Destroy()

	self:StopAllModules()
	
	-- This triggers respawn of the character
	char:ClearAllChildren()
	local newChar = Instance.new("Model")
	newChar.Parent = workspace
	game:GetService("Players").LocalPlayer.Character = newChar
	task.wait()
	game:GetService("Players").LocalPlayer.Character = char
	newChar:Destroy()

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.CFrame = oldCFrame
	spawnLocation.Transparency = 0.5
	spawnLocation.Anchored = true
	spawnLocation.Parent = workspace
	Player.getPlayer().RespawnLocation = spawnLocation

	lostOwnershipLocation:Destroy()

	respawnConnection = Player.getPlayer().CharacterAdded:Connect(function(character)
		local hrp = character:WaitForChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = oldCFrame			
			Player.getCharacter():SetPrimaryPartCFrame(oldCFrame)
		end
		spawnLocation:Destroy()
		respawnConnection:Disconnect()
	end)

	task.wait(0.5)
	Player:SetState("Respawning", false)
	Player:CleanStates()
	Player:UnhookFramerate()

	if getgenv then
		getgenv().Running = false
	end
	self.Initialized = false
end    


return PlayerController