local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local ControllerSettings = require(Project.Controllers.ControllerSettings)
local Player = require(Project.Player)

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local prevSettings = {}

local ActionHandler = {}

ActionHandler.Keybinds = {}

function table_eq(table1, table2)
    local avoid_loops = {}
    local function recurse(t1, t2)
       -- compare value types
       if type(t1) ~= type(t2) then return false end
       -- Base case: compare simple values
       if type(t1) ~= "table" then return t1 == t2 end
       -- Now, on to tables.
       -- First, let's avoid looping forever.
       if avoid_loops[t1] then return avoid_loops[t1] == t2 end
       avoid_loops[t1] = t2
       -- Copy keys from t2
       local t2keys = {}
       local t2tablekeys = {}
       for k, _ in pairs(t2) do
          if type(k) == "table" then 
            table.insert(t2tablekeys, k) 
        end
          t2keys[k] = true
       end
       -- Let's iterate keys from t1
       for k1, v1 in pairs(t1) do
          local v2 = t2[k1]
          if type(k1) == "table" then
             -- if key is a table, we need to find an equivalent one.
             local ok = false
             for i, tk in ipairs(t2tablekeys) do
                if table_eq(k1, tk) and recurse(v1, t2[tk]) then
                   table.remove(t2tablekeys, i)
                   t2keys[tk] = nil
                   ok = true
                   break
                end
             end
             if not ok then return false end
          else
             -- t1 has a key which t2 doesn't have, fail.
             if v2 == nil then return false end
             t2keys[k1] = nil
             if not recurse(v1, v2) then return false end
          end
       end
       -- if t2 has a key which t1 doesn't have, fail.
       if next(t2keys) then return false end
       return true
    end
    return recurse(table1, table2)
end


local function bool_to_number(val)
    return val and 1 or 0
end


function ActionHandler.IsKeyDownBool(keycode)
    return UserInputService:IsKeyDown(keycode)
end


function ActionHandler.IsKeyDown(keycode)
    return bool_to_number(ActionHandler.IsKeyDownBool(keycode))
end


function ActionHandler:Update()
    
    local Settings = ControllerSettings.GetSettings()
    
    if table_eq(Settings, prevSettings) then 
        --print("Tables equal") 
        return 
    end

    prevSettings = Settings
    
    ContextActionService:UnbindAction("Listen")
    ContextActionService:BindAction(
        "Listen", 
        ActionHandler.Listen, 
        false, 
        Settings.respawnButton, 
        Settings.sprintButton, 
        Settings.flightButton, 
        Settings.crouchButton,
        Settings.dodgeButton,
        table.unpack(ActionHandler.Keybinds)
    )
end


function ActionHandler.DelayListen(an, is, io)
    if is == Enum.UserInputState.Begin then    
        if io.KeyCode == prevSettings.sprintButton then
            --print("Sprinting")
            Player.Running:SetState(false)
            Player.Sprinting:SetState(true) 
        elseif io.KeyCode == Enum.KeyCode.Space then
            Player.Flying = not Player.Flying
        end
    end
end

-- TODO: Implement function to prevent keybinds when the player is typing
function ActionHandler:IsTyping()
    return
end


function ActionHandler.Listen(an, is, io)
    if is == Enum.UserInputState.Begin then
        if io.KeyCode == prevSettings.respawnButton then
            --print("Respawning")
            Player:SetState("Respawning", true)
        elseif io.KeyCode == prevSettings.sprintButton then
            --print("Sprinting")
            Player.Running:SetState(true)
        elseif io.KeyCode == Enum.KeyCode.Space then
            --print("Jumping")
            Player:SetState("Jumping", true)
            task.delay(0.1, function()
                Player:SetState("Jumping", false)
            end)
        elseif io.KeyCode == prevSettings.crouchButton then
            Player.Crouching:SetState(not Player.Crouching:GetState())
        elseif io.KeyCode == prevSettings.dodgeButton then
            local contraction = (Player.Sprinting:GetState() or Player:GetState("Walking") or Player.Running:GetState()) and 10 or 0
            Player.Dodging = true
            if Player:OnGround() then
                local anim = Player:GetAnimation("Roll")
                anim.UpperBound = anim.Length - contraction
            else
                local anim = Player:GetAnimation("Flip")
                anim.UpperBound = anim.Length - contraction
            end
        end
    elseif is == Enum.UserInputState.End then
        if io.KeyCode == prevSettings.sprintButton then
            --print("Not sprinting")
            Player.Running:SetState(false)
            Player.Sprinting:SetState(false)
        end
        ContextActionService:BindAction(
            "DelayListen", 
            ActionHandler.DelayListen, 
            false, 
            prevSettings.sprintButton, 
            Enum.KeyCode.Space
        )
        task.delay(0.1, function()
            ContextActionService:UnbindAction("DelayListen")
        end)
    end
end


function ActionHandler:Stop()
    ContextActionService:UnbindAction("Listen")
end


function ActionHandler:Init()
    local Settings = ControllerSettings.GetSettings()
    prevSettings = Settings

    ContextActionService:BindAction(
        "Listen", 
        ActionHandler.Listen, 
        false, 
        Settings.respawnButton, 
        Settings.sprintButton, 
        Settings.flightButton, 
        Settings.crouchButton,
        Settings.dodgeButton,
        Enum.KeyCode.Space,
        table.unpack(ActionHandler.Keybinds)
    )
end

return ActionHandler