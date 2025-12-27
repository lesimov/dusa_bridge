--[[
    NUI Bridge
    Handles NUI -> Client -> Server error forwarding

    OPEN SOURCE - Part of dusa_bridge
    CLIENT ONLY
]]

local Capture = TelemetryClientCapture

-------------------------------------------
-- NUI Callbacks
-------------------------------------------

-- Handle NUI errors forwarded from browser JavaScript
RegisterNUICallback('dusa_bridge:telemetry:nuiError', function(data, cb)
    if Capture then
        Capture.handleNuiError(data)
    end
    cb('ok')
end)

-- Handle NUI breadcrumbs (optional - for detailed NUI tracing)
RegisterNUICallback('dusa_bridge:telemetry:nuiBreadcrumb', function(data, cb)
    if TelemetryBreadcrumb then
        TelemetryBreadcrumb.add({
            category = data.category or 'NUI',
            message = data.message,
            level = data.level or 'info',
            source = 'nui',
            params = data.params,
        })
    end
    cb('ok')
end)
