local rbxmSuite = loadstring(game:HttpGetAsync("https://github.com/richie0866/rbxm-suite/releases/latest/download/rbxm-suite.lua"))()

local PROJECT = "FE-Player-Template.rbxm"

local project = rbxmSuite.launch(PROJECT:lower(), {
    runscripts = true,
    deferred = true,
    nocache = false,
    nocirculardeps = true,
    -- TODO: Remove unused packages 
    debug = true,
    verbose = false
})