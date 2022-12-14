
local Players = game:GetService("Players") --define variables n shit
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Velocity = Vector3.new(17.325,17.325,17.325)
--[[
Network Library by 4eyes

The basic concepts of Network Ownership for anyone interested:
1. Parts not network owned by server or another player will be owned by the player closest to it.
2. To retain network ownership, you must be constantly sending physics packets or people may be able to take ownership, as your network is contested when you aren't sending physics packets.

Usage: Put this in your script and use Network.RetainPart(Part) on any part you'd like to retain ownership over, then just apply a replicating method of movement. Credit me if you'd like.
loadstring(game:HttpGet("https://raw.githubusercontent.com/your4eyes/RobloxScripts/main/Net_Library.lua"))()
--]]

--[[
    Converted the library into a modulescript-like format

    I had to adjust variable names to make it more readable.

    I added a function to remove everything from baseparts tbale

    I also added another function for network ownership
    https://v3rmillion.net/showthread.php?tid=1180572

    Thank you for the release!
    - Vlazed
--]]


local Network = {}
     
Network["BaseParts"] = {}
     
Network["Velocity"] = Velocity
     
function Network:RetainPart(Part) --function for retaining ownership of unanchored parts
    if Part:IsA("BasePart") and Part:IsDescendantOf(workspace) then
        local CParts = Part:GetConnectedParts()
        for _,CPart in pairs(CParts) do --check if part is connected to anything already in baseparts being retained
            if table.find(self["BaseParts"],CPart) then
                warn("[NETWORK] Did not apply PartOwnership to part, as it is already connected to a part with this method active.")
                return
            end
        end
        table.insert(self["BaseParts"],Part)
        print("[NETWORK] PartOwnership applied to part"..Part:GetFullName()..".")
    end
end

function Network:RemovePart(Part) --function for removing ownership of unanchored part
    if Part:IsA("BasePart") and Part:IsDescendantOf(workspace) then
        local Index = table.find(self["BaseParts"],Part)
        if Index then
            table.remove(self["BaseParts"],Index)
            local Retainer = Part:FindFirstChild("NetworkRetainer")
            if Retainer then
                Retainer:Destroy()
            end
            print("[NETWORK] PartOwnership removed from part "..Part:GetFullName()..".")
        else
            warn("[NETWORK] Part "..Part:GetFullName().." not found in BaseParts table.")
        end
    end
end

function Network:RemoveParts()
    for i,part in ipairs(self["BaseParts"]) do
        self:RemovePart(part)
    end
end

Network["SuperStepper"] = Instance.new("BindableEvent") --make super fast event to connect to
for _,Event in pairs({RunService.Stepped,RunService.Heartbeat}) do
    Event:Connect(function()
        return Network["SuperStepper"]:Fire(Network["SuperStepper"],tick())
    end)
end

Network["PartOwnership"] = {}
Network["PartOwnership"]["PreMethodSettings"] = {}
Network["PartOwnership"]["Enabled"] = false
Network["PartOwnership"]["Enable"] = coroutine.create(function() --creating a thread for network stuff
    if Network["PartOwnership"]["Enabled"] == false then
        Network["PartOwnership"]["Enabled"] = true --do cool network stuff before doing more cool network stuff
        Network["PartOwnership"]["PreMethodSettings"].ReplicationFocus = LocalPlayer.ReplicationFocus
        LocalPlayer.ReplicationFocus = workspace
        Network["PartOwnership"]["PreMethodSettings"].SimulationRadius = gethiddenproperty(LocalPlayer,"SimulationRadius")
        Network["PartOwnership"]["Connection"] = Network["SuperStepper"].Event:Connect(function() --super fast asynchronous loop
            sethiddenproperty(LocalPlayer,"SimulationRadius",1/0)
            for _,Part in pairs(Network["BaseParts"]) do --loop through parts and do network stuff
                coroutine.wrap(function()
                    if Part:IsDescendantOf(workspace) then
                        --print("Apply velocity")
                        Part.Velocity = Network["Velocity"]+Vector3.new(0,math.cos(tick()*50),0)
                        if not isnetworkowner(Part) then --lag parts my ownership is contesting but dont have network over to spite the people who have ownership of stuff i want >:(
                            --print("[NETWORK] Part "..Part:GetFullName().." is not owned. Contesting ownership...") --you can comment this out if you dont want console spam lol
                            sethiddenproperty(Part,"NetworkIsSleeping",true)
                        else
                            sethiddenproperty(Part,"NetworkIsSleeping",false)
                        end
                    else
                        Network["RemovePart"](Part)
                    end
                    --[==[ [[by 4eyes btw]] ]==]--
                end)()
            end
        end)
    end
end)

Network["PartOwnership"]["Disable"] = coroutine.create(function()
    if Network["PartOwnership"]["Connection"] then
        Network["PartOwnership"]["Connection"]:Disconnect()
        LocalPlayer.ReplicationFocus = Network["PartOwnership"]["PreMethodSettings"].ReplicationFocus
        sethiddenproperty(LocalPlayer,"SimulationRadius",Network["PartOwnership"]["PreMethodSettings"].SimulationRadius)
        Network["PartOwnership"]["PreMethodSettings"] = {}
        for _,Part in pairs(Network["BaseParts"]) do
            Network["RemovePart"](Part)
        end
        Network["PartOwnership"]["Enabled"] = false
    end
end)


-- https://v3rmillion.net/showthread.php?tid=1180572
local GetFamily = function(ins, reverseorder)
    local Pathway = {}

    local function _GetFamily(v)
        if v.Parent ~= nil then
            if reverseorder then
                table.insert(Pathway, v)
            else
                table.insert(Pathway, 1, v)
            end
            _GetFamily(v.Parent)
        else
            if reverseorder then
                table.insert(Pathway, v)
            else
                table.insert(Pathway, 1, v)
            end
         end
    end

    _GetFamily(ins)
    return Pathway    
end

function Network:FollowPart(part)
    if not isnetworkowner then return end

    if part:IsA("BasePart") and not isnetworkowner(part) then
        local p = Instance.new("Part", part)
        p.Size = Vector3.new()
        p.Transparency = 1
        local Disconnect = false
        local followfunc = game.RunService.Heartbeat:connect(function()
            p.CFrame = part.CFrame
            if part.CFrame.Y < workspace.FallenPartsDestroyHeight or GetFamily(part)[1] ~= game then
                part:Destroy()
                Disconnect = true
            end
        end)

        coroutine.resume(coroutine.create(function()
            repeat wait() until Disconnect == true
            followfunc:Disconnect()
        end))
        
        return p
    end
end


function Network:Debug(DEBUG)
    if not isnetworkowner then return end

    for i,v in ipairs(Network["BaseParts"]) do
        local highlight = v:FindFirstChild("NetworkHighlight")

        if not highlight and DEBUG then
            local _ = Instance.new("SelectionBox")
            _.Name = "NetworkHighlight"
            _.Color3 = Color3.new()
            _.Adornee = v
            _.Transparency = 0.5
            _.Parent = v
        elseif highlight then
            if not DEBUG then highlight:Destroy() end
            if isnetworkowner(v) then 
                highlight.Color3 = Color3.new(0,1,0)
            else
                highlight.Color3 = Color3.new(1,0,0)
            end
        end
    end
end


return Network