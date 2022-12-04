local Thread = require(script.Parent.Util.Thread)
local PlayerAnimations = require(script.Parent.Controllers.PlayerAnimations)
local ControllerSettings = require(script.Parent.Controllers.ControllerSettings)

local Player = {}

Player.States = {
	["Idling"] = false,
	["Walking"] = false,
	["Jumping"] = false,
	["Falling"] = false,
	["Respawning"] = false,
}

--[[
	Add custom player states here
--]]
Player.Blocking = false
Player.Attacking = false
Player.FightMode = false
Player.Following = false
Player.Transitioning = false
Player.Flying = false
Player.Crouching = false
Player.Dodging = false
Player.Running = false
Player.Sprinting = false
Player.Dancing = false

Player.AnimationModule = PlayerAnimations
Player.InAir = false

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
	return workspace.Camera.CameraSubject.Parent
end


function Player:GetAnimation(animation)
	print(animation)
	if self.AnimationModule[animation] then
		return self.AnimationModule[animation]
	elseif self.AnimationModule.Emotes[animation] then
		return self.AnimationModule.Emotes[animation]
	elseif PlayerAnimations.Emotes[animation] then
		return PlayerAnimations.Emotes[animation]
	elseif PlayerAnimations[animation] then
		return PlayerAnimations[animation]
	end
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
	return ControllerSettings.GetSettings().DT * 100
end


function Player:InAir()
	local hrp = self.getNexoHumanoidRootPart()
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {hrp.Parent}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.IgnoreWater = false
	local raycastResult = workspace:Raycast(hrp.Position, Vector3.new(0,-1000,0), params)
	if raycastResult then
		return ((raycastResult.Position - hrp.Position).Magnitude > 5)
	else
		return true
	end	
end

function Player:SetAnimationModule(module)
	self.AnimationModule = module
end

function Player:ResetAnimationModule()
	self.AnimationModule = PlayerAnimations
end


function Player:ApplyImpulse(direction)
	self.getNexoHumanoidRootPart():ApplyImpulse(self.getHumanoidRootPart().Position + direction)
end


function Player:CFrameLerpToPosition(pos, alpha)
	self.getNexoHumanoidRootPart().CFrame:Lerp(CFrame.new(pos), alpha)
end


function Player.getHumanoid()
	return Player.getCharacter():FindFirstChildOfClass("Humanoid")
end


function Player.getNexoHumanoid()
	return Player.getNexoCharacter():FindFirstChildOfClass("Humanoid")
end


function Player.getHumanoidRootPart()
	return Player.getCharacter():FindFirstChild("HumanoidRootPart")
end


function Player.getNexoHumanoidRootPart()
	return Player.getNexoCharacter():FindFirstChild("HumanoidRootPart")
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


function Player.GetState(state)
	if Player.States[state] then
		return Player.States[state]
	end
end


function Player.SetState(targetState, value)
	for state, boolvalue in pairs(Player.States) do
		if state == targetState then
			Player.States[state] = value
		else
			Player.States[state] = false
		end
	end
end


function Player.setHumanoidAttribute(attribute: string, value: any)
	
end


function Player.tweenHumanoidAttribute(attribute: string, value: any, tweenInfo: table)
	
end

return Player