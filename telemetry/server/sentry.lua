--[[
    Sentry Integration
    HTTP communication with Sentry API

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY
]]

local Constants = TelemetryConstants
local Config = TelemetryConfig
local Context = TelemetryContext
local Breadcrumb = TelemetryBreadcrumb

-- Global Sentry manager
TelemetrySentry = TelemetrySentry or {}
local Sentry = TelemetrySentry

-- Internal state
local sentryConfig = nil
local isConfigured = false
local lastTransmission = nil
local transmissionCount = 0

-------------------------------------------
-- DSN Parsing
-------------------------------------------

--- Parse Sentry DSN into components
--- DSN format: https://<key>@<host>/<project_id>
--- @param dsn string
--- @return table|nil
local function parseDSN(dsn)
    if not dsn or dsn == '' then return nil end

    local key, host, projectId = dsn:match('https://([^@]+)@([^/]+)/(%d+)')
    if not key or not host or not projectId then
        print('^1[Telemetry]^7 Invalid Sentry DSN format')
        return nil
    end

    return {
        key = key,
        host = host,
        projectId = projectId,
        endpoint = string.format('https://%s/api/%s/store/', host, projectId),
    }
end

-------------------------------------------
-- Event Formatting
-------------------------------------------

--- Generate a valid 32-character hex event ID
--- @return string
local function generateEventId()
    local template = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
    return string.gsub(template, 'x', function()
        return string.format('%x', math.random(0, 15))
    end)
end

--- Parse Lua stack trace into Sentry frames format
--- @param stackTrace string|nil
--- @return table|nil
local function parseStackTrace(stackTrace)
    if not stackTrace then return nil end

    local frames = {}

    for line in stackTrace:gmatch('[^\n]+') do
        -- Skip empty lines and "stack traceback:" header
        if line ~= '' and not line:match('stack traceback') then
            -- Try to extract file, line, and function info
            -- FiveM format: "citizen:/path/file.lua:123: in function 'name'"
            -- Or: "@resource/file.lua:123: in function 'name'"
            local filename, lineNum, funcInfo = line:match('([^:]+):(%d+): in (.+)')

            if not filename then
                -- Fallback: just get filename and function
                filename, funcInfo = line:match('([^:]+): in (.+)')
            end

            if filename then
                -- Clean up function name
                local funcName = funcInfo and funcInfo:match("'([^']+)'") or funcInfo or 'anonymous'

                -- Clean up filename (remove @ prefix, citizen: prefix)
                filename = filename:gsub('^@', ''):gsub('^citizen:', '')

                table.insert(frames, {
                    filename = filename,
                    lineno = lineNum and tonumber(lineNum) or nil,
                    ['function'] = funcName,
                    in_app = not filename:match('^citizen:'),
                })
            else
                -- Fallback: store raw line
                table.insert(frames, {
                    filename = 'unknown',
                    ['function'] = line:sub(1, 200),
                    in_app = true,
                })
            end
        end

        -- Limit frames
        if #frames >= Constants.LIMITS.MAX_STACK_FRAMES then
            break
        end
    end

    -- Sentry expects frames in reverse order (most recent last)
    if #frames > 0 then
        return { frames = frames }
    end

    return nil
end

--- Format error data into Sentry event payload
--- @param errorData table
--- @return table
function Sentry.formatEvent(errorData)
    local serverInfo = Context.getServerInfo()
    local serverTags = Context.getServerTags()
    local timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')

    -- Determine level
    local level = errorData.level or 'error'
    if type(level) == 'number' then
        level = Constants.LOG_LEVEL_NAMES[level] or 'error'
    end

    -- Build base tags
    local tags = {
        resource = errorData.resourceName or 'unknown',
        source = errorData.source or 'server',
        category = errorData.category or 'unknown',
    }

    -- Merge server tags
    for k, v in pairs(serverTags) do
        tags[k] = v
    end

    -- Merge custom tags
    if errorData.tags then
        for k, v in pairs(errorData.tags) do
            tags[k] = tostring(v)
        end
    end

    -- Build event
    local event = {
        event_id = generateEventId(),
        timestamp = timestamp,
        platform = Constants.SENTRY.PLATFORM,
        level = level,
        logger = Constants.SENTRY.LOGGER,
        server_name = serverInfo.serverName,
        release = string.format('%s@%s',
            errorData.resourceName or 'dusa-ecosystem',
            errorData.resourceVersion or serverInfo.bridgeVersion or '1.0.0'
        ),
        environment = Config.Sentry.Environment,

        -- Exception data
        exception = {
            values = {
                {
                    type = errorData.category or 'Error',
                    value = errorData.message or 'Unknown error',
                    stacktrace = parseStackTrace(errorData.stackTrace),
                }
            }
        },

        -- Tags
        tags = tags,

        -- Extra context
        extra = {
            serverInfo = serverInfo,
            context = errorData.context,
            occurrenceCount = errorData.count or 1,
            traceId = errorData.traceId or Breadcrumb.getActiveTraceId(),
        },

        -- Breadcrumbs
        breadcrumbs = Breadcrumb.getForSentry(),

        -- User context (only owner contact if set)
        user = errorData.ownerContact and {
            id = errorData.ownerContact,
            username = 'Server Owner',
        } or nil,
    }

    return event
