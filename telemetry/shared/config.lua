--[[
    Telemetry Configuration
    Default configuration for the unified telemetry system

    OPEN SOURCE - Part of dusa_bridge
]]

TelemetryConfig = TelemetryConfig or {}

-- Rate limiting settings
TelemetryConfig.RateLimit = {
    -- Server-side rate limiting
    ErrorCooldownSeconds = 30,      -- Min seconds between same error signature
    MaxErrorsPerMinute = 20,        -- Global max errors per minute

    -- Client-side rate limiting
    ClientMaxPerMinute = 5,         -- Max client errors per minute per player

    -- NUI rate limiting
    NuiMaxPerMinute = 10,           -- Max NUI errors per minute per player
}

-- Breadcrumb settings
TelemetryConfig.Breadcrumbs = {
    MaxCount = 50,                  -- Max breadcrumbs to keep
    MaxOperationChain = 5,          -- Max operations in chain
    IncludeParams = true,           -- Include full params in breadcrumbs
    MaxParamsSize = 4096,           -- Max serialized params size
}

-- Feature toggles
TelemetryConfig.Features = {
    EnableServerCapture = true,     -- Capture server-side errors
    EnableClientCapture = true,     -- Capture client-side errors
    EnableNuiCapture = true,        -- Capture browser/NUI errors
    EnableTraceIntegration = true,  -- Send trace anomalies to Sentry
    EnableDegradationTracking = true, -- Track graceful degradation
    NotifyPlayerOnError = true,     -- Show error ID notification to players (for testers)
}

-- Sentry settings
TelemetryConfig.Sentry = {
    MinLevel = 5,                   -- Minimum level to send (ERROR = 5)
    RequestTimeout = 3000,          -- HTTP request timeout in ms
    Environment = 'production',     -- Default environment tag
}

-- Privacy settings
TelemetryConfig.Privacy = {
    ExcludePlayerData = true,       -- Never include player names/IPs
    SanitizeServerName = true,      -- Remove IPs from server name
    MaxServerNameLength = 50,       -- Truncate long server names
}

return TelemetryConfig
