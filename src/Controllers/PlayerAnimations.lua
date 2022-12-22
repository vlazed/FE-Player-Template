local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Animation = require(Project.Controllers.Animations.Animation)

local PlayerAnimations = {}

local directory = script.Parent.Animations

if game:GetService("Players").LocalPlayer.Character.Humanoid.RigType == Enum.HumanoidRigType.R6 then
    directory = directory.R6
else
    directory = directory.R15
end

for i,v in ipairs(directory:GetChildren()) do
    if v:IsA("ModuleScript") then
        --print(v)
        PlayerAnimations[v.Name] = Animation.new(v.Name, require(v), require(v).Properties.Framerate, true)
    end
end

--[[
PlayerAnimations.Walk = require(directory.Walk)
PlayerAnimations.Jump = require(directory.Jump)
PlayerAnimations.Fall = require(directory.Fall)
PlayerAnimations.Sprint = require(directory.Sprint)
PlayerAnimations.Run = require(directory.Run)
PlayerAnimations.Idle = require(directory.Idle)
PlayerAnimations.Roll = require(directory.Roll)

PlayerAnimations.FlyIdle = require(directory.FlyIdle)
PlayerAnimations.FlyWalk = require(directory.FlyWalk)
PlayerAnimations.FlySprint = require(directory.FlySprint)
PlayerAnimations.FlyFall = require(directory.FlyFall)
PlayerAnimations.FlyJump = require(directory.FlyJump)
PlayerAnimations.Flip = require(directory.Flip)
--]]

PlayerAnimations.Emotes = {}

for i,emote in ipairs(directory.Emotes:GetChildren()) do
    PlayerAnimations.Emotes[emote.name:lower()] = Animation.new(emote.name, require(emote), true)
end

return PlayerAnimations