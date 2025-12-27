--[[
    Enhanced Breadcrumb System
    Collects detailed context for error debugging

    OPEN SOURCE - Part of dusa_bridge
]]

local Constants = TelemetryConstants
local Config = TelemetryConfig

-- Global breadcrumb manager
TelemetryBreadcrumb = TelemetryBreadcrumb or {}
local Breadcrumb = TelemetryBreadcrumb

-- Internal state (per-context: server or client)
local breadcrumbs = {}
local operationChain = {}
local activeTraceId = nil

-- Serialize parameters safely
local function serializeParams(params, maxSize)
    if not params then return nil end

    local success, encoded = pcall(json.encode, params)
    if not success then
        return { _error = 'Failed to serialize params' }
    end

    -- Truncate if too large
    if #encoded > (maxSize or Config.Breadcrumbs.MaxParamsSize) then
        return {
            _truncated = true,
            _originalSize = #encoded,
            _preview = encoded:sub(1, 200) .. '...',
        }
    end

    return params
end

-- Get caller function name using debug.getinfo
local function getCaller(level)
    level = level or 3  -- Default: skip getCaller, add, and the calling function

    local info = debug.getinfo(level, 'nSl')
    if not info then return 'unknown' end

    local name = info.name or 'anonymous'
    local source = info.short_src or 'unknown'
    local line = info.currentline or 0

    -- Clean up source path (remove full path, keep filename)
    local filename = source:match('[^/\\]+$') or source

    return string.format('%s@%s:%d', name, filename, line)
end

-- Get high-precision timestamp
local function getTimestamp()
    local seconds = os.time()
    local millis = math.floor((os.clock() % 1) * 1000)
    return seconds * 1000 + millis
end

-------------------------------------------
-- Public API
-------------------------------------------

--- Add a breadcrumb to the ring buffer
--- @param data table Breadcrumb data
function Breadcrumb.add(data)
    if not Config.Breadcrumbs then return end

    local breadcrumb = {
        timestamp = getTimestamp(),
        category = data.category or Constants.BREADCRUMB_CATEGORY.DEFAULT,
        message = data.message and data.message:sub(1, Constants.LIMITS.MAX_MESSAGE_LENGTH) or '',
        level = data.level or 'info',
        source = data.source or (IsDuplicityVersion() and 'server' or 'client'),
        resourceName = data.resourceName or GetCurrentResourceName(),

        -- Enhanced context
        params = Config.Breadcrumbs.IncludeParams and serializeParams(data.params) or nil,
        caller = data.caller or getCaller(3),
        traceId = data.traceId or activeTraceId,
        operationChain = { table.unpack(operationChain) },  -- Copy current chain
    }

    -- Update operation chain
    local opName = string.format('%s:%s', breadcrumb.category, breadcrumb.message:sub(1, 30))
    table.insert(operationChain, opName)
    while #operationChain > Config.Breadcrumbs.MaxOperationChain do
        table.remove(operationChain, 1)
    end

    -- Add to ring buffer
    table.insert(breadcrumbs, breadcrumb)
    while #breadcrumbs > Config.Breadcrumbs.MaxCount do
        table.remove(breadcrumbs, 1)
    end
end

--- Get all breadcrumbs
--- @return table[] breadcrumbs
function Breadcrumb.getAll()
    return breadcrumbs
end

--- Get breadcrumbs formatted for Sentry
--- @return table sentryBreadcrumbs
function Breadcrumb.getForSentry()
    local sentryBreadcrumbs = {}

    for _, bc in ipairs(breadcrumbs) do
        table.insert(sentryBreadcrumbs, {
            timestamp = bc.timestamp / 1000,  -- Sentry wants seconds with decimal
            category = bc.category,
            message = bc.message,
            level = bc.level,
            data = {
                params = bc.params,
                caller = bc.caller,
                traceId = bc.traceId,
                operationChain = bc.operationChain,
                source = bc.source,
                resourceName = bc.resourceName,
            },
        })
    end

    return { values = sentryBreadcrumbs }
end

--- Clear all breadcrumbs
function Breadcrumb.clear()
    breadcrumbs = {}
    operationChain = {}
end

--- Set the active trace ID (called when DusaTrace starts)
--- @param traceId string|nil
function Breadcrumb.setActiveTraceId(traceId)
    activeTraceId = traceId
end

--- Get the active trace ID
--- @return string|nil
function Breadcrumb.getActiveTraceId()
    return activeTraceId
end

--- Get the current operation chain
--- @return table
function Breadcrumb.getOperationChain()
    return { table.unpack(operationChain) }
end

--- Get breadcrumb count
--- @return number
function Breadcrumb.count()
    return #breadcrumbs
end

return Breadcrumb
