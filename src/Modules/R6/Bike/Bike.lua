--[[
    Vlazed

    This is an example custom locomotion module, which modifies the PlayerController's locomotion scalars
    to provide controllable biking speed via the W and S keys. This also changes the tilt and move vectors
    of the character on the bicycle.
--]]

local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Player = require(Project.Player)
local PlayerController = require(Project.Controllers.PlayerController)
local ActionHandler = require(Project.Controllers.ActionHandler)
local AnimationController = require(Project.Controllers.AnimationController)

local Bike = {}
Bike.Name = "Bike"
Bike.Type = "Movement"

--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow loses the accessory.
--]]
local Vehicle = "Bike"

local Animations = script.Parent.Animations
local filterTable = {}

local onBike = false

local BikeButton = Enum.KeyCode.R
local TrickButton = Enum.KeyCode.G

Bike.Initialized = false

--[[
    An example of an animation table with fields to access those animations. All animation tables
    must have the fields listed below. Access the wiki for a list of animation fields
--]]
Bike.Animations = {
	Walk = require(Animations.Walk),
	Run = require(Animations.Run),
	Sprint = require(Animations.Sprint),
	Jump = require(Animations.Jump),
	Fall = require(Animations.Fall),
    Idle = require(Animations.Hold),
    Roll = require(Animations.Roll)
}

--[[
Bike.Tricks = {
    require(Animations.TrickA)
    require(Animations.TrickB)
}
--]]

Bike.TrickIndex = 1

--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function Bike:ProcessInputs()
    
end


--[[
    An example of a state processing function. 
--]]
function Bike:ProcessStates(char, Accessory)
    
end

--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function Bike:Update()
    local char = Player.getCharacter()

    self:ProcessInputs()

    self:ProcessStates(char)
end


function Bike:SetLocomotionScalars()
end


function Bike:Init()
    if self.Initialized then return end
    Player.AnimationModule = self.Animations
    PlayerController.Modules[self] = self
    Bike:SetLocomotionScalars()
    PlayerController:Init()
    Bike.Initialized = true
end


function Bike:Stop()
    Player:ResetAnimationModule()
    PlayerController.Modules[self] = nil
    PlayerController:ResetLocomotionScalars()
    self.Initialized = false
end


return Bike