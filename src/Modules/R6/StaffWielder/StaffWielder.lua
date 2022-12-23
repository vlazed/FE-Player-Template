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
        - Populate a keyboard with different emotes (with a known emote mapping), for instance to simulate playing notes.
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
local Animation = require(Project.Controllers.Animations.Animation)

local StaffWielder = {}
StaffWielder.Name = "Staff Wielder"

StaffWielder.Initialized = false

--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow lose the accessory.
--]]
local Staff = "Giant Sword Catcher"

local Animations = script.Parent.Animations
local Emotes = Animations.Emotes
local Equipped = Animations.Equipped
local Unequipped = Animations.Unequipped
local filterTable = {}

StaffWielder.Unequipp = Animation.new("Unequip", require(Equipped.Unequip), 30, true)
StaffWielder.Equipp = Animation.new("Equip", require(Unequipped.Equip), 30, true)
StaffWielder.Sit = Animation.new("Sit", require(Unequipped.Sit), 30, true)

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
    will need the fields listed below. Access the wiki for a list of animation fields
    - Walk
    - Run
    - Sprint
    - Jump
    - Fall
    - Idle
    - Roll
    - Flip

--]]

StaffWielder.UnequippedAnimations = {
    Emotes = {}
}

StaffWielder.EquippedAnimations = {
    Emotes = {}
}

StaffWielder.EquippedLightAttacks = {}

StaffWielder.UnequippedLightAttacks = {}

StaffWielder.EquippedHeavyAttacks = {}

StaffWielder.UnequippedHeavyAttacks = {}

