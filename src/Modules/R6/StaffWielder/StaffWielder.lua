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

local StaffWielder = {}

StaffWielder.Initialized = false

--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow loses the accessory.
--]]
local Staff = "Giant Sword Catcher"

local Animations = script.Parent.Animations
local Equipped = Animations.Equipped
local Unequipped = Animations.Unequipped
local filterTable = {}

StaffWielder.PlayerAnimator = AnimationController.new(true)

StaffWielder.Idle = require(Equipped.Hold)

StaffWielder.Unequipp = require(Equipped.Unequip)

StaffWielder.Equipp = require(Unequipped.Equip)

StaffWielder.Sit = require(Unequipped.Sit)

StaffWielder.Keybinds = {
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
StaffWielder.UnequippedAnimations = {
	Walk = require(Unequipped.Walk),
	Run = require(Unequipped.Run),
	Sprint = require(Unequipped.Sprint),
	Jump = require(Unequipped.Jump),
	Fall = require(Unequipped.Fall),
    Idle = require(Unequipped.Hold),
    Roll = require(Unequipped.DodgeGround),
    Emotes = {}
}
StaffWielder.EquippedAnimations = {
	Walk = require(Equipped.Walk),
	Run = require(Equipped.Run),
	Sprint = require(Equipped.Sprint),
	Jump = require(Equipped.Jump),
	Fall = require(Equipped.Fall),
    Idle = require(Equipped.Hold),
    Roll = require(Equipped.DodgeGround),
    Emotes = {}
}

StaffWielder.EquippedLightAttacks = {
    require(Equipped.LightAttackA),
    require(Equipped.LightAttackB)
}

StaffWielder.UnequippedLightAttacks = {
    require(Unequipped.LightAttackA),
    require(Unequipped.LightAttackB),
    require(Unequipped.LightAttackC),
    require(Unequipped.LightAttackD),
}

StaffWielder.EquippedHeavyAttacks = {
    require(Unequipped.HeavyAttackA),
    require(Unequipped.HeavyAttackB),
    require(Unequipped.HeavyAttackC),
    require(Unequipped.HeavyAttackD),
}

StaffWielder.UnequippedHeavyAttacks = {
    require(Unequipped.HeavyAttackA),
    require(Unequipped.HeavyAttackB),
    require(Unequipped.HeavyAttackC),
    require(Unequipped.HeavyAttackD),
}

StaffWielder.LightAttacks = {}
StaffWielder.HeavyAttacks = {}

StaffWielder.AttackIndex = 1

StaffWielder.Equipping = false
StaffWielder.Unequipping = false

StaffWielder.Equipped = false
StaffWielder.Attacking = false
StaffWielder.Sitting = false

local attack

for i,emote in ipairs(Unequipped.Parent.Emotes:GetChildren()) do
    StaffWielder.UnequippedAnimations.Emotes[emote.name:lower()] = require(emote)
end

for i,emote in ipairs(Equipped.Parent.Emotes:GetChildren()) do
    StaffWielder.EquippedAnimations.Emotes[emote.name:lower()] = require(emote)
end

--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function StaffWielder:ProcessInputs()
    if Player.Focusing or Player.Emoting then return end

    if ActionHandler.IsKeyDownBool(EquipButton) then
        if not self.Equipped and not self.Equipping then
            self.Unequipping = false
            self.PlayerAnimator.i = 1
            self.Equipping = true
        elseif self.Equipped and not self.Unequipping then
            self.Equipping = false
            self.PlayerAnimator.i = 1
            self.Unequipping = true
        end
    elseif ActionHandler.IsKeyDownBool(SitButton) then
        self.Sitting = not self.Sitting
    end

    if ActionHandler.IsKeyDownBool(LightAttackButton) and not Player.Attacking then
        self.PlayerAnimator.i = 1
        self.PlayerAnimator.speed = 1
        attack = self.LightAttacks[self.AttackIndex].Keyframes
        Player.Attacking = true
        print(attack[#attack]["Time"])
        task.delay(attack[#attack]["Time"]-attack[#attack]["Time"]/2,function()
            Player.Attacking = false
            self.AttackIndex = (self.AttackIndex - 1 + (1 % #self.LightAttacks) + #self.LightAttacks) % #self.LightAttacks + 1
            self.PlayerAnimator.speed = 1
        end)
    elseif ActionHandler.IsKeyDownBool(HeavyAttackButton) and not Player.Attacking then
        self.PlayerAnimator.i = 1
        self.PlayerAnimator.speed = 1.175
        attack = self.HeavyAttacks[self.AttackIndex].Keyframes
        Player.Attacking = true
        --print(attack[#attack]["Time"])
        task.delay((attack[#attack]["Time"]-attack[#attack]["Time"]/3)/self.PlayerAnimator.speed,function()
            Player.Attacking = false
            self.AttackIndex = (self.AttackIndex - 1 + (1 % #self.HeavyAttacks) + #self.HeavyAttacks) % #self.HeavyAttacks + 1
            self.PlayerAnimator.speed = 1
        end)
    end
    
end


--[[
    An example of a state processing function. 
--]]
function StaffWielder:ProcessStates(char, AccessoryStaff)
    
    if self.Sitting then
        self.lastKFTable = PlayerController.LayerA.KFTable
        Player.Transition(3)
        self.PlayerAnimator:Animate(
            self.Sit.Keyframes, 
            true, 
            30 * Player:GetAnimationSpeed(), 
            filterTable
        )
    end

    if self.Equipping then
        self.AttackIndex = 1
        print("Equipping")
        self.PlayerAnimator:Animate(self.Equipp.Keyframes, true, 30 * Player:GetAnimationSpeed(), filterTable)
        task.delay(25/30, function() self:Equip() end)
        task.delay(
            self.Equipp.Keyframes[#self.Equipp.Keyframes]["Time"],
            function() 
                self.Equipping = false 
            end
        )
    end

    if self.Unequipping then
        self.AttackIndex = 1
        print("Unequipping")
        self.PlayerAnimator:Animate(self.Unequipp.Keyframes, true, 30 * Player:GetAnimationSpeed(), filterTable)
        task.delay(25/30, function() self:Unequip() end)
        task.delay(
            self.Equipp.Keyframes[#self.Equipp.Keyframes]["Time"],
            function() 
                self.Unequipping = false 
            end
        )
    end

    --print(self.AttackIndex)

    if self.Equipped and AccessoryStaff then
        self.LightAttacks = self.EquippedLightAttacks
        self.HeavyAttacks = self.EquippedHeavyAttacks
        attack = self.LightAttacks[self.AttackIndex].Keyframes
        local nexoStaff = Player.getNexoCharacter():FindFirstChild(AccessoryStaff.Name)

        AccessoryStaff.Handle.CFrame = 
        char["Right Arm"].CFrame * char["Right Arm"].RightGripAttachment.CFrame 
            * AccessoryStaff.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
            * CFrame.fromOrientation(90, -0, 45)
            * CFrame.fromOrientation(1, 1, 0)
            * CFrame.new(1.5,1.5,0):Inverse()
        
        nexoStaff.Handle.CFrame = 
            char["Right Arm"].CFrame * char["Right Arm"].RightGripAttachment.CFrame 
                * AccessoryStaff.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
                * CFrame.fromOrientation(90, -0, 45)
                * CFrame.fromOrientation(1, 1, 0)
                * CFrame.new(1.5,1.5,0):Inverse()
    else
        self.LightAttacks = self.UnequippedLightAttacks
        self.HeavyAttacks = self.UnequippedHeavyAttacks
    end

    if Player.Attacking then
        self.PlayerAnimator.looking = false
        if self.Equipped and AccessoryStaff then
            char.HumanoidRootPart.Position = AccessoryStaff.Handle.Position    
        else
            char.HumanoidRootPart.Position = char.Torso.Position
        end
        self.PlayerAnimator:Animate(attack, true, 20 * Player:GetAnimationSpeed(), filterTable)
    end
        
    self.PlayerAnimator.looking = true
end

function StaffWielder:Unequip()
    self.Equipped = false
    filterTable[Staff] = nil
    Player.AnimationModule = self.UnequippedAnimations
end


function StaffWielder:Equip()
    self.Equipped = true
    local AccessoryStaff = Player.getCharacter():FindFirstChild(Staff)
    if AccessoryStaff then
        filterTable[Staff] = AccessoryStaff
    end
    Player.AnimationModule = self.EquippedAnimations
end

--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function StaffWielder:Update()
    local AccessoryStaff = Player.getCharacter():FindFirstChild(Staff)
    local char = Player.getCharacter()

    self:ProcessInputs()

    self:ProcessStates(char, AccessoryStaff)
end

function StaffWielder:Init()
    if self.Initialized then return end
    Player:SetAnimationModule(self.UnequippedAnimations)
    PlayerController.Modules[self] = self
    PlayerController:Init()
    self.Initialized = true
end


function StaffWielder:Stop()
    Player:ResetAnimationModule()
    PlayerController.Modules[self] = nil
    self.Initialized = false
end


return StaffWielder