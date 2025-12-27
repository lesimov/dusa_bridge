--[[
    Graceful Degradation Tracking
    Reports when fallback behavior is triggered

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY
]]

local Constants = TelemetryConstants
local Capture = TelemetryCapture
local Breadcrumb = TelemetryBreadcrumb

-- Global degradation tracker
TelemetryDegradation = TelemetryDegradation or {}
local Degradation = TelemetryDegradation

-- Track degradation events for deduplication
local recentDegradations = {}  -- { [signature] = lastTime }
local DEDUP_WINDOW = 300  -- 5 minutes

-------------------------------------------
-- Helper Functions
-------------------------------------------

--- Generate signature for deduplication
--- @param feature string
--- @param reason string
--- @return string
local function generateSignature(feature, reason)
    return string.format('%s:%s', feature or 'unknown', reason or 'unknown')
end

--- Check if we should deduplicate this degradation
--- @param signature string
--- @return boolean
local function shouldDeduplicate(signature)
    local now = os.time()
    local lastTime = recentDegradations[signature]

    if lastTime and (now - lastTime) < DEDUP_WINDOW then
        return true
    end

    recentDegradations[signature] = now
    return false
end

--- Clean up old degradation records
local function cleanupOldRecords()
    local now = os.time()
    for sig, time in pairs(recentDegradations) do
        if (now - time) > DEDUP_WINDOW then
            recentDegradations[sig] = nil
        end
    end
end

-------------------------------------------
-- Public API
-------------------------------------------

--- Report a graceful degradation event
--- @param feature string The feature that degraded (e.g., 'real_time_sync', 'payment_processing')
--- @param reason string Why degradation occurred (e.g., 'WebSocket unavailable', 'External API timeout')
--- @param fallback string What fallback was used (e.g., 'polling', 'cached_data', 'manual_retry')
--- @param context table|nil Additional context
function Degradation.report(feature, reason, fallback, context)
    if not Capture or not Capture.isEnabled() then return end

    -- Validate inputs
    if not feature or not reason or not fallback then
        return
    end

    -- Check deduplication
    local signature = generateSignature(feature, reason)
    if shouldDeduplicate(signature) then
        return
    end

    -- Add breadcrumb for the degradation
    Breadcrumb.add({
        category = Constants.BREADCRUMB_CATEGORY.DEGRADATION,
        message = string.format('Fallback triggered: %s -> %s', feature, fallback),
        level = 'warning',
        params = {
            feature = feature,
            reason = reason,
            fallback = fallback,
            context = context,
        },
    })

    -- Build context
    local reportContext = {
        feature = feature,
        reason = reason,
        fallback = fallback,
        degradationTime = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    -- Merge additional context
    if context then
        for k, v in pairs(context) do
            reportContext[k] = v
        end
    end

    -- Report to Sentry as info level (not error)
    Capture.reportError({
        message = string.format('[DEGRADATION] %s: %s (fallback: %s)', feature, reason, fallback),
        category = 'GRACEFUL_DEGRADATION',
        level = 'info',  -- Info level, not error
        source = 'server',
        context = reportContext,
        tags = {
            graceful_degradation = 'true',
            degraded_feature = feature,
            fallback_used = fallback,
        },
    })

    -- Periodic cleanup
    if math.random(1, 10) == 1 then
        cleanupOldRecords()
    end
end

--- Report multiple degradations at once
--- @param degradations table[] Array of { feature, reason, fallback, context }
function Degradation.reportBatch(degradations)
    for _, d in ipairs(degradations) do
        Degradation.report(d.feature, d.reason, d.fallback, d.context)
    end
end

--- Check if a feature has recently degraded
--- @param feature string
--- @return boolean
function Degradation.hasRecentlyDegraded(feature)
    local now = os.time()
    for sig, time in pairs(recentDegradations) do
        if sig:match('^' .. feature .. ':') and (now - time) < DEDUP_WINDOW then
            return true
        end
    end
    return false
end

--- Get recent degradation count
--- @return number
function Degradation.getRecentCount()
    local count = 0
    local now = os.time()
    for _, time in pairs(recentDegradations) do
        if (now - time) < DEDUP_WINDOW then
            count = count + 1
        end
    end
    return count
end

-------------------------------------------
-- Common Degradation Helpers
-------------------------------------------

--- Report database fallback
--- @param operation string The database operation that failed
--- @param fallback string The fallback used
--- @param context table|nil
function Degradation.reportDatabaseFallback(operation, fallback, context)
    Degradation.report(
        'database:' .. operation,
        'Database operation failed or timed out',
        fallback,
        context
    )
end

--- Report external API fallback
--- @param apiName string The external API name
--- @param fallback string The fallback used
--- @param context table|nil
function Degradation.reportApiFallback(apiName, fallback, context)
    Degradation.report(
        'api:' .. apiName,
        'External API unavailable or returned error',
        fallback,
        context
    )
end

--- Report feature disabled fallback
--- @param featureName string The feature name
--- @param fallback string The fallback used
--- @param context table|nil
function Degradation.reportFeatureDisabled(featureName, fallback, context)
    Degradation.report(
        'feature:' .. featureName,
        'Feature disabled or not available',
        fallback,
        context
    )
end

return Degradation
