--[[
    Telemetry Server Initialization
    Sets up exports and event handlers for the telemetry system

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY

    Note: All modules are loaded via fxmanifest.lua shared_scripts and server_scripts
]]

-- Verify modules loaded (they should be loaded by fxmanifest before this file)
if not TelemetryConstants or not TelemetryConfig then
    print('^1[Telemetry]^7 Core modules not loaded - check fxmanifest.lua')
    return
end

if not TelemetryCapture or not TelemetryContext or not TelemetrySentry or not TelemetryBreadcrumb then
    print('^1[Telemetry]^7 Server modules not loaded - check fxmanifest.lua')
    return
end

local silentMode = TelemetryConfig and TelemetryConfig.Features and TelemetryConfig.Features.SilentMode or false
if not silentMode then
    print('^2[Telemetry]^7 Initializing server telemetry...')
end

-- Aliases for easier access
local Capture = TelemetryCapture
local Context = TelemetryContext
local Sentry = TelemetrySentry
local Breadcrumb = TelemetryBreadcrumb

-------------------------------------------
-- Global Telemetry API
-------------------------------------------

Telemetry = Telemetry or {}

--- Initialize telemetry with DSN
--- @param dsn string Sentry DSN
--- @param options table|nil { ownerContact, autoEnable }
function Telemetry.init(dsn, options)
    options = options or {}

    if Sentry.configure(dsn) then
        if options.autoEnable ~= false then
            Capture.enable(options.ownerContact)
        end
        return true
    end
    return false
end

--- Report an error
--- @param errorData table
--- @return string|nil eventId Returns the event ID if sent
function Telemetry.reportError(errorData)
    return Capture.reportError(errorData)
end

--- Report an error and notify a player
--- @param playerSource number Player server ID
--- @param errorData table
--- @return string|nil eventId
function Telemetry.reportErrorWithNotify(playerSource, errorData)
    return Capture.reportErrorWithNotify(playerSource, errorData)
end

--- Get short ID from full event ID
--- @param eventId string
--- @return string shortId (format: "A1B2-C3D4")
function Telemetry.getShortId(eventId)
    return Capture.getShortId(eventId)
end

--- Add a breadcrumb
--- @param data table
function Telemetry.addBreadcrumb(data)
    Breadcrumb.add(data)
end

--- Enable telemetry
--- @param contact string|nil Owner contact
function Telemetry.enable(contact)
    Capture.enable(contact)
end

--- Disable telemetry
function Telemetry.disable()
    Capture.disable()
end

--- Check if enabled
--- @return boolean
function Telemetry.isEnabled()
    return Capture.isEnabled()
end

--- Get telemetry status
--- @return table
function Telemetry.getStatus()
    return {
        capture = Capture.getStatus(),
        sentry = Sentry.getStatus(),
        context = {
            registeredResources = Context.getRegisteredResourceNames(),
        },
        breadcrumbs = Breadcrumb.count(),
    }
end

--- Register a resource for telemetry
--- @param resourceName string
--- @param options table|nil { sentryDSN, ... }
function Telemetry.registerResource(resourceName, options)
    options = options or {}

    Context.registerResource(resourceName, options)

    -- If resource provides its own DSN and Sentry not yet configured
    if options.sentryDSN and not Sentry.isConfigured() then
        Sentry.configure(options.sentryDSN)
    end

    -- Auto-enable if configured
    if Sentry.isConfigured() and options.autoEnable ~= false then
        Capture.enable(options.ownerContact)
    end

    print('^2[Telemetry]^7 Resource registered: ' .. resourceName)
end

--- Set active trace ID (for DusaTrace integration)
--- @param traceId string|nil
function Telemetry.setActiveTraceId(traceId)
    Breadcrumb.setActiveTraceId(traceId)
end

--- Get active trace ID
--- @return string|nil
function Telemetry.getActiveTraceId()
    return Breadcrumb.getActiveTraceId()
end

--- Report graceful degradation
--- @param feature string
--- @param reason string
--- @param fallback string
--- @param context table|nil
function Telemetry.reportDegradation(feature, reason, fallback, context)
    if TelemetryDegradation then
        TelemetryDegradation.report(feature, reason, fallback, context)
    end
end

-------------------------------------------
-- Exports
-------------------------------------------

exports('reportError', function(errorData)
    return Telemetry.reportError(errorData)
end)

exports('reportErrorWithNotify', function(playerSource, errorData)
    return Telemetry.reportErrorWithNotify(playerSource, errorData)
end)

exports('getShortId', function(eventId)
    return Telemetry.getShortId(eventId)
end)

exports('addBreadcrumb', function(data)
    Telemetry.addBreadcrumb(data)
end)

exports('registerTelemetry', function(resourceName, options)
    Telemetry.registerResource(resourceName, options)
end)

exports('setActiveTraceId', function(traceId)
    Telemetry.setActiveTraceId(traceId)
end)

exports('getActiveTraceId', function()
    return Telemetry.getActiveTraceId()
end)

exports('reportDegradation', function(feature, reason, fallback, context)
    Telemetry.reportDegradation(feature, reason, fallback, context)
end)

exports('getTelemetryStatus', function()
    return Telemetry.getStatus()
end)

exports('enableTelemetry', function(contact)
    Telemetry.enable(contact)
end)

exports('disableTelemetry', function()
    Telemetry.disable()
end)

exports('isTelemetryEnabled', function()
    return Telemetry.isEnabled()
end)

-------------------------------------------
-- Event Handlers
-------------------------------------------

-- Handle client errors forwarded from client
RegisterNetEvent('dusa_bridge:telemetry:clientError', function(errorData)
    local src = source
    Capture.handleClientError(src, errorData)
end)