function StaffWielder:_InitializeAnimations()
    PlayerController.LayerA:LoadAnimation(self.Sit)
    PlayerController.LayerA:LoadAnimation(self.Equipp)
    PlayerController.LayerA:LoadAnimation(self.Unequipp)

    for i,v in ipairs(self.EquippedLightAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    for i,v in ipairs(self.UnequippedLightAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    for i,v in ipairs(self.EquippedHeavyAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    for i,v in ipairs(self.UnequippedHeavyAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
end

local function populateEmoteTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name:lower()] = Animation.new(v.Name, animation, animation.Properties.Framerate, true)
        end    
    end
end

local function populateAnimationTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name] = Animation.new(v.Name, animation, animation.Properties.Framerate, true)                
        end
    end
end

local function populateAttackTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            table.insert(targetTable, Animation.new(v.Name, animation, animation.Properties.Framerate, true))                
        end
    end
end

populateAnimationTable(Unequipped:GetChildren(), StaffWielder.UnequippedAnimations)
populateAnimationTable(Equipped:GetChildren(), StaffWielder.EquippedAnimations)
populateEmoteTable(Emotes:GetChildren(), StaffWielder.UnequippedAnimations.Emotes)
populateEmoteTable(Emotes:GetChildren(), StaffWielder.EquippedAnimations.Emotes)
populateAttackTable(Unequipped.LightAttacks:GetChildren(), StaffWielder.UnequippedLightAttacks)
populateAttackTable(Unequipped.HeavyAttacks:GetChildren(), StaffWielder.UnequippedHeavyAttacks)
populateAttackTable(Equipped.LightAttacks:GetChildren(), StaffWielder.EquippedLightAttacks)
populateAttackTable(Equipped.HeavyAttacks:GetChildren(), StaffWielder.EquippedHeavyAttacks)

StaffWielder.LightAttacks = {}
StaffWielder.HeavyAttacks = {}

StaffWielder.AttackIndex = 1

StaffWielder.Equipping = false
StaffWielder.Unequipping = false

StaffWielder.Equipped = false
StaffWielder.Attacking = false
StaffWielder.Sitting = false

local attack

--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function StaffWielder:ProcessInputs()
    if Player.Focusing or Player.Emoting:GetState() then return end

    if ActionHandler.IsKeyDownBool(EquipButton) then
        print("EquipButton")
        if not self.Equipped and not self.Equipping then
            self.Unequipping = false
            self.Equipping = true
            self.Equipp:Stop()
            self.Equipp:Play()
            task.delay(25/30, function() self:Equip() end)
        elseif self.Equipped and not self.Unequipping then
            self.Equipping = false
            self.Unequipping = true
            self.Unequipp:Stop()
            self.Unequipp:Play()
            task.delay(25/30, function() self:Unequip() end)
        end
    elseif ActionHandler.IsKeyDownBool(SitButton) then
        print("SitButotn")
        self.Sitting = not self.Sitting
        if self.Sit:IsPlaying() then
            self.Sit:Stop()
        else
            self.Sit:Play()
        end
    end

    --print("Attacking:", Player.Attacking)
    if ActionHandler.IsKeyDownBool(LightAttackButton) and not Player.Attacking then
        attack = self.LightAttacks[self.AttackIndex]
        attack.Speed = 1.175
        attack:Play()
        Player:SetStateForDuration("FightMode", true, 4)
        Player.Attacking = true
        task.delay(attack.TimeLength/2, function()
            print("Setting to false")
            Player.Attacking = false
            self.AttackIndex = (self.AttackIndex - 1 + (1 % #self.LightAttacks) + #self.LightAttacks) % #self.LightAttacks + 1
        end)
    elseif ActionHandler.IsKeyDownBool(HeavyAttackButton) and not Player.Attacking then
        attack = self.HeavyAttacks[self.AttackIndex]
        attack.Speed = 1.175
        attack:Play()
        Player:SetStateForDuration("FightMode", true, 4)
        Player.Attacking = true
        task.delay(2*attack.TimeLength/3, function()
            Player.Attacking = false
            self.AttackIndex = (self.AttackIndex - 1 + (1 % #self.HeavyAttacks) + #self.HeavyAttacks) % #self.HeavyAttacks + 1
        end)
    end
end


--[[
    An example of a state processing function. 
--]]
function StaffWielder:ProcessStates(char, AccessoryStaff)
    if self.Equipped and AccessoryStaff then
        self.LightAttacks = self.EquippedLightAttacks
        self.HeavyAttacks = self.EquippedHeavyAttacks
        attack = self.LightAttacks[self.AttackIndex]
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
        if char.HumanoidRootPart then
            if self.Equipped and AccessoryStaff then
                char.HumanoidRootPart.Position = AccessoryStaff.Handle.Position    
            else
                char.HumanoidRootPart.Position = Player.getNexoHumanoidRootPart().CFrame:PointToWorldSpace(Vector3.new(0, 0, -2))
            end
        end
    end
end

function StaffWielder:Unequip()
    self.Equipped = false
    filterTable[Staff] = nil
    Player:SetAnimationModule(self.UnequippedAnimations)
    PlayerController.LayerA:UpdateModule(self.UnequippedAnimations)
    PlayerController.LayerA.FilterTable = filterTable
end


function StaffWielder:Equip()
    self.Equipped = true
    local AccessoryStaff = Player.getCharacter():FindFirstChild(Staff)
    if AccessoryStaff then
        filterTable[Staff] = AccessoryStaff
    end
    Player:SetAnimationModule(self.EquippedAnimations)
    PlayerController.LayerA:UpdateModule(self.EquippedAnimations)
    PlayerController.LayerA.FilterTable = filterTable
end

--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function StaffWielder:Update()
    --print("Update")
    local AccessoryStaff = Player.getCharacter():FindFirstChild(Staff)
    local char = Player.getCharacter()

    self:ProcessInputs()

    self:ProcessStates(char, AccessoryStaff)
end

function StaffWielder:Init()
    if self.Initialized then return end
    Player:SetAnimationModule(self.UnequippedAnimations)
    PlayerController.LayerA:UpdateModule(self.UnequippedAnimations)
    self:_InitializeAnimations()
    PlayerController.Modules[self] = self
    PlayerController:Init()
    self.Initialized = true
end


function StaffWielder:Stop()
    Player:ResetAnimationModule()
    PlayerController.Modules[self] = nil
    self.Initialized = false
end


function StaffWielder:__tostring()
    return self.Name
end


return StaffWielder