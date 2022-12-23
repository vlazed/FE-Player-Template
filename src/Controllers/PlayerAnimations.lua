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
        PlayerAnimations[v.Name] = Animation.new(v.Name, require(v), 24, true)
    end
end

PlayerAnimations.Emotes = {}

for i,emote in ipairs(directory.Emotes:GetChildren()) do
    PlayerAnimations.Emotes[emote.name:lower()] = Animation.new(emote.name, require(emote), require(emote).Properties.Framerate, true)
end

return PlayerAnimations