-- Handle NUI errors forwarded from client
RegisterNetEvent('dusa_bridge:telemetry:nuiError', function(errorData)
    local src = source
    Capture.handleNuiError(src, errorData)
end)

-- Handle native resource errors
AddEventHandler('onResourceError', function(resourceName, errorMessage, errorTrace)
    -- Only capture if resource is registered
    if not Context.isResourceRegistered(resourceName) then return end

    Capture.reportError({
        message = errorMessage,
        stackTrace = errorTrace,
        category = 'NATIVE_ERROR',
        resourceName = resourceName,
        source = 'server',
    })
end)

-------------------------------------------
-- Commands (Admin)
-------------------------------------------

lib.addCommand('telemetrystatus', {
    help = 'Show telemetry system status',
    restricted = 'group.admin',
}, function(source, args)
    local status = Telemetry.getStatus()
    print('^2=== Telemetry Status ===^0')
    print(status.capture.enabled and '^2Capture: ENABLED^0' or '^3Capture: DISABLED^0')
    print(status.sentry.configured and '^2Sentry: CONFIGURED^0' or '^3Sentry: NOT CONFIGURED^0')
    print('Transmissions: ' .. tostring(status.sentry.transmissionCount))
    print('Breadcrumbs: ' .. tostring(status.breadcrumbs))
    print('Registered Resources: ' .. table.concat(status.context.registeredResources, ', '))
end)

-- Test command 1: Simulate a server-side database error
lib.addCommand('telemetrytest1', {
    help = 'Test telemetry - simulates a database connection error',
    restricted = 'group.admin',
}, function(source, args)
    print('^3[Telemetry Test]^7 Sending test error 1: Database connection failure...')

    -- Add some breadcrumbs for context
    Breadcrumb.add({
        category = 'DATABASE',
        message = 'Attempting to connect to MySQL',
        level = 'info',
        params = { host = 'localhost', port = 3306 },
    })

    Breadcrumb.add({
        category = 'DATABASE',
        message = 'Connection timeout after 5000ms',
        level = 'warning',
        params = { timeout = 5000 },
    })

    -- Report the error (now returns eventId instead of boolean)
    local eventId = Telemetry.reportError({
        message = 'Database connection failed: ETIMEDOUT - Connection timed out after 5000ms',
        category = 'DATABASE_ERROR',
        level = 'error',
        resourceName = 'dusa_bridge',
        stackTrace = debug.traceback('Database connection error', 2),
        context = {
            host = 'localhost',
            port = 3306,
            database = 'fivem_server',
            timeout = 5000,
            retryCount = 3,
        },
        tags = {
            error_type = 'connection_timeout',
            database = 'mysql',
        },
        -- Notify the player who ran the command
        notifyPlayer = source > 0,
        playerSource = source,
    })

    if eventId then
        local shortId = Telemetry.getShortId(eventId)
        print('^2[Telemetry Test]^7 Test error 1 sent successfully!')
        print('^2[Telemetry Test]^7 Error ID: ^3' .. shortId .. '^7 (Full: ' .. eventId .. ')')
    else
        print('^1[Telemetry Test]^7 Failed to send test error 1 (check if Sentry is configured)')
    end
end)

-- Test command 2: Simulate an API/callback error with different context
lib.addCommand('telemetrytest2', {
    help = 'Test telemetry - simulates an API callback error',
    restricted = 'group.admin',
}, function(source, args)
    print('^3[Telemetry Test]^7 Sending test error 2: API callback failure...')

    -- Add breadcrumbs showing the request flow
    Breadcrumb.add({
        category = 'HTTP',
        message = 'Incoming callback: mechanic:getWorkOrders',
        level = 'info',
        params = { playerId = 1, shopId = 5 },
    })

    Breadcrumb.add({
        category = 'VALIDATION',
        message = 'Permission check passed',
        level = 'debug',
        params = { permission = 'view_orders', result = true },
    })

    Breadcrumb.add({
        category = 'DATABASE',
        message = 'Executing query: SELECT * FROM mechanic_orders',
        level = 'info',
        params = { table = 'mechanic_orders', shopId = 5 },
    })

    -- Report a different type of error (now returns eventId instead of boolean)
    local eventId = Telemetry.reportError({
        message = 'Callback error in mechanic:getWorkOrders - attempt to index nil value (field \'status\')',
        category = 'CALLBACK_ERROR',
        level = 'error',
        resourceName = 'dusa_mechanic',
        stackTrace = [[stack traceback:
    @dusa_mechanic/server/tablet/callbacks.lua:156: in function 'getWorkOrders'
    @dusa_mechanic/server/tablet/callbacks.lua:42: in function <@dusa_mechanic/server/tablet/callbacks.lua:40>
    @ox_lib/resource/callback/server.lua:45: in function 'cb'
    citizen:/scripting/lua/scheduler.lua:175: in function <citizen:/scripting/lua/scheduler.lua:174>]],
        context = {
            callback = 'mechanic:getWorkOrders',
            playerId = 1,
            shopId = 5,
            queryResult = 'nil',
        },
        tags = {
            error_type = 'nil_index',
            callback_name = 'getWorkOrders',
            module = 'tablet',
        },
        -- Notify the player who ran the command
        notifyPlayer = source > 0,
        playerSource = source,
    })

    if eventId then
        local shortId = Telemetry.getShortId(eventId)
        print('^2[Telemetry Test]^7 Test error 2 sent successfully!')
        print('^2[Telemetry Test]^7 Error ID: ^3' .. shortId .. '^7 (Full: ' .. eventId .. ')')
    else
        print('^1[Telemetry Test]^7 Failed to send test error 2 (check if Sentry is configured)')
    end
end)

if not silentMode then
    print('^2[Telemetry]^7 Server telemetry initialized')
end
