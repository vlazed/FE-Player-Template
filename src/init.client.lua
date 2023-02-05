if game:GetService("RunService"):IsStudio() then
    print("Running in Roblox Studio")
elseif not Drawing then
    print("Exploit not supported")
    return    
end

if getgenv then
    getgenv().PROJECT_NAME = "FE-Player-Template"
    print(getgenv().PROJECT_NAME)
else
    _G.PROJECT_NAME = "FE-Player-Template"
end

print("FE Player Template v1.0")
task.wait(0.25)

local RunService = game:GetService("RunService")

local Settings = {
    respawnButton = Enum.KeyCode.Minus,
    sprintButton = Enum.KeyCode.LeftShift,
    flightButton = Enum.KeyCode.F,
    crouchButton = Enum.KeyCode.LeftControl,
    ascendButton = Enum.KeyCode.Space,
    dodgeButton = Enum.KeyCode.Z,
    copyButton = Enum.KeyCode.M,
    invisButton = Enum.KeyCode.N,
    debugButton = Enum.KeyCode.F2,

    DT = 0.01,

    RunSpeed = 50,
    SprintSpeed = 1000,
    IdleSpeed = 0,
    WalkSpeed = 16,
    JumpPower = 50,
    RunJumpPower = 125,
    SprintJumpPower = 300,
    AscentSpeed = 10,
    IdleTweenTime = 0.25,
    WalkTweenTime = 0.25,
    RunTweenTime = 2,
    SprintTweenTime = 10,

    IdleTiltRate = 10,
	FallTiltRate = 3,
	JumpTiltRate = 3,
	WalkTiltRate = 2,
	RunTiltRate = 4,
	SprintTiltRate = 3,

    WalkTiltMagnitude = 0.25,
	RunTiltMagnitude = 4,
	SprintTiltMagnitude = 8,
	JumpTiltMagnitude = 0.1,

    MoveRate = 2,
}

local ControllerSettings = require(script.Controllers.ControllerSettings)
ControllerSettings.SetSettings(Settings)

local PlayerController = require(script.Controllers.PlayerController)

local App = require(script.Components.App)
local Mimic = require(script.Modules.Mimic)

if RunService:IsStudio() then
    if script.Parent.Name == "NexoPD" then
        return
    end    
end

--local SelectedModule = require(script.Modules.R6.Bike.Bike)

if getgenv then
    getgenv().PROJECT_NAME = "FE-Player-Template"
    if getgenv().Running then
        print("Already activated")
        return
    end
end

local success, err = pcall(function()
    PlayerController:Init()
    --SelectedModule:Init()
    Mimic:Init()
    App:Init()
end)

if getgenv then
    if not getgenv().Running and success then
        getgenv().Running = true
    end
end

if not success then
    if getgenv then
        getgenv().Running = false
    end
    error("An error has occurred while running this module: \n" .. tostring(err))
end
