local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local App = {}

local RunService = game:GetService("RunService")
local ParentGui = game:GetService("CoreGui")

local Player = require(Project.Player)

local FastDraggable = require(Project.Util.FastDraggable)
local Sidebar = require(Project.Components.Sidebar)
local AnimPlayer = require(Project.Components.AnimPlayer)
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
    FastDraggable(gui.Player, gui.Player.Handle)
    gui.Parent = ParentGui

    Sidebar:Init(gui.AnimList)
    AnimPlayer:Init(gui.Player)

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
    if Player:GetState("Respawning") then
        print("Removing App")
        AnimPlayer:Remove()
        Sidebar:Remove()
        App:Remove()
    end
end


return App
