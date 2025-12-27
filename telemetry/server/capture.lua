--[[
    Server Error Capture
    Main error capture and rate limiting logic

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY
]]

local Constants = TelemetryConstants
local Config = TelemetryConfig
local Context = TelemetryContext
local Breadcrumb = TelemetryBreadcrumb
local Sentry = TelemetrySentry

-- Global capture manager
TelemetryCapture = TelemetryCapture or {}
local Capture = TelemetryCapture

-- Internal state
local isEnabled = false
local ownerContact = nil

-- Rate limiting state
local errorRateLimits = {}       -- { [signature] = { lastTime, count } }
local pendingErrors = {}         -- Aggregated errors waiting to be sent
local minuteErrorCount = 0       -- Errors this minute
local minuteResetTime = 0        -- When to reset minute counter

-------------------------------------------
-- Rate Limiting
-------------------------------------------

--- Generate error signature for rate limiting
--- @param message string
--- @param stackTrace string|nil
--- @return string
local function generateSignature(message, stackTrace)
    local firstLine = stackTrace and stackTrace:match('[^\n]+') or ''
    return string.format('%s|%s', message or 'unknown', firstLine)
end

--- Check if error should be rate limited
--- @param signature string
--- @return boolean shouldLimit, number|nil pendingCount
local function shouldRateLimit(signature)
    local now = os.time()

    -- Reset minute counter if needed
    if now >= minuteResetTime then
        minuteErrorCount = 0
        minuteResetTime = now + 60
    end

    -- Check global rate limit
    if minuteErrorCount >= Config.RateLimit.MaxErrorsPerMinute then
        return true, nil
    end

    -- Check per-error rate limit
    local limit = errorRateLimits[signature]
    if limit and (now - limit.lastTime) < Config.RateLimit.ErrorCooldownSeconds then
        -- Aggregate the error
        if not pendingErrors[signature] then
            pendingErrors[signature] = { count = 0 }
        end
        pendingErrors[signature].count = pendingErrors[signature].count + 1
        return true, pendingErrors[signature].count
    end

    -- Update rate limit
    errorRateLimits[signature] = { lastTime = now, count = 1 }
    minuteErrorCount = minuteErrorCount + 1

    -- Get and clear pending count
    local pending = pendingErrors[signature]
    pendingErrors[signature] = nil

    return false, pending and pending.count or 0
end

-------------------------------------------
-- Error Processing
-------------------------------------------

--- Process and send error to Sentry
--- @param errorData table
--- @return string|nil eventId Returns the event ID if sent successfully
local function processError(errorData)
    if not isEnabled then return nil end
    if not Sentry.isConfigured() then return nil end

    -- Check minimum level
    local level = errorData.level
    if type(level) == 'string' then
        level = Constants.LOG_LEVELS[level:upper()] or Constants.LOG_LEVELS.ERROR
    end
    if level < Config.Sentry.MinLevel then return nil end

    -- Generate signature and check rate limit
    local signature = generateSignature(errorData.message, errorData.stackTrace)
    local limited, pendingCount = shouldRateLimit(signature)

    if limited then
        return nil
    end

    -- Add pending count to error data
    if pendingCount and pendingCount > 0 then
        errorData.count = (errorData.count or 1) + pendingCount
    end

    -- Add owner contact
    errorData.ownerContact = ownerContact

    -- Format and send
    local event = Sentry.formatEvent(errorData)
    return Sentry.send(event)
end

-------------------------------------------
-- User Notification
-------------------------------------------

--- Notify a player about the error ID
--- @param playerSource number Player server ID (0 for console/server-side)
--- @param eventId string Full event ID
--- @param message string|nil Optional custom message
local function notifyPlayer(playerSource, eventId, message)
    if not eventId then return end

    local shortId = Sentry.getShortId(eventId)
    local notifyMessage = message or ('Error captured. ID: %s'):format(shortId)

    -- Only notify players, not console
    if playerSource and playerSource > 0 then
        -- Use ox_lib notification if available
        TriggerClientEvent('ox_lib:notify', playerSource, {
            title = 'Error Notification',
            description = notifyMessage,
            type = 'error',
            duration = 8000,
            icon = 'exclamation-triangle',
        })
    end
    
    -- Always print to console
    print(string.format('^3[Telemetry]^7 Error ID: %s (Full: %s)', shortId, eventId))
end

--- Get short ID helper (exposed for external use)
--- @param eventId string
--- @return string
function Capture.getShortId(eventId)
    return Sentry.getShortId(eventId)
end

-------------------------------------------
-- Public API
-------------------------------------------

