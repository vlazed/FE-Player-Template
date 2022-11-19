print("FE Player Template v0.1")
task.wait(1)

local Settings = {
    respawnButton = Enum.KeyCode.Minus,
    sprintButton = Enum.KeyCode.LeftShift,

    DT = 0.01,
    sprintSpeed = 100,
    walkSpeed = 16,
    jumpPower = 50,
    sprintJump = 300,
}

local ControllerSettings = require(script.Controllers.ControllerSettings)
ControllerSettings.SetSettings(Settings)

local PlayerController = require(script.Controllers.PlayerController)


PlayerController:Init()
