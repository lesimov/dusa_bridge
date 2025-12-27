--[[
    Trace-Sentry Integration
    Bridges DusaTrace anomalies to Sentry

    OPEN SOURCE - Part of dusa_bridge
    SERVER ONLY
]]

local Constants = TelemetryConstants
local Capture = TelemetryCapture
local Breadcrumb = TelemetryBreadcrumb

-- Global trace integration
TelemetryTraceIntegration = TelemetryTraceIntegration or {}
local TraceIntegration = TelemetryTraceIntegration

-- Track if we've hooked DusaTrace
local isHooked = false

-------------------------------------------
-- Anomaly Reporting
-------------------------------------------

--- Report a trace anomaly to Sentry
--- @param anomalyType string
--- @param data table
function TraceIntegration.reportAnomaly(anomalyType, data)
    if not Capture or not Capture.isEnabled() then return end

    -- Build descriptive message
    local message = '[TRACE ANOMALY] ' .. anomalyType

    -- Build context based on anomaly type
    local context = {
        anomalyType = anomalyType,
        anomalyData = data,
    }

    -- Add specific context per anomaly type
    if anomalyType == Constants.ANOMALY.HIGH_ERROR_RATE then
        message = string.format('[TRACE ANOMALY] High error rate: %.1f%% (%d/%d)',
            (data.errorRate or 0) * 100,
            data.errorCount or 0,
            data.totalTraces or 0
        )
        context.errorRate = data.errorRate
        context.errorCount = data.errorCount
        context.totalTraces = data.totalTraces

    elseif anomalyType == Constants.ANOMALY.SLOW_OPERATIONS then
        message = string.format('[TRACE ANOMALY] Slow operations: avg %dms (max %dms)',
            data.avgDuration or 0,
            data.maxDuration or 0
        )
        context.avgDuration = data.avgDuration
        context.maxDuration = data.maxDuration
        context.sampleSize = data.sampleSize

    elseif anomalyType == Constants.ANOMALY.ERROR_SPIKE then
        message = string.format('[TRACE ANOMALY] Error spike: %s (%d occurrences)',
            data.errorSignature or 'unknown',
            data.count or 0
        )
        context.errorSignature = data.errorSignature
        context.count = data.count

    elseif anomalyType == Constants.ANOMALY.DATABASE_TIMEOUT then
        message = string.format('[TRACE ANOMALY] Database timeouts: %d in last 5 minutes',
            data.count or 0
        )
        context.count = data.count
    end

    -- Add trace timeline if available
    if data.traceSteps then
        context.traceTimeline = data.traceSteps
    end

    -- Add recent traces if available
    if data.recentTraces then
        context.recentTraces = data.recentTraces
    end

    -- Report to Sentry as a warning-level issue
    Capture.reportError({
        message = message,
        category = 'TRACE_ANOMALY',
        level = 'warning',
        source = 'server',
        context = context,
        tags = {
            trace_anomaly = 'true',
            anomaly_type = anomalyType,
        },
    })
end

--- Report a trace error to Sentry
--- @param trace table The completed trace with error
function TraceIntegration.reportTraceError(trace)
    if not Capture or not Capture.isEnabled() then return end
    if not trace then return end

    -- Only report ERROR status traces
    if trace.finalStatus ~= 'ERROR' then return end

    -- Build context from trace
    local context = {
        traceId = trace.traceId,
        action = trace.action,
        duration = trace.duration,
        stepCount = trace.stepCount or (trace.steps and #trace.steps or 0),
        steps = trace.steps,
        initialData = trace.initialData,
        finalData = trace.finalData,
    }

    -- Extract error message
    local errorMessage = 'Trace failed'
    if trace.finalData and trace.finalData.error then
        errorMessage = tostring(trace.finalData.error)
    end

    Capture.reportError({
        message = string.format('[TRACE ERROR] %s: %s', trace.action or 'unknown', errorMessage),
        category = 'TRACE_ERROR',
        level = 'error',
        source = 'server',
        context = context,
        resourceName = trace.resource,
        tags = {
            trace_error = 'true',
            trace_action = trace.action or 'unknown',
        },
    })
end

-------------------------------------------
-- DusaTrace Hooks
-------------------------------------------

--- Hook into DusaTrace alerts system
function TraceIntegration.hookDusaTrace()
    if isHooked then return end

    -- Check if DusaTraceAlerts exists
    if not DusaTraceAlerts then
        -- Will try again when DusaTrace is loaded
        return false
    end

    -- Hook sendAnomaly
    if DusaTraceAlerts.sendAnomaly then
        local originalSendAnomaly = DusaTraceAlerts.sendAnomaly
        DusaTraceAlerts.sendAnomaly = function(anomalyType, data)
            -- Call original (Discord alert)
            originalSendAnomaly(anomalyType, data)

            -- Also send to Sentry
            TraceIntegration.reportAnomaly(anomalyType, data)
        end
    end

    -- Hook onError for trace errors
    if DusaTraceAlerts.onError then
        local originalOnError = DusaTraceAlerts.onError
        DusaTraceAlerts.onError = function(trace)
            -- Call original
            originalOnError(trace)

            -- Also send to Sentry
            TraceIntegration.reportTraceError(trace)
        end
    end

    isHooked = true
    print('^2[Telemetry]^7 DusaTrace integration hooked')
    return true
end

--- Set active trace ID in breadcrumbs (called when trace starts)
--- @param traceId string
--- @param action string|nil
function TraceIntegration.onTraceStart(traceId, action)
    Breadcrumb.setActiveTraceId(traceId)

    Breadcrumb.add({
        category = Constants.BREADCRUMB_CATEGORY.TRACE,
        message = 'Trace started: ' .. (action or 'unknown'),
        level = 'info',
        params = { traceId = traceId, action = action },
    })
end

--- Clear active trace ID (called when trace ends)
--- @param traceId string
--- @param status string
function TraceIntegration.onTraceEnd(traceId, status)
    Breadcrumb.add({
        category = Constants.BREADCRUMB_CATEGORY.TRACE,
        message = 'Trace ended: ' .. status,
        level = status == 'ERROR' and 'error' or 'info',
        params = { traceId = traceId, status = status },
    })

    Breadcrumb.setActiveTraceId(nil)
end

-------------------------------------------
-- Auto-hook on load
-------------------------------------------

-- Try to hook immediately
TraceIntegration.hookDusaTrace()

-- Also try after a delay (in case DusaTrace loads later)
CreateThread(function()
    Wait(1000)
    if not isHooked then
        TraceIntegration.hookDusaTrace()
    end
end)

return TraceIntegration
