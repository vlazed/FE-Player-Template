local RunService = game:GetService("RunService")
local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Thread = require(Project.Util.Thread)
local PlayerAnimations = require(Project.Controllers.PlayerAnimations)
local Animation = require(Project.Controllers.Animations.Animation)
local ControllerSettings = require(Project.Controllers.ControllerSettings)
local State = require(Project.Util.State)
local Spring = require(Project.Util.Spring)
local Promise = require(Project.Packages.Promise)

local Player = {}

Player.States = {
	["Idling"] = State.new("Idling", false, true),
	["Walking"] = State.new("Walking", false, true),
	["Jumping"] = State.new("Jumping", false, true),
	["Falling"] = State.new("Falling", false, true),
	["Respawning"] = State.new("Respawning", false, true),
}

--[[
	Add custom player states here
--]]
Player.Blocking = false
Player.Attacking = State.new("Attacking", false)
Player.FightMode = State.new("FightMode", false)
Player.Following = false
Player.Transitioning = false
Player.Flying = false
Player.Crouching = State.new("Crouching", false)
Player.Dodging = false
Player.Running = State.new("Running", false)
Player.Sprinting = State.new("Sprinting", false)
Player.Dancing = false
Player.Looking = false
Player.Swimming = false
Player.Leaning = true

Player.Emoting = State.new("Emoting", false)
Player.Focusing = false
Player.ChatEmoting = State.new("ChatEmoting", false)
Player.Landing = false
Player.Slowing = false
Player.DodgeMoving = false
Player.Flipping = false
Player.SetCFrame = true
Player.Climbing = State.new("Climbing", false)

Player.Invisible = false

Player.DefaultModule = PlayerAnimations
Player.AnimationModule = PlayerAnimations

Player.Locked = false

Player.Mass = 0

local prevClock = os.clock()
local framerate = 60
local framerateSpring = Spring.new(0.5, 60)

local heartbeatConnection

function Player.getPlayer()
	return game.Players.LocalPlayer
end


function Player.getMouse()
	return Player.getPlayer():GetMouse()
end


function Player.getCharacter()
	return Player.getPlayer().Character
end


function Player.getNexoCharacter()
	return Player.getCharacter():FindFirstChild("CWExtra").NexoPD
end


function Player:GetAnimation(animation: string): Animation
	if self.AnimationModule[animation] then
		--print(self.AnimationModule[animation])
		return self.AnimationModule[animation]
	elseif self.AnimationModule.Emotes[animation:lower()] then
		--print(self.AnimationModule.Emotes[animation])
		return self.AnimationModule.Emotes[animation:lower()]
	elseif self.DefaultModule.Emotes[animation:lower()] then
		--print(PlayerAnimations.Emotes[animation:lower()])	
		return PlayerAnimations.Emotes[animation:lower()]
	elseif self.DefaultModule[animation] then
		--print(PlayerAnimations[animation])
		return PlayerAnimations[animation]
	else
		return Animation.new()
	end
end


function Player:GetDefaultEmotes()
	return PlayerAnimations.Emotes
end


function Player.Transition(delayTime)
	if Player.Transitioning then return end
	delayTime = delayTime or 0.25

	Player.Transitioning = true
	Thread.Delay(delayTime, function()
		Player.Transitioning = false
	end)
end


function Player:GetAnimationSpeed()
	return 1 -- ControllerSettings.GetSettings().DT * 100 * 60 / framerate
end


function Player:OnGround(length)
	length = length or 7

	local hrp = self.getNexoHumanoidRootPart()

	if not hrp then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {hrp.Parent, Player.getCharacter()}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.IgnoreWater = false
	params.RespectCanCollide = true
	local raycastResult = workspace:Raycast(hrp.Position, Vector3.new(0,-length,0), params)
	
	if raycastResult then
		return raycastResult
	end
end

function Player:SetAnimationModule(module)
	self.AnimationModule = module
end

function Player:GetAnimationModule()
	return self.AnimationModule
end

function Player:ResetAnimationModule()
	self.AnimationModule = PlayerAnimations
end


function Player:ConstructMotor(name, parent, part1, c0, c1)
	if parent[name] then return end
	
	local nexoChar = self.getNexoCharacter()
	local part0 = nexoChar[parent]
	local motor6D = Instance.new("Motor6D")
	motor6D.C0 = c0
	motor6D.C1 = c1
	motor6D.Part0 = part0
	motor6D.Part1 = part1
	motor6D.Enabled = true

	return motor6D
end


function Player:ApplyImpulse(direction)
	local hrp = self.getNexoHumanoidRootPart()
	if not hrp then return end
	
	hrp:ApplyImpulse(hrp.Position + direction)
end


function Player:CFrameLerpToPosition(pos, alpha)
	local hrp = self.getNexoHumanoidRootPart()
	if not hrp then return end
	
	hrp.CFrame:Lerp(CFrame.new(pos), alpha)
end


function Player.getHumanoid()
	local char = Player.getCharacter()
	if not char then return end

	return char:FindFirstChildOfClass("Humanoid")
