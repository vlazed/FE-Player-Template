local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Player = require(Project.Player)

local Framerate = {}

local framerate

function Framerate:Update()
    framerate.Text = math.round(Player:GetFramerate())
end

function Framerate:Init(frame: Frame)
    framerate = frame.Framerate
end

function Framerate:Remove()

end

return Framerate
