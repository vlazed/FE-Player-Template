local Player = {}

Player.States = {
	["Idling"] = false,
	["Walking"] = false,
	["Sprinting"] = false,
	["Jumping"] = false,
	["Falling"] = false,
	["Respawning"] = false
}

--[[
	Add custom player states here
--]]
Player.Blocking = false
Player.Attacking = false
Player.FightMode = false
Player.Following = false

function Player.getPlayer()
	return game.Players.LocalPlayer
end


function Player.getCharacter()
	return Player.getPlayer().Character
end


function Player.getNexoCharacter()
	return workspace.Camera.CameraSubject.Parent
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