end


function Player.getNexoHumanoid()
	local char = Player.getNexoCharacter()
	if not char then return end

	return char:FindFirstChildOfClass("Humanoid")
end


function Player:GetRigType()
	return Player.getHumanoid().RigType
end


function Player.getHumanoidRootPart()
	local char = Player.getCharacter()
	if not char then return end

	return char:FindFirstChild("HumanoidRootPart")
end


function Player.getNexoHumanoidRootPart()
	local char = Player.getNexoCharacter()
	if not char then return end
	return char:FindFirstChild("HumanoidRootPart")
end


function Player.getCharacterRootAttachment()
	local hrp = Player.getHumanoidRootPart()
	if not hrp then return nil end

	return hrp:FindFirstChild("RootAttachment") or hrp:FindFirstChild("RootRigAttachment")
end


function Player.getNexoCharacterRootAttachment()
	local hrp = Player.getNexoHumanoidRootPart()
	if not hrp then return nil end

	return hrp:FindFirstChild("RootAttachment") or hrp:FindFirstChild("RootRigAttachment")
end


function Player.getPlayerGui()
	return Player.getPlayer().PlayerGui
end


function Player.GetStateTable()
	return Player.States
end


function Player:GetStateClass(state)
	if self.States[state] then
		return self.States[state]
	end
end


function Player:GetEnabledLocomotionState()
	return State:GetEnabledLocomotionState()
end


function Player:GetState(state)
	return self:GetStateClass(state):GetState()
end


function Player:SetState(targetState, value)
	for state, boolvalue in pairs(Player.States) do
		if state == targetState then
			self:GetStateClass(state):SetState(value)
		else
			self:GetStateClass(state):SetState(false)
		end
	end
end


function Player:_SetStateThroughValue(states, value, duration)
	if typeof(states) == "string" then
		local state = states

		if self[state] ~= nil then
			self.Locked = task.spawn(function()
				if self[state].GetState then
					self[state]:SetState(value)
				else
					self[state] = value
				end
				task.wait(duration)
				if self[state].GetState then
					self[state]:SetState(not value)
				else
					self[state] = not value
				end
			end)
		
		end
	elseif typeof(states) == "table" then
		self.Locked = task.spawn(function()

			for i,state in pairs(states) do
				if self[state] ~= nil then
					self[state] = value
				end 
			end
			task.wait(duration)
			self.Locked = false
			for i,state in pairs(states) do
				if self[state] ~= nil then
					self[state] = not value
				end 
			end
		end)
	end
end


function Player:_SetStateThroughTable(states, values, duration)
	if typeof(states) == "string" then
		local state = states[1]

		if self[state] ~= nil then
			self.Locked = task.spawn(function()
				self[state] = values[1]
				task.wait(duration)
				self.Locked = false
				self[state] = not values[1]
			end)
		end
	elseif typeof(states) == "table" then
		self.Locked = task.spawn(function()
			for i,state in pairs(states) do
				if self[state] ~= nil then
					self[state] = values[i]
				end 
			end
			task.wait(duration)
			self.Locked = false
			for i,state in pairs(states) do
				if self[state] ~= nil then
					self[state] = not values[i]
				end 
			end
		end)
	end	
end


function Player:SetStateForDuration(states: any, value: any, duration: number)
	if self.Locked then task.cancel(self.Locked) end
	
	if typeof(value) == "boolean" then
		self:_SetStateThroughValue(states, value, duration)
	elseif typeof(value) == "table" then
		self:_SetStateThroughTable(states, value, duration)
	end
end


function Player.setHumanoidAttribute(attribute: string, value: any)
	
end


function Player.tweenHumanoidAttribute(attribute: string, value: any, tweenInfo: table)
	
end

function Player:GetFramerate()
	return framerate
end


function Player:HookFramerate()
	heartbeatConnection = RunService.RenderStepped:Connect(function(dt)
		framerate = framerateSpring:Update(dt, 1/dt)
		--print(framerate)
	end)
end


function Player:UnhookFramerate()
	heartbeatConnection:Disconnect()
end


function Player:UpdateMass()
	local mass = 0
	local char = self.getNexoCharacter()
	if not char then return end

	for i,instance in ipairs(char:GetDescendants()) do
		if instance:IsA("BasePart") then
			if instance.Massless then continue end
			mass += instance.Mass
		end
	end
	if mass ~= self.Mass then
		self.Mass = mass
	end
end


function Player:_initializeMass()
	local char = self.getCharacter()
	if not char then return end

	for i,instance in ipairs(char:GetDescendants()) do
		if instance:IsA("BasePart") then
			if instance.Massless then continue end
			self.Mass += instance.Mass
		end
	end
end


function Player:GetWeight()
	return self.Mass * workspace.Gravity
end

function Player:CleanStates()
	for i,state in pairs(self.States) do
		state:Remove()
	end
	for i,state in pairs(State.States) do
		state:Remove()
	end
end


Player:_initializeMass()

return Player