--- Report an error to Sentry
--- @param errorData table { message, stackTrace, category, context, level, source, resourceName, tags, notifyPlayer, playerSource }
--- @return string|nil eventId Returns the event ID if sent, nil otherwise
function Capture.reportError(errorData)
    -- Validate input
    if not errorData or not errorData.message then
        return nil
    end

    -- Check if resource is registered (optional - can send from any resource)
    local resourceName = errorData.resourceName or GetInvokingResource() or 'unknown'
    errorData.resourceName = resourceName

    -- Get resource version if registered
    local resourceInfo = Context.getResourceInfo(resourceName)
    if resourceInfo then
        errorData.resourceVersion = resourceInfo.version
    end

    -- Add breadcrumb for the error
    Breadcrumb.add({
        category = errorData.category or 'error',
        message = 'Error reported: ' .. (errorData.message:sub(1, 100)),
        level = 'error',
        source = errorData.source or 'server',
        resourceName = resourceName,
        params = errorData.context,
    })

    local eventId = processError(errorData)

    -- Notify player if requested
    if eventId and errorData.notifyPlayer then
        notifyPlayer(errorData.playerSource or 0, eventId)
    end

    return eventId
end

--- Report an error and notify a specific player
--- @param playerSource number Player server ID
--- @param errorData table Error data
--- @return string|nil eventId
function Capture.reportErrorWithNotify(playerSource, errorData)
    errorData.notifyPlayer = true
    errorData.playerSource = playerSource
    return Capture.reportError(errorData)
end

--- Handle client error forwarded from client
--- @param source number Player source
--- @param errorData table
function Capture.handleClientError(source, errorData)
    if not isEnabled then return end
    if not Config.Features.EnableClientCapture then return end

    -- Rate limit per player
    local playerKey = 'client:' .. tostring(source)
    local now = os.time()

    if not errorRateLimits[playerKey] then
        errorRateLimits[playerKey] = { lastTime = now, count = 0 }
    end

    local limit = errorRateLimits[playerKey]
    if (now - limit.lastTime) >= 60 then
        limit.count = 0
        limit.lastTime = now
    end

    if limit.count >= Config.RateLimit.ClientMaxPerMinute then
        return
    end
    limit.count = limit.count + 1

    -- Add source tag
    errorData.source = Constants.SOURCES.CLIENT
    errorData.tags = errorData.tags or {}
    errorData.tags.player_source = tostring(source)

    -- Add client context as extra
    if errorData.clientContext then
        errorData.context = errorData.context or {}
        errorData.context.clientContext = errorData.clientContext
    end

    -- Enable notification for the player who experienced the error
    errorData.notifyPlayer = Config.Features.NotifyPlayerOnError
    errorData.playerSource = source

    Capture.reportError(errorData)
end

--- Handle NUI error forwarded from client
--- @param source number Player source
--- @param errorData table
function Capture.handleNuiError(source, errorData)
    if not isEnabled then return end
    if not Config.Features.EnableNuiCapture then return end

    -- Rate limit per player
    local playerKey = 'nui:' .. tostring(source)
    local now = os.time()

    if not errorRateLimits[playerKey] then
        errorRateLimits[playerKey] = { lastTime = now, count = 0 }
    end

    local limit = errorRateLimits[playerKey]
    if (now - limit.lastTime) >= 60 then
        limit.count = 0
        limit.lastTime = now
    end

    if limit.count >= Config.RateLimit.NuiMaxPerMinute then
        return
    end
    limit.count = limit.count + 1

    -- Add NUI-specific tags
    errorData.source = Constants.SOURCES.NUI
    errorData.tags = errorData.tags or {}
    errorData.tags.nui_source = errorData.nuiSource or 'unknown'  -- uncaught, console.error, promise_rejection
    errorData.tags.player_source = tostring(source)

    -- Set category
    errorData.category = 'NUI'

    -- Enable notification for the player who experienced the error
    errorData.notifyPlayer = Config.Features.NotifyPlayerOnError
    errorData.playerSource = source

    Capture.reportError(errorData)
end

-------------------------------------------
-- Configuration
-------------------------------------------

--- Enable telemetry
--- @param contact string|nil Owner contact (Discord ID)
function Capture.enable(contact)
    isEnabled = true
    ownerContact = contact
    print('^2[Telemetry]^7 Error capture enabled')
end

--- Disable telemetry
function Capture.disable()
    isEnabled = false
    print('^3[Telemetry]^7 Error capture disabled')
end

--- Check if enabled
--- @return boolean
function Capture.isEnabled()
    return isEnabled
end

--- Get status
--- @return table
function Capture.getStatus()
    return {
        enabled = isEnabled,
        ownerContact = ownerContact,
        minuteErrorCount = minuteErrorCount,
        sentryStatus = Sentry.getStatus(),
    }
end

--- Set owner contact
--- @param contact string|nil
function Capture.setOwnerContact(contact)
    ownerContact = contact
end

return Capture
