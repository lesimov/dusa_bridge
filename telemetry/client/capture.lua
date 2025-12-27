--[[
    Client Error Capture
    Captures client-side errors via onResourceError and forwards to server

    OPEN SOURCE - Part of dusa_bridge
    CLIENT ONLY
]]

local Config = TelemetryConfig
local Constants = TelemetryConstants
local Breadcrumb = TelemetryBreadcrumb

-- Global client capture
TelemetryClientCapture = TelemetryClientCapture or {}
local Capture = TelemetryClientCapture

-- Rate limiting
local errorCountThisMinute = 0
local minuteResetTime = 0
local MAX_ERRORS_PER_MINUTE = Config and Config.RateLimit and Config.RateLimit.ClientMaxPerMinute or 5

-------------------------------------------
-- Context Collection
-------------------------------------------

--- Collect client context for error reports
--- @return table
local function getClientContext()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    local context = {
        position = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
        },
        heading = GetEntityHeading(playerPed),
        health = GetEntityHealth(playerPed),
        armor = GetPedArmour(playerPed),
        isInVehicle = IsPedInAnyVehicle(playerPed, false),
        gameTime = GetGameTimer(),
    }

    -- Add vehicle info if in vehicle
    if context.isInVehicle then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        context.vehicle = {
            model = GetEntityModel(vehicle),
            health = GetEntityHealth(vehicle),
            engineHealth = GetVehicleEngineHealth(vehicle),
            speed = GetEntitySpeed(vehicle) * 3.6,  -- Convert to km/h
        }
    end

    return context
end

-------------------------------------------
-- Rate Limiting
-------------------------------------------

--- Check if we should rate limit
--- @return boolean
local function shouldRateLimit()
    local now = GetGameTimer()

    -- Reset every minute
    if now >= minuteResetTime then
        errorCountThisMinute = 0
        minuteResetTime = now + 60000
    end

    if errorCountThisMinute >= MAX_ERRORS_PER_MINUTE then
        return true
    end

    errorCountThisMinute = errorCountThisMinute + 1
    return false
end

-------------------------------------------
-- Public API
-------------------------------------------

--- Report a client error to server
--- @param errorData table
function Capture.reportError(errorData)
    if shouldRateLimit() then return end

    -- Add client context
    errorData.clientContext = getClientContext()
    errorData.source = Constants.SOURCES.CLIENT

    -- Add breadcrumb
    Breadcrumb.add({
        category = errorData.category or 'error',
        message = 'Client error: ' .. (errorData.message or 'unknown'):sub(1, 100),
        level = 'error',
        source = 'client',
        params = errorData.context,
    })

    -- Forward to server
    TriggerServerEvent('dusa_bridge:telemetry:clientError', {
        message = errorData.message,
        stackTrace = errorData.stackTrace,
        category = errorData.category or 'CLIENT_ERROR',
        context = errorData.context,
        clientContext = errorData.clientContext,
        resourceName = errorData.resourceName or GetCurrentResourceName(),
        timestamp = os.time(),
    })
end

--- Handle NUI error (called from NUI callback)
--- @param nuiErrorData table
function Capture.handleNuiError(nuiErrorData)
    if shouldRateLimit() then return end

    -- Add breadcrumb
    Breadcrumb.add({
        category = 'NUI',
        message = 'NUI error: ' .. (nuiErrorData.message or 'unknown'):sub(1, 100),
        level = 'error',
        source = 'nui',
        params = {
            nuiSource = nuiErrorData.source,
            stack = nuiErrorData.stack and nuiErrorData.stack:sub(1, 200) or nil,
        },
    })

    -- Forward to server
    TriggerServerEvent('dusa_bridge:telemetry:nuiError', {
        message = nuiErrorData.message,
        stackTrace = nuiErrorData.stack,
        nuiSource = nuiErrorData.source,  -- 'uncaught', 'console.error', 'promise_rejection'
        location = nuiErrorData.location,
        componentStack = nuiErrorData.componentStack,
        resourceName = nuiErrorData.resourceName or GetCurrentResourceName(),
        timestamp = os.time(),
    })
end

-------------------------------------------
-- Native Error Hook
-------------------------------------------

-- Hook into FiveM's native error handler for client
AddEventHandler('onResourceError', function(resourceName, errorMessage, errorTrace)
    -- Only capture if telemetry features are enabled
    if not Config or not Config.Features or not Config.Features.EnableClientCapture then
        return
    end

    Capture.reportError({
        message = errorMessage,
        stackTrace = errorTrace,
        category = 'NATIVE_ERROR',
        resourceName = resourceName,
    })
end)

return Capture
