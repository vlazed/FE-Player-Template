--[[
    Vlazed

    The following is an example module that interfaces with the template's controllers and provides its own animation package for
    movement. Every module must have the following functions:
        - An update function (StaffWielder:Update())
        - A process state function (processStates(args))
        - A process input function (processInputs(args))
        - An initialization function (StaffWielder:Init())
        - A stopping function (StaffWielder:Stop())
    
    In addition, all animation packages (folders with animation data) must have the following files, with a .lua extension:
        - Walk
        - Run
        - Sprint
        - Jump
        - Fall
        - Fly variants of the above (prefixed with Fly*Name* e.g. FlyWalk)
        - DodgeGround
        - DodgeAir
    If none of the above are provided, as a failsafe the Player will default to a set of animations found in Controllers/Animations

    The premise of a module is to allow the player to switch between different animation styles or modes without having to run
    different scripts. For example, this allows the player to
        - Switch between different fighting animations,
        - Equip different weapons on their character, or
        - Populate a keyboard with different emotes (with a known emote mapping).
--]]

local Project = script:FindFirstAncestor("FE-Player-Template")
local Player = require(Project.Player)
local PlayerController = require(Project.Controllers.PlayerController)
local ActionHandler = require(Project.Controllers.ActionHandler)
local AnimationController = require(Project.Controllers.AnimationController)

local MuayThai = {}

--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow loses the accessory.
--]]
local Staff = "Giant Sword Catcher"

local Animations = script.Parent.Animations
local filterTable = {}

MuayThai.PlayerAnimator = AnimationController.new()
MuayThai.Initialized = false

MuayThai.Keybinds = {
    Enum.KeyCode.Q,    -- Equip/Unequip
    Enum.KeyCode.F,    -- Light Attack
    Enum.KeyCode.G,    -- Heavy Attack
    Enum.KeyCode.Z,    -- Dodging
}

local EquipButton = Enum.KeyCode.Q
local LightAttackButton = Enum.KeyCode.F
local HeavyAttackButton = Enum.KeyCode.G
local DodgeButton = Enum.KeyCode.Z
local SitButton = Enum.KeyCode.C

--[[
    An example of an animation table with fields to access those animations. All animation tables
    must have the fields listed below. Access the wiki for a list of animation fields
--]]
MuayThai.Animations = {
	Walk = require(Animations.Walk),
	Run = require(Animations.Run),
	Sprint = require(Animations.Sprint),
	Jump = require(Animations.Jump),
	Fall = require(Animations.Fall),
    Idle = require(Animations.Hold),
    Roll = require(Animations.DodgeGround)
}

--[[
Bike.Tricks = {
    require(Animations.TrickA)
    require(Animations.TrickB)
}
--]]

MuayThai.AttackIndex = 1

--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function MuayThai:ProcessInputs()
    
end


--[[
    An example of a state processing function. 
--]]
function MuayThai:ProcessStates(char, AccessoryStaff)
    
end

--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function MuayThai:Update()
    local char = Player.getCharacter()

    self:ProcessInputs()

    self:ProcessStates(char)
end

function MuayThai:Init()
    if self.Initialized then return end
    Player.AnimationModule = self.Animations
    PlayerController.Modules[self] = self
    PlayerController:Init()
    MuayThai.Initialized = true
end


function MuayThai:Stop()
    Player:ResetAnimationModule()
    PlayerController.Modules[self] = nil
    self.Initialized = false
end


return MuayThai