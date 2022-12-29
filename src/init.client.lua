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

    DT = 0.01,
    runSpeed = 50,
    sprintSpeed = 1000,
    walkSpeed = 16,
    jumpPower = 50,
    runJump = 125,
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

local SelectedModule = require(script.Modules.R6.ElegantSword.ElegantSword)

if getgenv then
    getgenv().PROJECT_NAME = "FE-Player-Template"
    if getgenv().Running then
        print("Already activated")
        return
    end
end

local success, err = pcall(function()
    PlayerController:Init()
    SelectedModule:Init()
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
    error("An error has occurred while running this module:", err)
end