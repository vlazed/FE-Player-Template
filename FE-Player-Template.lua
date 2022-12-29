local rbxmSuite = loadstring(game:HttpGetAsync("https://github.com/richie0866/rbxm-suite/releases/latest/download/rbxm-suite.lua"))()

local PROJECT = "FE-Player-Template.rbxm"


local ContextActionService = game:GetService("ContextActionService")

local runButton = Enum.KeyCode.F1

local function launchRbxm(_, is, _)
    if is == Enum.UserInputState.Begin then
        local project = rbxmSuite.launch(PROJECT:lower(), {
            runscripts = true,
            deferred = true,
            nocache = false,
            nocirculardeps = true,
            -- TODO: Remove unused packages 
            debug = true,
            verbose = false
        }) 
    end
end

ContextActionService:UnbindAction("RunRBXM")
ContextActionService:BindAction("RunRBXM", launchRbxm, false, runButton)