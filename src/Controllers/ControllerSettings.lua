local ControllerSettings = {}

local Settings = {}

function ControllerSettings.GetSettings()
    return Settings
end

function ControllerSettings.SetSettings(settings)
    Settings = settings
end


return ControllerSettings