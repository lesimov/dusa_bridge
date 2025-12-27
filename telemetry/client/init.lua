--[[
    Telemetry Client Initialization
    Sets up client-side telemetry API

    OPEN SOURCE - Part of dusa_bridge
    CLIENT ONLY

    Note: All modules are loaded via fxmanifest.lua shared_scripts and client_scripts
]]

-- Verify modules loaded (they should be loaded by fxmanifest before this file)
if not TelemetryConstants or not TelemetryConfig then
    print('^1[Telemetry]^7 Core modules not loaded on client - check fxmanifest.lua')
    return
end

if not TelemetryBreadcrumb or not TelemetryClientCapture then
    print('^1[Telemetry]^7 Client modules not loaded - check fxmanifest.lua')
    return
end

-- Aliases
local Breadcrumb = TelemetryBreadcrumb
local ClientCapture = TelemetryClientCapture

-------------------------------------------
-- Global Client Telemetry API
-------------------------------------------

TelemetryClient = TelemetryClient or {}

--- Add a client-side breadcrumb
--- @param data table
function TelemetryClient.addBreadcrumb(data)
    data.source = 'client'
    Breadcrumb.add(data)
end

--- Report a client error (forwards to server)
--- @param errorData table
function TelemetryClient.reportError(errorData)
    if ClientCapture then
        ClientCapture.reportError(errorData)
    end
end

--- Set active trace ID
--- @param traceId string|nil
function TelemetryClient.setActiveTraceId(traceId)
    Breadcrumb.setActiveTraceId(traceId)
end

--- Get active trace ID
--- @return string|nil
function TelemetryClient.getActiveTraceId()
    return Breadcrumb.getActiveTraceId()
end

print('^2[Telemetry]^7 Client module ready')
