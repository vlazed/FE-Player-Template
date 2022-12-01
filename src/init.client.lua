print("FE Player Template v1.0")
task.wait(0.1)

local RunService = game:GetService("RunService")

local Settings = {
    respawnButton = Enum.KeyCode.Minus,
    sprintButton = Enum.KeyCode.LeftShift,
    flightButton = Enum.KeyCode.F,
    crouchButton = Enum.KeyCode.LeftControl,
    ascendButton = Enum.KeyCode.Space,
    dodgeButton = Enum.KeyCode.Z,

    DT = 0.01,
    runSpeed = 50,
    sprintSpeed = 1000,
    walkSpeed = 16,
    jumpPower = 50,
    sprintJump = 300,
    ascentSpeed = 10,
}

local PlayerController = require(script.Controllers.PlayerController)

local ControllerSettings = require(script.Controllers.ControllerSettings)
ControllerSettings.SetSettings(Settings)
local App = require(script.Components.App)

if RunService:IsStudio() then
    if script.Parent.Name == "NexoPD" then
        return
    end    
end

PlayerController:Init()
App:Init()