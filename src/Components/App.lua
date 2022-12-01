
local App = {}

local RunService = game:GetService("RunService")
local ParentGui = game:GetService("CoreGui")

local Project = script:FindFirstAncestor("FE-Player-Template")

local Player = require(Project.Player)

local FastDraggable = require(Project.Util.FastDraggable)
local Sidebar = require(Project.Components.Sidebar)
local Thread = require(Project.Util.Thread)

local gui = Project.Assets.ScreenGui

local connection

function App:GetGUI()
    return gui
end


function App:Init()

    if RunService:IsStudio() then
        print("Inserting gui into playergui")
        ParentGui = game:GetService("Players").LocalPlayer.PlayerGui
    end

    FastDraggable(gui.AnimList, gui.AnimList.Handle)
    gui.Parent = ParentGui

    Sidebar:Init(gui.AnimList)

    connection = Thread.DelayRepeat(0.1, App.Update)
end


function App:Remove()
    App:GetGUI():Destroy()

    connection:Disconnect()
    if Sidebar.SelectedModule then
        Sidebar.SelectedModule:Stop()
    end
end


function App.Update()
    --print("App update")
    --print(PlayerHelper.Respawning)
    if Player.GetState("Respawning") then
        print("Removing App")
        Sidebar:Remove()
        App:Remove()
    end
end


return App
