local rbxmSuite = loadstring(game:HttpGetAsync("https://github.com/richie0866/rbxm-suite/releases/latest/download/rbxm-suite.lua"))()

local project = rbxmSuite.launch("FE-Player-Template.rbxm", {
    runscripts = true,
    deferred = true,
    nocache = false,
    nocirculardeps = true,
    -- TODO: Remove unused packages 
    debug = true,
    verbose = false
})