end

-------------------------------------------
-- Short ID Generation
-------------------------------------------

--- Generate a short, user-friendly error ID from the full event ID
--- Format: First 4 chars + last 4 chars uppercase (e.g., "A1B2-C3D4")
--- @param eventId string Full 32-character hex event ID
--- @return string shortId User-friendly short ID
local function generateShortId(eventId)
    if not eventId or #eventId < 8 then
        return 'UNKNOWN'
    end
    return string.upper(eventId:sub(1, 4) .. '-' .. eventId:sub(-4))
end

--- Get short ID from full event ID (public function)
--- @param eventId string
--- @return string
function Sentry.getShortId(eventId)
    return generateShortId(eventId)
end

-------------------------------------------
-- HTTP Communication
-------------------------------------------

--- Send event to Sentry (async, non-blocking)
--- @param event table
--- @return string|nil eventId Returns the full event ID if queued successfully
function Sentry.send(event)
    if not sentryConfig then
        print('^1[Telemetry]^7 Sentry not configured')
        return nil
    end

    local eventId = event.event_id
    local shortId = generateShortId(eventId)

    local success, payload = pcall(json.encode, event)
    if not success then
        print('^1[Telemetry]^7 Failed to encode event: ' .. tostring(payload))
        return nil
    end

    local headers = {
        ['Content-Type'] = 'application/json',
        ['X-Sentry-Auth'] = string.format(
            'Sentry sentry_version=%d, sentry_client=%s, sentry_key=%s',
            Constants.SENTRY.VERSION,
            Constants.SENTRY.CLIENT_NAME,
            sentryConfig.key
        ),
    }

    PerformHttpRequest(sentryConfig.endpoint, function(statusCode, responseText, responseHeaders)
        if statusCode >= 200 and statusCode < 300 then
            lastTransmission = os.time()
            transmissionCount = transmissionCount + 1

            -- Debug log only if Bridge.DebugMode is on
            if Bridge and Bridge.DebugMode then
                print('^2[Telemetry]^7 Event sent to Sentry: ' .. shortId)
            end
        else
            print(string.format('^1[Telemetry]^7 Sentry request failed: HTTP %s (ID: %s)', statusCode or 'timeout', shortId))
            if responseText and Bridge and Bridge.DebugMode then
                print('^1[Telemetry]^7 Response: ' .. responseText:sub(1, 200))
            end
        end
    end, 'POST', payload, headers)

    -- Return full event ID immediately (HTTP is async)
    return eventId
end

-------------------------------------------
-- Configuration
-------------------------------------------

--- Configure Sentry with DSN
--- @param dsn string
--- @return boolean success
function Sentry.configure(dsn)
    sentryConfig = parseDSN(dsn)
    isConfigured = sentryConfig ~= nil

    if isConfigured then
        print('^2[Telemetry]^7 Sentry configured successfully')
    end

    return isConfigured
end

--- Check if Sentry is configured
--- @return boolean
function Sentry.isConfigured()
    return isConfigured
end

--- Get Sentry status
--- @return table
function Sentry.getStatus()
    return {
        configured = isConfigured,
        lastTransmission = lastTransmission,
        transmissionCount = transmissionCount,
    }
end

--- Get the Sentry endpoint (for debugging)
--- @return string|nil
function Sentry.getEndpoint()
    return sentryConfig and sentryConfig.endpoint or nil
end

return Sentry
